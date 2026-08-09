import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Stripe from 'stripe';
import PDFDocument from 'pdfkit';
import { shouldDeactivateExpiredContract } from './contract_expiry.js';

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();
const messaging = admin.messaging();

// ═══ Stripe ═══
const stripeConfig = functions.config().stripe;
const stripeSecret: string | undefined = stripeConfig?.secret_key;
const stripeWebhookSecret: string = stripeConfig?.webhook_secret || '';

if (!stripeSecret) {
  console.warn('⚠️  Stripe secret_key não definida.');
}

const stripe = stripeSecret
  ? new Stripe(stripeSecret, { apiVersion: '2025-06-30.acacia' as any })
  : null;

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

// CORS para todas as rotas
createStudentApp.use((_req: any, res: any, next: any) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  next();
});

createStudentApp.options('/', (_req: any, res: any) => { res.status(204).send(''); });

createStudentApp.post('/', async (req: any, res: any) => {
  // Aceita ambos os formatos: {data: {...}} (onCall antigo) ou fields diretos
  const d = (req.body && req.body.data) ? req.body.data : (req.body || {});
  const { nome, email, personalId, genero, password, authToken } = d;
  const isActive = d.isActive !== false;

  console.log('createStudent body keys:', Object.keys(req.body || {}), 'nome:', nome, 'email:', email);

  if (!nome || !email) {
    res.status(400).json({ error: { message: 'Nome e email obrigatórios.' } });
    return;
  }

  if (!authToken) {
    res.status(401).json({ error: { message: 'Login necessário.' } });
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
    const existingUser = await auth.getUserByEmail(email);
    if (existingUser) {
      await db.collection('users').doc(existingUser.uid).set({
        nome, email, role: 'aluno',
        ...(personalId ? { personalId } : {}),
        ...(genero ? { genero } : {}),
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
  } catch (_) { /* não existe */ }

  try {
    const temporaryPassword = password || (Math.random().toString(36).slice(-10) + 'A1!');
    const userRecord = await auth.createUser({ email, password: temporaryPassword, displayName: nome });
    await db.collection('users').doc(userRecord.uid).set({
      nome, email, role: 'aluno',
      personalId: personalId || null,
      genero: genero || 'feminino',
      pesoAtual: null, altura: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive,
      ...(isActive ? {} : { deactivatedAt: admin.firestore.FieldValue.serverTimestamp() }),
    });
    res.json({ uid: userRecord.uid, email, created: true, temporaryPassword: password ? undefined : temporaryPassword });
  } catch (e: any) {
    res.status(400).json({ error: { message: e.message || 'Erro ao criar utilizador.' } });
  }
});

export const createStudentHttp = functions.region('europe-west1').https.onRequest(createStudentApp);

// ═══ DELETE STUDENT (onRequest) ═══
const deleteStudentApp = require('express')();
deleteStudentApp.use(require('express').json());
deleteStudentApp.use((_req: any, res: any, next: any) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  next();
});
deleteStudentApp.options('/', (_req: any, res: any) => { res.status(204).send(''); });
deleteStudentApp.post('/', async (req: any, res: any) => {
  const d = (req.body && req.body.data) ? req.body.data : (req.body || {});
  const { userId, authToken } = d;

  if (!userId) {
    res.status(400).json({ error: { message: 'userId obrigatório.' } });
    return;
  }
  if (!authToken) {
    res.status(401).json({ error: { message: 'Login necessário.' } });
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

  // Não deixar o admin apagar-se a si próprio
  if (userId === callerUid) {
    res.status(400).json({ error: { message: 'Não podes apagar a tua própria conta.' } });
    return;
  }

  try {
    await auth.deleteUser(userId);
  } catch (e: any) {
    if (e.code === 'auth/user-not-found') {
      // Utilizador já não existe no Auth — limpa só o Firestore
    } else {
      res.status(400).json({ error: { message: e.message || 'Erro ao apagar utilizador.' } });
      return;
    }
  }

  await db.collection('users').doc(userId).delete();
  res.json({ success: true, message: 'Aluno eliminado com sucesso.' });
});

export const deleteStudentHttp = functions.region('europe-west1').https.onRequest(deleteStudentApp);

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
export const searchOpenFoodFacts = functions.region('europe-west1').https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
  }

  const query = typeof data?.query === 'string' ? data.query.trim() : '';
  if (query.length < 3 || query.length > 80) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'A pesquisa deve ter entre 3 e 80 caracteres.',
    );
  }

  const params = new URLSearchParams({
    search_terms: query,
    search_simple: '1',
    action: 'process',
    json: '1',
    page_size: '20',
    lc: 'pt',
    fields: 'code,product_name,product_name_pt,nutriments,categories_tags_pt',
  });

  try {
    const response = await fetch(
      `https://pt.openfoodfacts.org/cgi/search.pl?${params.toString()}`,
      {
        headers: {
          'User-Agent': 'GymApp/1.0 (https://github.com/Ric-Sousa/gym)',
          Accept: 'application/json',
        },
        signal: AbortSignal.timeout(8000),
      },
    );

    if (!response.ok) {
      console.warn(`Open Food Facts returned HTTP ${response.status}.`);
      return { products: [] };
    }

    const body: unknown = await response.json();
    if (!body || typeof body !== 'object') return { products: [] };
    const products = (body as { products?: unknown }).products;
    return { products: Array.isArray(products) ? products.slice(0, 20) : [] };
  } catch (error) {
    console.warn('Open Food Facts request failed:', error);
    return { products: [] };
  }
});

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

