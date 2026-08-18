import * as admin from 'firebase-admin';

export type NotificationInput = {
  userId: string;
  type: string;
  title: string;
  body: string;
  action?: string;
  paymentId?: string;
  metadata?: Record<string, string>;
};

function db() {
  return admin.firestore();
}

function messaging() {
  return admin.messaging();
}

export async function createNotification(input: NotificationInput): Promise<string> {
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

export async function sendUserPush(
  userId: string,
  title: string,
  body: string,
  data: Record<string, string> = {},
): Promise<void> {
  const user = await db().collection('users').doc(userId).get();
  const token = user.data()?.fcmToken;
  if (typeof token !== 'string' || token.length === 0) return;

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
  } catch (error: any) {
    if (
      error?.code === 'messaging/registration-token-not-registered' ||
      error?.code === 'messaging/invalid-registration-token'
    ) {
      await db().collection('users').doc(userId).update({
        fcmToken: admin.firestore.FieldValue.delete(),
      }).catch(() => undefined);
      return;
    }
    console.error('Could not send user push notification', { userId, error });
  }
}

function legacyResendConfig(): Record<string, any> {
  const raw = process.env.CLOUD_RUNTIME_CONFIG;
  if (!raw) return {};
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed.resend === 'object' ? parsed.resend : {};
  } catch (_) {
    return {};
  }
}

function resendApiKey(): string {
  return process.env.RESEND_API_KEY || legacyResendConfig().api_key || '';
}

function resendFrom(): string {
  return process.env.RESEND_FROM_EMAIL ||
    legacyResendConfig().from_email ||
    'GymBT <onboarding@resend.dev>';
}

export async function sendUserEmail(
  to: string,
  subject: string,
  html: string,
): Promise<boolean> {
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
  } catch (error) {
    console.error('Resend request failed', error);
    return false;
  }
}

export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
