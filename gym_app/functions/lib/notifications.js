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
exports.createNotification = createNotification;
exports.sendUserPush = sendUserPush;
exports.sendUserEmail = sendUserEmail;
exports.escapeHtml = escapeHtml;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
function db() {
    return admin.firestore();
}
function messaging() {
    return admin.messaging();
}
async function createNotification(input) {
    const ref = await db().collection('notificacoes').add({
        userId: input.userId,
        type: input.type,
        title: input.title,
        body: input.body,
        read: false,
        ...(input.action ? { action: input.action } : {}),
        ...(input.paymentId ? { paymentId: input.paymentId } : {}),
        ...(input.metadata ? { metadata: input.metadata } : {}),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return ref.id;
}
async function sendUserPush(userId, title, body, data = {}) {
    const user = await db().collection('users').doc(userId).get();
    const token = user.data()?.fcmToken;
    if (typeof token !== 'string' || token.length === 0)
        return;
    try {
        await messaging().send({
            token,
            notification: { title, body },
            data,
            webpush: {
                fcmOptions: {
                    link: data.link || 'https://gymbt-4ef87.web.app/',
                },
            },
        });
    }
    catch (error) {
        if (error?.code === 'messaging/registration-token-not-registered' ||
            error?.code === 'messaging/invalid-registration-token') {
            await db().collection('users').doc(userId).update({
                fcmToken: admin.firestore.FieldValue.delete(),
            }).catch(() => undefined);
            return;
        }
        console.error('Could not send user push notification', { userId, error });
    }
}
function legacyResendConfig() {
    // functions.config() throws while a 2nd gen container is starting.
    if (process.env.K_CONFIGURATION)
        return {};
    return functions.config().resend ?? {};
}
function resendApiKey() {
    return process.env.RESEND_API_KEY || legacyResendConfig().api_key || '';
}
function resendFrom() {
    return process.env.RESEND_FROM_EMAIL ||
        legacyResendConfig().from_email ||
        'GymBT <onboarding@resend.dev>';
}
async function sendUserEmail(to, subject, html) {
    const apiKey = resendApiKey();
    if (!apiKey || !to) {
        console.warn('Resend email skipped: RESEND_API_KEY or recipient is missing.');
        return false;
    }
    try {
        const response = await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: {
                Authorization: `Bearer ${apiKey}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ from: resendFrom(), to: [to], subject, html }),
            signal: AbortSignal.timeout(10000),
        });
        if (!response.ok) {
            console.error('Resend returned an error', response.status, await response.text());
            return false;
        }
        return true;
    }
    catch (error) {
        console.error('Resend request failed', error);
        return false;
    }
}
function escapeHtml(value) {
    return value
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}
//# sourceMappingURL=notifications.js.map