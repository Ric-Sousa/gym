import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { createHash, randomBytes } from 'node:crypto';
import Stripe from 'stripe';
import PDFDocument from 'pdfkit';
import { shouldDeactivateExpiredContract } from './contract_expiry.js';
import {
  billingInterval,
  billingTypeLabels,
  calculateBillingPeriod,
  isBillingType,
  type BillingType,
} from './billing.js';
import {
  createNotification,
  escapeHtml,
  sendUserEmail,
  sendUserPush,
} from './notifications.js';
import {
  isLegacyStorageUrl,
  storagePathFromResource,
} from './storage_migration.js';

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();
const messaging = admin.messaging();

// ═══ Stripe ═══
// Não chamar functions.config() durante o carregamento do módulo: o Firebase
// CLI importa este ficheiro para descobrir as exports e esse acesso ao config
// legado pode bloquear a descoberta por 10 segundos. O runtime legado expõe o
// mesmo conteúdo em CLOUD_RUNTIME_CONFIG; as Functions Gen 2 usam variáveis de
// ambiente diretamente.
function legacyRuntimeConfig(): Record<string, any> {
  const raw = process.env.CLOUD_RUNTIME_CONFIG;
  if (!raw) return {};
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch (_) {
    return {};
  }
}

function runtimeConfig(): Record<string, any> {
  const legacy = legacyRuntimeConfig();
  return {
    ...legacy,
    stripe: {
      ...(legacy.stripe ?? {}),
      ...(process.env.STRIPE_SECRET_KEY
        ? { secret_key: process.env.STRIPE_SECRET_KEY }
        : {}),
      ...(process.env.STRIPE_WEBHOOK_SECRET
        ? { webhook_secret: process.env.STRIPE_WEBHOOK_SECRET }
        : {}),
    },
    resend: {
      ...(legacy.resend ?? {}),
      ...(process.env.RESEND_API_KEY
        ? { api_key: process.env.RESEND_API_KEY }
        : {}),
      ...(process.env.RESEND_FROM_EMAIL
        ? { from_email: process.env.RESEND_FROM_EMAIL }
        : {}),
    },
  };
}

const configured = runtimeConfig();
const stripeConfig = configured.stripe ?? {};
const stripeSecret: string | undefined = stripeConfig.secret_key;
const stripeWebhookSecret: string = stripeConfig.webhook_secret || '';

if (!stripeSecret) {
  console.warn('⚠️  Stripe secret_key não definida.');
}

const stripe = stripeSecret
  ? new Stripe(stripeSecret, { apiVersion: '2025-03-31.basil' as any })
  : null;

const publicAppUrl = 'https://gymbt-4ef87.web.app';
const recoveryTokenLifetimeMs = 7 * 24 * 60 * 60 * 1000;

/**
 * Keeps the Stripe return on the same origin that started the checkout. This
 * matters on Flutter Web development servers because Firebase Auth persistence
 * is scoped to an origin. Never accept an arbitrary origin from the client.
 */
