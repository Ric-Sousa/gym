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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.syncAccessFromPaidPayment = exports.stripeWebhook = exports.cleanupInvalidFcmTokens = exports.dailyFirestoreBackup = exports.sendWeeklyCheckin = exports.sendWeighInReminder = exports.sendWorkoutReminder = exports.sendWaterReminder = exports.sendPaymentRecoveryReminders = exports.notifyBookingStatusChange = exports.notifyUserAccessChange = exports.deactivateExpiredContractOnWrite = exports.deactivateExpiredContracts = exports.notifyBookingCancelled = exports.notifyBookingUpdate = exports.notifyNewBooking = exports.sendChatNotification = exports.createCheckoutSession = exports.resendPaymentRecovery = exports.createPaymentRecoveryCheckoutSession = exports.createPaymentCheckoutSession = exports.cancelPaymentSubscription = exports.cancelPayment = exports.createPaymentSchedule = exports.requestProgress = exports.searchOpenFoodFacts = exports.seedFoods = exports.deleteStudentHttp = exports.createStudentHttp = exports.onUserCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const node_crypto_1 = require("node:crypto");
const stripe_1 = __importDefault(require("stripe"));
const pdfkit_1 = __importDefault(require("pdfkit"));
const contract_expiry_js_1 = require("./contract_expiry.js");
const billing_js_1 = require("./billing.js");
const notifications_js_1 = require("./notifications.js");
admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();
const messaging = admin.messaging();
// ═══ Stripe ═══
// functions.config() is unavailable in Cloud Functions 2nd gen. Keep the
// legacy config for existing 1st gen functions, but use environment variables
// when this module is loaded by a 2nd gen container.
function runtimeConfig() {
    if (process.env.K_CONFIGURATION) {
        return {
            stripe: {
                secret_key: process.env.STRIPE_SECRET_KEY,
                webhook_secret: process.env.STRIPE_WEBHOOK_SECRET,
            },
            resend: {
                api_key: process.env.RESEND_API_KEY,
                from_email: process.env.RESEND_FROM_EMAIL,
            },
        };
    }
    return functions.config();
}
const configured = runtimeConfig();
const stripeConfig = configured.stripe ?? {};
const stripeSecret = stripeConfig.secret_key;
const stripeWebhookSecret = stripeConfig.webhook_secret || '';
if (!stripeSecret) {
    console.warn('⚠️  Stripe secret_key não definida.');
}
const stripe = stripeSecret
    ? new stripe_1.default(stripeSecret, { apiVersion: '2025-06-30.acacia' })
    : null;
