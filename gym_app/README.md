# GymBT

Aplicação Flutter para gestão de treino, nutrição, agenda, chat e pagamentos.

## Pagamentos e recuperação

O Stripe é a fonte de verdade dos pagamentos. O admin cria a cobrança com aluno,
valor e periodicidade (`mensal`, `trimestral` ou `anual`); o servidor calcula os
períodos. O cliente paga no Checkout Stripe e as Functions tratam os webhooks:

- `checkout.session.completed`
- `invoice.paid`
- `invoice.payment_failed`
- `customer.subscription.deleted`

Quando uma cobrança falha, é criado um aviso persistente, enviado push (quando
o dispositivo/browser tem token) e enviado um link de recuperação por e-mail.
O portal de recuperação não exige login, porque o acesso do cliente pode estar
bloqueado por atraso.

## Segredos

Nunca colocar chaves secretas no Flutter, no Git ou nesta conversa. A chave
`pk_...` do Stripe é pública; `sk_...`, `whsec_...`, `re_...` e a VAPID privada
não são.

Na pasta `gym_app`, depois de revogar qualquer chave exposta, configurar:

```bash
firebase use gymbt-4ef87
firebase functions:config:set \
  stripe.secret_key="sk_test_NOVA_CHAVE" \
  stripe.webhook_secret="whsec_NOVO_SEGREDO" \
  resend.api_key="re_NOVA_CHAVE" \
  resend.from_email="GymBT <pagamentos@teu-dominio-verificado.pt>"
```

O domínio/remetente do Resend tem de estar verificado no painel do fornecedor.
A chave anterior enviada na conversa não deve ser reutilizada.

## Push Web

Obter a chave VAPID pública em Firebase Console → Project Settings → Cloud
Messaging → Web configuration. Ela não é um segredo. Compilar com:

```bash
flutter build web --dart-define=FCM_WEB_VAPID_KEY="TUA_CHAVE_VAPID_PUBLICA"
```

O service worker `web/firebase-messaging-sw.js` recebe notificações quando o
browser está em background. O utilizador ainda precisa de aceitar a permissão
de notificações no browser.

## Deploy

```bash
cd gym_app/functions
npm run build
cd ..
firebase deploy --only functions,firestore:rules,hosting
```

Antes do deploy, configurar no Stripe o webhook para:

```text
https://europe-west1-gymbt-4ef87.cloudfunctions.net/stripeWebhook
```

Depois de publicar o Web, fazer `Ctrl + Shift + R` ou limpar os dados do site.