function paymentReturnOrigin(value: unknown): string {
  if (typeof value !== 'string' || value.length === 0) return publicAppUrl;
  try {
    const parsed = new URL(value);
    const isProduction =
      parsed.origin === 'https://gymbt-4ef87.web.app' ||
      parsed.origin === 'https://gymbt-4ef87.firebaseapp.com';
    const isLocal =
      (parsed.protocol === 'http:' || parsed.protocol === 'https:') &&
      (parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1');
    return isProduction || isLocal ? parsed.origin : publicAppUrl;
  } catch (_) {
    return publicAppUrl;
  }
}

function hashRecoveryToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

async function issuePaymentRecovery(
  paymentId: string,
  userId: string,
  reason: 'failed' | 'overdue',
): Promise<void> {
  const token = randomBytes(32).toString('base64url');
  const tokenHash = hashRecoveryToken(token);
  const expiresAt = new Date(Date.now() + recoveryTokenLifetimeMs);
  const previousTokens = await db.collection('paymentRecoveryTokens')
    .where('paymentId', '==', paymentId)
    .where('usedAt', '==', null)
    .get();
  const revokeBatch = db.batch();
  for (const previous of previousTokens.docs) {
    revokeBatch.update(previous.ref, {
      revokedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  if (!previousTokens.empty) await revokeBatch.commit();
  await db.collection('paymentRecoveryTokens').doc(tokenHash).set({
    paymentId,
    userId,
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    usedAt: null,
  });
  await db.collection('pagamentos').doc(paymentId).update({
    recoveryLastSentAt: admin.firestore.FieldValue.serverTimestamp(),
    recoveryTokenExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
  }).catch(() => undefined);

  const userDoc = await db.collection('users').doc(userId).get();
  const user = userDoc.data() ?? {};
  const name = String(user.nome ?? 'Cliente');
  const payment = await db.collection('pagamentos').doc(paymentId).get();
  const amount = Number(payment.data()?.valor ?? 0).toFixed(2);
  const recoveryUrl = `${publicAppUrl}/?recoveryToken=${encodeURIComponent(token)}`;
  const title = reason === 'failed'
    ? 'Pagamento recusado — regulariza a tua mensalidade'
    : 'Mensalidade em atraso — regulariza o teu acesso';
  const body = reason === 'failed'
    ? `A cobrança de ${amount} EUR não foi concluída. Usa o link para pagar manualmente.`
    : `A mensalidade de ${amount} EUR está em atraso. Usa o link para recuperar o acesso.`;

  await createNotification({
    userId,
    type: 'payment_recovery',
    title,
    body,
    action: 'payment_recovery',
    paymentId,
    metadata: { recoveryUrl },
  });
  await sendUserPush(userId, title, body, {
    type: 'payment_recovery',
    paymentId,
    link: recoveryUrl,
  });
  if (typeof user.email === 'string' && user.email.length > 0) {
    await sendUserEmail(
      user.email,
      title,
      `<p>Olá ${escapeHtml(name)},</p><p>${escapeHtml(body)}</p>` +
        `<p><a href="${recoveryUrl}">Abrir portal de pagamento seguro</a></p>` +
        `<p>Este link expira em 7 dias.</p>`,
    );
  }
}

// ──────────── AUTH ────────────

export const onUserCreated = functions.auth.user().onCreate(async (user) => {
  await db.collection('users').doc(user.uid).set({
    nome: user.displayName ?? user.email?.split('@')[0] ?? 'Novo Aluno',
    email: user.email ?? '',
    role: 'aluno',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log(`User doc created for ${user.uid}`);
});

// ──────────── CALLABLES ────────────

// ═══ CREATE STUDENT (onRequest = HTTP puro, sem verificação automática de auth) ═══
const createStudentApp = require('express')();
createStudentApp.use(require('express').json());

function applyRestrictedCors(req: any, res: any, next: any): void {
  const origin = typeof req.headers.origin === 'string' ? req.headers.origin : '';
  const allowed = [
    publicAppUrl,
    'https://gymbt-4ef87.firebaseapp.com',
    'http://localhost:5000',
    'http://localhost:3000',
  ];
  if (allowed.includes(origin)) res.set('Access-Control-Allow-Origin', origin);
  res.set('Vary', 'Origin');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  next();
}

function bearerToken(req: any): string {
  const header = req.headers.authorization;
  if (typeof header !== 'string' || !header.startsWith('Bearer ')) return '';
  return header.slice('Bearer '.length).trim();
}

const httpRateLimitWindowMs = 60 * 1000;

/**
 * Persistent rate limit for privileged HTTP endpoints. In-memory limits are
 * insufficient because Cloud Functions can serve consecutive requests on
 * different instances.
 */
async function consumeHttpRateLimit(
  callerUid: string,
  action: 'createStudent' | 'deleteStudent',
): Promise<void> {
  const key = createHash('sha256')
    .update(`${action}:${callerUid}`)
    .digest('hex');
  const ref = db.collection('httpRateLimits').doc(key);
  const now = Date.now();

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const lastAt = snapshot.data()?.lastAt;
    const lastMillis = lastAt instanceof admin.firestore.Timestamp
      ? lastAt.toMillis()
      : 0;
    if (lastMillis > 0 && now - lastMillis < httpRateLimitWindowMs) {
      const error = new Error('HTTP rate limit exceeded');
      (error as Error & { code?: string }).code = 'resource-exhausted';
      throw error;
    }
    transaction.set(ref, {
      uid: callerUid,
      action,
      lastAt: admin.firestore.Timestamp.fromMillis(now),
      expiresAt: admin.firestore.Timestamp.fromMillis(
        now + httpRateLimitWindowMs * 2,
      ),
    });
  });
}

createStudentApp.use(applyRestrictedCors);

createStudentApp.options('/', (_req: any, res: any) => { res.status(204).send(''); });

createStudentApp.post('/', async (req: any, res: any) => {
  // Aceita ambos os formatos: {data: {...}} (onCall antigo) ou fields diretos
  const d = (req.body && req.body.data) ? req.body.data : (req.body || {});
  const { nome, email, personalId, password } = d;
  const isActive = d.isActive !== false;
  const authToken = bearerToken(req);

  console.log('createStudent request received', { hasName: Boolean(nome), hasEmail: Boolean(email) });

  if (!nome || !email) {
    res.status(400).json({ error: { message: 'Nome e email obrigatórios.' } });
    return;
  }

  if (!authToken) {
    res.status(401).json({ error: { message: 'Authorization Bearer obrigatório.' } });
    return;
  }

  let callerUid: string;
  try {
    const decoded = await auth.verifyIdToken(authToken);
    callerUid = decoded.uid;
  } catch (_) {
    res.status(401).json({ error: { message: 'Token inválido. Tenta sair e entrar novamente.' } });
    return;
  }

  const callerDoc = await db.collection('users').doc(callerUid).get();
  if (callerDoc.data()?.role !== 'admin') {
    res.status(403).json({ error: { message: 'Apenas admin.' } });
    return;
  }

  try {
    await consumeHttpRateLimit(callerUid, 'createStudent');
  } catch (error: any) {
    if (error?.code === 'resource-exhausted') {
      res.status(429).json({ error: { message: 'Tenta novamente dentro de um minuto.' } });
    } else {
      console.error('Could not apply create-student rate limit', error);
      res.status(503).json({ error: { message: 'Serviço temporariamente indisponível.' } });
    }
    return;
  }

  try {
    const existingUser = await auth.getUserByEmail(email);
    if (existingUser) {
      const existingProfile = await db.collection('users').doc(existingUser.uid).get();
      if (existingProfile.data()?.role === 'admin') {
        res.status(403).json({ error: { message: 'Não é permitido converter um administrador em aluno.' } });
        return;
      }
      await db.collection('users').doc(existingUser.uid).set({
        nome, email, role: 'aluno',
        ...(personalId ? { personalId } : {}),
        isActive,
        ...(isActive ? {
          deactivatedAt: admin.firestore.FieldValue.delete(),
          contractEndsAt: admin.firestore.FieldValue.delete(),
        } : {
          deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      res.json({ uid: existingUser.uid, email, alreadyExists: true });
      return;
    }
  } catch (error: any) {
    if (error?.code !== 'auth/user-not-found') {
      res.status(500).json({ error: { message: 'Não foi possível verificar o e-mail.' } });
      return;
    }
  }

  try {
    const temporaryPassword = password || `${randomBytes(18).toString('base64url')}A1!`;
    const userRecord = await auth.createUser({ email, password: temporaryPassword, displayName: nome });
    // Todo o aluno criado pelo admin começa com um período inicial de um mês.
    // O cálculo usa meses de calendário: 15/08 -> 15/09, incluindo a
    // proteção para meses que não têm o mesmo número de dia.
    const activationPeriod = calculateBillingPeriod(new Date(), 'mensal');
    await db.collection('users').doc(userRecord.uid).set({
      nome, email, role: 'aluno',
      personalId: personalId || null,
      pesoAtual: null, altura: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true,
      contractEndsAt: admin.firestore.Timestamp.fromDate(activationPeriod.end),
      mustResetPassword: !password,
    });
    if (!password) {
      const resetLink = await auth.generatePasswordResetLink(email);
      await sendUserEmail(
        email,
        'Define a tua palavra-passe — GymBT',
        `<p>Olá ${escapeHtml(nome)},</p><p>Usa o seguinte link para definires a tua palavra-passe de acesso:</p><p><a href="${resetLink}">Definir palavra-passe</a></p>`,
      );
    }
    res.json({ uid: userRecord.uid, email, created: true, passwordResetEmailSent: !password });
  } catch (e: any) {
    res.status(400).json({ error: { message: e.message || 'Erro ao criar utilizador.' } });
  }
});

export const createStudentHttp = functions.region('europe-west1').https.onRequest(createStudentApp);

async function deleteQueryDocuments(
  collection: string,
  field: string,
  value: unknown,
): Promise<void> {
  while (true) {
    const snapshot = await db.collection(collection).where(field, '==', value).limit(400).get();
    if (snapshot.empty) return;
    const batch = db.batch();
    for (const document of snapshot.docs) batch.delete(document.ref);
    await batch.commit();
  }
}

async function purgeStudentData(userId: string): Promise<void> {
  const userRef = db.collection('users').doc(userId);
  // recursiveDelete removes all private subcollections (questionnaire, diary,
  // progress, plans and logs), not just the profile document.
  await db.recursiveDelete(userRef);

  const directRooms = await db.collection('chat')
    .where('participantIds', 'array-contains', userId)
    .get();
  for (const room of directRooms.docs) {
    await db.recursiveDelete(room.ref);
    await admin.storage().bucket().deleteFiles({ prefix: `chat_audio/${room.id}/` });
    await admin.storage().bucket().deleteFiles({ prefix: `chat_attachments/${room.id}/` });
  }

  const groups = await db.collection('grupos')
    .where('membros', 'array-contains', userId)
    .get();
  const groupBatch = db.batch();
  for (const group of groups.docs) {
    if (group.data().criadoPor === userId) {
      groupBatch.delete(group.ref);
    } else {
      groupBatch.update(group.ref, {
        membros: admin.firestore.FieldValue.arrayRemove(userId),
      });
    }
  }
  if (!groups.empty) await groupBatch.commit();

  await deleteQueryDocuments('agenda', 'studentId', userId);
  await deleteQueryDocuments('notificacoes', 'userId', userId);
  await deleteQueryDocuments('paymentRecoveryTokens', 'userId', userId);

  const payments = await db.collection('pagamentos').where('userId', '==', userId).get();
  for (const payment of payments.docs) {
    const stripeSubscriptionId = payment.data().stripeSubscriptionId;
    if (stripe && stripeSubscriptionId) {
      await stripe.subscriptions.cancel(String(stripeSubscriptionId)).catch((error) => {
        console.warn('Could not cancel subscription during student purge', {
          paymentId: payment.id,
          type: error?.type,
          code: error?.code,
        });
      });
    }
    // Paid records may be retained for legal/accounting reasons, but no longer
    // point at an existing personal account.
    if (payment.data().status === 'paid') {
      await payment.ref.update({
        userId: null,
        anonymizedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      await payment.ref.delete();
    }
  }

  await admin.storage().bucket().deleteFiles({ prefix: `users/${userId}/` });
}

// ═══ DELETE STUDENT (onRequest) ═══
const deleteStudentApp = require('express')();
deleteStudentApp.use(require('express').json());
deleteStudentApp.use(applyRestrictedCors);
deleteStudentApp.options('/', (_req: any, res: any) => { res.status(204).send(''); });
deleteStudentApp.post('/', async (req: any, res: any) => {
  const d = (req.body && req.body.data) ? req.body.data : (req.body || {});
  const { userId } = d;
  const authToken = bearerToken(req);

  if (!userId) {
    res.status(400).json({ error: { message: 'userId obrigatório.' } });
    return;
  }
  if (!authToken) {
    res.status(401).json({ error: { message: 'Authorization Bearer obrigatório.' } });
    return;
  }

  let callerUid: string;
  try {
    const decoded = await auth.verifyIdToken(authToken);
    callerUid = decoded.uid;
  } catch (_) {
    res.status(401).json({ error: { message: 'Token inválido.' } });
    return;
  }

  const callerDoc = await db.collection('users').doc(callerUid).get();
  if (callerDoc.data()?.role !== 'admin') {
    res.status(403).json({ error: { message: 'Apenas admin.' } });
    return;
  }

  try {
    await consumeHttpRateLimit(callerUid, 'deleteStudent');
  } catch (error: any) {
    if (error?.code === 'resource-exhausted') {
      res.status(429).json({ error: { message: 'Tenta novamente dentro de um minuto.' } });
    } else {
      console.error('Could not apply delete-student rate limit', error);
      res.status(503).json({ error: { message: 'Serviço temporariamente indisponível.' } });
    }
    return;
  }

  // Não deixar o admin apagar-se a si próprio nem apagar outro administrador
  // através de um endpoint destinado a alunos.
  if (userId === callerUid) {
    res.status(400).json({ error: { message: 'Não podes apagar a tua própria conta.' } });
    return;
  }
  const targetDoc = await db.collection('users').doc(userId).get();
  if (targetDoc.data()?.role === 'admin') {
    res.status(403).json({ error: { message: 'A eliminação de administradores requer um fluxo próprio.' } });
    return;
  }

  // Primeiro limpa os dados. Se houver uma falha transitória, a conta Auth
  // permanece disponível para repetir a operação sem deixar uma conta órfã.
  try {
    await purgeStudentData(userId);
  } catch (error) {
    console.error('Student purge failed', { userId, error });
    res.status(500).json({
      error: { message: 'Não foi possível concluir a limpeza de dados. Tenta novamente.' },
    });
    return;
  }

  try {
    await auth.deleteUser(userId);
  } catch (e: any) {
    if (e.code !== 'auth/user-not-found') {
      res.status(400).json({ error: { message: e.message || 'Erro ao apagar utilizador.' } });
      return;
    }
  }
  res.json({ success: true, message: 'Aluno eliminado com sucesso.' });
});

export const deleteStudentHttp = functions.region('europe-west1').https.onRequest(deleteStudentApp);

type StorageMigrationUpdate = {
  ref: any;
  data: Record<string, any>;
};

function migrateStorageValue(value: unknown, paths: Set<string>): unknown {
  if (!isLegacyStorageUrl(value)) return value;
  const path = storagePathFromResource(value);
  if (!path) return value;
  paths.add(path);
  return path;
}

function migrateStorageMap(
  source: Record<string, any>,
  paths: Set<string>,
): Record<string, any> {
  const data = { ...source };
  for (const field of [
    'fotoPerfil',
    'imagemUrl',
    'criadoPorFoto',
    'audioUrl',
    'attachmentUrl',
    'videoUrl',
    'comprovativoUrl',
  ]) {
    if (field in data) data[field] = migrateStorageValue(data[field], paths);
  }
  if (Array.isArray(data.fotos)) {
    data.fotos = data.fotos.map((value: unknown) =>
      migrateStorageValue(value, paths));
  }
  for (const field of ['fotosPorPosicao', 'membrosFotos']) {
    if (data[field] && typeof data[field] === 'object' &&
        !Array.isArray(data[field])) {
      data[field] = Object.fromEntries(
        Object.entries(data[field]).map(([key, value]) => [
          key,
          migrateStorageValue(value, paths),
        ]),
      );
    }
  }
  return data;
}

function hasStorageMigration(
  before: Record<string, any>,
  after: Record<string, any>,
): boolean {
  for (const field of [
    'fotoPerfil',
    'imagemUrl',
    'criadoPorFoto',
    'audioUrl',
    'attachmentUrl',
    'videoUrl',
    'comprovativoUrl',
  ]) {
    if (before[field] !== after[field]) return true;
  }
  return JSON.stringify(before.fotos ?? null) !== JSON.stringify(after.fotos ?? null) ||
    JSON.stringify(before.fotosPorPosicao ?? null) !==
      JSON.stringify(after.fotosPorPosicao ?? null) ||
    JSON.stringify(before.membrosFotos ?? null) !==
      JSON.stringify(after.membrosFotos ?? null);
}

/**
 * Migra URLs Firebase Storage legadas para paths. O fluxo é explicitamente
 * opt-in e suporta dryRun; nunca é executado automaticamente por um trigger.
 */
export const backfillStoragePaths = functions.region('europe-west1').https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
    }
    const caller = await db.collection('users').doc(context.auth.uid).get();
    if (caller.data()?.role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Apenas admin.');
    }

    const limit = Math.min(
      Math.max(Number.isInteger(data?.limit) ? Number(data.limit) : 100, 1),
      400,
    );
    // A migração é dry-run por defeito. Uma escrita/revogação exige a flag
    // explícita `apply: true`, reduzindo o risco de uma chamada administrativa
    // incompleta alterar documentos ou invalidar tokens.
    const apply = data?.apply === true;
    const dryRun = !apply;
    const revokeTokens = data?.revokeTokens === true && apply;
    const paths = new Set<string>();
    const updates = new Map<string, StorageMigrationUpdate>();
    let scanned = 0;

    const collect = (snapshot: FirebaseFirestore.QuerySnapshot): void => {
      for (const doc of snapshot.docs) {
        scanned++;
        const before = doc.data();
        const after = migrateStorageMap(before, paths);
        if (hasStorageMigration(before, after)) {
          updates.set(doc.ref.path, { ref: doc.ref, data: after });
        }
      }
    };

    const users = await db.collection('users').limit(limit).get();
    collect(users);
    for (const user of users.docs) {
      collect(await user.ref.collection('progresso').limit(limit).get());
      collect(await user.ref.collection('progressVideos').limit(limit).get());
    }

    const groups = await db.collection('grupos').limit(limit).get();
    collect(groups);
    for (const group of groups.docs) {
      collect(await group.ref.collection('mensagens').limit(limit).get());
    }

    const rooms = await db.collection('chat').limit(limit).get();
    collect(rooms);
    for (const room of rooms.docs) {
      collect(await room.ref.collection('mensagens').limit(limit).get());
    }

    collect(await db.collection('pagamentos').limit(limit).get());

    if (apply) {
      const entries = [...updates.values()];
      for (let offset = 0; offset < entries.length; offset += 400) {
        const batch = db.batch();
        for (const update of entries.slice(offset, offset + 400)) {
          batch.set(update.ref, update.data, { merge: true });
        }
        await batch.commit();
      }
    }

    if (revokeTokens) {
      const bucket = admin.storage().bucket();
      await Promise.all([...paths].map(async (path) => {
        await bucket.file(path).setMetadata({
          metadata: { firebaseStorageDownloadTokens: null },
        });
      }));
    }

    return {
      apply,
      dryRun,
      revokeTokens,
      scanned,
      migrated: updates.size,
      paths: paths.size,
    };
  },
);

export const acceptPrivacyPolicy = functions.region('europe-west1').https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
  }
  const uid = context.auth.uid;
  const version = typeof data?.version === 'string' ? data.version.trim() : '';
  if (version !== 'privacy-2026-08-draft') {
    throw new functions.https.HttpsError('failed-precondition', 'Versão da política inválida.');
  }
  const platform = typeof data?.platform === 'string'
    ? data.platform.trim().slice(0, 40)
    : 'unknown';
  const userAgent = typeof data?.userAgent === 'string'
    ? data.userAgent.trim().slice(0, 500)
    : '';
  const userRef = db.collection('users').doc(uid);
  const auditRef = userRef.collection('privacyConsentAudit').doc(version);
  await db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    if (!userSnapshot.exists || userSnapshot.data()?.role === 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Perfil não elegível.');
    }
    transaction.set(userRef, {
      privacyPolicyAcceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      privacyPolicyVersion: version,
    }, { merge: true });
    transaction.set(auditRef, {
      version,
      platform,
      ...(userAgent ? { userAgent } : {}),
      acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      uid,
    }, { merge: false });
  });
  return { success: true, version };
});

export const registerFcmToken = functions.region('europe-west1').https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
  const token = typeof data?.token === 'string' ? data.token.trim() : '';
  if (token.length < 20 || token.length > 4096) {
    throw new functions.https.HttpsError('invalid-argument', 'Token FCM inválido.');
  }
  await db.collection('users').doc(context.auth.uid).update({
    fcmToken: token,
    fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { success: true };
});

export const removeFcmToken = functions.region('europe-west1').https.onCall(async (_data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
  await db.collection('users').doc(context.auth.uid).update({
    fcmToken: admin.firestore.FieldValue.delete(),
    fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { success: true };
});

export const seedFoods = functions.region('europe-west1').https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
  const callerDoc = await db.collection('users').doc(context.auth.uid).get();
  if (callerDoc.data()?.role !== 'admin') throw new functions.https.HttpsError('permission-denied', 'Apenas admin.');

  const { alimentos } = data;
  if (!alimentos || !Array.isArray(alimentos)) throw new functions.https.HttpsError('invalid-argument', 'Array obrigatório.');

  let added = 0, skipped = 0;
  for (const a of alimentos) {
    if (!a.nome) { skipped++; continue; }
    const existing = await db.collection('alimentos').where('nome', '==', a.nome).limit(1).get();
    if (!existing.empty) { skipped++; continue; }
    await db.collection('alimentos').add({
      nome: a.nome,
      caloriasPor100g: a.caloriasPor100g ?? 0,
      proteinasPor100g: a.proteinasPor100g ?? null,
      hidratosPor100g: a.hidratosPor100g ?? null,
      gordurasPor100g: a.gordurasPor100g ?? null,
      categoria: a.categoria ?? null,
    });
    added++;
  }
  return { added, skipped };
});

// ═══ OPEN FOOD FACTS SEARCH ═══
// The browser must not call Open Food Facts directly: its search endpoint does
// not expose CORS headers consistently. Keeping this request server-side also
// lets us provide the required application User-Agent without exposing it in
// every client request.
function normaliseFoodSearchTerm(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

function singularFoodSearchTerm(value: string): string {
  if (value.endsWith('ões') && value.length > 4) {
    return `${value.slice(0, -3)}ão`;
  }
  if (value.endsWith('ães') && value.length > 4) {
    return `${value.slice(0, -3)}ão`;
  }
  // Para alimentos, a remoção do s final cobre casos como ovos -> ovo,
  // maçãs -> maca, queijos -> queijo e massas -> massa.
  if (value.endsWith('s') && value.length > 3) {
    return value.slice(0, -1);
  }
  return value;
}

function foodSearchVariants(query: string): string[] {
  const normalised = normaliseFoodSearchTerm(query);
  const singular = singularFoodSearchTerm(normalised);
  const aliases: Record<string, string[]> = {
    leite: ['milk'],
    pao: ['bread'],
    arroz: ['rice'],
    massa: ['pasta'],
    macarrao: ['pasta'],
    frango: ['chicken'],
    peru: ['turkey'],
    carne: ['meat', 'beef'],
    vaca: ['beef'],
    porco: ['pork'],
    peixe: ['fish'],
    atum: ['tuna'],
    ovo: ['egg'],
    queijo: ['cheese'],
    iogurte: ['yogurt'],
    manteiga: ['butter'],
    aveia: ['oats'],
    banana: ['banana'],
    maca: ['apple'],
    batata: ['potato'],
    tomate: ['tomato'],
    agua: ['water'],
  };

  return [...new Set([
    query.trim(),
    normalised,
    singular,
    ...(aliases[normalised] ?? []),
    ...(aliases[singular] ?? []),
  ])]
    .filter((term) => term.length >= 3)
    // Mantemos a variante inglesa mesmo quando a palavra original tem
    // acento/plural (por exemplo: maçãs -> maca -> apple).
    .slice(0, 6);
}

async function fetchOpenFoodFactsProducts(
  searchTerm: string,
): Promise<Record<string, unknown>[]> {
  const hosts = [
    'https://pt.openfoodfacts.org/cgi/search.pl',
    'https://world.openfoodfacts.org/cgi/search.pl',
  ];
  const params = new URLSearchParams({
    search_terms: searchTerm,
    search_simple: '1',
    action: 'process',
    json: '1',
    page_size: '20',
    lc: 'pt',
    fields:
        'code,product_name,product_name_pt,languages_codes,nutriments,categories_tags_pt,categories_tags',
  });

  for (const host of hosts) {
    try {
      const response = await fetch(`${host}?${params.toString()}`, {
        headers: {
          'User-Agent': 'GymApp/1.0 (https://github.com/Ric-Sousa/gym)',
          Accept: 'application/json',
        },
        signal: AbortSignal.timeout(7000),
      });
      if (!response.ok) {
        console.warn(`Open Food Facts returned HTTP ${response.status}.`);
        continue;
      }

      const body: unknown = await response.json();
      if (!body || typeof body !== 'object') continue;
      const products = (body as { products?: unknown }).products;
      if (!Array.isArray(products)) continue;
      const validProducts = products.filter(
        (product): product is Record<string, unknown> =>
            Boolean(product) && typeof product === 'object',
      ).filter((product) => {
        const translatedName = typeof product.product_name_pt === 'string'
          ? product.product_name_pt.trim()
          : '';
        const mainName = typeof product.product_name === 'string'
          ? product.product_name.trim()
          : '';
        return (translatedName.length > 0 || mainName.length > 0) &&
            hasUsableNutrition(product);
      });
      // Uma resposta não vazia, mas composta apenas por fichas incompletas,
      // não deve impedir a tentativa no domínio mundial.
      if (validProducts.length > 0) return validProducts;
    } catch (error) {
      console.warn(`Open Food Facts request failed for ${host}:`, error);
    }
  }
  return [];
}

/**
 * Obtém uma lista inicial para os seletores que abrem sem pesquisa.
 * Mantemos os termos aqui para usar exatamente a mesma fonte Open Food Facts
 * da pesquisa, mas sem fazer uma chamada impossível com query vazia.
 */
async function fetchOpenFoodFactsCatalog(): Promise<Record<string, unknown>[]> {
  const terms = ['arroz', 'frango', 'ovo', 'banana', 'iogurte', 'aveia'];
  const responses = await Promise.all(
    terms.map((term) => fetchOpenFoodFactsProducts(term)),
  );
  const products: Record<string, unknown>[] = [];
  const seenCodes = new Set<string>();
  const seenNames = new Set<string>();

  for (const response of responses) {
    for (const product of response) {
      const code = typeof product.code === 'string' ? product.code.trim() : '';
      const rawName = typeof product.product_name_pt === 'string' &&
          product.product_name_pt.trim().length > 0
        ? product.product_name_pt
        : product.product_name;
      const name = typeof rawName === 'string' ? rawName.trim() : '';
      const nameKey = normaliseFoodSearchTerm(name);
      if ((code && seenCodes.has(code)) ||
          (nameKey && seenNames.has(nameKey))) {
        continue;
      }
      if (code) seenCodes.add(code);
      if (nameKey) seenNames.add(nameKey);
      products.push(product);
      if (products.length >= 40) return products;
    }
  }
  return products;
}

export const searchOpenFoodFacts = functions.region('europe-west1').https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
  }

  const query = typeof data?.query === 'string' ? data.query.trim() : '';
  if ((query.length > 0 && query.length < 3) || query.length > 80) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'A pesquisa deve ter entre 3 e 80 caracteres, ou ficar vazia para carregar a lista inicial.',
    );
  }

  try {
    if (query.length === 0) {
      return { products: await fetchOpenFoodFactsCatalog() };
    }

    const products: Record<string, unknown>[] = [];
    const seenCodes = new Set<string>();
    const seenNames = new Set<string>();
    const searchTerms = foodSearchVariants(query);
    const portugueseQuery = normaliseFoodSearchTerm(query);

    for (const searchTerm of searchTerms) {
      const responseProducts = await fetchOpenFoodFactsProducts(searchTerm);
      if (responseProducts.length === 0) continue;

      const rankedProducts = responseProducts
        .filter((product): product is Record<string, unknown> =>
          Boolean(product) && typeof product === 'object',
        )
        // A API devolve frequentemente fichas sem nutrientes. Não as
        // contamos como resultados, porque a app não as consegue mostrar.
        .filter(hasUsableNutrition)
        .filter((product) =>
          isRelevantFoodResult(product, portugueseQuery),
        )
        .sort((a, b) =>
          portugueseProductRank(b, portugueseQuery) -
          portugueseProductRank(a, portugueseQuery),
        );

      for (const product of rankedProducts) {
        const code = typeof product.code === 'string'
          ? product.code.trim()
          : '';
        const rawName = typeof product.product_name_pt === 'string' &&
            product.product_name_pt.trim().length > 0
          ? product.product_name_pt
          : product.product_name;
        const name = typeof rawName === 'string' ? rawName.trim() : '';
        const nameKey = normaliseFoodSearchTerm(name);
        if ((code && seenCodes.has(code)) ||
            (nameKey && seenNames.has(nameKey))) {
          continue;
        }
        if (code) seenCodes.add(code);
        if (nameKey) seenNames.add(nameKey);
        products.push(product);
        if (products.length >= 40) break;
      }

      if (products.length >= 40) break;
      // Continua após uma resposta vazia/incompleta para permitir o alias
      // inglês, mas para assim que já temos resultados suficientes para a
      // lista. Isto evita várias chamadas sequenciais desnecessárias.
      if (products.length >= 8) break;
    }

    products.sort((a, b) =>
      portugueseProductRank(b, portugueseQuery) -
      portugueseProductRank(a, portugueseQuery),
    );
    return { products: products.slice(0, 20) };
  } catch (error) {
    console.warn('Open Food Facts request failed:', error);
    return { products: [] };
  }
});

