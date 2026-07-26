import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();
const messaging = admin.messaging();

// ────────────────────────────────────────────────
// CRIAÇÃO DE UTILIZADOR
// ────────────────────────────────────────────────

/**
 * Cria automaticamente o documento do utilizador no Firestore
 * quando uma nova conta Firebase Auth é criada.
 * Por defeito todos os novos utilizadores são 'aluno'.
 * Para criar um admin, define role: 'admin' manualmente no Firestore.
 */
export const onUserCreated = functions.auth.user().onCreate(async (user) => {
  const userDoc = {
    nome: user.displayName ?? user.email?.split('@')[0] ?? 'Novo Aluno',
    email: user.email ?? '',
    role: 'aluno',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection('users').doc(user.uid).set(userDoc);
  console.log(`User document created for ${user.uid} with role: aluno`);
});

// ────────────────────────────────────────────────
// CALLABLE: Criar aluno (admin)
// ────────────────────────────────────────────────

interface CreateStudentResult {
  uid: string;
  email: string;
  temporaryPassword?: string;
}

/**
 * Callable function que permite ao admin criar um novo aluno.
 * Cria a conta Firebase Auth + documento Firestore.
 * O admin que invoca deve estar autenticado e ter role='admin'.
 */
export const createStudent = functions.region('europe-west1').https.onCall(
  async (request): Promise<CreateStudentResult> => {
    // Verifica autenticação
    if (!request.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Tens de iniciar sessão para criar alunos.'
      );
    }

    // Verifica se quem chama é admin
    const callerDoc = await db.collection('users').doc(request.auth.uid).get();
    const callerRole = callerDoc.data()?.role;
    if (callerRole !== 'admin') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Apenas administradores podem criar alunos.'
      );
    }

    const { nome, email } = request.data;

    if (!nome || !email) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Nome e email são obrigatórios.'
      );
    }

    // Verifica se já existe
    try {
      const existingUser = await auth.getUserByEmail(email);
      if (existingUser) {
        // Já existe — apenas garante que o documento Firestore tem os dados
        await db.collection('users').doc(existingUser.uid).set(
          {
            nome: nome,
            email: email,
            role: 'aluno',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        return {
          uid: existingUser.uid,
          email: email,
        };
      }
    } catch (_) {
      // Não existe — continua para criar
    }

    // Gera password aleatória
    const temporaryPassword = Math.random().toString(36).slice(-10) + 'A1!';

    // Cria utilizador Firebase Auth
    const userRecord = await auth.createUser({
      email: email,
      password: temporaryPassword,
      displayName: nome,
    });

    // Cria documento Firestore
    await db.collection('users').doc(userRecord.uid).set({
      nome: nome,
      email: email,
      role: 'aluno',
      pesoAtual: null,
      altura: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(
      `Admin ${request.auth.uid} created student ${userRecord.uid} (${email})`
    );

    return {
      uid: userRecord.uid,
      email: email,
      temporaryPassword: temporaryPassword,
    };
  }
);

// ────────────────────────────────────────────────
// CALLABLE: Seed de alimentos (admin)
// ────────────────────────────────────────────────

interface SeedFoodsResult {
  added: number;
  skipped: number;
}

export const seedFoods = functions.region('europe-west1').https.onCall(
  async (request): Promise<SeedFoodsResult> => {
    // Verifica autenticação
    if (!request.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Tens de iniciar sessão.'
      );
    }

    // Verifica se quem chama é admin
    const callerDoc = await db.collection('users').doc(request.auth.uid).get();
    const callerRole = callerDoc.data()?.role;
    if (callerRole !== 'admin') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Apenas administradores podem gerir alimentos.'
      );
    }

    const { alimentos } = request.data;

    if (!alimentos || !Array.isArray(alimentos)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Array de alimentos obrigatório.'
      );
    }

    let added = 0;
    let skipped = 0;

    for (const alimento of alimentos) {
      const nome = alimento.nome as string;
      if (!nome) {
        skipped++;
        continue;
      }

      // Verifica duplicado
      const existing = await db
        .collection('alimentos')
        .where('nome', '==', nome)
        .limit(1)
        .get();

      if (!existing.empty) {
        skipped++;
        continue;
      }

      await db.collection('alimentos').add({
        nome: nome,
        caloriasPor100g: alimento.caloriasPor100g ?? 0,
        proteinasPor100g: alimento.proteinasPor100g ?? null,
        hidratosPor100g: alimento.hidratosPor100g ?? null,
        gordurasPor100g: alimento.gordurasPor100g ?? null,
        categoria: alimento.categoria ?? null,
      });
      added++;
    }

    console.log(`Seed complete: ${added} added, ${skipped} skipped`);
    return { added, skipped };
  }
);

// ────────────────────────────────────────────────
// NOTIFICAÇÕES PUSH
// ────────────────────────────────────────────────

