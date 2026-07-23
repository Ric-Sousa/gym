import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ────────────────────────────────────────────────
// NOTIFICAÇÕES PUSH
// ────────────────────────────────────────────────

/**
 * Envia notificação quando uma nova mensagem de chat é criada.
 * Gatilho: documento criado em chat/{salaId}/mensagens/{msgId}
 */
export const onNewChatMessage = functions.firestore
  .document('chat/{salaId}/mensagens/{msgId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data || !data.remetenteId) return null;

    const salaId = context.params.salaId;
    // Extrai UIDs do ID da sala: formato "chat_uid1_uid2"
    const parts = salaId.split('_');
    if (parts.length < 3) return null;

    const uid1 = parts[1];
    const uid2 = parts[2];
    const destinatarioId =
      data.remetenteId === uid1 ? uid2 : uid1;

    try {
      // Obtém o token FCM do destinatário
      const userDoc = await db.collection('users').doc(destinatarioId).get();
      const fcmToken = userDoc.data()?.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token for user ${destinatarioId}`);
        return null;
      }

      // Obtém nome do remetente
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

    return null;
  });

/**
 * Gatilho agendado: lembrete de água a cada 2 horas (8h-22h).
 * Usar Cloud Scheduler para publicar no tópico 'water-reminder'.
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

        // Verifica se já atingiu a meta de água
        const diaryDoc = await db
          .collection('users')
          .doc(userDoc.id)
          .collection('diario')
          .doc(today)
          .get();

        const agua = diaryDoc.data()?.agua ?? 0;
        if (agua >= 2500) return; // Já atingiu a meta

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

/**
 * Exporta os dados do Firestore para Cloud Storage diariamente.
 */
export const dailyFirestoreBackup = functions.pubsub
  .schedule('every day 03:00')
  .timeZone('Europe/Lisbon')
  .onRun(async (_context) => {
    try {
      const bucket = admin.storage().bucket();
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const fileName = `backups/firestore-${timestamp}.json`;

      // Exporta todas as coleções principais
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

/**
 * Remove tokens FCM inválidos quando o envio falha.
 */
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
          // Tenta enviar uma mensagem silenciosa para verificar
          await messaging.send({
            token: fcmToken,
            data: { type: 'token_check' },
          }, { dryRun: true });
        } catch (error: any) {
          if (error.code === 'messaging/registration-token-not-registered') {
            batch.update(userDoc.ref, { fcmToken: admin.firestore.FieldValue.delete() });
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