function isRelevantFoodResult(
  product: Record<string, unknown>,
  portugueseQuery: string,
): boolean {
  // A pesquisa do Open Food Facts também procura ingredientes e descrições.
  // Por isso, a resposta da API não é suficiente: o termo tem de aparecer
  // no nome visível ou numa categoria do próprio produto.
  // Os aliases ingleses servem apenas para encontrar mais fichas na API;
  // nunca podem, por si só, tornar um nome inglês irrelevante num resultado.
  const queryTerms = [...new Set([
    portugueseQuery,
    singularFoodSearchTerm(portugueseQuery),
  ])].filter((term) => term.length >= 3);

  const names = [product.product_name_pt, product.product_name]
    .filter((name): name is string => typeof name === 'string')
    .map(normaliseFoodSearchTerm);
  if (queryTerms.some((term) =>
      names.some((name) => name.includes(term)))) {
    return true;
  }

  const categories = [product.categories_tags_pt, product.categories_tags]
    .flatMap((value) => Array.isArray(value) ? value : [])
    .filter((value): value is string => typeof value === 'string')
    .map(normaliseFoodSearchTerm);
  return queryTerms.some((term) =>
    categories.some((category) => category.includes(term)),
  );
}

function hasUsableNutrition(product: Record<string, unknown>): boolean {
  const nutriments = product.nutriments;
  if (!nutriments || typeof nutriments !== 'object') return false;
  const values = nutriments as Record<string, unknown>;
  return ['energy-kcal_100g', 'energy_100g'].some((key) => {
    const value = values[key];
    if (typeof value === 'number') return Number.isFinite(value);
    if (typeof value === 'string') return Number.isFinite(Number(value));
    return false;
  });
}

function portugueseProductRank(
  product: Record<string, unknown>,
  portugueseQuery: string,
): number {
  let rank = 0;
  // Os aliases ingleses servem apenas para encontrar mais fichas na API;
  // nunca podem, por si só, tornar um nome inglês irrelevante num resultado.
  const queryTerms = [...new Set([
    portugueseQuery,
    singularFoodSearchTerm(portugueseQuery),
  ])].filter((term) => term.length >= 3);
  const names = [product.product_name_pt, product.product_name]
    .filter((name): name is string => typeof name === 'string')
    .map(normaliseFoodSearchTerm);

  if (names.some((name) => name.includes(portugueseQuery))) rank += 10;
  if (names.some((name) =>
      queryTerms.some((term) => name.includes(term)))) {
    rank += 5;
  }
  if (typeof product.product_name_pt === 'string' &&
      product.product_name_pt.trim().length > 0) {
    rank += 3;
  }
  if (hasPortugueseLanguage(product)) rank += 2;
  return rank;
}

function hasPortugueseLanguage(product: Record<string, unknown>): boolean {
  const languages = product.languages_codes;
  if (Array.isArray(languages)) {
    return languages.some((language) =>
      String(language).toLowerCase().startsWith('pt'),
    );
  }
  if (languages && typeof languages === 'object') {
    return Object.keys(languages).some((language) =>
      language.toLowerCase().startsWith('pt'),
    );
  }
  return false;
}

export const requestProgress = functions.region('europe-west1').https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
  const callerDoc = await db.collection('users').doc(context.auth.uid).get();
  if (callerDoc.data()?.role !== 'admin') throw new functions.https.HttpsError('permission-denied', 'Apenas admin.');

  const { userId } = data;
  if (!userId) throw new functions.https.HttpsError('invalid-argument', 'userId obrigatório.');

  await db.collection('users').doc(userId).set({
    hasPendingProgress: true,
    progressRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  const adminName = callerDoc.data()?.nome ?? 'Personal Trainer';
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (fcmToken) {
      await messaging.send({
        token: fcmToken,
        notification: {
          title: 'Avaliação de Progresso 📊',
          body: `${adminName} pediu a tua avaliação mensal!`,
        },
        data: { type: 'progress_request', requestedBy: context.auth.uid },
      });
    }
  } catch (e) { console.error('FCM error:', e); }

  return { success: true, message: 'Pedido de progresso enviado.' };
});

export const createPaymentSchedule = functions.region('europe-west1').https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
  const callerDoc = await db.collection('users').doc(context.auth.uid).get();
  if (callerDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Apenas admin.');
  }

  const { userId, valor, tipoMensalidade } = data as {
    userId?: unknown;
    valor?: unknown;
    tipoMensalidade?: unknown;
  };
  if (typeof userId !== 'string' || userId.length === 0 ||
      typeof valor !== 'number' || !Number.isFinite(valor) || valor <= 0 ||
      !isBillingType(tipoMensalidade)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Aluno, valor e tipo de mensalidade são obrigatórios.',
    );
  }

  const studentRef = db.collection('users').doc(userId);
  const studentDoc = await studentRef.get();
  if (!studentDoc.exists || studentDoc.data()?.role === 'admin') {
    throw new functions.https.HttpsError('not-found', 'Aluno não encontrado.');
  }

  const now = new Date();
  const candidateStarts: Date[] = [now];
  const currentContractEnd = asDate(studentDoc.data()?.contractEndsAt);
  if (currentContractEnd && currentContractEnd > now) {
    candidateStarts.push(currentContractEnd);
  }

  const existingPayments = await db.collection('pagamentos')
    .where('userId', '==', userId)
    .get();
  for (const payment of existingPayments.docs) {
    const periodEnd = asDate(payment.data().periodoFim);
    if (periodEnd && periodEnd > now) candidateStarts.push(periodEnd);
  }

  const periodStart = new Date(Math.max(
    ...candidateStarts.map((date) => date.getTime()),
  ));
  const period = calculateBillingPeriod(periodStart, tipoMensalidade);
  const paymentRef = await db.collection('pagamentos').add({
    userId,
    valor,
    moeda: 'eur',
    status: 'pending',
    tipoMensalidade,
    recorrente: true,
    descricao: `Mensalidade ${billingTypeLabels[tipoMensalidade]}`,
    data: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    periodoInicio: admin.firestore.Timestamp.fromDate(period.start),
    periodoFim: admin.firestore.Timestamp.fromDate(period.end),
    dataVencimento: admin.firestore.Timestamp.fromDate(
      period.start > now ? period.start : now,
    ),
  });

  await createNotification({
    userId,
    type: 'payment_created',
    title: 'Nova cobrança disponível 💳',
    body: `Foi criada uma cobrança de ${valor.toFixed(2)} EUR. Abre o Perfil para pagar ou ativar o automático.`,
    action: 'payment',
    paymentId: paymentRef.id,
  });
  await sendUserPush(
    userId,
    'Nova cobrança disponível 💳',
    `Foi criada uma cobrança de ${valor.toFixed(2)} EUR.`,
    { type: 'payment_created', paymentId: paymentRef.id, link: `${publicAppUrl}/` },
  );

  return {
    paymentId: paymentRef.id,
    periodoInicio: period.start.toISOString(),
    periodoFim: period.end.toISOString(),
  };
});

