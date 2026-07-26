"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupInvalidFcmTokens = exports.dailyFirestoreBackup = exports.sendWaterReminder = exports.onNewChatMessage = exports.seedFoods = exports.createStudent = exports.onUserCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
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
exports.onUserCreated = functions.auth.user().onCreate(async (user) => {
    const userDoc = {
        nome: user.displayName ?? user.email?.split('@')[0] ?? 'Novo Aluno',
        email: user.email ?? '',
        role: 'aluno',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await db.collection('users').doc(user.uid).set(userDoc);
    console.log(`User document created for ${user.uid} with role: aluno`);
});
/**
 * Callable function que permite ao admin criar um novo aluno.
 * Cria a conta Firebase Auth + documento Firestore.
 * O admin que invoca deve estar autenticado e ter role='admin'.
 */
exports.createStudent = functions.https.onCall(async (request) => {
    // Verifica autenticação
    if (!request.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Tens de iniciar sessão para criar alunos.');
    }
    // Verifica se quem chama é admin
    const callerDoc = await db.collection('users').doc(request.auth.uid).get();
    const callerRole = callerDoc.data()?.role;
    if (callerRole !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'Apenas administradores podem criar alunos.');
    }
    const { nome, email } = request.data;
    if (!nome || !email) {
        throw new functions.https.HttpsError('invalid-argument', 'Nome e email são obrigatórios.');
    }
    // Verifica se já existe
    try {
        const existingUser = await auth.getUserByEmail(email);
        if (existingUser) {
            // Já existe — apenas garante que o documento Firestore tem os dados
            await db.collection('users').doc(existingUser.uid).set({
                nome: nome,
                email: email,
                role: 'aluno',
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            return {
                uid: existingUser.uid,
                email: email,
            };
        }
    }
    catch (_) {
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
    console.log(`Admin ${request.auth.uid} created student ${userRecord.uid} (${email})`);
    return {
        uid: userRecord.uid,
        email: email,
        temporaryPassword: temporaryPassword,
    };
});
exports.seedFoods = functions.https.onCall(async (request) => {
    // Verifica autenticação
    if (!request.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Tens de iniciar sessão.');
    }
    // Verifica se quem chama é admin
    const callerDoc = await db.collection('users').doc(request.auth.uid).get();
    const callerRole = callerDoc.data()?.role;
    if (callerRole !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'Apenas administradores podem gerir alimentos.');
    }
    const { alimentos } = request.data;
    if (!alimentos || !Array.isArray(alimentos)) {
        throw new functions.https.HttpsError('invalid-argument', 'Array de alimentos obrigatório.');
    }
    let added = 0;
    let skipped = 0;
    for (const alimento of alimentos) {
        const nome = alimento.nome;
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
});
// ────────────────────────────────────────────────
// NOTIFICAÇÕES PUSH
// ────────────────────────────────────────────────
/**
 * Envia notificação quando uma nova mensagem de chat é criada.
 * Gatilho: documento criado em chat/{salaId}/mensagens/{msgId}
 */
exports.onNewChatMessage = functions.firestore
    .document('chat/{salaId}/mensagens/{msgId}')
    .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data || !data.remetenteId)
        return null;
    const salaId = context.params.salaId;
    const parts = salaId.split('_');
    if (parts.length < 3)
        return null;
    const uid1 = parts[1];
    const uid2 = parts[2];
    const destinatarioId = data.remetenteId === uid1 ? uid2 : uid1;
    try {
        const userDoc = await db.collection('users').doc(destinatarioId).get();
        const fcmToken = userDoc.data()?.fcmToken;
        if (!fcmToken) {
            console.log(`No FCM token for user ${destinatarioId}`);
            return null;
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
    }
    catch (error) {
        console.error('Error sending notification:', error);
    }
    return null;
});
/**
 * Gatilho agendado: lembrete de água a cada 2 horas (8h-22h).
 */
exports.sendWaterReminder = functions.pubsub
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
            if (!fcmToken)
                return;
            const diaryDoc = await db
                .collection('users')
                .doc(userDoc.id)
                .collection('diario')
                .doc(today)
                .get();
            const agua = diaryDoc.data()?.agua ?? 0;
            if (agua >= 2500)
                return;
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
    }
    catch (error) {
        console.error('Error sending water reminders:', error);
    }
    return null;
});
// ────────────────────────────────────────────────
// BACKUP DIÁRIO DO FIRESTORE
// ────────────────────────────────────────────────
exports.dailyFirestoreBackup = functions.pubsub
    .schedule('every day 03:00')
    .timeZone('Europe/Lisbon')
    .onRun(async (_context) => {
    try {
        const bucket = admin.storage().bucket();
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const fileName = `backups/firestore-${timestamp}.json`;
        const collections = ['users', 'chat', 'alimentos', 'exercicios'];
        const backup = {};
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
    }
    catch (error) {
        console.error('Error during backup:', error);
    }
    return null;
});
// ────────────────────────────────────────────────
// LIMPEZA DE TOKENS FCM INVÁLIDOS
// ────────────────────────────────────────────────
exports.cleanupInvalidFcmTokens = functions.pubsub
    .schedule('every day 04:00')
    .timeZone('Europe/Lisbon')
    .onRun(async (_context) => {
    try {
        const usersSnapshot = await db.collection('users').get();
        const batch = db.batch();
        let cleanupCount = 0;
        for (const userDoc of usersSnapshot.docs) {
            const fcmToken = userDoc.data().fcmToken;
            if (!fcmToken)
                continue;
            try {
                await messaging.send({
                    token: fcmToken,
                    data: { type: 'token_check' },
                }, true // dryRun
                );
            }
            catch (error) {
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
    }
    catch (error) {
        console.error('Error cleaning up FCM tokens:', error);
    }
    return null;
});
//# sourceMappingURL=index.js.map