/**
 * Envia notificação quando uma nova mensagem de chat é criada.
 * Gatilho: documento criado em chat/{salaId}/mensagens/{msgId}
 * Usa Cloud Functions 2nd Gen para compatibilidade com Firestore eur3.
 */
export const onNewChatMessage = onDocumentCreated(
  { document: 'chat/{salaId}/mensagens/{msgId}', region: 'europe-west1' },
  async (event) => {
    const data = event.data?.data();
    if (!data || !data.remetenteId) return;

    const salaId = event.params.salaId;
    const parts = salaId.split('_');
    if (parts.length < 3) return;

    const uid1 = parts[1];
    const uid2 = parts[2];
    const destinatarioId =
      data.remetenteId === uid1 ? uid2 : uid1;

    try {
      const userDoc = await db.collection('users').doc(destinatarioId).get();
      const fcmToken = userDoc.data()?.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token for user ${destinatarioId}`);
        return;
      }

      const senderDoc = await db
        .collection('users')
        .doc(data.remetenteId)
        .get();
      const senderName = senderDoc.data()?.nome ?? 'Personal Trainer';

      await messaging.send({
        token: fcmToken,
        notification: {
          title: senderName,
          body: data.texto?.substring(0, 100) ?? 'Nova mensagem',
        },
        data: {
          type: 'chat',
          salaId: salaId,
        },
      });

      console.log(`Notification sent to ${destinatarioId}`);
    } catch (error) {
      console.error('Error sending notification:', error);
    }
  }
);

/**
 * Gatilho agendado: lembrete de água a cada 2 horas (8h-22h).
 */
export const sendWaterReminder = functions.pubsub
  .schedule('every 2 hours from 08:00 to 22:00')
  .timeZone('Europe/Lisbon')
  .onRun(async (_context) => {
    try {
      const usersSnapshot = await db
        .collection('users')
        .where('role', '==', 'aluno')
        .get();

      const today = new Date().toISOString().split('T')[0];
      const promises = usersSnapshot.docs.map(async (userDoc) => {
        const fcmToken = userDoc.data().fcmToken;
        if (!fcmToken) return;

        const diaryDoc = await db
          .collection('users')
          .doc(userDoc.id)
          .collection('diario')
          .doc(today)
          .get();

        const agua = diaryDoc.data()?.agua ?? 0;
        if (agua >= 2500) return;

        await messaging.send({
          token: fcmToken,
          notification: {
            title: 'Hora de beber água! 💧',
            body: `Já bebeste ${agua}ml de ${2500}ml hoje. Continua!`,
          },
          data: {
            type: 'water_reminder',
          },
        });
      });

      await Promise.all(promises);
      console.log(`Water reminders sent`);
    } catch (error) {
      console.error('Error sending water reminders:', error);
    }

    return null;
  });

// ────────────────────────────────────────────────
// BACKUP DIÁRIO DO FIRESTORE
// ────────────────────────────────────────────────

export const dailyFirestoreBackup = functions.pubsub
  .schedule('every day 03:00')
  .timeZone('Europe/Lisbon')
  .onRun(async (_context) => {
    try {
      const bucket = admin.storage().bucket();
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const fileName = `backups/firestore-${timestamp}.json`;

      const collections = ['users', 'chat', 'alimentos', 'exercicios'];
      const backup: Record<string, unknown> = {};

      for (const col of collections) {
        const snapshot = await db.collection(col).get();
        backup[col] = snapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));
      }

      const file = bucket.file(fileName);
      await file.save(JSON.stringify(backup, null, 2), {
        contentType: 'application/json',
      });

      console.log(`Backup saved to ${fileName}`);
    } catch (error) {
      console.error('Error during backup:', error);
    }

    return null;
  });

// ────────────────────────────────────────────────
// LIMPEZA DE TOKENS FCM INVÁLIDOS
// ────────────────────────────────────────────────

export const cleanupInvalidFcmTokens = functions.pubsub
  .schedule('every day 04:00')
  .timeZone('Europe/Lisbon')
  .onRun(async (_context) => {
    try {
      const usersSnapshot = await db.collection('users').get();
      const batch = db.batch();
      let cleanupCount = 0;

      for (const userDoc of usersSnapshot.docs) {
        const fcmToken = userDoc.data().fcmToken;
        if (!fcmToken) continue;

        try {
          await messaging.send(
            {
              token: fcmToken,
              data: { type: 'token_check' },
            },
            true // dryRun
          );
        } catch (error: any) {
          if (error.code === 'messaging/registration-token-not-registered') {
            batch.update(userDoc.ref, {
              fcmToken: admin.firestore.FieldValue.delete(),
            });
            cleanupCount++;
            console.log(`Removed invalid token for user ${userDoc.id}`);
          }
        }
      }

      if (cleanupCount > 0) {
        await batch.commit();
      }
      console.log(`Cleaned up ${cleanupCount} invalid FCM tokens`);
    } catch (error) {
      console.error('Error cleaning up FCM tokens:', error);
    }

    return null;
  });