/** Cancela uma cobrança ainda não paga e interrompe a subscrição Stripe, se existir. */
const cancelPaymentHandler = async (data: any, context: any) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
  }

  const callerDoc = await db.collection('users').doc(context.auth.uid).get();
  if (callerDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Apenas admin.');
  }

  const paymentId = typeof data?.paymentId === 'string' ? data.paymentId.trim() : '';
  if (!paymentId) {
    throw new functions.https.HttpsError('invalid-argument', 'paymentId obrigatório.');
  }

  const paymentRef = db.collection('pagamentos').doc(paymentId);
  const paymentDoc = await paymentRef.get();
  if (!paymentDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Pagamento não encontrado.');
  }

  const payment = paymentDoc.data() ?? {};
  if (payment.status === 'cancelled') {
    return { success: true, paymentId };
  }
  if (payment.status === 'paid' || payment.status === 'refunded') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Um pagamento já concluído ou reembolsado não pode ser cancelado.',
    );
  }

  if (payment.stripeSubscriptionId) {
    if (!stripe) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Stripe não está configurado para cancelar a subscrição.',
      );
    }
    try {
      await stripe.subscriptions.cancel(String(payment.stripeSubscriptionId));
    } catch (error: any) {
      console.error('Stripe subscription cancellation failed', {
        paymentId,
        stripeSubscriptionId: payment.stripeSubscriptionId,
        type: error?.type,
        code: error?.code,
        message: error?.message,
        requestId: error?.requestId,
      });
      throw new functions.https.HttpsError(
        'internal',
        'Não foi possível cancelar a subscrição Stripe.',
      );
    }
  } else if (payment.stripeSessionId && stripe) {
    // Sessões Checkout ainda abertas podem ser expiradas. Sessões já
    // concluídas não entram aqui porque o pagamento teria outro estado.
    try {
      const session = await stripe.checkout.sessions.retrieve(
        String(payment.stripeSessionId),
      );
      if (session.status === 'open') {
        await stripe.checkout.sessions.expire(session.id);
      }
    } catch (error: any) {
      console.warn('Could not expire Stripe checkout session', {
        paymentId,
        stripeSessionId: payment.stripeSessionId,
        type: error?.type,
        code: error?.code,
        message: error?.message,
      });
    }
  }

  await paymentRef.update({
    status: 'cancelled',
    cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
    cancelledBy: context.auth.uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await createNotification({
    userId: String(payment.userId),
    type: 'payment_cancelled',
    title: 'Cobrança cancelada',
    body: 'A cobrança foi cancelada pelo administrador e já não requer pagamento.',
    action: 'payment',
    paymentId,
  });
  await sendUserPush(
    String(payment.userId),
    'Cobrança cancelada',
    'A cobrança foi cancelada pelo administrador.',
    { type: 'payment_cancelled', paymentId, link: `${publicAppUrl}/` },
  );

  return { success: true, paymentId };
};

// A exportação remota cancelPayment é uma callable Gen 1 antiga. Ela não é
// incluída no bundle local para impedir que o Firebase CLI tente validá-la
// como uma alteração Gen 2 -> Gen 1. Ao publicar apenas a nova função, a
// função remota antiga não é apagada.
export const cancelPaymentCallable = functions.region('europe-west1').https.onCall(
  cancelPaymentHandler,
);

/** Agenda o cancelamento da renovação para o fim do período já pago. */
export const cancelPaymentSubscription = functions.region('europe-west1').https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
  const caller = await db.collection('users').doc(context.auth.uid).get();
  if (caller.data()?.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Apenas admin.');
  }
  const paymentId = typeof data?.paymentId === 'string' ? data.paymentId.trim() : '';
  const paymentRef = db.collection('pagamentos').doc(paymentId);
  const paymentDoc = await paymentRef.get();
  const payment = paymentDoc.data();
  if (!paymentDoc.exists || !payment) {
    throw new functions.https.HttpsError('not-found', 'Pagamento não encontrado.');
  }
  if (!payment.stripeSubscriptionId) {
    throw new functions.https.HttpsError('failed-precondition', 'Não existe subscrição automática.');
  }
  if (!stripe) throw new functions.https.HttpsError('failed-precondition', 'Stripe não configurado.');

  try {
    await stripe.subscriptions.update(String(payment.stripeSubscriptionId), {
      cancel_at_period_end: true,
    });
  } catch (error) {
    throw stripeCheckoutHttpsError(error, 'cancelamento da renovação');
  }

  await paymentRef.update({
    subscriptionCancelAtPeriodEnd: true,
    subscriptionCancelRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await createNotification({
    userId: String(payment.userId),
    type: 'subscription_cancelled',
    title: 'Renovação automática desativada',
    body: 'O acesso mantém-se ativo até ao fim do período já pago.',
    action: 'payment',
    paymentId,
  });
  return { success: true, paymentId };
});

export const createPaymentCheckoutSession = functions.region('europe-west1').https.onCall(async (data, context) => {
  if (!stripe) throw new functions.https.HttpsError('failed-precondition', 'Stripe não configurado.');
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');

  const paymentId = typeof data?.paymentId === 'string' ? data.paymentId : '';
  if (!paymentId) {
    throw new functions.https.HttpsError('invalid-argument', 'paymentId obrigatório.');
  }

  const paymentRef = db.collection('pagamentos').doc(paymentId);
  const paymentDoc = await paymentRef.get();
  const payment = paymentDoc.data();
  if (!paymentDoc.exists || !payment) {
    throw new functions.https.HttpsError('not-found', 'Pagamento não encontrado.');
  }
  if (payment.userId !== context.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'Pagamento não pertence ao utilizador.');
  }
  if (payment.status === 'paid' || payment.status === 'refunded') {
    throw new functions.https.HttpsError('failed-precondition', 'Este pagamento já não está disponível.');
  }
  if (payment.stripeSubscriptionId) {
    throw new functions.https.HttpsError('failed-precondition', 'Este pagamento já tem uma subscrição configurada.');
  }
  // Pagamentos antigos podem não ter tipoMensalidade. Mantemos o checkout
  // compatível, assumindo mensalidade nesses registos legados.
  const tipoMensalidade: BillingType = isBillingType(payment.tipoMensalidade)
    ? payment.tipoMensalidade
    : 'mensal';
  const valor = Number(payment.valor);
  if (!Number.isFinite(valor) || valor <= 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'O valor desta cobrança é inválido.',
    );
  }

  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  const user = userDoc.data() ?? {};
  const returnOrigin = paymentReturnOrigin(data?.returnOrigin);
  const periodStart = asDate(payment.periodoInicio);
  const trialEnd = periodStart && periodStart.getTime() > Date.now() + 60_000
    ? Math.floor(periodStart.getTime() / 1000)
    : null;
  const subscriptionData: Record<string, unknown> = {
    metadata: {
      paymentId,
      userId: context.auth.uid,
      tipoMensalidade,
    },
  };
  if (trialEnd != null) subscriptionData.trial_end = trialEnd;

  const interval = billingInterval(tipoMensalidade);
  let session: Stripe.Checkout.Session;
  try {
    session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      line_items: [{
        price_data: {
          currency: 'eur',
          product_data: {
            name: payment.descricao || `Mensalidade ${billingTypeLabels[tipoMensalidade]}`,
          },
          unit_amount: Math.round(valor * 100),
          recurring: interval,
        },
        quantity: 1,
      }],
      ...(typeof user.stripeCustomerId === 'string' && user.stripeCustomerId.length > 0
        ? { customer: user.stripeCustomerId }
        : { customer_email: user.email || undefined }),
      payment_method_collection: 'always',
      subscription_data: subscriptionData as any,
      metadata: { paymentId, userId: context.auth.uid },
      success_url: `${returnOrigin}/?pagamento=sucesso&destino=perfil`,
      cancel_url: `${returnOrigin}/?pagamento=cancelado&destino=perfil`,
    });
  } catch (error) {
    throw stripeCheckoutHttpsError(error, 'subscrição');
  }

  if (!session.url) {
    throw new functions.https.HttpsError(
      'internal',
      'O Stripe não devolveu um endereço de checkout.',
    );
  }

  await paymentRef.update({
    stripeSessionId: session.id,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { url: session.url, paymentId };
});

/**
 * Cria um checkout público de recuperação. O token é aleatório, só o hash é
 * guardado no Firestore e expira em sete dias. Não depende de Firebase Auth,
 * porque o login do cliente fica bloqueado quando existe atraso.
 */
export const createPaymentRecoveryCheckoutSession = functions
  .region('europe-west1')
  .https.onCall(async (data) => {
    if (!stripe) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Stripe não configurado.',
      );
    }
    const token = typeof data?.token === 'string' ? data.token.trim() : '';
    if (token.length < 32) {
      throw new functions.https.HttpsError('invalid-argument', 'Token inválido.');
    }

    const tokenRef = db.collection('paymentRecoveryTokens').doc(hashRecoveryToken(token));
    const tokenDoc = await tokenRef.get();
    const recovery = tokenDoc.data();
    const expiresAt = asDate(recovery?.expiresAt);
    if (!tokenDoc.exists || !recovery || recovery.revokedAt ||
        !expiresAt || expiresAt <= new Date()) {
      throw new functions.https.HttpsError('not-found', 'Este link expirou ou não é válido.');
    }
    if (recovery.checkoutSessionId) {
      try {
        const existingSession = await stripe.checkout.sessions.retrieve(
          String(recovery.checkoutSessionId),
        );
        if (existingSession.url) {
          return { url: existingSession.url, paymentId: String(recovery.paymentId) };
        }
      } catch (_) {
        // Se a sessão antiga já não existe, continua com uma nova apenas se o
        // token ainda não foi consumido.
      }
    }
    if (recovery.usedAt) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Este link já foi utilizado. Usa o checkout já criado ou pede um novo link.',
      );
    }
    const lockAcquired = await db.runTransaction(async (transaction) => {
      const latest = await transaction.get(tokenRef);
      const latestData = latest.data() ?? {};
      const lockDate = asDate(latestData.checkoutLockAt);
      if (latestData.usedAt || latestData.revokedAt ||
          (lockDate && Date.now() - lockDate.getTime() < 10 * 60 * 1000)) {
        return false;
      }
      transaction.update(tokenRef, {
        checkoutLockAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return true;
    });
    if (!lockAcquired) {
      throw new functions.https.HttpsError(
        'aborted',
        'Este link já está a preparar um checkout. Tenta novamente dentro de instantes.',
      );
    }

    const paymentRef = db.collection('pagamentos').doc(String(recovery.paymentId));
    const paymentDoc = await paymentRef.get();
    const payment = paymentDoc.data();
    if (!paymentDoc.exists || !payment || payment.userId !== recovery.userId) {
      throw new functions.https.HttpsError('not-found', 'Cobrança não encontrada.');
    }
    if (payment.status === 'paid' || payment.status === 'cancelled' || payment.status === 'refunded') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Esta cobrança já não está disponível.',
      );
    }

    if (typeof payment.stripeHostedInvoiceUrl === 'string' &&
        payment.stripeHostedInvoiceUrl.length > 0) {
      return {
        url: payment.stripeHostedInvoiceUrl,
        paymentId: paymentRef.id,
      };
    }

    const userDoc = await db.collection('users').doc(String(recovery.userId)).get();
    const user = userDoc.data() ?? {};
    const amount = Math.round(Number(payment.valor) * 100);
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new functions.https.HttpsError('failed-precondition', 'Valor inválido.');
    }

    let session: Stripe.Checkout.Session;
    try {
      session = await stripe.checkout.sessions.create({
        mode: 'payment',
        line_items: [{
          price_data: {
            currency: payment.moeda || 'eur',
            product_data: { name: payment.descricao || 'Regularização de mensalidade' },
            unit_amount: amount,
          },
          quantity: 1,
        }],
        ...(typeof user.email === 'string' && user.email.length > 0
          ? { customer_email: user.email }
          : {}),
        metadata: {
          paymentId: paymentRef.id,
          userId: String(recovery.userId),
          recoveryTokenHash: tokenRef.id,
        },
        success_url: `${publicAppUrl}/?recovery=success`,
        cancel_url: `${publicAppUrl}/?recovery=cancelled`,
      });
    } catch (error) {
      await tokenRef.update({
        checkoutLockAt: admin.firestore.FieldValue.delete(),
      }).catch(() => undefined);
      throw stripeCheckoutHttpsError(error, 'recuperação');
    }

    if (!session.url) {
      await tokenRef.update({
        checkoutLockAt: admin.firestore.FieldValue.delete(),
      }).catch(() => undefined);
      throw new functions.https.HttpsError('internal', 'O Stripe não devolveu o checkout.');
    }
    await tokenRef.update({
      checkoutSessionId: session.id,
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
      checkoutLockAt: admin.firestore.FieldValue.delete(),
    });
    await paymentRef.update({
      recoveryCheckoutSessionId: session.id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { url: session.url, paymentId: paymentRef.id };
  });

/** Permite ao admin reenviar o acesso ao portal sem expor o token existente. */
export const resendPaymentRecovery = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
    const caller = await db.collection('users').doc(context.auth.uid).get();
    if (caller.data()?.role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Apenas admin.');
    }
    const paymentId = typeof data?.paymentId === 'string' ? data.paymentId.trim() : '';
    const payment = await db.collection('pagamentos').doc(paymentId).get();
    if (!payment.exists || !payment.data()?.userId) {
      throw new functions.https.HttpsError('not-found', 'Pagamento não encontrado.');
    }
    const lastSentAt = asDate(payment.data()?.recoveryLastSentAt);
    if (lastSentAt && Date.now() - lastSentAt.getTime() < 5 * 60 * 1000) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Já foi enviado um link recentemente. Aguarda alguns minutos.',
      );
    }
    await issuePaymentRecovery(paymentId, String(payment.data()!.userId), 'failed');
    return { success: true };
  });

/**
 * Endpoint antigo mantido para clientes ainda não atualizados.
 * O fluxo novo deve usar createPaymentSchedule e o aluno deve iniciar o
 * checkout através de createPaymentCheckoutSession.
 */