export const createCheckoutSession = functions.region('europe-west1').https.onCall(async (data, context) => {
  if (!stripe) throw new functions.https.HttpsError('failed-precondition', 'Stripe não configurado.');
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
  const callerDoc = await db.collection('users').doc(context.auth.uid).get();
  if (callerDoc.data()?.role !== 'admin') throw new functions.https.HttpsError('permission-denied', 'Apenas admin.');

  const { userId, valor, descricao } = data;
  if (!userId || !valor || valor <= 0) throw new functions.https.HttpsError('invalid-argument', 'userId e valor obrigatórios.');

  const paymentRef = await db.collection('pagamentos').add({
    userId, valor, moeda: 'eur', status: 'pending',
    descricao: descricao || 'Mensalidade',
    data: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const session = await stripe.checkout.sessions.create({
    payment_method_types: ['card'], mode: 'payment',
    line_items: [{ price_data: { currency: 'eur', product_data: { name: descricao || 'Mensalidade GymBT' }, unit_amount: Math.round(valor * 100) }, quantity: 1 }],
    metadata: { paymentId: paymentRef.id, userId },
    success_url: 'https://gymbt-4ef87.web.app/perfil?pagamento=sucesso',
    cancel_url: 'https://gymbt-4ef87.web.app/perfil?pagamento=cancelado',
  });

  await paymentRef.update({ stripeSessionId: session.id });
  return { url: session.url!, paymentId: paymentRef.id };
});

// ──────────── FIRESTORE TRIGGERS ────────────

// ═══ NOTIFICAÇÕES DE CHAT & BOOKING (callables v1 — compatível com eur3) ═══

// Resolve o UID autenticado. A callable v1 recebe (data, context), mas
// mantém o token no payload como fallback para clientes Web antigos.
async function resolvedUid(data: any, context: any): Promise<string> {
  if (context.auth?.uid) return context.auth.uid;
  const token = data?.authToken;
  if (!token)
    throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
  try {
    const decoded = await auth.verifyIdToken(token);
    return decoded.uid;
  } catch (_) {
    throw new functions.https.HttpsError('unauthenticated', 'Token inválido. Tenta sair e entrar novamente.');
  }
}

export const sendChatNotification = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    const uid = await resolvedUid(data, context);

    const { salaId, remetenteId, texto } = data;
    if (!salaId || !remetenteId || !texto)
      throw new functions.https.HttpsError('invalid-argument', 'salaId, remetenteId e texto obrigatórios.');

    // Verifica que o remetente é o utilizador autenticado
    if (remetenteId !== uid)
      throw new functions.https.HttpsError('permission-denied', 'ID não corresponde.');

    const senderDoc = await db.collection('users').doc(remetenteId).get();
    const title = senderDoc.data()?.nome ?? 'Personal Trainer';
    const notification = {
      title,
      body: texto.substring(0, 100),
    };

    // Salas 1:1 usam o formato chat_uid_uid. Grupos usam o próprio ID do
    // documento em /grupos e precisam de notificar todos os membros.
    const parts = salaId.split('_');
    let recipientIds: string[];
    if (parts.length >= 3 && parts[0] === 'chat') {
      const uid1 = parts[1];
      const uid2 = parts[2];
      recipientIds = [remetenteId === uid1 ? uid2 : uid1];
    } else {
      const groupDoc = await db.collection('grupos').doc(salaId).get();
      if (!groupDoc.exists) return { ok: true };
      const members = groupDoc.data()?.membros;
      if (!Array.isArray(members)) return { ok: true };
      recipientIds = members.filter((id: unknown): id is string =>
        typeof id === 'string' && id !== remetenteId,
      );
    }

    if (recipientIds.length === 0) return { ok: true };

    const recipientDocs = await Promise.all(
      recipientIds.map((id) => db.collection('users').doc(id).get()),
    );
    const sends = recipientDocs
      .map((doc) => ({ id: doc.id, token: doc.data()?.fcmToken as string | undefined }))
      .filter((recipient): recipient is { id: string; token: string } =>
        Boolean(recipient.token),
      )
      .map(({ token }) => messaging.send({
        token,
        notification,
        data: { type: 'chat', salaId },
      }));

    await Promise.all(sends);
    return { ok: true };
  });

