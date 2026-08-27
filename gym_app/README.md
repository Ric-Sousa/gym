# GymBT

Aplicação Flutter para gestão de treino, nutrição, agenda, chat e pagamentos.

O alvo oficial é **Web + Android + iOS**. Os projetos nativos estão em
`android/` e `ios/`; os identificadores são `com.gymbt.app`. Para validar
builds locais é necessário instalar Android SDK/Gradle no Android e Xcode +
CocoaPods no macOS para iOS. As credenciais de assinatura, APNs e ficheiros de
configuração de distribuição não devem ser commitados.

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

## Build mobile

```bash
flutter pub get
flutter build apk --debug       # requer Android SDK
flutter build ios --no-codesign # requer macOS/Xcode
```

As permissões nativas versionadas cobrem câmara, microfone, biblioteca de
fotografias, movimento/pedómetro e notificações. A autorização em runtime
continua a ser pedida pelos plugins e pelo Firebase Messaging.

## Testes das Firebase Rules

Os testes de segurança das regras Firestore/Storage estão em `rules-tests` e
usam o Firebase Emulator Suite. Requerem Node.js, Firebase CLI e Java 11+ no
`PATH`:

```bash
cd rules-tests
npm install
npm run test:emulator

# Alternativa equivalente a partir da raiz:
# npx firebase-tools emulators:exec --project gymbt-rules-test --config firebase.rules-test.json --only firestore,storage "npm test --prefix rules-tests -- --runInBand"
```

A suite valida isolamento de salas de chat, autoria de mensagens, composição
de grupos, conclusão do questionário, o agregado administrativo read-only e
limites/privacidade dos uploads.


## Deploy

```bash
cd gym_app/functions
npm run build
cd ..
firebase deploy --only "functions:NOME_DA_FUNCAO"
firebase deploy --only "firestore:rules,firestore:indexes,storage"
flutter build web --release
firebase deploy --only hosting
```

As funções devem ser publicadas explicitamente pelo nome. Evitar um deploy
global de `functions`, porque podem existir funções legadas em produção que
já não pertencem ao bundle local e seriam propostas para remoção.

Antes do primeiro deploy desta versão, executar também um backfill administrativo dos diários existentes para `adminAggregates/dashboard`; o trigger `aggregateDiaryStats` mantém automaticamente apenas alterações posteriores.

## Migração de URLs legadas do Storage

`backfillStoragePaths` é uma callable administrativa em `europe-west1`. A
primeira execução é deliberadamente um dry-run: basta chamar a função sem
`apply` (ou com `apply: false`) para medir `scanned`, `migrated` e `paths`.
Depois de rever o resultado, aplicar em lotes pequenos:

```dart
await FirebaseFunctions.instanceFor(region: 'europe-west1')
    .httpsCallable('backfillStoragePaths')
    .call({'apply': true, 'limit': 100});
```

A revogação dos tokens antigos é separada e só deve ser pedida depois de
confirmar que os paths resolvem corretamente:

```dart
.call({'apply': true, 'revokeTokens': true, 'limit': 100});
```

A callable não é executada automaticamente por triggers. Fazer backup/export
antes de aplicar e repetir lotes; os documentos já convertidos são ignorados.
Os utilizadores têm de atualizar a aplicação antes da revogação para não
perderem acesso a documentos legados ainda não migrados.

Antes do deploy, configurar no Stripe o webhook para:

```text
https://europe-west1-gymbt-4ef87.cloudfunctions.net/stripeWebhook
```

Depois de publicar o Web, fazer `Ctrl + Shift + R` ou limpar os dados do site.
