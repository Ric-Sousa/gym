# Como correr e validar

## Flutter

```powershell
cd gym_app
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```

## Cloud Functions

```powershell
cd gym_app\functions
npm run build
npm test -- --runInBand
```

## Regras Firestore e Storage

```powershell
cd gym_app
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
npm run test:emulator --prefix rules-tests
```

## Executar a aplicação no Chrome

```powershell
cd gym_app
flutter run -d chrome
```

## Deploy da aplicação web

```powershell
cd gym_app
flutter build web --release
firebase deploy --only hosting
```

## Deploy seguro de Cloud Functions

Publicar apenas as funções alteradas. Isto evita apagar funções legadas que
ainda possam existir em produção:

```powershell
cd gym_app
firebase deploy --only "functions:NOME_DA_FUNCAO"
```

Para várias funções:

```powershell
firebase deploy --only "functions:FUNCAO_1,functions:FUNCAO_2"
```

## Deploy de regras e índices

```powershell
cd gym_app
firebase deploy --only "firestore:rules,firestore:indexes,storage"
```

## Stripe

https://dashboard.stripe.com/apikeys