export const createCheckoutSession = functions.region('europe-west1').https.onCall(async (data, context) => {
  if (!stripe) throw new functions.https.HttpsError('failed-precondition', 'Stripe não configurado. Configura stripe.secret_key e publica as Functions.');
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
  const callerDoc = await db.collection('users').doc(context.auth.uid).get();
  if (callerDoc.data()?.role !== 'admin') throw new functions.https.HttpsError('permission-denied', 'Apenas admin.');

  const input = data && typeof data === 'object' ? data : {};
  const userId = typeof input.userId === 'string' ? input.userId.trim() : '';
  const valor = typeof input.valor === 'number' ? input.valor : Number(input.valor);
  const descricao = typeof input.descricao === 'string' && input.descricao.trim().length > 0
    ? input.descricao.trim()
    : 'Mensalidade';
  const periodoInicio = input.periodoInicio;
  const periodoFim = input.periodoFim;
  const dataVencimento = input.dataVencimento;

  if (!userId || !Number.isFinite(valor) || valor <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'userId e valor válidos são obrigatórios.');
  }

  const studentDoc = await db.collection('users').doc(userId).get();
  if (!studentDoc.exists || studentDoc.data()?.role === 'admin') {
    throw new functions.https.HttpsError('not-found', 'Aluno não encontrado.');
  }

  const parsedStart = periodoInicio == null ? null : asDate(periodoInicio);
  const parsedEnd = periodoFim == null ? null : asDate(periodoFim);
  const parsedDue = dataVencimento == null ? null : asDate(dataVencimento);
  if ((periodoInicio != null && !parsedStart) ||
      (periodoFim != null && !parsedEnd) ||
      (dataVencimento != null && !parsedDue)) {
    throw new functions.https.HttpsError('invalid-argument', 'Datas de pagamento inválidas.');
  }
  if (parsedStart && parsedEnd && parsedStart > parsedEnd) {
    throw new functions.https.HttpsError('invalid-argument', 'O início do período deve ser anterior ao fim.');
  }

  const paymentRef = await db.collection('pagamentos').add({
    userId, valor, moeda: 'eur', status: 'pending', descricao,
    data: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    ...(parsedStart ? { periodoInicio: admin.firestore.Timestamp.fromDate(parsedStart) } : {}),
    ...(parsedEnd ? { periodoFim: admin.firestore.Timestamp.fromDate(parsedEnd) } : {}),
    ...(parsedDue ? { dataVencimento: admin.firestore.Timestamp.fromDate(parsedDue) } : {}),
  });

  try {
    const email = typeof studentDoc.data()?.email === 'string'
      ? studentDoc.data()?.email
      : undefined;
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      mode: 'payment',
      line_items: [{
        price_data: {
          currency: 'eur',
          product_data: { name: descricao },
          unit_amount: Math.round(valor * 100),
        },
        quantity: 1,
      }],
      ...(email ? { customer_email: email } : {}),
      metadata: { paymentId: paymentRef.id, userId },
      success_url: 'https://gymbt-4ef87.web.app/?pagamento=sucesso&destino=perfil',
      cancel_url: 'https://gymbt-4ef87.web.app/?pagamento=cancelado&destino=perfil',
    });

    if (!session.url) {
      throw new functions.https.HttpsError(
        'internal',
        'O Stripe não devolveu um endereço de checkout.',
      );
    }

    await paymentRef.update({
      stripeSessionId: session.id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { url: session.url, paymentId: paymentRef.id };
  } catch (error) {
    // Não deixar cobranças órfãs quando o Stripe rejeita a sessão.
    await paymentRef.delete().catch(() => undefined);
    if (error instanceof functions.https.HttpsError) throw error;
    throw stripeCheckoutHttpsError(error, 'pagamento');
  }
});

// ──────────── FIRESTORE TRIGGERS ────────────

// ═══ DASHBOARD AGGREGATES ═══

/**
 * Mantém um agregado pequeno para o dashboard administrativo. Sem este
 * materialized view, o painel precisa de uma collectionGroup listener sobre
 * todo o histórico de diários, o que cresce linearmente com os alunos e dias.
 *
 * O trigger é delta-based e idempotente para cada transição before/after:
 * criar, editar e apagar um diário ajusta apenas os contadores afetados.
 * Dados anteriores ao deploy precisam de um backfill operacional único.
 */
export const aggregateDiaryStats = functions
  .region('europe-west1')
  .firestore.document('users/{userId}/diario/{date}')
  .onWrite(async (change) => {
    const before = change.before.exists ? change.before.data() ?? {} : null;
    const after = change.after.exists ? change.after.data() ?? {} : null;

    const sessionInfo = (data: Record<string, any> | null) => {
      if (!data || data.treinoConcluido !== true ||
          typeof data.treinoData !== 'object' || data.treinoData == null) {
        return { completed: false, month: null as string | null };
      }
      const completedAt = asDate(data.treinoData.completedAt);
      if (!completedAt) return { completed: false, month: null as string | null };
      const month = `${completedAt.getUTCFullYear()}-${String(
        completedAt.getUTCMonth() + 1,
      ).padStart(2, '0')}`;
      return { completed: true, month };
    };

    const beforeInfo = sessionInfo(before);
    const afterInfo = sessionInfo(after);
    if (beforeInfo.completed === afterInfo.completed &&
        beforeInfo.month === afterInfo.month) return null;

    const aggregateRef = db.collection('adminAggregates').doc('dashboard');
    await db.runTransaction(async (transaction) => {
      const aggregateSnapshot = await transaction.get(aggregateRef);
      const current = aggregateSnapshot.data() ?? {};
      const sessionsByMonth = {
        ...(current.sessionsByMonth ?? {}),
      } as Record<string, number>;
      let total = Number(current.sessoesTotal ?? 0);

      if (beforeInfo.completed && beforeInfo.month) {
        total = Math.max(0, total - 1);
        sessionsByMonth[beforeInfo.month] = Math.max(
          0,
          Number(sessionsByMonth[beforeInfo.month] ?? 0) - 1,
        );
      }
      if (afterInfo.completed && afterInfo.month) {
        total += 1;
        sessionsByMonth[afterInfo.month] =
          Number(sessionsByMonth[afterInfo.month] ?? 0) + 1;
      }

      transaction.set(aggregateRef, {
        sessoesTotal: total,
        sessionsByMonth,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    });
    return null;
  });

// ═══ NOTIFICAÇÕES DE CHAT & BOOKING (callables v1 — compatível com eur3) ═══

// Callable Functions já recebem o ID token no contexto autenticado. Nunca
// aceitamos tokens enviados dentro de data: ficam expostos em payloads/logs e
// permitem que clientes antigos contornem a semântica normal de callable.
async function resolvedUid(_data: any, context: any): Promise<string> {
  if (context.auth?.uid) return context.auth.uid;
  throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
}

type ChatNotificationDetails = {
  recipientIds: string[];
  type: 'chat_direct' | 'chat_group';
  title: string;
  metadata: Record<string, string>;
};

async function resolveChatNotificationDetails(
  salaId: string,
  remetenteId: string,
): Promise<ChatNotificationDetails | null> {
  const senderDoc = await db.collection('users').doc(remetenteId).get();
  const senderName = String(senderDoc.data()?.nome ?? 'Personal Trainer');
  const parts = salaId.split('_');

  // Salas 1:1 usam o formato chat_uid_uid.
  if (parts.length >= 3 && parts[0] === 'chat') {
    const roomDoc = await db.collection('chat').doc(salaId).get();
    const participants = roomDoc.data()?.participantIds;
    if (!roomDoc.exists || !Array.isArray(participants) ||
        participants.length !== 2 || !participants.includes(remetenteId)) {
      return null;
    }
    const recipientId = participants.find((id: unknown) =>
      typeof id === 'string' && id !== remetenteId,
    );
    if (!recipientId) return null;
    return {
      recipientIds: [recipientId],
      type: 'chat_direct',
      title: `Nova mensagem direta de ${senderName}`,
      metadata: {
        salaId,
        link: `${publicAppUrl}/?destino=chat`,
        chatKind: 'direct',
      },
    };
  }

  // Grupos usam o próprio ID do documento em /grupos.
  const groupDoc = await db.collection('grupos').doc(salaId).get();
  if (!groupDoc.exists) return null;
  const groupData = groupDoc.data() ?? {};
  const groupName = String(groupData.nome ?? groupData.name ?? 'Grupo');
  const members = Array.isArray(groupData.membros) ? groupData.membros : [];
  const groupAdmin = groupData.criadoPor;
  if (!members.includes(remetenteId) && groupAdmin !== remetenteId) return null;
  const recipientIds = [...members, groupAdmin]
    .filter((id: unknown): id is string =>
      typeof id === 'string' && id.length > 0 && id !== remetenteId,
    )
    .filter((id, index, ids) => ids.indexOf(id) === index);
  if (recipientIds.length === 0) return null;

  return {
    recipientIds,
    type: 'chat_group',
    title: `Nova mensagem no grupo ${groupName}`,
    metadata: {
      salaId,
      link: `${publicAppUrl}/?destino=chat`,
      chatKind: 'group',
      groupId: salaId,
      groupName,
    },
  };
}

/** Envia o push de uma mensagem; o histórico persistente é criado pelo trigger. */
export const sendChatNotification = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    const uid = await resolvedUid(data, context);
    const salaId = typeof data?.salaId === 'string' ? data.salaId : '';
    const messageId = typeof data?.messageId === 'string' ? data.messageId : '';
    if (!salaId || !messageId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'salaId e messageId são obrigatórios.',
      );
    }

    const messageRef = salaId.startsWith('chat_')
      ? db.collection('chat').doc(salaId).collection('mensagens').doc(messageId)
      : db.collection('grupos').doc(salaId).collection('mensagens').doc(messageId);
    const messageDoc = await messageRef.get();
    const message = messageDoc.data() ?? {};
    const remetenteId = typeof message.remetenteId === 'string'
      ? message.remetenteId
      : '';
    if (!messageDoc.exists || remetenteId !== uid) {
      throw new functions.https.HttpsError('permission-denied', 'Mensagem não autorizada.');
    }

    const details = await resolveChatNotificationDetails(salaId, remetenteId);
    if (!details) return { ok: true };
    const rawText = typeof message.texto === 'string' ? message.texto : '';
    const body = (rawText || '[Anexo]').substring(0, 100);
    await Promise.all(
      details.recipientIds.map((recipientId) =>
        sendUserPush(recipientId, details.title, body, {
          type: 'chat',
          chatKind: details.metadata.chatKind,
          salaId,
          link: details.metadata.link,
        }),
      ),
    );
    return { ok: true };
  });

/**
 * Cria o aviso persistente a partir da mensagem efetivamente gravada.
 * Assim o sino funciona mesmo quando um widget envia a mensagem sem chamar
 * explicitamente a callable (por exemplo, um compositor administrativo).
 */
export const notifyChatMessageCreated = functions
  .region('europe-west1')
  .firestore.document('chat/{salaId}/mensagens/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data() ?? {};
    const salaId = context.params.salaId as string;
    const remetenteId = typeof message.remetenteId === 'string'
      ? message.remetenteId
      : '';
    if (!remetenteId) return null;

    const details = await resolveChatNotificationDetails(salaId, remetenteId);
    if (!details) return null;
    const rawText = typeof message.texto === 'string' && message.texto.trim()
      ? message.texto
      : message.attachmentUrl
          ? '[Imagem]'
          : '[Mensagem de áudio]';
    const body = rawText.substring(0, 100);
    const metadata = {
      ...details.metadata,
      messageId: context.params.messageId as string,
    };

    await Promise.all(
      details.recipientIds.map((recipientId) =>
        createNotification({
          userId: recipientId,
          type: details.type,
          title: details.title,
          body,
          action: 'chat',
          metadata,
        }),
      ),
    );
    return null;
  });

/** Persiste avisos das mensagens criadas dentro de grupos. */
export const notifyGroupMessageCreated = functions
  .region('europe-west1')
  .firestore.document('grupos/{groupId}/mensagens/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data() ?? {};
    const salaId = context.params.groupId as string;
    const remetenteId = typeof message.remetenteId === 'string'
      ? message.remetenteId
      : '';
    if (!remetenteId) return null;

    const details = await resolveChatNotificationDetails(salaId, remetenteId);
    if (!details) return null;
    const rawText = typeof message.texto === 'string' && message.texto.trim()
      ? message.texto
      : message.attachmentUrl
          ? '[Imagem]'
          : '[Mensagem de áudio]';
    const metadata = {
      ...details.metadata,
      messageId: context.params.messageId as string,
    };

    await Promise.all(
      details.recipientIds.map((recipientId) =>
        createNotification({
          userId: recipientId,
          type: details.type,
          title: details.title,
          body: rawText.substring(0, 100),
          action: 'chat',
          metadata,
        }),
      ),
    );
    return null;
  });

/**
 * Cria um pedido de marcação de forma transacional.
 *
 * A app não escreve diretamente em /agenda: esta verificação no servidor
 * impede que o mesmo aluno tenha dois pedidos `pending`, mesmo que abra dois
 * dispositivos ou faça duas tentativas simultâneas.
 */
