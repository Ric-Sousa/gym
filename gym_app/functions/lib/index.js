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
exports.syncAccessFromPaidPayment = exports.stripeWebhook = exports.cleanupInvalidFcmTokens = exports.dailyFirestoreBackup = exports.sendWeeklyCheckin = exports.sendWeighInReminder = exports.sendWorkoutReminder = exports.sendWaterReminder = exports.deactivateExpiredContractOnWrite = exports.deactivateExpiredContracts = exports.notifyBookingCancelled = exports.notifyBookingUpdate = exports.notifyNewBooking = exports.sendChatNotification = exports.createCheckoutSession = exports.requestProgress = exports.searchOpenFoodFacts = exports.seedFoods = exports.deleteStudentHttp = exports.createStudentHttp = exports.onUserCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const stripe_1 = __importDefault(require("stripe"));
const pdfkit_1 = __importDefault(require("pdfkit"));
const contract_expiry_js_1 = require("./contract_expiry.js");
admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();
const messaging = admin.messaging();
// ═══ Stripe ═══
const stripeConfig = functions.config().stripe;
const stripeSecret = stripeConfig?.secret_key;
const stripeWebhookSecret = stripeConfig?.webhook_secret || '';
if (!stripeSecret) {
    console.warn('⚠️  Stripe secret_key não definida.');
}
const stripe = stripeSecret
    ? new stripe_1.default(stripeSecret, { apiVersion: '2025-06-30.acacia' })
    : null;
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
exports.createCheckoutSession = functions.region('europe-west1').https.onCall(async (data, context) => {
    if (!stripe)
        throw new functions.https.HttpsError('failed-precondition', 'Stripe não configurado.');
    if (!context.auth)
        throw new functions.https.HttpsError('unauthenticated', 'Login necessário.');
    const callerDoc = await db.collection('users').doc(context.auth.uid).get();
    if (callerDoc.data()?.role !== 'admin')
        throw new functions.https.HttpsError('permission-denied', 'Apenas admin.');
    const { userId, valor, descricao, periodoInicio, periodoFim, dataVencimento } = data;
    if (!userId || !valor || valor <= 0)
        throw new functions.https.HttpsError('invalid-argument', 'userId e valor obrigatórios.');
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
        userId, valor, moeda: 'eur', status: 'pending',
        descricao: descricao || 'Mensalidade',
        data: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(parsedStart ? { periodoInicio: admin.firestore.Timestamp.fromDate(parsedStart) } : {}),
        ...(parsedEnd ? { periodoFim: admin.firestore.Timestamp.fromDate(parsedEnd) } : {}),
        ...(parsedDue ? { dataVencimento: admin.firestore.Timestamp.fromDate(parsedDue) } : {}),
    });
    const session = await stripe.checkout.sessions.create({
        payment_method_types: ['card'], mode: 'payment',
        line_items: [{ price_data: { currency: 'eur', product_data: { name: descricao || 'Mensalidade GymBT' }, unit_amount: Math.round(valor * 100) }, quantity: 1 }],
        metadata: { paymentId: paymentRef.id, userId },
        success_url: 'https://gymbt-4ef87.web.app/perfil?pagamento=sucesso',
        cancel_url: 'https://gymbt-4ef87.web.app/perfil?pagamento=cancelado',
    });
    await paymentRef.update({ stripeSessionId: session.id });
    return { url: session.url, paymentId: paymentRef.id };
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
// ──────────── SCHEDULED ────────────
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
    if (event.type === 'checkout.session.completed') {
        const session = event.data.object;
        const { paymentId, userId } = session.metadata || {};
        if (!paymentId) {
            res.status(400).json({ error: 'Missing paymentId' });
            return;
        }
        await db.collection('pagamentos').doc(paymentId).update({
            status: 'paid',
            stripePaymentIntentId: typeof session.payment_intent === 'string' ? session.payment_intent : session.payment_intent?.id,
            paidAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        if (userId)
            await generateInvoicePdf(paymentId, userId);
    }
    res.status(200).json({ received: true });
});
exports.stripeWebhook = functions.region('europe-west1').https.onRequest(stripeApp);
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