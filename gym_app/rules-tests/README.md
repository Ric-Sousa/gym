# Testes das Firebase Rules

Esta pasta contém testes de isolamento das Firestore Rules e Storage Rules.

## Pré-requisitos

- Node.js 20+
- Java 11+ disponível no `PATH` (necessário pelo Firestore/Storage Emulator)
- Firebase CLI

## Instalação

```bash
cd gym_app/rules-tests
npm install
```

## Execução

A partir de `gym_app/rules-tests`:

```bash
npm run test:emulator
```

Ou, a partir de `gym_app`:

```bash
npx firebase-tools emulators:exec --project gymbt-rules-test --config firebase.rules-test.json --only firestore,storage "npm test --prefix rules-tests -- --runInBand"
```

O comando termina com erro explícito se Java não estiver no `PATH`; não usa
emuladores remotos nem dados de produção.

No Windows, se o Java instalado não for detetado, definir primeiro o JDK 21
na sessão PowerShell:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
```

O ficheiro `firebase.rules-test.json` usa as portas 8180 e 9299 para evitar o
conflito frequente da porta 8080 no Windows.

A suite cobre, entre outros casos:

- isolamento de salas diretas entre alunos;
- autoria das mensagens e prevenção de impersonação;
- composição imutável de grupos para alunos;
- cursores de leitura por membro;
- conclusão atómica e schema mínimo do questionário;
- acesso aos anexos apenas por participantes;
- limites de tamanho e MIME type;
- paths arbitrários em `users/`;
- vídeos de progresso e comprovativos de pagamento.

Os testes usam `withSecurityRulesDisabled` apenas para preparar dados fixos no
emulador. As operações verificadas usam sempre contextos autenticados normais.