export const createBooking = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    const uid = await resolvedUid(data, context);
    const studentId = typeof data?.studentId === 'string'
      ? data.studentId.trim()
      : '';
    const trainerId = typeof data?.trainerId === 'string'
      ? data.trainerId.trim()
      : '';
    const bookingDate = typeof data?.bookingDate === 'string'
      ? data.bookingDate.trim()
      : '';
    const duration = Number(data?.duracaoMinutos ?? 60);
    const tipo = data?.tipo === 'online' ? 'online' : 'presencial';

    if (!studentId || !trainerId || !bookingDate ||
        !Number.isInteger(duration) || duration <= 0 || duration > 240) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Aluno, trainer, data e duração válidos são obrigatórios.',
      );
    }
    if (studentId !== uid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Só podes criar marcações para a tua própria conta.',
      );
    }

    const date = new Date(bookingDate);
    const now = new Date();
    if (Number.isNaN(date.getTime()) || date <= now ||
        date > new Date(now.getTime() + 366 * 24 * 60 * 60 * 1000)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'A marcação deve ser uma data futura dentro do próximo ano.',
      );
    }

    const [studentDoc, trainerDoc] = await Promise.all([
      db.collection('users').doc(studentId).get(),
      db.collection('users').doc(trainerId).get(),
    ]);
    const student = studentDoc.data() ?? {};
    const trainer = trainerDoc.data() ?? {};
    if (!studentDoc.exists || student.role === 'admin') {
      throw new functions.https.HttpsError('not-found', 'Aluno não encontrado.');
    }
    if (student.isActive === false) {
      throw new functions.https.HttpsError('permission-denied', 'Acesso inativo.');
    }
    const contractEndsAt = asDate(student.contractEndsAt);
    if (contractEndsAt && contractEndsAt <= new Date()) {
      throw new functions.https.HttpsError('permission-denied', 'Contrato expirado.');
    }
    if (!trainerDoc.exists || trainer.role !== 'admin' ||
        student.personalId !== trainerId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'O personal indicado não está associado ao aluno.',
      );
    }

    const agenda = db.collection('agenda');
    const bookingRef = agenda.doc();
    const requestedEnd = new Date(date.getTime() + duration * 60_000);
    await db.runTransaction(async (transaction) => {
      const existingSnapshot = await transaction.get(
        agenda.where('studentId', '==', studentId),
      );
      const hasPending = existingSnapshot.docs.some((doc) => {
        const status = doc.data().status;
        return status == null || status === 'pending';
      });
      if (hasPending) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Já existe um pedido de marcação pendente.',
        );
      }

      const trainerBookingsSnapshot = await transaction.get(
        agenda.where('trainerId', '==', trainerId),
      );
      const hasTimeConflict = trainerBookingsSnapshot.docs.some((doc) => {
        const data = doc.data();
        if (data.status !== 'pending' && data.status !== 'confirmed') {
          return false;
        }
        const existingDate = asDate(data.data);
        if (!existingDate) return false;
        const existingDuration = Number(data.duracaoMinutos ?? 60);
        const existingEnd = new Date(
          existingDate.getTime() + existingDuration * 60_000,
        );
        return date < existingEnd && requestedEnd > existingDate;
      });
      if (hasTimeConflict) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Este horário já não está disponível.',
        );
      }

      transaction.create(bookingRef, {
        studentId,
        trainerId,
        data: admin.firestore.Timestamp.fromDate(date),
        duracaoMinutos: duration,
        status: 'pending',
        tipo,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return { bookingId: bookingRef.id };
  });

export const notifyNewBooking = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    const uid = await resolvedUid(data, context);
    const bookingId = typeof data?.bookingId === 'string' ? data.bookingId.trim() : '';
    if (!bookingId) {
      throw new functions.https.HttpsError('invalid-argument', 'bookingId obrigatório.');
    }
    const bookingDoc = await db.collection('agenda').doc(bookingId).get();
    const booking = bookingDoc.data() ?? {};
    if (!bookingDoc.exists || booking.studentId !== uid || booking.status !== 'pending') {
      throw new functions.https.HttpsError('permission-denied', 'Marcação não autorizada.');
    }
    const [studentDoc, trainerDoc] = await Promise.all([
      db.collection('users').doc(uid).get(),
      db.collection('users').doc(String(booking.trainerId)).get(),
    ]);
    if (studentDoc.data()?.personalId !== booking.trainerId ||
        trainerDoc.data()?.role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Relação aluno-personal inválida.');
    }
    const fcmToken = trainerDoc.data()?.fcmToken;
    if (!fcmToken) return { ok: true };
    const date = asDate(booking.data) ?? new Date();
    const timeStr = `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
    const dateStr = date.toLocaleDateString('pt-PT', { weekday: 'short', day: 'numeric', month: 'short' });
    const tipoLabel = booking.tipo === 'online' ? '💻 Online' : '🏋️ Presencial';
    await messaging.send({
      token: fcmToken,
      notification: {
        title: 'Nova Aula Marcada 📅',
        body: `${studentDoc.data()?.nome ?? 'Aluno'} marcou aula para ${dateStr} às ${timeStr} (${tipoLabel})`,
      },
      data: { type: 'new_booking', bookingId },
    });
    return { ok: true };
  });

export const notifyBookingUpdate = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    const uid = await resolvedUid(data, context);
    const bookingId = typeof data?.bookingId === 'string' ? data.bookingId.trim() : '';
    const newStatus = typeof data?.newStatus === 'string' ? data.newStatus : '';
    if (!bookingId || !newStatus) {
      throw new functions.https.HttpsError('invalid-argument', 'bookingId e newStatus obrigatórios.');
    }
    const bookingDoc = await db.collection('agenda').doc(bookingId).get();
    const booking = bookingDoc.data() ?? {};
    if (!bookingDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Marcação não encontrada.');
    }
    const [callerDoc, studentDoc, trainerDoc] = await Promise.all([
      db.collection('users').doc(uid).get(),
      db.collection('users').doc(String(booking.studentId)).get(),
      db.collection('users').doc(String(booking.trainerId)).get(),
    ]);
    const callerRole = callerDoc.data()?.role;
    const isAdminCaller = callerRole === 'admin' && uid === booking.trainerId;
    const isStudentCaller = uid === booking.studentId;
    if (!isAdminCaller && !isStudentCaller) {
      throw new functions.https.HttpsError('permission-denied', 'Marcação não pertence ao utilizador.');
    }
    if ((newStatus === 'confirmed' || newStatus === 'cancelled') && !isAdminCaller) {
      throw new functions.https.HttpsError('permission-denied', 'Só o personal pode alterar este estado.');
    }
    if (newStatus === 'completed' && !isStudentCaller) {
      throw new functions.https.HttpsError('permission-denied', 'Só o aluno pode concluir a aula.');
    }
    if (!['confirmed', 'cancelled', 'completed'].includes(newStatus)) {
      throw new functions.https.HttpsError('invalid-argument', 'Estado inválido.');
    }
    const recipientDoc = isAdminCaller ? studentDoc : trainerDoc;
    const fcmToken = recipientDoc.data()?.fcmToken;
    if (!fcmToken) return { ok: true };
    const callerName = callerDoc.data()?.nome ?? 'Utilizador';
    const date = asDate(booking.data) ?? new Date();
    const timeStr = `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
    const dateStr = date.toLocaleDateString('pt-PT', { weekday: 'short', day: 'numeric', month: 'short' });
    const tipoLabel = booking.tipo === 'online' ? '💻 Online' : '🏋️ Presencial';
    const title = newStatus === 'confirmed' ? 'Aula Confirmada ✅'
      : newStatus === 'cancelled' ? 'Aula Cancelada ❌' : 'Aula Concluída 💪';
    const body = newStatus === 'completed'
      ? `${studentDoc.data()?.nome ?? 'Aluno'} concluiu a aula de ${dateStr} às ${timeStr} (${tipoLabel})`
      : `${callerName} ${newStatus === 'confirmed' ? 'confirmou' : 'cancelou'} a tua aula de ${dateStr} às ${timeStr} (${tipoLabel})`;
    await messaging.send({
      token: fcmToken,
      notification: { title, body },
      data: { type: 'booking_update', bookingId, newStatus },
    });
    return { ok: true };
  });