export const notifyNewBooking = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    const uid = await resolvedUid(data, context);

    const { studentId, trainerId, bookingDate, tipo } = data;
    if (!studentId || !trainerId || !bookingDate)
      throw new functions.https.HttpsError('invalid-argument', 'studentId, trainerId e bookingDate obrigatórios.');

    // Verifica que o aluno é o utilizador autenticado
    if (studentId !== uid)
      throw new functions.https.HttpsError('permission-denied', 'ID não corresponde.');

    const trainerDoc = await db.collection('users').doc(trainerId).get();
    const studentDoc = await db.collection('users').doc(studentId).get();

    const fcmToken = trainerDoc.data()?.fcmToken;
    if (!fcmToken) return { ok: true };

    const date = new Date(bookingDate);
    const timeStr = `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
    const dateStr = date.toLocaleDateString('pt-PT', { weekday: 'short', day: 'numeric', month: 'short' });
    const tipoLabel = tipo === 'online' ? '💻 Online' : '🏋️ Presencial';

    await messaging.send({
      token: fcmToken,
      notification: {
        title: 'Nova Aula Marcada 📅',
        body: `${studentDoc.data()?.nome ?? 'Aluno'} marcou aula para ${dateStr} às ${timeStr} (${tipoLabel})`,
      },
      data: { type: 'new_booking', studentId },
    });
    return { ok: true };
  });

export const notifyBookingUpdate = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    const uid = await resolvedUid(data, context);

    const { bookingId, studentId, trainerId, newStatus, bookingDate, tipo } = data;
    if (!bookingId || !studentId || !trainerId || !newStatus)
      throw new functions.https.HttpsError('invalid-argument', 'bookingId, studentId, trainerId e newStatus obrigatórios.');

    const callerUid = uid;
    const callerDoc = await db.collection('users').doc(callerUid).get();
    const callerName = callerDoc.data()?.nome ?? 'Utilizador';

    const date = bookingDate ? new Date(bookingDate) : new Date();
    const timeStr = `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
    const dateStr = date.toLocaleDateString('pt-PT', { weekday: 'short', day: 'numeric', month: 'short' });
    const tipoLabel = tipo === 'online' ? '💻 Online' : '🏋️ Presencial';

    if (newStatus === 'confirmed' || newStatus === 'cancelled') {
      // Admin updated status → notify student
      const studentDoc = await db.collection('users').doc(studentId).get();
      const fcmToken = studentDoc.data()?.fcmToken;
      if (!fcmToken) return { ok: true };

      const title = newStatus === 'confirmed' ? 'Aula Confirmada ✅' : 'Aula Cancelada ❌';
      const body = newStatus === 'confirmed'
        ? `${callerName} confirmou a tua aula de ${dateStr} às ${timeStr} (${tipoLabel})`
        : `${callerName} cancelou a tua aula de ${dateStr} às ${timeStr}`;

      await messaging.send({
        token: fcmToken,
        notification: { title, body },
        data: { type: 'booking_update', bookingId, newStatus },
      });
    } else if (newStatus === 'completed') {
      // Student completed → notify trainer
      const trainerDoc = await db.collection('users').doc(trainerId).get();
      const fcmToken = trainerDoc.data()?.fcmToken;
      if (!fcmToken) return { ok: true };

      const studentDoc = await db.collection('users').doc(studentId).get();
      const studentName = studentDoc.data()?.nome ?? 'Aluno';

      await messaging.send({
        token: fcmToken,
        notification: {
          title: 'Aula Concluída 💪',
          body: `${studentName} concluiu a aula de ${dateStr} às ${timeStr} (${tipoLabel})`,
        },
        data: { type: 'booking_update', bookingId, newStatus },
      });
    }
    return { ok: true };
  });