const publicAppUrl = 'https://gymbt-4ef87.web.app';
const recoveryTokenLifetimeMs = 7 * 24 * 60 * 60 * 1000;
function hashRecoveryToken(token) {
    return (0, node_crypto_1.createHash)('sha256').update(token).digest('hex');
}
async function issuePaymentRecovery(paymentId, userId, reason) {
    const token = (0, node_crypto_1.randomBytes)(32).toString('base64url');
    const tokenHash = hashRecoveryToken(token);
    const expiresAt = new Date(Date.now() + recoveryTokenLifetimeMs);
    await db.collection('paymentRecoveryTokens').doc(tokenHash).set({
        paymentId,
        userId,
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
    await (0, notifications_js_1.createNotification)({
        userId,
        type: 'payment_recovery',
        title,
        body,
        action: 'payment_recovery',
        paymentId,
        metadata: { recoveryUrl },
    });
    await (0, notifications_js_1.sendUserPush)(userId, title, body, {
        type: 'payment_recovery',
        paymentId,
        link: recoveryUrl,
    });
    if (typeof user.email === 'string' && user.email.length > 0) {
        await (0, notifications_js_1.sendUserEmail)(user.email, title, `<p>Olá ${(0, notifications_js_1.escapeHtml)(name)},</p><p>${(0, notifications_js_1.escapeHtml)(body)}</p>` +
            `<p><a href="${recoveryUrl}">Abrir portal de pagamento seguro</a></p>` +
            `<p>Este link expira em 7 dias.</p>`);
    }
}
// ──────────── AUTH ────────────
exports.onUserCreated = functions.auth.user().onCreate(async (user) => {
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
createStudentApp.use((_req, res, next) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    next();
});
createStudentApp.options('/', (_req, res) => { res.status(204).send(''); });
createStudentApp.post('/', async (req, res) => {
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
    let callerUid;
    try {
        const decoded = await auth.verifyIdToken(authToken);
        callerUid = decoded.uid;
    }
    catch (_) {
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
    }
    catch (_) { /* não existe */ }
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
    }
    catch (e) {
        res.status(400).json({ error: { message: e.message || 'Erro ao criar utilizador.' } });
    }
});
exports.createStudentHttp = functions.region('europe-west1').https.onRequest(createStudentApp);
// ═══ DELETE STUDENT (onRequest) ═══
const deleteStudentApp = require('express')();
deleteStudentApp.use(require('express').json());
deleteStudentApp.use((_req, res, next) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    next();
});
deleteStudentApp.options('/', (_req, res) => { res.status(204).send(''); });
deleteStudentApp.post('/', async (req, res) => {
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
    let callerUid;
    try {
        const decoded = await auth.verifyIdToken(authToken);
        callerUid = decoded.uid;
    }
    catch (_) {
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
    }
    catch (e) {
        if (e.code === 'auth/user-not-found') {
            // Utilizador já não existe no Auth — limpa só o Firestore
        }
        else {
            res.status(400).json({ error: { message: e.message || 'Erro ao apagar utilizador.' } });
            return;
        }
    }
    await db.collection('users').doc(userId).delete();
    res.json({ success: true, message: 'Aluno eliminado com sucesso.' });
});
exports.deleteStudentHttp = functions.region('europe-west1').https.onRequest(deleteStudentApp);
exports.seedFoods = functions.region('europe-west1').https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
    const callerDoc = await db.collection('users').doc(context.auth.uid).get();
    if (callerDoc.data()?.role !== 'admin')
        throw new functions.https.HttpsError('permission-denied', 'Apenas admin.');
    const { alimentos } = data;
    if (!alimentos || !Array.isArray(alimentos))
        throw new functions.https.HttpsError('invalid-argument', 'Array obrigatório.');
    let added = 0, skipped = 0;
    for (const a of alimentos) {
        if (!a.nome) {
            skipped++;
            continue;
        }
        const existing = await db.collection('alimentos').where('nome', '==', a.nome).limit(1).get();
        if (!existing.empty) {
            skipped++;
            continue;
        }
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
function normaliseFoodSearchTerm(value) {
    return value
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .toLowerCase()
        .replace(/\s+/g, ' ')
        .trim();
}
function singularFoodSearchTerm(value) {
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
function foodSearchVariants(query) {
    const normalised = normaliseFoodSearchTerm(query);
    const singular = singularFoodSearchTerm(normalised);
    const aliases = {
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
async function fetchOpenFoodFactsProducts(searchTerm) {
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
        fields: 'code,product_name,product_name_pt,languages_codes,nutriments,categories_tags_pt,categories_tags',
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
            const body = await response.json();
            if (!body || typeof body !== 'object')
                continue;
            const products = body.products;
            if (!Array.isArray(products))
                continue;
            const validProducts = products.filter((product) => Boolean(product) && typeof product === 'object').filter((product) => {
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
            if (validProducts.length > 0)
                return validProducts;
        }
        catch (error) {
            console.warn(`Open Food Facts request failed for ${host}:`, error);
        }
    }
    return [];
}
exports.searchOpenFoodFacts = functions.region('europe-west1').https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
    }
    const query = typeof data?.query === 'string' ? data.query.trim() : '';
    if (query.length < 3 || query.length > 80) {
        throw new functions.https.HttpsError('invalid-argument', 'A pesquisa deve ter entre 3 e 80 caracteres.');
    }
    try {
        const products = [];
        const seenCodes = new Set();
        const seenNames = new Set();
        const searchTerms = foodSearchVariants(query);
        const portugueseQuery = normaliseFoodSearchTerm(query);
        for (const searchTerm of searchTerms) {
            const responseProducts = await fetchOpenFoodFactsProducts(searchTerm);
            if (responseProducts.length === 0)
                continue;
            const rankedProducts = responseProducts
                .filter((product) => Boolean(product) && typeof product === 'object')
                // A API devolve frequentemente fichas sem nutrientes. Não as
                // contamos como resultados, porque a app não as consegue mostrar.
                .filter(hasUsableNutrition)
                .filter((product) => isRelevantFoodResult(product, portugueseQuery))
                .sort((a, b) => portugueseProductRank(b, portugueseQuery) -
                portugueseProductRank(a, portugueseQuery));
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
                if (code)
                    seenCodes.add(code);
                if (nameKey)
                    seenNames.add(nameKey);
                products.push(product);
                if (products.length >= 40)
                    break;
            }
            if (products.length >= 40)
                break;
            // Continua após uma resposta vazia/incompleta para permitir o alias
            // inglês, mas para assim que já temos resultados suficientes para a
            // lista. Isto evita várias chamadas sequenciais desnecessárias.
            if (products.length >= 8)
                break;
        }
        products.sort((a, b) => portugueseProductRank(b, portugueseQuery) -
            portugueseProductRank(a, portugueseQuery));
        return { products: products.slice(0, 20) };
    }
    catch (error) {
        console.warn('Open Food Facts request failed:', error);
        return { products: [] };
    }
});
function isRelevantFoodResult(product, portugueseQuery) {
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
        .filter((name) => typeof name === 'string')
        .map(normaliseFoodSearchTerm);
    if (queryTerms.some((term) => names.some((name) => name.includes(term)))) {
        return true;
    }
    const categories = [product.categories_tags_pt, product.categories_tags]
        .flatMap((value) => Array.isArray(value) ? value : [])
        .filter((value) => typeof value === 'string')
        .map(normaliseFoodSearchTerm);
    return queryTerms.some((term) => categories.some((category) => category.includes(term)));
}
function hasUsableNutrition(product) {
    const nutriments = product.nutriments;
    if (!nutriments || typeof nutriments !== 'object')
        return false;
    const values = nutriments;
    return ['energy-kcal_100g', 'energy_100g'].some((key) => {
        const value = values[key];
        if (typeof value === 'number')
            return Number.isFinite(value);
        if (typeof value === 'string')
            return Number.isFinite(Number(value));
        return false;
    });
}
function portugueseProductRank(product, portugueseQuery) {
    let rank = 0;
    // Os aliases ingleses servem apenas para encontrar mais fichas na API;
    // nunca podem, por si só, tornar um nome inglês irrelevante num resultado.
    const queryTerms = [...new Set([
            portugueseQuery,
            singularFoodSearchTerm(portugueseQuery),
        ])].filter((term) => term.length >= 3);
    const names = [product.product_name_pt, product.product_name]
        .filter((name) => typeof name === 'string')
        .map(normaliseFoodSearchTerm);
    if (names.some((name) => name.includes(portugueseQuery)))
        rank += 10;
    if (names.some((name) => queryTerms.some((term) => name.includes(term)))) {
        rank += 5;
    }
    if (typeof product.product_name_pt === 'string' &&
        product.product_name_pt.trim().length > 0) {
        rank += 3;
    }
    if (hasPortugueseLanguage(product))
        rank += 2;
    return rank;
}
function hasPortugueseLanguage(product) {
    const languages = product.languages_codes;
    if (Array.isArray(languages)) {
        return languages.some((language) => String(language).toLowerCase().startsWith('pt'));
    }
    if (languages && typeof languages === 'object') {
        return Object.keys(languages).some((language) => language.toLowerCase().startsWith('pt'));
    }
    return false;
}
exports.requestProgress = functions.region('europe-west1').https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
    const callerDoc = await db.collection('users').doc(context.auth.uid).get();
    if (callerDoc.data()?.role !== 'admin')
        throw new functions.https.HttpsError('permission-denied', 'Apenas admin.');
    const { userId } = data;
    if (!userId)
        throw new functions.https.HttpsError('invalid-argument', 'userId obrigatório.');
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
    }
    catch (e) {
        console.error('FCM error:', e);
    }
    return { success: true, message: 'Pedido de progresso enviado.' };
});
exports.createPaymentSchedule = functions.region('europe-west1').https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
    const callerDoc = await db.collection('users').doc(context.auth.uid).get();
    if (callerDoc.data()?.role !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'Apenas admin.');
    }
    const { userId, valor, tipoMensalidade } = data;
    if (typeof userId !== 'string' || userId.length === 0 ||
        typeof valor !== 'number' || !Number.isFinite(valor) || valor <= 0 ||
        !(0, billing_js_1.isBillingType)(tipoMensalidade)) {
        throw new functions.https.HttpsError('invalid-argument', 'Aluno, valor e tipo de mensalidade são obrigatórios.');
    }
    const studentRef = db.collection('users').doc(userId);
    const studentDoc = await studentRef.get();
    if (!studentDoc.exists || studentDoc.data()?.role === 'admin') {
        throw new functions.https.HttpsError('not-found', 'Aluno não encontrado.');
    }
    const now = new Date();
    const candidateStarts = [now];
    const currentContractEnd = asDate(studentDoc.data()?.contractEndsAt);
    if (currentContractEnd && currentContractEnd > now) {
        candidateStarts.push(currentContractEnd);
    }
    const existingPayments = await db.collection('pagamentos')
        .where('userId', '==', userId)
        .get();
    for (const payment of existingPayments.docs) {
        const periodEnd = asDate(payment.data().periodoFim);
        if (periodEnd && periodEnd > now)
            candidateStarts.push(periodEnd);
    }
    const periodStart = new Date(Math.max(...candidateStarts.map((date) => date.getTime())));
    const period = (0, billing_js_1.calculateBillingPeriod)(periodStart, tipoMensalidade);
    const paymentRef = await db.collection('pagamentos').add({
        userId,
        valor,
        moeda: 'eur',
        status: 'pending',
        tipoMensalidade,
        recorrente: true,
        descricao: `Mensalidade ${billing_js_1.billingTypeLabels[tipoMensalidade]}`,
        data: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        periodoInicio: admin.firestore.Timestamp.fromDate(period.start),
        periodoFim: admin.firestore.Timestamp.fromDate(period.end),
        dataVencimento: admin.firestore.Timestamp.fromDate(period.start > now ? period.start : now),
    });
    await (0, notifications_js_1.createNotification)({
        userId,
        type: 'payment_created',
        title: 'Nova cobrança disponível 💳',
        body: `Foi criada uma cobrança de ${valor.toFixed(2)} EUR. Abre o Perfil para pagar ou ativar o automático.`,
        action: 'payment',
        paymentId: paymentRef.id,
    });
    await (0, notifications_js_1.sendUserPush)(userId, 'Nova cobrança disponível 💳', `Foi criada uma cobrança de ${valor.toFixed(2)} EUR.`, { type: 'payment_created', paymentId: paymentRef.id, link: `${publicAppUrl}/` });
    return {
        paymentId: paymentRef.id,
        periodoInicio: period.start.toISOString(),
        periodoFim: period.end.toISOString(),
    };
});
/** Cancela uma cobrança ainda não paga e interrompe a subscrição Stripe, se existir. */
exports.cancelPayment = (0, https_1.onRequest)({
    region: 'europe-west1',
    cors: false,
}, async (req, res) => {
    const origin = String(req.headers?.origin ?? '');
    const allowedOrigins = new Set([
        'https://gymbt-4ef87.web.app',
        'https://gymbt-4ef87.firebaseapp.com',
        'http://localhost:3000',
        'http://localhost:5000',
    ]);
    if (allowedOrigins.has(origin)) {
        res.set('Access-Control-Allow-Origin', origin);
        res.set('Vary', 'Origin');
    }
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }
    if (req.method !== 'POST') {
        res.status(405).json({ error: { message: 'Método não permitido.' } });
        return;
    }
    try {
        const authorization = String(req.headers?.authorization ?? '');
        const match = authorization.match(/^Bearer\s+(.+)$/i);
        if (!match) {
            throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
        }
        const decoded = await auth.verifyIdToken(match[1]);
        const data = (req.body?.data ?? req.body ?? {});
        const context = { auth: { uid: decoded.uid } };
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
            res.status(200).json({ data: { success: true, paymentId } });
            return;
        }
        if (payment.status === 'paid' || payment.status === 'refunded') {
            throw new functions.https.HttpsError('failed-precondition', 'Um pagamento já concluído ou reembolsado não pode ser cancelado.');
        }
        if (payment.stripeSubscriptionId) {
            if (!stripe) {
                throw new functions.https.HttpsError('failed-precondition', 'Stripe não está configurado para cancelar a subscrição.');
            }
            try {
                await stripe.subscriptions.cancel(String(payment.stripeSubscriptionId));
            }
            catch (error) {
                console.error('Stripe subscription cancellation failed', {
                    paymentId,
                    stripeSubscriptionId: payment.stripeSubscriptionId,
                    type: error?.type,
                    code: error?.code,
                    message: error?.message,
                    requestId: error?.requestId,
                });
                throw new functions.https.HttpsError('internal', 'Não foi possível cancelar a subscrição Stripe.');
            }
        }
        else if (payment.stripeSessionId && stripe) {
            // Sessões Checkout ainda abertas podem ser expiradas. Sessões já
            // concluídas não entram aqui porque o pagamento teria outro estado.
            try {
                const session = await stripe.checkout.sessions.retrieve(String(payment.stripeSessionId));
                if (session.status === 'open') {
                    await stripe.checkout.sessions.expire(session.id);
                }
            }
            catch (error) {
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
        await (0, notifications_js_1.createNotification)({
            userId: String(payment.userId),
            type: 'payment_cancelled',
            title: 'Cobrança cancelada',
            body: 'A cobrança foi cancelada pelo administrador e já não requer pagamento.',
            action: 'payment',
            paymentId,
        });
        await (0, notifications_js_1.sendUserPush)(String(payment.userId), 'Cobrança cancelada', 'A cobrança foi cancelada pelo administrador.', { type: 'payment_cancelled', paymentId, link: `${publicAppUrl}/` });
        res.status(200).json({ data: { success: true, paymentId } });
    }
    catch (error) {
        const status = error?.httpErrorCode?.status ?? 500;
        const message = error instanceof functions.https.HttpsError
            ? error.message
            : 'Não foi possível cancelar a cobrança.';
        res.status(status).json({
            error: {
                message,
                status: error instanceof functions.https.HttpsError
                    ? error.code
                    : 'internal',
            },
        });
    }
});
/** Agenda o cancelamento da renovação para o fim do período já pago. */
exports.cancelPaymentSubscription = functions.region('europe-west1').https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
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
    if (!stripe)
        throw new functions.https.HttpsError('failed-precondition', 'Stripe não configurado.');
    try {
        await stripe.subscriptions.update(String(payment.stripeSubscriptionId), {
            cancel_at_period_end: true,
        });
    }
    catch (error) {
        throw stripeCheckoutHttpsError(error, 'cancelamento da renovação');
    }
    await paymentRef.update({
        subscriptionCancelAtPeriodEnd: true,
        subscriptionCancelRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await (0, notifications_js_1.createNotification)({
        userId: String(payment.userId),
        type: 'subscription_cancelled',
        title: 'Renovação automática desativada',
        body: 'O acesso mantém-se ativo até ao fim do período já pago.',
        action: 'payment',
        paymentId,
    });
    return { success: true, paymentId };
});
exports.createPaymentCheckoutSession = functions.region('europe-west1').https.onCall(async (data, context) => {
    if (!stripe)
        throw new functions.https.HttpsError('failed-precondition', 'Stripe não configurado.');
    if (!context.auth)
        throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
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
    if (!(0, billing_js_1.isBillingType)(payment.tipoMensalidade)) {
        throw new functions.https.HttpsError('failed-precondition', 'Tipo de mensalidade inválido.');
    }
    const userDoc = await db.collection('users').doc(context.auth.uid).get();
    const user = userDoc.data() ?? {};
    const periodStart = asDate(payment.periodoInicio);
    const trialEnd = periodStart && periodStart.getTime() > Date.now() + 60000
        ? Math.floor(periodStart.getTime() / 1000)
        : null;
    const subscriptionData = {
        metadata: {
            paymentId,
            userId: context.auth.uid,
            tipoMensalidade: payment.tipoMensalidade,
        },
    };
    if (trialEnd != null)
        subscriptionData.trial_end = trialEnd;
    const interval = (0, billing_js_1.billingInterval)(payment.tipoMensalidade);
    let session;
    try {
        session = await stripe.checkout.sessions.create({
            mode: 'subscription',
            line_items: [{
                    price_data: {
                        currency: 'eur',
                        product_data: {
                            name: payment.descricao || `Mensalidade ${billing_js_1.billingTypeLabels[payment.tipoMensalidade]}`,
                        },
                        unit_amount: Math.round(Number(payment.valor) * 100),
                        recurring: interval,
                    },
                    quantity: 1,
                }],
            ...(typeof user.stripeCustomerId === 'string' && user.stripeCustomerId.length > 0
                ? { customer: user.stripeCustomerId }
                : { customer_email: user.email || undefined }),
            payment_method_collection: 'always',
            subscription_data: subscriptionData,
            metadata: { paymentId, userId: context.auth.uid },
            success_url: 'https://gymbt-4ef87.web.app/perfil?pagamento=sucesso',
            cancel_url: 'https://gymbt-4ef87.web.app/perfil?pagamento=cancelado',
        });
    }
    catch (error) {
        throw stripeCheckoutHttpsError(error, 'subscrição');
    }
    if (!session.url) {
        throw new functions.https.HttpsError('internal', 'O Stripe não devolveu um endereço de checkout.');
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
exports.createPaymentRecoveryCheckoutSession = functions
    .region('europe-west1')
    .https.onCall(async (data) => {
    if (!stripe) {
        throw new functions.https.HttpsError('failed-precondition', 'Stripe não configurado.');
    }
    const token = typeof data?.token === 'string' ? data.token.trim() : '';
    if (token.length < 32) {
        throw new functions.https.HttpsError('invalid-argument', 'Token inválido.');
    }
    const tokenRef = db.collection('paymentRecoveryTokens').doc(hashRecoveryToken(token));
    const tokenDoc = await tokenRef.get();
    const recovery = tokenDoc.data();
    const expiresAt = asDate(recovery?.expiresAt);
    if (!tokenDoc.exists || !recovery || !expiresAt || expiresAt <= new Date()) {
        throw new functions.https.HttpsError('not-found', 'Este link expirou ou não é válido.');
    }
    const paymentRef = db.collection('pagamentos').doc(String(recovery.paymentId));
    const paymentDoc = await paymentRef.get();
    const payment = paymentDoc.data();
    if (!paymentDoc.exists || !payment || payment.userId !== recovery.userId) {
        throw new functions.https.HttpsError('not-found', 'Cobrança não encontrada.');
    }
    if (payment.status === 'paid' || payment.status === 'cancelled' || payment.status === 'refunded') {
        throw new functions.https.HttpsError('failed-precondition', 'Esta cobrança já não está disponível.');
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
    let session;
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
    }
    catch (error) {
        throw stripeCheckoutHttpsError(error, 'recuperação');
    }
    if (!session.url) {
        throw new functions.https.HttpsError('internal', 'O Stripe não devolveu o checkout.');
    }
    await paymentRef.update({
        recoveryCheckoutSessionId: session.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { url: session.url, paymentId: paymentRef.id };
});
/** Permite ao admin reenviar o acesso ao portal sem expor o token existente. */
exports.resendPaymentRecovery = functions
    .region('europe-west1')
    .https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
    const caller = await db.collection('users').doc(context.auth.uid).get();
    if (caller.data()?.role !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'Apenas admin.');
    }
    const paymentId = typeof data?.paymentId === 'string' ? data.paymentId.trim() : '';
    const payment = await db.collection('pagamentos').doc(paymentId).get();
    if (!payment.exists || !payment.data()?.userId) {
        throw new functions.https.HttpsError('not-found', 'Pagamento não encontrado.');
    }
    await issuePaymentRecovery(paymentId, String(payment.data().userId), 'failed');
    return { success: true };
});
/**
 * Endpoint antigo mantido para clientes ainda não atualizados.
 * O fluxo novo deve usar createPaymentSchedule e o aluno deve iniciar o
 * checkout através de createPaymentCheckoutSession.
 */
exports.createCheckoutSession = functions.region('europe-west1').https.onCall(async (data, context) => {
    if (!stripe)
        throw new functions.https.HttpsError('failed-precondition', 'Stripe não configurado. Configura stripe.secret_key e publica as Functions.');
    if (!context.auth)
        throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
    const callerDoc = await db.collection('users').doc(context.auth.uid).get();
    if (callerDoc.data()?.role !== 'admin')
        throw new functions.https.HttpsError('permission-denied', 'Apenas admin.');
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
            success_url: 'https://gymbt-4ef87.web.app/perfil?pagamento=sucesso',
            cancel_url: 'https://gymbt-4ef87.web.app/perfil?pagamento=cancelado',
        });
        if (!session.url) {
            throw new functions.https.HttpsError('internal', 'O Stripe não devolveu um endereço de checkout.');
        }
        await paymentRef.update({
            stripeSessionId: session.id,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { url: session.url, paymentId: paymentRef.id };
    }
    catch (error) {
        // Não deixar cobranças órfãs quando o Stripe rejeita a sessão.
        await paymentRef.delete().catch(() => undefined);
        if (error instanceof functions.https.HttpsError)
            throw error;
        throw stripeCheckoutHttpsError(error, 'pagamento');
    }
});
// ──────────── FIRESTORE TRIGGERS ────────────
// ═══ NOTIFICAÇÕES DE CHAT & BOOKING (callables v1 — compatível com eur3) ═══
// Resolve o UID autenticado. A callable v1 recebe (data, context), mas
// mantém o token no payload como fallback para clientes Web antigos.
async function resolvedUid(data, context) {
    if (context.auth?.uid)
        return context.auth.uid;
    const token = data?.authToken;
    if (!token)
        throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
    try {
        const decoded = await auth.verifyIdToken(token);
        return decoded.uid;
    }
    catch (_) {
        throw new functions.https.HttpsError('unauthenticated', 'Token inválido. Tenta sair e entrar novamente.');
    }
}
exports.sendChatNotification = functions
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
    let recipientIds;
    if (parts.length >= 3 && parts[0] === 'chat') {
        const uid1 = parts[1];
        const uid2 = parts[2];
        recipientIds = [remetenteId === uid1 ? uid2 : uid1];
    }
    else {
        const groupDoc = await db.collection('grupos').doc(salaId).get();
        if (!groupDoc.exists)
            return { ok: true };
        const members = groupDoc.data()?.membros;
        if (!Array.isArray(members))
            return { ok: true };
        recipientIds = members.filter((id) => typeof id === 'string' && id !== remetenteId);
    }
    if (recipientIds.length === 0)
        return { ok: true };
    const recipientDocs = await Promise.all(recipientIds.map((id) => db.collection('users').doc(id).get()));
    const sends = recipientDocs
        .map((doc) => ({ id: doc.id, token: doc.data()?.fcmToken }))
        .filter((recipient) => Boolean(recipient.token))
        .map(({ token }) => messaging.send({
        token,
        notification,
        data: { type: 'chat', salaId },
    }));
    await Promise.all(sends);
    return { ok: true };
});
exports.notifyNewBooking = functions
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
    if (!fcmToken)
        return { ok: true };
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
exports.notifyBookingUpdate = functions
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
        if (!fcmToken)
            return { ok: true };
        const title = newStatus === 'confirmed' ? 'Aula Confirmada ✅' : 'Aula Cancelada ❌';
        const body = newStatus === 'confirmed'
            ? `${callerName} confirmou a tua aula de ${dateStr} às ${timeStr} (${tipoLabel})`
            : `${callerName} cancelou a tua aula de ${dateStr} às ${timeStr}`;
        await messaging.send({
            token: fcmToken,
            notification: { title, body },
            data: { type: 'booking_update', bookingId, newStatus },
        });
    }
    else if (newStatus === 'completed') {
        // Student completed → notify trainer
        const trainerDoc = await db.collection('users').doc(trainerId).get();
        const fcmToken = trainerDoc.data()?.fcmToken;
        if (!fcmToken)
            return { ok: true };
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
exports.notifyBookingCancelled = functions
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
    if (!fcmToken)
        return { ok: true };
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
exports.deactivateExpiredContracts = functions
    .region('europe-west1')
    .pubsub.schedule('every 15 minutes')
    .timeZone('Europe/Lisbon')
    .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const expiredUsers = await db
        .collection('users')
        .where('contractEndsAt', '<=', now)
        .get();
    const usersToDeactivate = expiredUsers.docs.filter((doc) => (0, contract_expiry_js_1.shouldDeactivateExpiredContract)(doc.data(), now.toDate()));
    // Re-read each profile in a transaction before changing it. This avoids
    // deactivating a client whose contract was renewed after the query ran.
    for (const user of usersToDeactivate) {
        await db.runTransaction(async (transaction) => {
            const latest = await transaction.get(user.ref);
            if (!latest.exists ||
                !(0, contract_expiry_js_1.shouldDeactivateExpiredContract)(latest.data() ?? {}, new Date())) {
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
exports.deactivateExpiredContractOnWrite = functions
    .region('europe-west1')
    .firestore.document('users/{uid}')
    .onWrite(async (change) => {
    if (!change.after.exists)
        return null;
    const data = change.after.data();
    if (!data || !(0, contract_expiry_js_1.shouldDeactivateExpiredContract)(data, new Date())) {
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
exports.notifyUserAccessChange = functions
    .region('europe-west1')
    .firestore.document('users/{uid}')
    .onUpdate(async (change, context) => {
    const before = change.before.data() ?? {};
    const after = change.after.data() ?? {};
    const uid = context.params.uid;
    if (after.role === 'admin')
        return null;
    const wasActive = before.isActive !== false;
    const isActive = after.isActive !== false;
    const beforeEnd = asDate(before.contractEndsAt)?.getTime() ?? null;
    const afterEnd = asDate(after.contractEndsAt)?.getTime() ?? null;
    if (wasActive === isActive && beforeEnd === afterEnd)
        return null;
    const title = !isActive ? 'Acesso desativado' : 'Acesso ativado ✅';
    const body = !isActive
        ? 'O teu acesso foi desativado. Contacta o administrador para obter ajuda.'
        : 'O teu acesso foi ativado. Já podes utilizar a aplicação.';
    await (0, notifications_js_1.createNotification)({ userId: uid, type: 'access_change', title, body, action: 'login' });
    await (0, notifications_js_1.sendUserPush)(uid, title, body, { type: 'access_change', link: `${publicAppUrl}/` });
    return null;
});
/** Persiste avisos quando uma marcação é aceite, recusada ou cancelada. */
exports.notifyBookingStatusChange = functions
    .region('europe-west1')
    .firestore.document('agenda/{bookingId}')
    .onUpdate(async (change, context) => {
    const before = change.before.data() ?? {};
    const after = change.after.data() ?? {};
    if (before.status === after.status)
        return null;
    const studentId = typeof after.studentId === 'string' ? after.studentId : '';
    if (!studentId)
        return null;
    const labels = {
        confirmed: 'A tua aula foi aceite ✅',
        cancelled: 'A tua aula foi recusada/cancelada ❌',
        completed: 'A tua aula foi marcada como concluída',
    };
    const title = labels[String(after.status)] || 'A tua marcação foi atualizada';
    await (0, notifications_js_1.createNotification)({
        userId: studentId,
        type: 'booking_update',
        title,
        body: 'Consulta a agenda para veres os detalhes da marcação.',
        action: 'agenda',
        metadata: { bookingId: context.params.bookingId },
    });
    // As callables de agenda já enviam o push; este trigger acrescenta apenas
    // o histórico persistente para evitar notificações duplicadas.
    return null;
});
// ──────────── SCHEDULED ────────────
exports.sendPaymentRecoveryReminders = functions.pubsub
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
        if (!isFailed && (!dueAt || dueAt > now))
            continue;
        const lastSent = asDate(data.recoveryLastSentAt)?.getTime() ?? 0;
        if (now - lastSent < 24 * 60 * 60 * 1000)
            continue;
        const userId = typeof data.userId === 'string' ? data.userId : '';
        if (userId) {
            await issuePaymentRecovery(doc.id, userId, isFailed ? 'failed' : 'overdue');
        }
    }
    return null;
});
exports.sendWaterReminder = functions.pubsub
    .schedule('every 2 hours from 08:00 to 22:00').timeZone('Europe/Lisbon')
    .onRun(async () => {
    const usersSnapshot = await db.collection('users').where('role', '==', 'aluno').get();
    const today = new Date().toISOString().split('T')[0];
    const promises = usersSnapshot.docs.map(async (u) => {
        const token = u.data().fcmToken;
        if (!token)
            return;
        const diary = await db.collection('users').doc(u.id).collection('diario').doc(today).get();
        const agua = diary.data()?.agua ?? 0;
        if (agua >= 2500)
            return;
        await messaging.send({ token, notification: { title: 'Hora de beber água! 💧', body: `Já bebeste ${agua}ml de 2500ml. Continua!` }, data: { type: 'water_reminder' } });
    });
    await Promise.all(promises);
    return null;
});
exports.sendWorkoutReminder = functions.pubsub
    .schedule('every day 07:00').timeZone('Europe/Lisbon')
    .onRun(async () => {
    const usersSnapshot = await db.collection('users').where('role', '==', 'aluno').get();
    const today = new Date().toISOString().split('T')[0];
    const promises = usersSnapshot.docs.map(async (u) => {
        const token = u.data().fcmToken;
        if (!token)
            return;
        const log = await db.collection('users').doc(u.id).collection('workoutLogs').doc(today).get();
        if (log.exists)
            return;
        const nome = u.data().nome ?? 'Aluno';
        await messaging.send({ token, notification: { title: 'Bom dia! 🏋️ Hora de treinar!', body: `Vê o teu plano de hoje, ${nome.split(' ')[0]}!` }, data: { type: 'workout_reminder', screen: 'workout' } });
    });
    await Promise.all(promises);
    return null;
});
exports.sendWeighInReminder = functions.pubsub
    .schedule('every monday 09:00').timeZone('Europe/Lisbon')
    .onRun(async () => {
    const usersSnapshot = await db.collection('users').where('role', '==', 'aluno').get();
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    const promises = usersSnapshot.docs.map(async (u) => {
        const token = u.data().fcmToken;
        if (!token)
            return;
        const recent = await db.collection('users').doc(u.id).collection('progresso')
            .where('data', '>=', admin.firestore.Timestamp.fromDate(sevenDaysAgo)).limit(1).get();
        if (!recent.empty)
            return;
        const nome = u.data().nome ?? 'Aluno';
        const peso = u.data().pesoAtual;
        const pesoMsg = peso ? `Último peso: ${peso}kg. ` : '';
        await messaging.send({ token, notification: { title: 'Hora de pesar! ⚖️', body: `${nome.split(' ')[0]}, ${pesoMsg}Regista o teu peso esta semana!` }, data: { type: 'weighin_reminder', screen: 'profile' } });
    });
    await Promise.all(promises);
    return null;
});
exports.sendWeeklyCheckin = functions.pubsub
    .schedule('every sunday 18:00').timeZone('Europe/Lisbon')
    .onRun(async () => {
    const usersSnapshot = await db.collection('users').where('role', '==', 'aluno').get();
    const today = new Date();
    const daysSinceMonday = today.getDay() === 0 ? 6 : today.getDay() - 1;
    const weekStart = new Date(today);
    weekStart.setDate(today.getDate() - daysSinceMonday);
    weekStart.setHours(0, 0, 0, 0);
    const promises = usersSnapshot.docs.map(async (u) => {
        const token = u.data().fcmToken;
        if (!token)
            return;
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
exports.dailyFirestoreBackup = functions.pubsub
    .schedule('every day 03:00').timeZone('Europe/Lisbon')
    .onRun(async () => {
    const bucket = admin.storage().bucket();
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backup = {};
    for (const col of ['users', 'chat', 'alimentos', 'exercicios']) {
        const snap = await db.collection(col).get();
        backup[col] = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    }
    await bucket.file(`backups/firestore-${timestamp}.json`).save(JSON.stringify(backup, null, 2), { contentType: 'application/json' });
    return null;
});
exports.cleanupInvalidFcmTokens = functions.pubsub
    .schedule('every day 04:00').timeZone('Europe/Lisbon')
    .onRun(async () => {
    const usersSnapshot = await db.collection('users').get();
    const batch = db.batch();
    let count = 0;
    for (const u of usersSnapshot.docs) {
        const token = u.data().fcmToken;
        if (!token)
            continue;
        try {
            await messaging.send({ token, data: { type: 'token_check' } }, true);
        }
        catch (e) {
            if (e.code === 'messaging/registration-token-not-registered') {
                batch.update(u.ref, { fcmToken: admin.firestore.FieldValue.delete() });
                count++;
            }
        }
    }
    if (count > 0)
        await batch.commit();
    return null;
});
// ──────────── STRIPE WEBHOOK ────────────
const stripeApp = require('express')();
stripeApp.use(require('express').raw({ type: 'application/json' }));
stripeApp.post('/', async (req, res) => {
    if (!stripe) {
        res.status(500).json({ error: 'Stripe não configurado.' });
        return;
    }
    const sig = req.headers['stripe-signature'];
    if (!sig) {
        res.status(400).json({ error: 'Missing signature.' });
        return;
    }
    let event;
    try {
        event = stripe.webhooks.constructEvent(req.body, sig, stripeWebhookSecret);
    }
    catch (e) {
        res.status(400).json({ error: `Webhook Error: ${e.message}` });
        return;
    }
    // Stripe pode reenviar o mesmo evento. Registar o ID antes do processamento
    // torna o webhook idempotente e evita faturas/avisos duplicados.
    const eventRef = db.collection('stripeEvents').doc(event.id);
    const eventAlreadyProcessed = await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(eventRef);
        if (existing.exists)
            return true;
        transaction.create(eventRef, {
            type: event.type,
            receivedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return false;
    });
    if (eventAlreadyProcessed) {
        res.status(200).json({ received: true, duplicate: true });
        return;
    }
    try {
        if (event.type === 'checkout.session.completed') {
            const session = event.data.object;
            const { paymentId, userId } = session.metadata || {};
            if (!paymentId) {
                res.status(400).json({ error: 'Missing paymentId' });
                return;
            }
            const paymentRef = db.collection('pagamentos').doc(paymentId);
            const currentPayment = await paymentRef.get();
            if (!currentPayment.exists || currentPayment.data()?.status === 'cancelled') {
                console.warn('Ignoring Stripe checkout for cancelled/missing payment', {
                    paymentId,
                    sessionId: session.id,
                });
                res.status(200).json({ received: true });
                return;
            }
            if (session.mode === 'subscription') {
                const subscriptionId = typeof session.subscription === 'string'
                    ? session.subscription
                    : session.subscription?.id;
                await paymentRef.update({
                    // A subscrição é marcada como paga apenas pelo evento invoice.paid;
                    // assim o checkout e o webhook não criam dois registos para a primeira fatura.
                    ...(currentPayment.data()?.status === 'paid'
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
            }
            else {
                await paymentRef.update({
                    status: 'paid',
                    stripePaymentIntentId: typeof session.payment_intent === 'string'
                        ? session.payment_intent
                        : session.payment_intent?.id,
                    paidAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                if (userId) {
                    await generateInvoicePdf(paymentId, userId);
                    await (0, notifications_js_1.createNotification)({
                        userId,
                        type: 'payment_paid',
                        title: 'Pagamento confirmado ✅',
                        body: 'A tua mensalidade foi paga com sucesso.',
                        action: 'payment',
                        paymentId,
                    });
                    await (0, notifications_js_1.sendUserPush)(userId, 'Pagamento confirmado ✅', 'A tua mensalidade foi paga com sucesso.', { type: 'payment_paid', paymentId, link: `${publicAppUrl}/` });
                }
            }
        }
        if (event.type === 'customer.subscription.deleted') {
            await handleSubscriptionDeleted(event.data.object);
        }
        if (event.type === 'invoice.paid') {
            await handleInvoicePaid(event.data.object);
        }
        if (event.type === 'invoice.payment_failed') {
            await handleInvoicePaymentFailed(event.data.object);
        }
    }
    catch (error) {
        // Permitir que o Stripe reenvie um evento se o processamento falhar a
        // meio, em vez de deixar um marcador "processado" permanentemente.
        await eventRef.delete().catch(() => undefined);
        console.error('Stripe webhook processing failed', error);
        res.status(500).json({ error: 'Webhook processing failed.' });
        return;
    }
    res.status(200).json({ received: true });
});
exports.stripeWebhook = functions.region('europe-west1').https.onRequest(stripeApp);
async function handleSubscriptionDeleted(subscription) {
    const metadata = subscription.metadata ?? {};
    const paymentId = typeof metadata.paymentId === 'string' ? metadata.paymentId : '';
    const userId = typeof metadata.userId === 'string' ? metadata.userId : '';
    if (!paymentId || !userId)
        return;
    const paymentRef = db.collection('pagamentos').doc(paymentId);
    const payment = await paymentRef.get();
    if (!payment.exists || payment.data()?.status === 'cancelled')
        return;
    await paymentRef.update({
        subscriptionEndedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await (0, notifications_js_1.createNotification)({
        userId,
        type: 'subscription_ended',
        title: 'Renovação automática terminada',
        body: 'A subscrição terminou. Se precisares, podes regularizar pelo próximo pagamento disponível.',
        action: 'payment',
        paymentId,
    });
}
async function handleInvoicePaid(invoice) {
    const context = await getInvoiceSubscriptionContext(invoice);
    if (!context)
        return;
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
        if (current.data()?.status === 'cancelled')
            return;
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
    }
    else {
        paymentRef = await db.collection('pagamentos').add({
            userId,
            valor: amount ?? 0,
            moeda: 'eur',
            descricao: `Mensalidade ${billing_js_1.billingTypeLabels[tipoMensalidade]}`,
            data: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            ...data,
        });
    }
    await generateInvoicePdf(paymentRef.id, userId);
    await (0, notifications_js_1.createNotification)({
        userId,
        type: 'payment_paid',
        title: 'Pagamento confirmado ✅',
        body: 'A tua mensalidade foi paga e o acesso foi atualizado.',
        action: 'payment',
        paymentId: paymentRef.id,
    });
    await (0, notifications_js_1.sendUserPush)(userId, 'Pagamento confirmado ✅', 'A tua mensalidade foi paga e o acesso foi atualizado.', { type: 'payment_paid', paymentId: paymentRef.id, link: `${publicAppUrl}/` });
}
async function handleInvoicePaymentFailed(invoice) {
    const context = await getInvoiceSubscriptionContext(invoice);
    if (!context)
        return;
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
        if (current.data()?.status === 'cancelled')
            return;
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
    }
    else {
        paymentRef = await db.collection('pagamentos').add({
            userId,
            valor: amount ?? 0,
            moeda: 'eur',
            descricao: `Mensalidade ${billing_js_1.billingTypeLabels[tipoMensalidade]}`,
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
        }
        catch (error) {
            console.error('Could not cancel unpaid initial subscription', error);
        }
    }
    // O primeiro pagamento recusado também precisa de recuperação pública;
    // o utilizador pode estar impedido de iniciar sessão.
    await issuePaymentRecovery(paymentRef.id, userId, 'failed');
}
async function getInvoiceSubscriptionContext(invoice) {
    if (!stripe)
        return null;
    const subscriptionId = typeof invoice.subscription === 'string'
        ? invoice.subscription
        : invoice.subscription?.id;
    if (!subscriptionId)
        return null;
    const subscription = await stripe.subscriptions.retrieve(subscriptionId);
    const metadata = subscription.metadata ?? {};
    if (typeof metadata.paymentId !== 'string' ||
        typeof metadata.userId !== 'string' ||
        !(0, billing_js_1.isBillingType)(metadata.tipoMensalidade)) {
        return null;
    }
    return {
        subscription,
        paymentId: metadata.paymentId,
        userId: metadata.userId,
        tipoMensalidade: metadata.tipoMensalidade,
    };
}
async function findPaymentByInvoiceId(invoiceId) {
    const snapshot = await db.collection('pagamentos')
        .where('stripeInvoiceId', '==', invoiceId)
        .limit(1)
        .get();
    return snapshot.empty ? null : snapshot.docs[0].ref;
}
function stripeTimestampDate(value) {
    if (typeof value === 'number')
        return new Date(value * 1000);
    return asDate(value);
}
/**
 * Renova/reactiva o acesso quando um pagamento pago contém um período válido.
 * Funciona tanto para pagamentos manuais como para o webhook Stripe, mantendo
 * o perfil do aluno como fonte de verdade para as regras e novas sessões.
 */
exports.syncAccessFromPaidPayment = functions
    .region('europe-west1')
    .firestore.document('pagamentos/{paymentId}')
    .onWrite(async (change) => {
    if (!change.after.exists)
        return null;
    const payment = change.after.data();
    if (payment?.status !== 'paid' || !payment?.userId || !payment?.periodoFim) {
        return null;
    }
    const periodEnd = asDate(payment.periodoFim);
    if (!periodEnd || periodEnd <= new Date())
        return null;
    const userRef = db.collection('users').doc(String(payment.userId));
    await db.runTransaction(async (transaction) => {
        const userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists)
            return;
        const user = userSnapshot.data() ?? {};
        const currentEnd = asDate(user.contractEndsAt);
        if (currentEnd && currentEnd >= periodEnd && user.isActive !== false) {
            return;
        }
        transaction.update(userRef, {
            contractEndsAt: admin.firestore.Timestamp.fromDate(currentEnd && currentEnd > periodEnd ? currentEnd : periodEnd),
            isActive: true,
            deactivatedAt: admin.firestore.FieldValue.delete(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    });
    return null;
});
// ──────────── HELPERS ────────────
function asDate(value) {
    if (value instanceof Date)
        return value;
    if (value instanceof admin.firestore.Timestamp)
        return value.toDate();
    if (typeof value === 'string' || typeof value === 'number') {
        const parsed = new Date(value);
        return Number.isNaN(parsed.getTime()) ? null : parsed;
    }
    return null;
}
function stripeCheckoutHttpsError(error, operation) {
    const stripeError = error;
    console.error(`Stripe checkout (${operation}) failed`, {
        type: stripeError?.type,
        code: stripeError?.code,
        message: stripeError?.message,
        requestId: stripeError?.requestId,
    });
    if (stripeError?.type === 'StripeAuthenticationError') {
        return new functions.https.HttpsError('failed-precondition', 'A chave secreta do Stripe é inválida, foi revogada ou não está configurada nas Functions.');
    }
    if (stripeError?.type === 'StripeInvalidRequestError') {
        return new functions.https.HttpsError('invalid-argument', `O Stripe rejeitou os dados do checkout: ${stripeError.message || 'pedido inválido.'}`);
    }
    return new functions.https.HttpsError('internal', 'Não foi possível iniciar o checkout do Stripe. Consulta os logs da Function para mais detalhes.');
}
async function generateInvoicePdf(paymentId, userId) {
    const [paymentDoc, userDoc] = await Promise.all([db.collection('pagamentos').doc(paymentId).get(), db.collection('users').doc(userId).get()]);
    const payment = paymentDoc.data(), user = userDoc.data();
    if (!payment || !user)
        return;
    const valor = payment.valor || 0, descricao = payment.descricao || 'Mensalidade';
    const date = payment.paidAt ? payment.paidAt.toDate() : new Date();
    const nome = user.nome || 'Aluno', email = user.email || '';
    const chunks = [];
    const doc = new pdfkit_1.default({ size: 'A4', margin: 50 });
    doc.on('data', (c) => chunks.push(c));
    const pdfPromise = new Promise(r => doc.on('end', () => r(Buffer.concat(chunks))));
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
//# sourceMappingURL=index.js.map