export const notifyBookingCancelled = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    const uid = await resolvedUid(data, context);
    const bookingId = typeof data?.bookingId === 'string' ? data.bookingId.trim() : '';
    if (!bookingId) {
      throw new functions.https.HttpsError('invalid-argument', 'bookingId obrigatório.');
    }
    const bookingDoc = await db.collection('agenda').doc(bookingId).get();
    const booking = bookingDoc.data() ?? {};
    if (!bookingDoc.exists || booking.status !== 'cancelled') {
      throw new functions.https.HttpsError('failed-precondition', 'A marcação ainda não está cancelada.');
    }
    const [callerDoc, studentDoc, trainerDoc] = await Promise.all([
      db.collection('users').doc(uid).get(),
      db.collection('users').doc(String(booking.studentId)).get(),
      db.collection('users').doc(String(booking.trainerId)).get(),
    ]);
    const callerRole = callerDoc.data()?.role;
    if (uid !== booking.studentId && !(callerRole === 'admin' && uid === booking.trainerId)) {
      throw new functions.https.HttpsError('permission-denied', 'Marcação não pertence ao utilizador.');
    }
    const recipientDoc = uid === booking.studentId ? trainerDoc : studentDoc;
    const fcmToken = recipientDoc.data()?.fcmToken;
    if (!fcmToken) return { ok: true };
    const date = asDate(booking.data) ?? new Date();
    const timeStr = `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
    const dateStr = date.toLocaleDateString('pt-PT', { weekday: 'short', day: 'numeric', month: 'short' });
    const tipoLabel = booking.tipo === 'online' ? '💻 Online' : '🏋️ Presencial';
    await messaging.send({
      token: fcmToken,
      notification: {
        title: 'Aula Cancelada ❌',
        body: `${studentDoc.data()?.nome ?? 'Aluno'} cancelou a aula de ${dateStr} às ${timeStr} (${tipoLabel})`,
      },
      data: { type: 'booking_update', bookingId, newStatus: 'cancelled' },
    });
    return { ok: true };
  });

// ──────────── CONTRACT EXPIRY ────────────

/**
 * Deactivates students whose contract has reached its end date.
 *
 * The client already blocks access when the date passes, but the Firestore
 * profile must also be updated so the account is consistently inactive for
 * the admin panel, rules, and future sessions. The scheduled job is the
 * fallback for contracts whose date passes while nobody is online.
 */
export const deactivateExpiredContracts = functions
  .region('europe-west1')
  .pubsub.schedule('every 15 minutes')
  .timeZone('Europe/Lisbon')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const expiredUsers = await db
      .collection('users')
      .where('contractEndsAt', '<=', now)
      .get();

    const usersToDeactivate = expiredUsers.docs.filter((doc) =>
      shouldDeactivateExpiredContract(doc.data(), now.toDate()),
    );

    // Re-read each profile in a transaction before changing it. This avoids
    // deactivating a client whose contract was renewed after the query ran.
    for (const user of usersToDeactivate) {
        await db.runTransaction(async (transaction) => {
        const latest = await transaction.get(user.ref);
        if (
          !latest.exists ||
          !shouldDeactivateExpiredContract(latest.data() ?? {}, new Date())
        ) {
          return;
        }
        transaction.update(user.ref, {
          isActive: false,
          deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
    }

    console.log(`Deactivated ${usersToDeactivate.length} expired contract(s).`);
    return null;
  });

/**
 * Handles an expiry date written in the past immediately. The scheduled job
 * above still handles the normal case when time passes after the write.
 */
export const deactivateExpiredContractOnWrite = functions
  .region('europe-west1')
  .firestore.document('users/{uid}')
  .onWrite(async (change) => {
    if (!change.after.exists) return null;

    const data = change.after.data();
    if (!data || !shouldDeactivateExpiredContract(data, new Date())) {
      return null;
    }

    await change.after.ref.update({
      isActive: false,
      deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return null;
  });

/** Mantém o centro de avisos sincronizado com ativações/desativações feitas pelo admin. */
export const notifyUserAccessChange = functions
  .region('europe-west1')
  .firestore.document('users/{uid}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() ?? {};
    const after = change.after.data() ?? {};
    const uid = context.params.uid as string;
    if (after.role === 'admin') return null;

    const wasActive = before.isActive !== false;
    const isActive = after.isActive !== false;
    const beforeEnd = asDate(before.contractEndsAt)?.getTime() ?? null;
    const afterEnd = asDate(after.contractEndsAt)?.getTime() ?? null;
    if (wasActive === isActive && beforeEnd === afterEnd) return null;

    const title = !isActive ? 'Acesso desativado' : 'Acesso ativado ✅';
    const body = !isActive
      ? 'O teu acesso foi desativado. Contacta o administrador para obter ajuda.'
      : 'O teu acesso foi ativado. Já podes utilizar a aplicação.';
    await createNotification({ userId: uid, type: 'access_change', title, body, action: 'login' });
    await sendUserPush(uid, title, body, { type: 'access_change', link: `${publicAppUrl}/` });
    return null;
  });

/** Persiste avisos quando uma marcação é aceite, recusada ou concluída. */
export const notifyBookingStatusChange = functions
  .region('europe-west1')
  .firestore.document('agenda/{bookingId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() ?? {};
    const after = change.after.data() ?? {};
    if (before.status === after.status) return null;

    const studentId = typeof after.studentId === 'string' ? after.studentId : '';
    if (!studentId) return null;

    const status = String(after.status ?? '')
      .trim()
      .toLowerCase()
      .replace(/ /g, '_')
      .replace(/-/g, '_');
    const accepted = new Set([
      'confirmed', 'approved', 'accepted', 'aprovado', 'aprovada', 'aceite', 'aceita',
    ]);
    const rejected = new Set([
      'cancelled', 'canceled', 'rejected', 'declined', 'recusado', 'recusada',
      'rejeitado', 'rejeitada', 'cancelado', 'cancelada',
    ]);
    const completed = new Set(['completed', 'complete', 'concluido', 'concluida', 'concluído', 'concluída']);
    if (!accepted.has(status) && !rejected.has(status) && !completed.has(status)) {
      return null;
    }

    const bookingDate = asDate(after.data);
    const dateLabel = bookingDate
      ? bookingDate.toLocaleDateString('pt-PT', {
          weekday: 'long', day: 'numeric', month: 'long',
        })
      : 'a aula agendada';
    const timeLabel = bookingDate
      ? bookingDate.toLocaleTimeString('pt-PT', {
          hour: '2-digit', minute: '2-digit',
        })
      : '';
    const typeLabel = after.tipo === 'online' ? 'sessão online' : 'sessão presencial';

    const title = accepted.has(status)
      ? 'Marcação aceite ✅'
      : rejected.has(status)
          ? 'Marcação recusada ❌'
          : 'Aula concluída';
    const body = accepted.has(status)
      ? `O administrador aceitou a tua ${typeLabel} de ${dateLabel} às ${timeLabel}.`
      : rejected.has(status)
          ? `O administrador recusou a tua ${typeLabel} de ${dateLabel} às ${timeLabel}. Consulta a agenda para escolher outro horário.`
          : `A tua ${typeLabel} de ${dateLabel} às ${timeLabel} foi marcada como concluída.`;
    const metadata: Record<string, string> = {
      bookingId: context.params.bookingId as string,
      status,
      ...(bookingDate ? { bookingDate: bookingDate.toISOString() } : {}),
    };

    await createNotification({
      userId: studentId,
      type: 'booking_update',
      title,
      body,
      action: 'agenda',
      metadata,
    });
    await sendUserPush(studentId, title, body, {
      type: 'booking_update',
      bookingId: context.params.bookingId as string,
      newStatus: status,
      link: `${publicAppUrl}/?destino=agenda`,
    });
    return null;
  });

// ──────────── SCHEDULED ────────────

export const sendPaymentRecoveryReminders = functions.pubsub
  .schedule('every day 09:00')
  .timeZone('Europe/Lisbon')
  .onRun(async () => {
    const unpaid = await db.collection('pagamentos')
      .where('status', 'in', ['pending', 'failed'])
      .get();
    const now = Date.now();
    for (const doc of unpaid.docs) {
      const data = doc.data();
      const isFailed = data.status === 'failed';
      const dueAt = asDate(data.dataVencimento)?.getTime();
      if (!isFailed && (!dueAt || dueAt > now)) continue;
      const lastSent = asDate(data.recoveryLastSentAt)?.getTime() ?? 0;
      if (now - lastSent < 24 * 60 * 60 * 1000) continue;
      const userId = typeof data.userId === 'string' ? data.userId : '';
      if (userId) {
        await issuePaymentRecovery(doc.id, userId, isFailed ? 'failed' : 'overdue');
      }
    }
    return null;
  });

export const sendWaterReminder = functions.pubsub
  .schedule('every 2 hours from 08:00 to 22:00').timeZone('Europe/Lisbon')
  .onRun(async () => {
    const usersSnapshot = await db.collection('users').where('role', '==', 'aluno').get();
    const today = new Date().toISOString().split('T')[0];
    const promises = usersSnapshot.docs.map(async (u) => {
      const token = u.data().fcmToken;
      if (!token) return;
      const diary = await db.collection('users').doc(u.id).collection('diario').doc(today).get();
      const agua = diary.data()?.agua ?? 0;
      if (agua >= 2500) return;
      await messaging.send({ token, notification: { title: 'Hora de beber água! 💧', body: `Já bebeste ${agua}ml de 2500ml. Continua!` }, data: { type: 'water_reminder' } });
    });
    await Promise.all(promises);
    return null;
  });

export const sendWorkoutReminder = functions.pubsub
  .schedule('every day 07:00').timeZone('Europe/Lisbon')
  .onRun(async () => {
    const usersSnapshot = await db.collection('users').where('role', '==', 'aluno').get();
    const today = new Date().toISOString().split('T')[0];
    const promises = usersSnapshot.docs.map(async (u) => {
      const token = u.data().fcmToken;
      if (!token) return;
      const log = await db.collection('users').doc(u.id).collection('workoutLogs').doc(today).get();
      if (log.exists) return;
      const nome = u.data().nome ?? 'Aluno';
      await messaging.send({ token, notification: { title: 'Bom dia! 🏋️ Hora de treinar!', body: `Vê o teu plano de hoje, ${nome.split(' ')[0]}!` }, data: { type: 'workout_reminder', screen: 'workout' } });
    });
    await Promise.all(promises);
    return null;
  });

export const sendWeighInReminder = functions.pubsub
  .schedule('every monday 09:00').timeZone('Europe/Lisbon')
  .onRun(async () => {
    const usersSnapshot = await db.collection('users').where('role', '==', 'aluno').get();
    const sevenDaysAgo = new Date(); sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    const promises = usersSnapshot.docs.map(async (u) => {
      const token = u.data().fcmToken;
      if (!token) return;
      const recent = await db.collection('users').doc(u.id).collection('progresso')
        .where('data', '>=', admin.firestore.Timestamp.fromDate(sevenDaysAgo)).limit(1).get();
      if (!recent.empty) return;
      const nome = u.data().nome ?? 'Aluno';
      const peso = u.data().pesoAtual;
      const pesoMsg = peso ? `Último peso: ${peso}kg. ` : '';
      await messaging.send({ token, notification: { title: 'Hora de pesar! ⚖️', body: `${nome.split(' ')[0]}, ${pesoMsg}Regista o teu peso esta semana!` }, data: { type: 'weighin_reminder', screen: 'profile' } });
    });
    await Promise.all(promises);
    return null;
  });

export const sendWeeklyCheckin = functions.pubsub
  .schedule('every sunday 18:00').timeZone('Europe/Lisbon')
  .onRun(async () => {
    const usersSnapshot = await db.collection('users').where('role', '==', 'aluno').get();
    const today = new Date();
    const daysSinceMonday = today.getDay() === 0 ? 6 : today.getDay() - 1;
    const weekStart = new Date(today); weekStart.setDate(today.getDate() - daysSinceMonday); weekStart.setHours(0, 0, 0, 0);
    const promises = usersSnapshot.docs.map(async (u) => {
      const token = u.data().fcmToken;
      if (!token) return;
      const logs = await db.collection('users').doc(u.id).collection('workoutLogs')
        .where('data', '>=', admin.firestore.Timestamp.fromDate(weekStart)).get();
      const treinos = logs.size;
      const nome = u.data().nome ?? 'Aluno';
      const msg = treinos > 0 ? `Fizeste ${treinos} treino(s) esta semana! 💪 Continua, ${nome.split(' ')[0]}!` : `Como foi a tua semana? Vamos retomar! 💪`;
      await messaging.send({ token, notification: { title: 'Check-in Semanal 📊', body: msg }, data: { type: 'weekly_checkin', screen: 'home', treinosSemana: String(treinos) } });
    });
    await Promise.all(promises);
    return null;
  });

export const dailyFirestoreBackup = functions.pubsub
  .schedule('every day 03:00').timeZone('Europe/Lisbon')
  .onRun(async () => {
    const bucket = admin.storage().bucket();
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backup: Record<string, unknown> = {};
    for (const col of ['users', 'chat', 'alimentos', 'exercicios']) {
      const snap = await db.collection(col).get();
      backup[col] = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    }
    await bucket.file(`backups/firestore-${timestamp}.json`).save(JSON.stringify(backup, null, 2), { contentType: 'application/json' });
    return null;
  });

export const cleanupInvalidFcmTokens = functions.pubsub
  .schedule('every day 04:00').timeZone('Europe/Lisbon')
  .onRun(async () => {
    const usersSnapshot = await db.collection('users').get();
    const batch = db.batch(); let count = 0;
    for (const u of usersSnapshot.docs) {
      const token = u.data().fcmToken;
      if (!token) continue;
      try { await messaging.send({ token, data: { type: 'token_check' } }, true); } catch (e: any) {
        if (e.code === 'messaging/registration-token-not-registered') { batch.update(u.ref, { fcmToken: admin.firestore.FieldValue.delete() }); count++; }
      }
    }
    if (count > 0) await batch.commit();
    return null;
  });

// ──────────── STRIPE WEBHOOK ────────────

const stripeApp = require('express')();
stripeApp.use(require('express').raw({ type: 'application/json' }));
stripeApp.post('/', async (req: any, res: any) => {
  if (!stripe) { res.status(500).json({ error: 'Stripe não configurado.' }); return; }
  const sig = req.headers['stripe-signature'];
  if (!sig) { res.status(400).json({ error: 'Missing signature.' }); return; }

  let event: Stripe.Event;
  try {
    // O Firebase Functions disponibiliza o corpo assinado em rawBody. Usar
    // req.body aqui é incorreto porque o Express/Firebase já o pode ter
    // convertido para objeto e a assinatura deixa de ser verificável.
    const rawBody: Buffer | string | null = Buffer.isBuffer(req.rawBody)
      ? req.rawBody
      : Buffer.isBuffer(req.body) || typeof req.body === 'string'
        ? req.body
        : null;
    if (rawBody == null) {
      res.status(400).json({ error: 'Webhook payload raw não disponível.' });
      return;
    }
    event = stripe.webhooks.constructEvent(rawBody, sig, stripeWebhookSecret);
  } catch (e: any) {
    res.status(400).json({ error: `Webhook Error: ${e.message}` }); return;
  }

  // Stripe pode reenviar o mesmo evento. Só um evento com `processedAt` é
  // considerado concluído: marcadores `received`, `processing` ou `failed`
  // podem ser retomados depois de uma falha/crash do processo.
  const eventRef = db.collection('stripeEvents').doc(event.id);
  const eventAlreadyProcessed = await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(eventRef);
    if (existing.exists) {
      const data = existing.data() ?? {};
      if (data.status === 'processed' || data.processedAt) return true;
      const processingAt = asDate(data.processingAt);
      if (data.status === 'processing' && processingAt &&
          Date.now() - processingAt.getTime() < 10 * 60 * 1000) {
        return true;
      }
      transaction.update(eventRef, {
        status: 'processing',
        processingAt: admin.firestore.FieldValue.serverTimestamp(),
        attempts: admin.firestore.FieldValue.increment(1),
      });
      return false;
    }
    transaction.create(eventRef, {
      type: event.type,
      status: 'processing',
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      processingAt: admin.firestore.FieldValue.serverTimestamp(),
      attempts: 1,
    });
    return false;
  });
  if (eventAlreadyProcessed) {
    res.status(200).json({ received: true, duplicate: true });
    return;
  }

  try {
  if (event.type === 'checkout.session.completed') {
    const session = event.data.object as Stripe.Checkout.Session;
    const { paymentId, userId } = session.metadata || {};
    if (!paymentId) {
      await eventRef.update({
        status: 'ignored',
        failureReason: 'missing_payment_id',
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.status(200).json({ received: true, ignored: true });
      return;
    }

    const paymentRef = db.collection('pagamentos').doc(paymentId);
    const currentPayment = await paymentRef.get();
    if (!currentPayment.exists || currentPayment.data()?.status === 'cancelled') {
      console.warn('Ignoring Stripe checkout for cancelled/missing payment', {
        paymentId,
        sessionId: session.id,
      });
      await eventRef.update({
        status: 'ignored',
        ignoredAt: admin.firestore.FieldValue.serverTimestamp(),
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.status(200).json({ received: true, ignored: true });
      return;
    }

    if (session.mode === 'subscription') {
      const subscriptionId = typeof session.subscription === 'string'
        ? session.subscription
        : session.subscription?.id;
      const checkoutWasPaid = session.payment_status === 'paid';
      console.log('Stripe subscription checkout completed', {
        paymentId,
        sessionId: session.id,
        paymentStatus: session.payment_status,
        subscriptionId,
      });
      await paymentRef.update({
        // Quando o Checkout já confirma o primeiro pagamento, não dependemos
        // apenas do invoice.paid para tirar a cobrança de pendente. Esse
        // evento continua a completar fatura, período e notificações.
        ...(checkoutWasPaid
          ? {
              status: 'paid',
              paidAt: admin.firestore.FieldValue.serverTimestamp(),
            }
          : currentPayment.data()?.status === 'paid'
            ? {}
            : { status: 'scheduled' }),
        ...(subscriptionId ? { stripeSubscriptionId: subscriptionId } : {}),
        ...(typeof session.customer === 'string'
          ? { stripeCustomerId: session.customer }
          : {}),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      if (userId && typeof session.customer === 'string') {
        await db.collection('users').doc(userId).set({
          stripeCustomerId: session.customer,
        }, { merge: true });
      }
    } else {
      // Checkout de recuperação é uma cobrança avulsa. Quando a conta já
      // expirou, o período antigo não pode ser reutilizado: começa agora (ou
      // no fim atual, caso o contrato ainda esteja ativo) e é calculado pelo
      // servidor para que o trigger de acesso possa reativar a conta.
      const recoveryUser = userId
        ? (await db.collection('users').doc(userId).get()).data() ?? {}
        : {};
      const currentEnd = asDate(recoveryUser.contractEndsAt);
      const periodStart = currentEnd && currentEnd > new Date()
        ? currentEnd
        : new Date();
      const billingType = isBillingType(currentPayment.data()?.tipoMensalidade)
        ? currentPayment.data()!.tipoMensalidade as BillingType
        : 'mensal';
      const period = calculateBillingPeriod(periodStart, billingType);
      await paymentRef.update({
        status: 'paid',
        periodoInicio: admin.firestore.Timestamp.fromDate(period.start),
        periodoFim: admin.firestore.Timestamp.fromDate(period.end),
        tipoMensalidade: billingType,
        stripePaymentIntentId: typeof session.payment_intent === 'string'
          ? session.payment_intent
          : session.payment_intent?.id,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      if (userId) {
        await generateInvoicePdf(paymentId, userId);
        await createNotification({
          userId,
          type: 'payment_paid',
          title: 'Pagamento confirmado ✅',
          body: 'A tua mensalidade foi paga com sucesso.',
          action: 'payment',
          paymentId,
        });
        await sendUserPush(
          userId,
          'Pagamento confirmado ✅',
          'A tua mensalidade foi paga com sucesso.',
          { type: 'payment_paid', paymentId, link: `${publicAppUrl}/` },
        );
      }
    }
  }

  if (event.type === 'customer.subscription.deleted') {
    await handleSubscriptionDeleted(event.data.object as any);
  }

  if (event.type === 'invoice.paid') {
    await handleInvoicePaid(event.data.object as any);
  }

  if (event.type === 'invoice.payment_failed') {
    await handleInvoicePaymentFailed(event.data.object as any);
  }
  } catch (error) {
    // Permitir que o Stripe reenvie um evento se o processamento falhar a
    // meio, em vez de deixar um marcador "processado" permanentemente.
    await eventRef.delete().catch(() => undefined);
    console.error('Stripe webhook processing failed', error);
    res.status(500).json({ error: 'Webhook processing failed.' });
    return;
  }

  await eventRef.update({
    status: 'processed',
    processedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  res.status(200).json({ received: true });
});

export const stripeWebhook = functions.region('europe-west1').https.onRequest(stripeApp);

async function handleSubscriptionDeleted(subscription: any): Promise<void> {
  const metadata = subscription.metadata ?? {};
  const paymentId = typeof metadata.paymentId === 'string' ? metadata.paymentId : '';
  const userId = typeof metadata.userId === 'string' ? metadata.userId : '';
  if (!paymentId || !userId) return;

  const paymentRef = db.collection('pagamentos').doc(paymentId);
  const payment = await paymentRef.get();
  if (!payment.exists || payment.data()?.status === 'cancelled') return;
  await paymentRef.update({
    subscriptionEndedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await createNotification({
    userId,
    type: 'subscription_ended',
    title: 'Renovação automática terminada',
    body: 'A subscrição terminou. Se precisares, podes regularizar pelo próximo pagamento disponível.',
    action: 'payment',
    paymentId,
  });
}

async function handleInvoicePaid(invoice: any): Promise<void> {
  const context = await getInvoiceSubscriptionContext(invoice);
  if (!context) return;

  const { subscription, paymentId, userId, tipoMensalidade } = context;
  const invoiceId = String(invoice.id);
  const existingByInvoice = await findPaymentByInvoiceId(invoiceId);
  let paymentRef = existingByInvoice;

  if (!paymentRef && paymentId) {
    const initialRef = db.collection('pagamentos').doc(paymentId);
    const initialDoc = await initialRef.get();
    if (initialDoc.exists &&
        initialDoc.data()?.status !== 'paid' &&
        initialDoc.data()?.status !== 'cancelled') {
      paymentRef = initialRef;
    }
  }

  if (paymentRef) {
    const current = await paymentRef.get();
    if (current.data()?.status === 'cancelled') return;
  }

  const periodStart = stripeTimestampDate(invoice.period_start) ??
    stripeTimestampDate(subscription.current_period_start);
  const periodEnd = stripeTimestampDate(invoice.period_end) ??
    stripeTimestampDate(subscription.current_period_end);
  const amount = typeof invoice.amount_paid === 'number' && invoice.amount_paid > 0
    ? invoice.amount_paid / 100
    : null;
  const data = {
    status: 'paid',
    paidAt: admin.firestore.FieldValue.serverTimestamp(),
    stripeInvoiceId: invoiceId,
    stripeSubscriptionId: subscription.id,
    stripePaymentIntentId: typeof invoice.payment_intent === 'string'
      ? invoice.payment_intent
      : invoice.payment_intent?.id,
    stripeHostedInvoiceUrl: invoice.hosted_invoice_url || invoice.invoice_pdf || null,
    tipoMensalidade,
    ...(periodStart ? { periodoInicio: admin.firestore.Timestamp.fromDate(periodStart) } : {}),
    ...(periodEnd ? { periodoFim: admin.firestore.Timestamp.fromDate(periodEnd) } : {}),
    dataVencimento: admin.firestore.Timestamp.fromDate(new Date()),
    ...(amount != null ? { valor: amount } : {}),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (paymentRef) {
    await paymentRef.update(data);
  } else {
    paymentRef = await db.collection('pagamentos').add({
      userId,
      valor: amount ?? 0,
      moeda: 'eur',
      descricao: `Mensalidade ${billingTypeLabels[tipoMensalidade]}`,
      data: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      ...data,
    });
  }

  await generateInvoicePdf(paymentRef.id, userId);
  await createNotification({
    userId,
    type: 'payment_paid',
    title: 'Pagamento confirmado ✅',
    body: 'A tua mensalidade foi paga e o acesso foi atualizado.',
    action: 'payment',
    paymentId: paymentRef.id,
  });
  await sendUserPush(
    userId,
    'Pagamento confirmado ✅',
    'A tua mensalidade foi paga e o acesso foi atualizado.',
    { type: 'payment_paid', paymentId: paymentRef.id, link: `${publicAppUrl}/` },
  );
}

async function handleInvoicePaymentFailed(invoice: any): Promise<void> {
  const context = await getInvoiceSubscriptionContext(invoice);
  if (!context) return;

  const { subscription, paymentId, userId, tipoMensalidade } = context;
  const invoiceId = String(invoice.id);
  const existingByInvoice = await findPaymentByInvoiceId(invoiceId);
  let paymentRef = existingByInvoice;

  if (!paymentRef && paymentId) {
    const initialRef = db.collection('pagamentos').doc(paymentId);
    const initialDoc = await initialRef.get();
    if (initialDoc.exists &&
        initialDoc.data()?.status !== 'paid' &&
        initialDoc.data()?.status !== 'cancelled') {
      paymentRef = initialRef;
    }
  }

  if (paymentRef) {
    const current = await paymentRef.get();
    if (current.data()?.status === 'cancelled') return;
  }

  const periodStart = stripeTimestampDate(invoice.period_start) ??
    stripeTimestampDate(subscription.current_period_start);
  const periodEnd = stripeTimestampDate(invoice.period_end) ??
    stripeTimestampDate(subscription.current_period_end);
  const amount = typeof invoice.amount_due === 'number' && invoice.amount_due > 0
    ? invoice.amount_due / 100
    : null;
  const data = {
    status: 'failed',
    stripeInvoiceId: invoiceId,
    stripeSubscriptionId: subscription.id,
    stripeHostedInvoiceUrl: invoice.hosted_invoice_url || invoice.invoice_pdf || null,
    tipoMensalidade,
    dataVencimento: admin.firestore.Timestamp.fromDate(new Date()),
    ...(periodStart ? { periodoInicio: admin.firestore.Timestamp.fromDate(periodStart) } : {}),
    ...(periodEnd ? { periodoFim: admin.firestore.Timestamp.fromDate(periodEnd) } : {}),
    ...(amount != null ? { valor: amount } : {}),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (paymentRef) {
    await paymentRef.update(data);
  } else {
    paymentRef = await db.collection('pagamentos').add({
      userId,
      valor: amount ?? 0,
      moeda: 'eur',
      descricao: `Mensalidade ${billingTypeLabels[tipoMensalidade]}`,
      data: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      ...data,
    });
  }

  // Se ainda não existe um período pago, não manter uma subscrição em
  // cobrança/retry automático. O cliente recebe o portal para pagar uma vez
  // manualmente; depois o webhook reativa o acesso.
  const userDoc = await db.collection('users').doc(userId).get();
  const currentContractEnd = asDate(userDoc.data()?.contractEndsAt);
  if ((!currentContractEnd || currentContractEnd <= new Date()) && stripe) {
    try {
      await stripe.subscriptions.cancel(String(subscription.id));
      await paymentRef.update({
        subscriptionCancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error('Could not cancel unpaid initial subscription', error);
    }
  }

  // O primeiro pagamento recusado também precisa de recuperação pública;
  // o utilizador pode estar impedido de iniciar sessão.
  await issuePaymentRecovery(paymentRef.id, userId, 'failed');
}

async function getInvoiceSubscriptionContext(invoice: any): Promise<{
  subscription: any;
  paymentId: string;
  userId: string;
  tipoMensalidade: BillingType;
} | null> {
  if (!stripe) return null;
  const subscriptionId = typeof invoice.subscription === 'string'
    ? invoice.subscription
    : invoice.subscription?.id;
  if (!subscriptionId) return null;

  const subscription = await stripe.subscriptions.retrieve(subscriptionId);
  const metadata = subscription.metadata ?? {};
  if (typeof metadata.paymentId !== 'string' ||
      typeof metadata.userId !== 'string' ||
      !isBillingType(metadata.tipoMensalidade)) {
    return null;
  }
  return {
    subscription,
    paymentId: metadata.paymentId,
    userId: metadata.userId,
    tipoMensalidade: metadata.tipoMensalidade,
  };
}

async function findPaymentByInvoiceId(invoiceId: string): Promise<
  FirebaseFirestore.DocumentReference | null
> {
  const snapshot = await db.collection('pagamentos')
    .where('stripeInvoiceId', '==', invoiceId)
    .limit(1)
    .get();
  return snapshot.empty ? null : snapshot.docs[0].ref;
}

function stripeTimestampDate(value: unknown): Date | null {
  if (typeof value === 'number') return new Date(value * 1000);
  return asDate(value);
}

/**
 * Renova/reactiva o acesso quando um pagamento pago contém um período válido.
 * Funciona tanto para pagamentos manuais como para o webhook Stripe, mantendo
 * o perfil do aluno como fonte de verdade para as regras e novas sessões.
 */
export const syncAccessFromPaidPayment = functions
  .region('europe-west1')
  .firestore.document('pagamentos/{paymentId}')
  .onWrite(async (change) => {
    if (!change.after.exists) return null;

    const payment = change.after.data();
    if (payment?.status !== 'paid' || !payment?.userId || !payment?.periodoFim) {
      return null;
    }

    const periodEnd = asDate(payment.periodoFim);
    if (!periodEnd || periodEnd <= new Date()) return null;

    const userRef = db.collection('users').doc(String(payment.userId));
    await db.runTransaction(async (transaction) => {
      const userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) return;

      const user = userSnapshot.data() ?? {};
      const currentEnd = asDate(user.contractEndsAt);
      if (currentEnd && currentEnd >= periodEnd && user.isActive !== false) {
        return;
      }

      transaction.update(userRef, {
        contractEndsAt: admin.firestore.Timestamp.fromDate(
          currentEnd && currentEnd > periodEnd ? currentEnd : periodEnd,
        ),
        isActive: true,
        deactivatedAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return null;
  });

// ──────────── HELPERS ────────────

function asDate(value: unknown): Date | null {
  if (value instanceof Date) return value;
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (typeof value === 'string' || typeof value === 'number') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function stripeCheckoutHttpsError(error: unknown, operation: string): functions.https.HttpsError {
  const stripeError = error as {
    type?: string;
    code?: string;
    message?: string;
    requestId?: string;
  };
  console.error(`Stripe checkout (${operation}) failed`, {
    type: stripeError?.type,
    code: stripeError?.code,
    message: stripeError?.message,
    requestId: stripeError?.requestId,
  });

  if (stripeError?.type === 'StripeAuthenticationError') {
    return new functions.https.HttpsError(
      'failed-precondition',
      'A chave secreta do Stripe é inválida, foi revogada ou não está configurada nas Functions.',
    );
  }

  if (stripeError?.type === 'StripeInvalidRequestError') {
    return new functions.https.HttpsError(
      'invalid-argument',
      `O Stripe rejeitou os dados do checkout: ${stripeError.message || 'pedido inválido.'}`,
    );
  }

  return new functions.https.HttpsError(
    'internal',
    'Não foi possível iniciar o checkout do Stripe. Consulta os logs da Function para mais detalhes.',
  );
}

async function generateInvoicePdf(paymentId: string, userId: string): Promise<void> {
  const [paymentDoc, userDoc] = await Promise.all([db.collection('pagamentos').doc(paymentId).get(), db.collection('users').doc(userId).get()]);
  const payment = paymentDoc.data(), user = userDoc.data();
  if (!payment || !user) return;

  const valor = payment.valor || 0, descricao = payment.descricao || 'Mensalidade';
  const date = payment.paidAt ? (payment.paidAt as admin.firestore.Timestamp).toDate() : new Date();
  const nome = user.nome || 'Aluno', email = user.email || '';

  const chunks: Buffer[] = [];
  const doc = new PDFDocument({ size: 'A4', margin: 50 });
  doc.on('data', (c: Buffer) => chunks.push(c));
  const pdfPromise = new Promise<Buffer>(r => doc.on('end', () => r(Buffer.concat(chunks))));

  doc.fontSize(28).font('Helvetica-Bold').text('GymBT', { align: 'center' }).moveDown(0.3);
  doc.fontSize(14).font('Helvetica').text('FATURA / RECIBO', { align: 'center' }).moveDown(1);
  doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#B20C7E').lineWidth(2).stroke().moveDown(1);
  doc.fontSize(12).font('Helvetica-Bold').text('Dados do Aluno').moveDown(0.3);
  doc.font('Helvetica').fontSize(11).text(`Nome: ${nome}`).text(`Email: ${email}`).text(`Data: ${date.toLocaleDateString('pt-PT')}`).moveDown(1);
  doc.fontSize(12).font('Helvetica-Bold').text('Detalhes do Pagamento').moveDown(0.3);
  doc.font('Helvetica').fontSize(11).text(`Descrição: ${descricao}`).text(`Valor: ${valor.toFixed(2)} EUR`).text('Estado: PAGO').text(`Ref.ª: ${paymentId}`).moveDown(1);
  doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#CCCCCC').lineWidth(1).stroke().moveDown(0.5);
  doc.fontSize(16).font('Helvetica-Bold').text(`TOTAL: ${valor.toFixed(2)} EUR`, { align: 'right' }).moveDown(2);
  doc.fontSize(9).font('Helvetica').fillColor('#888888').text('GymBT — A tua app de fitness', { align: 'center' }).text('Documento gerado automaticamente', { align: 'center' });
  doc.end();

  const pdfBuffer = await pdfPromise;
  const bucket = admin.storage().bucket();
  const faturaPath = `faturas/${userId}/${paymentId}.pdf`;
  await bucket.file(faturaPath).save(pdfBuffer, { contentType: 'application/pdf', metadata: { metadata: { userId, paymentId, nome, valor: String(valor) } } });
  const [faturaUrl] = await bucket.file(faturaPath).getSignedUrl({ action: 'read', expires: Date.now() + 30 * 24 * 60 * 60 * 1000 });
  await db.collection('pagamentos').doc(paymentId).update({ faturaUrl });
}