export const notifyBookingCancelled = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    const uid = await resolvedUid(data, context);

    const { bookingId, studentId, trainerId, bookingDate, tipo } = data;
    if (!bookingId || !studentId || !trainerId)
      throw new functions.https.HttpsError('invalid-argument', 'bookingId, studentId e trainerId obrigatórios.');

    // Apenas o aluno titular ou um admin pode notificar o cancelamento
    if (studentId !== uid) {
      const callerDoc = await db.collection('users').doc(uid).get();
      if (callerDoc.data()?.role !== 'admin')
        throw new functions.https.HttpsError('permission-denied', 'ID não corresponde.');
    }

    const studentDoc = await db.collection('users').doc(studentId).get();
    const fcmToken = (await db.collection('users').doc(trainerId).get()).data()?.fcmToken;
    if (!fcmToken) return { ok: true };

    const date = bookingDate ? new Date(bookingDate) : new Date();
    const timeStr = `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
    const dateStr = date.toLocaleDateString('pt-PT', { weekday: 'short', day: 'numeric', month: 'short' });
    const tipoLabel = tipo === 'online' ? '💻 Online' : '🏋️ Presencial';

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

// ──────────── SCHEDULED ────────────

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
  try { event = stripe.webhooks.constructEvent(req.body, sig, stripeWebhookSecret); } catch (e: any) {
    res.status(400).json({ error: `Webhook Error: ${e.message}` }); return;
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object as Stripe.Checkout.Session;
    const { paymentId, userId } = session.metadata || {};
    if (!paymentId) { res.status(400).json({ error: 'Missing paymentId' }); return; }
    await db.collection('pagamentos').doc(paymentId).update({
      status: 'paid',
      stripePaymentIntentId: typeof session.payment_intent === 'string' ? session.payment_intent : session.payment_intent?.id,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    if (userId) await generateInvoicePdf(paymentId, userId);
  }
  res.status(200).json({ received: true });
});

export const stripeWebhook = functions.region('europe-west1').https.onRequest(stripeApp);

// ──────────── HELPERS ────────────

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
