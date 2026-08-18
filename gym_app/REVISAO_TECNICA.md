# Revisão Técnica — GymBT

## Resultado da revisão técnica

Foi revista a estrutura completa do projeto Flutter, camadas de dados, providers, repositórios, modelos, ecrãs, widgets, regras Firebase, Cloud Functions, configuração Web, dependências e testes.

### Estado das correções

- `[x]` Resolvido e verificado por código/testes disponíveis.
- `[ ]` Pendente ou apenas parcialmente resolvido; mantém-se como risco.

A revisão é mantida como checklist: um item só recebe `[x]` quando a correção está implementada no source. A execução do Emulator continua dependente de Java.

### Validação executada

- `flutter test`: **239 testes passaram**.
- `npm run lint` em `functions`: **passou** (sem erros).
- `npm run build` em `functions`: **passou**; `functions/lib` deixou de ser versionado e é gerado apenas no build.
- `npm test` em `functions`: **11 testes passaram**.
- `npm run test:emulator` foi preparado, mas bloqueou neste ambiente porque `java -version` não está disponível.
- `flutter analyze --no-fatal-infos`: **191 issues**, todos infos; não há erros nem warnings. Os 23 métodos legados não referenciados foram removidos; permanece dívida histórica de estilo/lifecycle.

Os testes locais não substituem a execução das Rules no Emulator nem testes de integração contra Stripe/Firebase reais.

---

# 1. Problemas críticos de segurança

## [x] P0 — Qualquer aluno ativo pode ler e escrever qualquer sala de chat

**Estado:** ✅ Resolvido nas Rules; exige migração das salas legadas.

**Ficheiro:** `firestore.rules`, secção `match /chat/{salaId}` e subcoleção `mensagens`.

As regras atuais são equivalentes a:

```text
allow read, create, update:
  if isAdmin() || isActiveOwner(request.auth.uid)
```

Não existe validação de que:

- `salaId` contém o UID do utilizador;
- o aluno é membro da sala;
- a sala corresponde ao seu `personalId`;
- o remetente da mensagem é `request.auth.uid`;
- o destinatário é válido.

### Impacto

- Um aluno autenticado pode tentar ler qualquer documento em `/chat`.
- Pode ler mensagens privadas entre outros alunos e o personal trainer.
- Pode criar mensagens numa sala alheia.
- Pode impersonar outro utilizador alterando `remetenteId`.
- Pode alterar o documento-pai da sala.
- Pode marcar mensagens de terceiros como lidas.
- Pode substituir `lastMessage`, `lastSenderId`, `typing`, etc.

O cliente envia mensagens através de `FirestoreDataSource.sendMessage`, aproximadamente em `lib/data/datasources/firestore_datasource.dart:707`, mas a segurança não pode depender dos valores enviados pelo Flutter.

### Correção sugerida

- Guardar `participantIds: [studentId, trainerId]` no documento da sala.
- Exigir `request.auth.uid in resource.data.participantIds`.
- Em mensagens, exigir `request.resource.data.remetenteId == request.auth.uid`.
- Impedir que alunos alterem campos do documento-pai.
- Permitir alterações ao estado `lida` apenas ao destinatário.
- Validar o `salaId` e os participantes no servidor ou através de regras.
- Idealmente, escrever mensagens através de uma callable ou de regras muito restritivas.

---

## [x] P0 — Qualquer utilizador autenticado pode escrever em qualquer upload de áudio/anexo

**Estado:** ✅ Resolvido nas Storage Rules e coberto por testes de isolamento.

**Ficheiro:** `storage.rules`.

As regras atuais incluem:

```text
match /chat_audio/{allPaths=**} {
  allow read, write: if request.auth != null;
}

match /chat_attachments/{allPaths=**} {
  allow read, write: if request.auth != null;
}
```

Isto permite a qualquer utilizador autenticado:

- ler anexos privados de qualquer conversa;
- substituir ou apagar ficheiros;
- carregar ficheiros arbitrários;
- escrever em paths de outros utilizadores/grupos;
- consumir Storage sem limite de tamanho ou tipo.

### Correção sugerida

Usar paths com participantes ou UID do autor e validar:

- pertença à sala/grupo;
- `request.resource.size`;
- `request.resource.contentType`;
- operações de criação vs atualização vs remoção;
- nomes/extensões permitidos;
- limite por utilizador/conversa.

---

## [x] P0 — A regra geral de Storage invalida a restrição específica de vídeos

**Estado:** ✅ Resolvido: removido o catch-all recursivo de `users`.

**Ficheiro:** `storage.rules`.

Existe uma regra específica para:

```text
/users/{uid}/progress_videos/{videoId}
```

com limite de 200 MB e MIME type de vídeo.

Mas também existe:

```text
/users/{uid}/{allPaths=**}
```

com:

```text
allow write: if request.auth.uid == uid || admin
```

Em Firebase Storage, regras sobrepostas são avaliadas de forma permissiva: basta uma permitir. Portanto, o path de vídeos também é abrangido pela regra geral e pode contornar:

- limite de 200 MB;
- validação de MIME type;
- restrição ao formato vídeo.

### Correção sugerida

Remover a regra recursiva genérica ou separar explicitamente os paths. Cada tipo de ficheiro deve ter uma regra própria e não existir uma regra posterior que a torne inútil.

---

## [x] P0 — URLs de download do Storage tornam ficheiros privados em URLs bearer

**Estado:** ✅ Resolvido para novos uploads: o Firestore passa a persistir apenas paths privados e a resolução autenticada produz URLs transitórios apenas em runtime. URLs HTTP/HTTPS/GS existentes continuam suportadas como fallback de leitura até ao backfill e à revogação dos tokens antigos.

**Ficheiros:** `lib/data/datasources/storage_datasource.dart`, `lib/core/utils/storage_resource.dart` e widgets de imagem/áudio/vídeo.

A implementação atual:

- devolve `ref.fullPath` em vez de `getDownloadURL()` nos uploads;
- grava paths em fotos de progresso/perfil, grupos, chat, áudio, vídeos e comprovativos;
- resolve paths com o SDK Firebase Storage apenas quando o recurso é consumido;
- mantém compatibilidade de leitura para URLs HTTP/HTTPS/GS legadas;
- evita `NetworkImage`/`Image.network` diretos para recursos Storage.

Os documentos antigos podem ainda conter URLs com token de download. Quem obtiver uma dessas URLs pode descarregar o ficheiro sem autenticação Firebase, independentemente das Storage Rules; por isso o backfill e a revogação dos tokens antigos continuam uma tarefa operacional antes do go-live.

### Impacto

- Fotos de progresso são informação de saúde/corporal.
- URLs podem ser copiadas de logs, notificações, documentos ou browsers.
- Revogar regras Storage não invalida automaticamente os tokens já emitidos.

### Trabalho operacional restante

- executar backfill dos campos legados (`fotoPerfil`, `fotos`, `fotosPorPosicao`, `imagemUrl`, `audioUrl`, `attachmentUrl`, `videoUrl` e comprovativos);
- revogar tokens antigos ou reescrever os objetos para invalidar URLs bearer já emitidas;
- confirmar no Emulator/ambiente Firebase que as Rules continuam a proteger os paths privados.

---

## [x] P0 — Qualquer aluno pode contornar a conclusão do questionário

**Estado:** ✅ Resolvido com validação da resposta e conclusão atómica nas Rules.

**Ficheiro:** `firestore.rules`, regra `users/{uid}`.

A segunda cláusula de `allow update` permite ao próprio aluno alterar:

```text
questionnaireCompletedAt
questionnaireVersion
genero
```

desde que a versão e o género tenham os valores esperados.

Não exige:

- existência de `/users/{uid}/questionario/resposta`;
- que as respostas estejam completas;
- que `answers` contenha as perguntas obrigatórias;
- que `completedAt` corresponda a uma data controlada pelo servidor;
- que o conteúdo da resposta corresponda ao estado do perfil.

Um cliente modificado pode marcar o questionário como concluído sem o preencher.

Além disso, `questionario/resposta` só valida que `answers` é um mapa. Não valida IDs, tipos, perguntas obrigatórias ou valores admissíveis.

### Correção sugerida

Mover a conclusão para uma callable/backend:

1. Validar respostas no servidor.
2. Validar a versão ativa.
3. Validar campos obrigatórios.
4. Escrever resposta e marcador numa transação.
5. Impedir que o aluno escreva diretamente `questionnaireVersion` e `questionnaireCompletedAt`.

---

## [x] P0 — A submissão normal do questionário é incompatível com as regras

**Estado:** ✅ Resolvido: o batch do cliente e a política das Rules estão alinhados, incluindo `dataNascimento` e versão ativa.

**Ficheiros:**

- `lib/features/auth/screens/questionnaire_screen.dart:286`;
- `lib/data/datasources/firestore_datasource.dart:112-145`;
- `firestore.rules`, regra `users/{uid}`.

O cliente faz um batch que escreve no perfil:

- `questionnaireCompletedAt`;
- `questionnaireVersion`;
- `nome`;
- `genero`;
- `pesoAtual`;
- `altura`;
- `dataNascimento`.

Contudo:

- a regra de perfil/privacidade permite um conjunto de campos que não inclui os campos de conclusão;
- a regra de questionário permite apenas `questionnaireCompletedAt`, `questionnaireVersion` e `genero`;
- `dataNascimento` não aparece na lista autorizada;
- não existe uma cláusula que permita o conjunto combinado enviado pelo batch.

Na prática, quando o utilizador preenche dados novos, a operação tende a falhar com `permission-denied`.

Existe ainda outro acoplamento perigoso: `QuestionnaireConfig.versionId` é editável pelo admin, mas a regra exige literalmente:

```text
questionnaire-2026-08-health-v2
```

Se o admin publicar outra versão, o formulário usa a nova versão e as regras rejeitam-na.

### Correção sugerida

- Definir uma única política de versões.
- Validar a versão no backend, não com string duplicada nas regras.
- Separar a escrita da resposta da atualização de perfil, ou permitir explicitamente a operação atómica correta.
- Adicionar `dataNascimento` às regras apenas se essa escrita continuar a ser feita diretamente.
- Criar testes de regras para este batch.

---

## [x] P0 — Recuperação de pagamento pode não reativar o contrato

**Estado:** ✅ Resolvido no webhook: checkout de recuperação calcula um novo período e o trigger sincroniza o acesso.

**Ficheiros:**

- `functions/src/index.ts:1000-1085`;
- `functions/src/index.ts:1710-1785`;
- `functions/src/index.ts:2042-2078`.

O checkout de recuperação usa:

```text
mode: 'payment'
```

Depois, `checkout.session.completed` marca o pagamento como `paid`, mas não recalcula `periodoInicio`/`periodoFim`.

A trigger `syncAccessFromPaidPayment` só reativa o acesso se:

```text
periodoFim > agora
```

Num pagamento em atraso, o `periodoFim` original já expirou. Consequentemente:

1. o Stripe cobra;
2. o Firestore marca o pagamento como pago;
3. o trigger corre;
4. o período antigo é considerado expirado;
5. o contrato pode continuar terminado.

Isto contradiz o objetivo documentado do portal de recuperação.

### Correção sugerida

No fluxo de recuperação, após pagamento confirmado:

- calcular um novo período com início em `max(now, contractEndsAt)`;
- atualizar o pagamento com o novo período;
- atualizar o perfil do aluno numa transação;
- tornar a operação idempotente;
- testar especificamente a recuperação de uma conta expirada.

---

## [x] P0 — Token de recuperação de pagamento não é de utilização única

**Estado:** ✅ Resolvido: token tem lock, `usedAt`, sessão reutilizável e tokens anteriores são revogados.

**Ficheiro:** `functions/src/index.ts:80-108 e 1000-1085`.

O token é guardado com hash e expiração, o que é positivo, mas nunca é marcado como usado.

Enquanto estiver válido, alguém com o link pode:

- criar várias sessões Stripe;
- abrir vários checkouts;
- provocar cobranças duplicadas;
- gerar múltiplos eventos e estados concorrentes.

### Correção sugerida

Usar uma transação ou update condicional com `usedAt == null` e marcar o token como usado antes de criar o checkout, ou reutilizar uma sessão existente por `paymentId`.

Também deve existir rate limiting e uma política para invalidar tokens anteriores.

---

# 2. Autorização e integridade dos dados

## [x] P1 — Grupos permitem alteração indevida da composição

**Estado:** ✅ Resolvido nas Rules; alunos só atualizam o próprio cursor de leitura.

**Ficheiro:** `firestore.rules`, secção `match /grupos/{groupId}`.

A regra de update permite:

```text
request.auth.uid in request.resource.data.membros
```

Isto permite que um utilizador que consiga referenciar um grupo altere o próprio documento para se adicionar como membro.

Além disso, um membro atual pode alterar livremente:

- `membros`;
- `criadoPor`;
- nome;
- imagem;
- dados de leitura;
- outros campos do grupo.

Isso permite adicionar terceiros, remover membros ou manipular o grupo.

### Correção sugerida

- Apenas admin deve alterar a lista de membros;
- ou validar operações individuais com `arrayUnion/arrayRemove` através de callable;
- exigir que o utilizador já seja membro para qualquer update não administrativo;
- restringir campos alteráveis com `diff().affectedKeys().hasOnly(...)`.

---

## [x] P1 — Bookings não têm validação server-side suficiente

**Estado:** ✅ Resolvido no fluxo novo `createBooking`, com relação aluno/PT, data, duração e conflito transacional; criação direta está bloqueada.

**Ficheiros:**

- `firestore.rules`, secção `agenda`;
- `lib/features/aluno/agenda/screens/calendar_screen.dart:502`;
- `lib/data/datasources/firestore_datasource.dart:1264-1280`.

O aluno pode criar uma marcação cujo único requisito relevante é `studentId == request.auth.uid`.

Não é validado no backend:

- se `trainerId` é o personal trainer associado;
- se a data é futura;
- se a duração é válida;
- se o status inicial é `pending`;
- se o tipo é válido;
- se existe conflito;
- se o intervalo está dentro do horário do trainer.

O cliente calcula disponibilidade localmente, mas duas pessoas podem marcar o mesmo slot simultaneamente.

A regra de update autoriza um aluno com base no documento antigo (`resource`), mas não restringe os campos do novo documento. Assim, o aluno pode alterar o booking para outro `studentId`, `trainerId`, data, duração ou status.

### Correção sugerida

Criar uma callable `createBooking` que:

- valide a relação aluno/PT;
- valide datas e duração;
- verifique conflitos numa transação;
- crie uma reserva/slot único;
- aplique transições de estado válidas.

Nas regras, restringir updates a campos específicos e manter `studentId`/`trainerId` imutáveis.

---

## [x] P1 — Callables de notificações de agenda podem ser abusadas

**Estado:** ✅ Resolvido: as Functions carregam o booking real e validam caller, papel, relação e estado.

**Ficheiro:** `functions/src/index.ts:1284-1410`, sobretudo `notifyBookingUpdate`.

`notifyBookingUpdate` resolve o UID, mas não valida de forma robusta:

- se o caller é admin;
- se é o aluno do booking;
- se é o trainer;
- se o booking existe;
- se `studentId` e `trainerId` correspondem ao documento real;
- se a transição de estado é autorizada.

Um utilizador autenticado pode enviar dados arbitrários para provocar push notifications a outros utilizadores.

`notifyNewBooking` valida o aluno autenticado, mas não valida que o `trainerId` corresponde ao seu PT.

### Correção sugerida

Estas funções devem receber apenas `bookingId`, ler o booking no backend e verificar o papel/relação do caller. Não devem confiar em `studentId`, `trainerId`, data ou status enviados pelo cliente.

---

## [x] P1 — Notificações de chat não verificam a mensagem ou participação

**Estado:** ✅ Resolvido: trigger/callable validam documento persistido, autoria e participação; chamadas duplicadas no cliente foram removidas.

**Ficheiro:** `functions/src/index.ts:1216-1283`.

`sendChatNotification` valida `remetenteId == UID autenticado`, mas não valida:

- que o remetente pertence à sala direta;
- que a sala existe;
- que a mensagem foi realmente escrita;
- que o remetente é membro do grupo.

Um aluno pode provocar notificações para membros de grupos alheios ou inventar mensagens.

### Correção sugerida

Passar `messageId`, carregar a mensagem e validar remetente/sala/membros no backend. Melhor ainda, remover esta chamada do cliente e usar trigger Firestore `onCreate`.

---

## [x] P1 — Escritas de diário, progresso e logs aceitam qualquer schema

**Estado:** ✅ Resolvido para o schema base: Rules aplicam campos permitidos, tipos, limites e `userId`; validações profundas de listas continuam limitadas pelo modelo de Rules.

**Ficheiro:** `firestore.rules`.

As seguintes subcoleções permitem escrita ampla pelo próprio aluno:

- `diario`;
- `workoutLogs`;
- `progresso`.

Não há validação de:

- tipos;
- campos permitidos;
- limites numéricos;
- datas;
- `userId` interno;
- valores negativos;
- campos inesperados.

Exemplos:

- água negativa ou ilimitada;
- rating fora de 1–5;
- peso negativo;
- medidas absurdas;
- `completedAt` no futuro;
- logs de treino inventados;
- progresso com `userId` de outra pessoa no payload;
- documentos que podem quebrar os parsers.

O cliente faz parsing e validação parcial, mas o Firestore pode ser escrito diretamente por qualquer cliente autenticado.

### Correção sugerida

Usar regras com `keys().hasOnly([...])` e validações de tipo/intervalo, ou centralizar estas escritas em callables.

---

## [x] P1 — Modelos frágeis perante dados inválidos

**Estado:** ✅ Resolvido nos modelos identificados: parsers de booking/diário/progresso/grupos/user/mensagens/nutrição/logs usam defaults e filtragem segura; documentos inválidos deixam de derrubar uma stream inteira.

Vários parsers fazem casts diretos e podem quebrar streams inteiras:

- `BookingModel.fromMap`: `map['data'].toDate()`;
- `DiaryModel.fromMap`: casts diretos para `int`;
- `ProgressModel.fromMap`: `data.toDate()` e medidas como `num`;
- `UserModel.fromMap`: alguns timestamps usam `toDate()` sem fallback;
- `MealEntry.fromMap`: `List<String>.from` e casts de mapas;
- `GroupModel.fromMap`: `List<String>.from(membros)`.

Como as regras permitem dados arbitrários, um único documento malformado pode fazer um provider deixar de emitir.

### Correção sugerida

- Validar schema antes de persistir;
- usar parsers seguros e defaults;
- distinguir documento inválido de erro de rede;
- enviar erro observável para Crashlytics;
- não converter uma stream com dados inválidos silenciosamente em lista vazia.

---

# 3. Autenticação, sessão e privacidade

## [x] P1 — Token FCM antigo não é removido no logout

**Estado:** ✅ Resolvido: logout chama `removeFcmToken`, cancela listeners e elimina o token local.

**Ficheiros:**

- `lib/core/services/fcm_service.dart:240`;
- `lib/features/auth/providers/auth_provider.dart`;
- `lib/app.dart`.

Existe `FCMService.removeToken()`, mas não foi encontrada nenhuma chamada produtiva a esse método.

Ao terminar sessão:

- o `fcmToken` continua no documento do utilizador antigo;
- ao entrar com outra conta no mesmo browser/dispositivo, o token pode ficar associado a ambas;
- o utilizador antigo pode continuar a receber notificações dirigidas à conta anterior.

### Correção sugerida

No logout:

1. apagar o token do perfil atual;
2. cancelar listeners FCM;
3. limpar callbacks;
4. só depois terminar a sessão Firebase.

Também deve existir uma coleção de tokens por dispositivo, com UID, plataforma e timestamp.

---

## [x] P1 — O utilizador pode gravar um `fcmToken` arbitrário

**Estado:** ✅ Resolvido: escrita direta removida das Rules e substituída por callable autenticada com limite.

**Ficheiro:** `firestore.rules`, regra de update do perfil.

`fcmToken` está na lista de campos editáveis pelo próprio aluno, sem validação de tipo/formato. Um cliente pode:

- substituir o token real;
- inserir token inválido;
- impedir notificações;
- provocar remoção posterior do token pelo backend.

### Correção sugerida

Guardar tokens através de callable/backend ou validar string, comprimento e associação ao dispositivo.

---

## [x] P1 — Aceitação da política e conclusão do questionário são controladas por flags do cliente

**Estado:** ✅ Melhorado no código: a aceitação agora passa pela callable `acceptPrivacyPolicy`, que valida a versão, grava timestamp de servidor e cria `users/{uid}/privacyConsentAudit/{version}` imutável para auditoria. A validade jurídica do texto continua dependente de revisão legal.

Embora a aceitação de uma política seja necessariamente iniciada pelo cliente, as regras tratam os campos como prova suficiente. Qualquer cliente modificado pode escrever os valores corretos sem apresentar o texto ou recolher consentimento real.

Para requisitos legais, guardar também:

- versão/hash do documento;
- timestamp de servidor;
- user-agent/plataforma, se necessário;
- evento de auditoria imutável.

---

## [x] P2 — Falhas de pagamentos bloqueiam login por “fail closed”

**Estado:** ✅ Resolvido como política explícita: indisponibilidade financeira gera erro técnico/retry, não dívida falsa.

**Ficheiro:** `lib/data/repositories/auth_repository.dart:117`.

Se a consulta a pagamentos falhar por indisponibilidade temporária do Firestore, erro de índice, rede ou configuração, `_hasOverduePayment` devolve `true`, bloqueando o login.

É uma decisão de segurança válida em alguns cenários, mas cria uma falha de disponibilidade total. Deve ser uma política explícita, diferenciando pagamento confirmado em atraso de backend indisponível.

---

## [x] P2 — Enumeração de contas no login

**Estado:** ✅ Mensagens de `user-not-found` e `wrong-password` foram uniformizadas em `AuthException`; permanece necessária a ativação de Email Enumeration Protection no Firebase Console.

**Ficheiro:** `lib/core/errors/exceptions.dart`.

São apresentadas mensagens diferentes para utilizador inexistente, password errada e email inválido. Isto facilita enumeração de emails.

Ativar email enumeration protection no Firebase Auth e uniformizar mensagens públicas.

---

# 4. Uploads, consistência e limpeza

## [x] P1 — Uploads podem deixar ficheiros órfãos

**Estado:** ✅ Cleanup implementado para progresso, vídeos, imagens de grupo e mensagens de chat/áudio: se a escrita Firestore falhar, o path carregado é removido em best effort. A gravação ainda não é uma transação distribuída; dados legados com URLs continuam a exigir backfill/revogação operacional.

**Ficheiros:**

- `lib/features/aluno/perfil/screens/progress_submission_screen.dart:615-710`;
- `lib/data/repositories/progress_video_repository.dart:35-65`;
- `lib/shared/utils/chat_attachment.dart`;
- `lib/shared/utils/audio_chat_message.dart`.

O padrão é:

1. fazer upload Storage;
2. obter URL;
3. escrever documento Firestore.

Se o passo 3 falhar, o ficheiro fica abandonado. No progresso, se uma das quatro fotos falhar, pode haver uma submissão parcial.

### Correção sugerida

- gerar um `submissionId` idempotente;
- criar estado `uploading`;
- fazer cleanup dos paths já enviados em caso de falha;
- usar trigger de limpeza de órfãos;
- guardar paths, não URLs permanentes;
- evitar várias submissões para o mesmo pedido sem verificar estado.

---

## [x] P1 — Vídeos não validam extensão/MIME no backend

**Estado:** ✅ Resolvido no cliente/repositório e reforçado pelas Storage Rules.

**Ficheiro:** `lib/features/aluno/perfil/screens/video_progress_screen.dart:50-65`.

A extensão e MIME são derivados do nome do ficheiro:

```dart
contentType: 'video/$extension'
```

Isso pode gerar valores inválidos ou enganadores. A validação Storage específica já é contornável pela regra recursiva geral.

### Correção sugerida

Validar MIME real no backend/Storage, limitar extensões permitidas e impor tamanho máximo também na aplicação.

---

# 5. Cloud Functions e pagamentos

## [x] P1 — Endpoints HTTP privilegiados usam CORS `*` e token no body

**Estado:** ✅ Resolvido no código: CORS está restrito, o token é lido apenas do header `Authorization: Bearer` e existe rate limit persistente por admin/ação. App Check continua uma configuração adicional recomendada no Firebase Console.

**Ficheiros:** `functions/src/index.ts:159-308`.

`createStudentHttp` e `deleteStudentHttp`:

- aceitam `Access-Control-Allow-Origin: *`;
- recebem `authToken` no JSON;
- não usam o header `Authorization`;
- registam nome/email no log;
- não têm rate limit.

O token não é automaticamente comprometido apenas por CORS, mas este desenho aumenta a superfície de exposição e dificulta políticas de segurança.

### Correção sugerida

- usar callable Functions ou `Authorization: Bearer`;
- restringir origins;
- aplicar App Check/rate limiting;
- não enviar tokens no payload;
- remover PII dos logs.

---

## [x] P1 — Password temporária usa `Math.random()`

**Estado:** ✅ Resolvido o RNG e o segredo deixou de ser devolvido na resposta; novos alunos recebem email de reset.

**Ficheiro:** `functions/src/index.ts:228`.

```ts
Math.random().toString(36).slice(-10) + 'A1!'
```

`Math.random()` não é um gerador criptograficamente seguro. Além disso, a password temporária é devolvida na resposta HTTP e não há mecanismo claro de reset obrigatório no primeiro login.

### Correção sugerida

Usar `randomBytes`, enviar reset de password por email e forçar alteração no primeiro acesso.

---

## [x] P1 — Eliminar um aluno não elimina os seus dados associados

**Estado:** ✅ Resolvido com purge recursivo, limpeza Storage, grupos, agenda, notificações e anonimização de pagamentos pagos; requer validação operacional em produção.

**Ficheiro:** `functions/src/index.ts:249-308`.

`deleteStudentHttp` elimina o utilizador Firebase Auth e o documento `/users/{uid}`, mas não elimina:

- subcoleções;
- Storage;
- mensagens;
- grupos;
- pagamentos;
- tokens de recuperação;
- contratos/subscrições Stripe;
- faturas;
- notificações.

Não há transação distribuída entre Auth, Firestore, Storage e Stripe. Se falhar a meio, o sistema fica inconsistente.

### Correção sugerida

Implementar um processo de eliminação assíncrono/idempotente com:

- cancelamento de subscrição;
- apagamento recursivo;
- limpeza Storage;
- anonimização ou retenção legal de pagamentos;
- registo de auditoria;
- retries.

Validar também se apagar outros admins é realmente permitido.

---

## [x] P1 — `resendPaymentRecovery` não tem rate limit

**Estado:** ✅ Resolvido com janela mínima de cinco minutos.

**Ficheiro:** `functions/src/index.ts:1088-1105`.

Um admin ou sessão administrativa comprometida pode gerar repetidamente tokens, notificações, pushes e emails.

### Correção sugerida

Guardar `recoveryLastSentAt`, impor janela mínima também nesta callable e registar auditoria.

---

## [x] P2 — Webhook Stripe deixa eventos inconsistentes em alguns retornos antecipados

**Estado:** ✅ Resolvido no fluxo: eventos ficam em `processing`, `ignored` ou `processed`; falhas removem o marcador para permitir retry e os retornos antecipados gravam estado terminal com `processedAt`. Um lock temporário impede processamento concorrente.

**Ficheiro:** `functions/src/index.ts:1680-1810`.

O evento é registado em `stripeEvents` antes do processamento. Em alguns `return` antecipados, como metadata incompleta, o marcador não é removido. O Stripe pode reenviar o evento, mas a aplicação responde como duplicado sem o reprocessar.

### Correção sugerida

Guardar estados `received`, `processed`, `failed`, e apenas considerar duplicado um evento com `processedAt`.

---

# 6. Frontend, estado e bugs funcionais

## [x] P1 — Streams transformam erros em dados vazios

**Estado:** ✅ Resolvido nos fluxos de chat, agenda e diário revistos: erros propagam-se em vez de virar listas vazias.

**Ficheiros:**

- `lib/data/datasources/firestore_datasource.dart`, streams de agenda;
- `lib/data/repositories/chat_repository.dart`.

Há vários padrões como:

```dart
.handleError((_) => <BookingModel>[])
```

e o chat imprime o erro mas não o propaga.

Impacto:

- uma falha de permissões aparece como “não existem marcações”;
- uma falha de rede parece uma lista vazia;
- utilizadores podem criar dados duplicados por pensarem que a operação não existia;
- bugs de regras ficam escondidos.

### Correção sugerida

Modelar estados `loading/data/error`, preservar o erro e mostrar retry técnico.

---

## [x] P1 — Histórico de chat é carregado integralmente

**Estado:** ✅ Mitigado: chats usam `limit(100)` e leitura usa limite de 500; falta UI de paginação de histórico antigo.

**Ficheiros:**

- `FirestoreDataSource.messagesStream`;
- `watchGroupMessages`;
- `admin_messages_view.dart`;
- `floating_chat_button.dart`;
- `chat_notification_providers.dart`.

As queries usam `orderBy` mas não usam paginação/`limit`. Cada alteração pode carregar todo o histórico da conversa e todos os documentos de todas as salas observadas.

`markMessagesAsRead` também lê todas as mensagens da sala antes de atualizar em batches.

### Correção sugerida

- paginação por cursor;
- `limit`;
- carregar mensagens antigas sob pedido;
- manter contador/cursor no documento da sala;
- marcar como lidas apenas por intervalo/ID.

---

## [x] P1 — Dashboard do admin cria um listener de diário por aluno

**Estado:** ✅ Resolvido no código: o dashboard lê um agregado materializado em `adminAggregates/dashboard`, mantido por trigger delta-based; continua necessário um backfill único para dados históricos anteriores ao deploy do trigger.

**Ficheiro:** `lib/shared/providers/admin_providers.dart:92-190`.

`adminDashboardStatsProvider`:

1. observa todos os alunos;
2. cria um listener Firestore individual para o diário de cada aluno;
3. lê todos os documentos de diário;
4. recalcula tudo localmente.

Isto escala mal em número de alunos e aumenta leituras/custos.

### Correção sugerida

Manter agregados no backend ou usar Cloud Functions para contadores diários/mensais. Se necessário, usar queries limitadas e dados agregados.

---

## [ ] P1 — Listagens sem paginação

**Estado:** ⚠️ Parcial: clientes, pagamentos, grupos e alimentos usam agora páginas com `limit` e `startAfterDocument`, com controladores e botões de carregamento. Streams de preview em tempo real estão limitados a 100 documentos. Exercícios, planos, notificações e alguns históricos/chat ainda precisam de cursor de UI completo.

As listagens que ainda não têm cursor de UI completo incluem:

- históricos de chat e mensagens antigas;
- planos atribuídos e alguns históricos de diário/progresso/logs;
- notificações antigas;
- catálogo de exercícios além do primeiro lote.

Clientes, pagamentos, grupos e alimentos já usam páginas explícitas com cursor.
Os históricos de diário, progresso e treino têm limites server-side, mas ainda não têm um botão de carregamento incremental.

### Correção sugerida

Paginar no Firestore com `limit`, `startAfterDocument` e ordenação estável.

---

## [x] P2 — Erros de autosave do treino são silenciosos

**Estado:** ✅ Resolvido: o autosave mantém estado pendente, agenda alterações concorrentes e mostra uma indicação de sincronização falhada, mantendo retry na próxima edição.

**Ficheiro:** `lib/features/aluno/treino/screens/workout_screen.dart:118-155`.

O autosave captura qualquer exceção e não informa o estado ao utilizador:

```dart
catch (_) {
  // Silently fail auto-save
}
```

O treino pode parecer guardado quando não está. O retry depende da existência de uma nova edição.

### Correção sugerida

Guardar estado “pendente de sincronização”, retry com backoff e sinalizar erro de persistência.

---

## [x] P2 — Escrita do progresso não é idempotente

**Estado:** ✅ Resolvido: a submissão usa uma chave determinística baseada no pedido de progresso (ou no dia), `set` no documento correspondente e paths de fotos reutilizáveis; retries não criam entradas novas.

**Ficheiro:** `progress_submission_screen.dart:635-710`.

Uma falha depois de `addProgress` mas antes de limpar `hasPendingProgress` pode causar:

- entrada duplicada ao repetir;
- fotos duplicadas;
- peso duplicado;
- pedido ainda marcado como pendente.

### Correção sugerida

Usar um ID determinístico por pedido e `set`/transação em vez de `add` sem chave idempotente.

---

## [x] P2 — Conectividade deixa subscrição pendurada

**Estado:** ✅ Resolvido: a `StreamSubscription` é cancelada no `dispose`.

**Ficheiro:** `lib/core/utils/connectivity_service.dart`.

O serviço faz:

```dart
_connectivity.onConnectivityChanged.listen(...)
```

mas não guarda a `StreamSubscription`. `dispose()` fecha apenas o controller próprio. A subscrição à plataforma continua ativa.

### Correção sugerida

Guardar a subscrição e cancelá-la no `dispose()`.

Também convém não tratar “há uma interface de rede” como prova de que Firebase está acessível.

---

## [x] P2 — FCM foreground não está ligado a nenhum callback

**Estado:** ✅ Resolvido: aluno e admin ligam `onForegroundMessage` à notificação local.

**Ficheiro:** `lib/core/services/fcm_service.dart:111`.

O serviço chama:

```dart
onForegroundMessage?.call(message);
```

mas não foi encontrado código produtivo que atribua `onForegroundMessage`. `showLocalNotification` existe, mas não é usado.

Assim, notificações FCM gerais recebidas com a aplicação aberta não têm tratamento visual local. O sistema de sons cobre alguns eventos de chat, mas não substitui o tratamento geral de FCM.

### Correção sugerida

Ligar o callback no root da app e encaminhar por tipo de notificação.

---

# 7. Integração e plataformas

## [x] P1 — O repositório não contém projetos Android/iOS

**Estado:** ✅ Resolvido no source: foram gerados e versionados `android/` e `ios/`, com identificador `com.gymbt.app`, permissões de câmara/microfone/fotografias/movimento/notificações e configurações Dart Firebase para Android/iOS. O build efetivo ainda requer Android SDK, assinatura Android, Xcode/CocoaPods e configuração APNs fora deste ambiente.

---

## [x] P2 — APIs web obsoletas

**Estado:** ✅ Resolvido: as integrações Web foram migradas para `package:web`/JS interop e os imports condicionais usam `dart.library.js_interop`.

**Ficheiros:**

- `audio_recording_service_web.dart`;
- `sound_service_web.dart`.

As duas implementações usam agora `package:web`, incluindo `HTMLAudioElement` e `URL.revokeObjectURL`, sem referências a `dart:html`.

### Correção sugerida

Migrar para `package:web`/`dart:js_interop` ou encapsular a integração num plugin compatível.

---

## [x] P2 — Configuração de índices Firestore não é reproduzível

**Estado:** ✅ Resolvido com `firestore.indexes.json` referenciado no `firebase.json`.

O projeto passou a versionar `firestore.indexes.json` e a referenciá-lo no `firebase.json`.

Há queries que precisam de índice composto, por exemplo:

```dart
where('membros', arrayContains: userId)
.orderBy('createdAt', descending: true)
```

em `FirestoreDataSource.getMyGroups`.

Se o índice existir apenas manualmente na consola, um novo ambiente/deploy não reproduz a configuração.

### Correção sugerida

Versionar os índices e incluí-los no `firebase.json`.

---

# 8. Dependências e configuração

## [x] P2 — Script de lint inválido

**Estado:** ✅ Resolvido: ESLint 9, parser/plugin TypeScript e configuração flat foram adicionados.

**Ficheiro:** `functions/package.json`.

Existe:

```json
"lint": "eslint --ext .js,.ts ."
```

mas `eslint` não está em `devDependencies` e não há configuração ESLint visível. O comando falha imediatamente.

### Correção sugerida

Adicionar ESLint, configuração TypeScript e parser/plugin apropriados, ou remover o script.

---

## [x] P2 — Testes das Functions podem usar JavaScript compilado antigo

**Estado:** ✅ Resolvido: `npm test` executa `npm run build` antes do Jest.

**Ficheiro:** `functions/test/index.test.ts`.

O teste importa:

```ts
require('../lib/index')
```

mas `npm test` não executa `npm run build` previamente. Portanto, os testes podem passar sobre um `lib/index.js` antigo, diferente de `src/index.ts`.

### Correção sugerida

- testar diretamente `src` com ts-jest;
- ou mudar o script para `npm run build && jest`;
- ou garantir que `lib` é sempre gerado em CI/deploy.

---

## [x] P2 — Código compilado `functions/lib` está versionado

**Estado:** ✅ Resolvido: `functions/lib` está ignorado, os artefactos historicamente rastreados foram removidos e `npm test`/deploy geram o JavaScript a partir de `src` antes de o utilizar.

O deploy usa:

```json
"main": "lib/index.js"
```

e `functions/lib` está presente no repositório. Isto cria risco de divergência entre source e artefacto compilado.

### Correção sugerida

Escolher uma estratégia:

- não versionar `lib` e fazer build em CI/deploy;
- ou versioná-lo com verificação obrigatória de que está sincronizado.

---

## [x] P2 — Dependências não usadas ou sem uso confirmado

**Estado:** ✅ Resolvido no código: `firebase_analytics`, `riverpod_annotation` e `riverpod_generator` foram removidos por não terem uso; `firebase_crashlytics` passou a capturar erros Flutter e assíncronos em plataformas nativas.

Não foi encontrado uso de `riverpod_annotation`, `riverpod_generator` ou `firebase_analytics`, que foram removidos. `firebase_crashlytics` permanece e é inicializado em `main.dart` para erros Flutter e assíncronos nativos.

### Correção sugerida

Remover dependências não usadas ou implementar efetivamente:

- captura de erros Flutter;
- erros assíncronos;
- contexto de utilizador;
- breadcrumbs;
- eventos Analytics.

---

# 9. Qualidade e cobertura

## [ ] Issues do analyzer mais relevantes

**Estado:** ⚠️ Parcial: não há erros nem warnings do analyzer e os 23 métodos legados identificados foram removidos. Permanecem **191 infos** de dívida histórica de estilo/lifecycle.

O resultado atual contém apenas infos, sobretudo:

- múltiplos `use_build_context_synchronously` em `admin_panel_screen.dart` e widgets de chat;
- `prefer_const`, `curly_braces` e `unnecessary_underscores` em vários ecrãs;
- ordenação de propriedades de widgets;
- alguns helpers de teste e a ferramenta de geração de som.

Nem todos são bugs, mas o volume reduz a capacidade de distinguir regressões reais de ruído.

### Próximas melhorias não bloqueantes

- reduzir progressivamente os infos de lifecycle/async context;
- substituir `prefer_const`, `curly_braces` e `unnecessary_underscores` onde fizer sentido;
- ativar análise fatal para erros/warnings em CI, mantendo infos não fatais;
- separar o `admin_panel_screen.dart`, que continua excessivamente grande;
- usar logging estruturado em vez de `print`/silenciamento indiscriminado.

---

## [ ] Cobertura insuficiente dos fluxos críticos

**Estado:** ⚠️ Parcial: foram adicionados testes de Rules para chat, grupos, questionário, agenda, schema, FCM e Storage, mas não puderam ser executados neste ambiente sem Java.

Os testes atuais cobrem sobretudo:

- modelos;
- validators;
- widgets básicos;
- lógica pura de fotos;
- alguns testes offline de Functions.

Ainda não há execução comprovada neste ambiente para:

- Firestore/Storage Rules no Emulator;
- bookings concorrentes via callable;
- pagamento Stripe completo;
- webhook idempotente;
- recuperação de pagamento;
- permissões mobile.

Os testes de código das Rules já cobrem isolamento entre alunos, chat direto, grupos, agenda, schema, limites de Storage, questionário e o path FCM; aguardam apenas Java/Emulator para serem executados.

### Correção prioritária

Adicionar Firebase Emulator Suite e testes que provem:

1. aluno A não lê chat do aluno B;
2. aluno não altera membros do grupo;
3. aluno não escreve dados fora do próprio perfil;
4. Storage rejeita ficheiros grandes/MIME inválido;
5. booking concorrente não duplica slot;
6. recuperação paga realmente reativa o contrato.

---

# 10. Observações positivas

- Não foram encontradas chaves `sk_`, `whsec_` ou `re_` no código analisado.
- As Firebase API keys e a VAPID pública presentes no frontend não são, por si só, segredos.
- As Cloud Functions usam verificação de assinatura Stripe.
- Existe tentativa de idempotência por `event.id`.
- Há validação de roles em várias callables administrativas.
- A separação entre modelos, repositories e datasources é uma boa base.
- Os testes de modelos e da lógica de fotos são razoáveis e passaram.

---

# Ordem recomendada de correção

## Imediato antes de produção

1. `[x]` Corrigir regras de chat direto.
2. `[x]` Corrigir regras de grupos.
3. `[x]` Corrigir Storage Rules sobrepostas e paths de chat.
4. `[x]` Parar de expor URLs permanentes de download para dados sensíveis em novos uploads; concluir backfill/revogação dos dados legados antes do go-live.
5. `[x]` Corrigir questionário e adicionar testes de regras.
6. `[x]` Corrigir recuperação Stripe para renovar o período.
7. `[x]` Tornar tokens de recuperação de utilização única.
8. `[x]` Restringir bookings no backend e resolver conflitos por transação.
9. `[x]` Remover FCM token no logout.
10. `[x]` Validar schema base de escritas feitas por alunos.

## Segunda fase

1. `[ ]` Paginação completa de streams e históricos; clientes, pagamentos, grupos e alimentos já têm cursor de UI.
2. `[ ]` Agregado materializado para dashboard; o trigger delta está implementado e falta executar a reconciliação histórica antes do go-live.
3. `[x]` Limpeza de uploads órfãos de progresso/vídeo/chat/grupo e persistência de paths; backfill/revogação de URLs legadas continua pendente.
4. `[x]` Triggers Firestore para notificações de chat.
5. `[ ]` Executar testes com Emulator Suite; comando reproduzível adicionado, mas Java está ausente neste ambiente.
6. `[x]` Corrigir lint Functions, configurar build antes dos testes e remover os warnings Flutter; permanecem apenas infos históricos.
7. `[x]` Implementar Crashlytics ou remover dependências sem uso; Analytics foi removido.
8. `[x]` Decidir/configurar suporte Android/iOS: alvo confirmado e projetos nativos gerados; assinatura, APNs e toolchains permanecem configuração de release.

## Contexto que requer verificação fora do código

A revisão estática não confirma:

- regras atualmente publicadas no projeto Firebase;
- índices existentes apenas na consola;
- variáveis Stripe/Resend realmente configuradas;
- se o webhook de produção aponta para a Function correta;
- configuração de App Check;
- providers de autenticação ativos;
- intenção de permitir que admins eliminem/demovam outros admins.

## Estado após esta fase

### Resolvidos nesta fase

- `[x]` Isolamento de chat direto, grupos e uploads Storage.
- `[x]` Questionário atómico e compatível com o cliente.
- `[x]` Bookings transacionais e notificações baseadas em documentos reais.
- `[x]` Recuperação Stripe: renovação de período, token único, rate limit e estados de webhook.
- `[x]` FCM: registo server-side, remoção no logout e foreground callback.
- `[x]` Validação base de diário/progresso/logs, parsers principais, cleanup de uploads e persistência de paths Storage.
- `[x]` Índices versionados, lint Functions e build antes dos testes.

### Ainda bloqueantes antes de produção

- `[x]` Migrar novos uploads de URLs bearer para paths + resolução autenticada transitória; `[ ]` executar backfill/revogação de URLs legadas.
- `[ ]` Executar a suite no Emulator com Java e corrigir qualquer incompatibilidade das Rules.
- `[ ]` Completar paginação dos históricos/streams restantes e executar backfill/revogação dos recursos Storage legados; os quatro catálogos administrativos principais já usam cursores.
- `[x]` Decidir/configurar suporte Android/iOS no source; faltam apenas toolchains, assinatura e serviços de distribuição.
- `[x]` Remover os 23 métodos legados não referenciados e eliminar todos os warnings do analyzer; `[ ]` reduzir os 191 infos históricos restantes.
- `[x]` Substituir as integrações Web obsoletas por `package:web`.

## Conclusão

A aplicação tem uma base funcional sólida e os testes locais passam. Os principais P0 de Firestore, Storage, questionário e recuperação foram corrigidos no código, mas **não deve ser considerada pronta para produção enquanto os itens bloqueantes acima, especialmente as URLs bearer e a validação efetiva no Emulator, não forem concluídos**.

---

# Pontos restantes em falta — identificação rápida

Esta secção consolida apenas o trabalho que ainda falta executar, validar ou configurar. Os itens marcados como operacionais não devem ser considerados resolvidos apenas porque o código já está preparado.

## Bloqueantes antes do go-live

- `[ ]` **Backfill dos recursos Storage legados:** executar `backfillStoragePaths` em dry-run, rever os resultados, aplicar em lotes pequenos, confirmar que os clientes atualizados resolvem os paths e só depois revogar tokens antigos.
- `[ ]` **Reconciliação do agregado administrativo:** executar o backfill histórico de `adminAggregates/dashboard`; o trigger `aggregateDiaryStats` cobre alterações posteriores, mas não substitui a reconciliação inicial.
- `[ ]` **Firebase Emulator Suite:** instalar Java 11+ e executar `cd rules-tests && npm install && npm run test:emulator`; corrigir quaisquer falhas reais das Firestore/Storage Rules que surgirem.
- `[ ]` **Validação de produção Firebase:** confirmar Rules e índices publicados, providers de autenticação ativos, App Check configurado e permissões efetivas no projeto correto.
- `[ ]` **Validação Stripe/Resend:** confirmar variáveis secretas, remetente/domínio do Resend, endpoint e assinatura do webhook Stripe, e testar os fluxos reais de pagamento, recuperação e idempotência.

## Trabalho de código ainda pendente

- `[ ]` **Paginação dos históricos restantes:** adicionar cursor e carregamento incremental à pesquisa/histórico antigo de chat, planos, notificações, diário, progresso, logs de treino e catálogo completo de exercícios.
- `[ ]` **Testes de integração críticos:** executar concorrência de bookings, webhooks Stripe, recuperação de pagamento, notificações e permissões Storage contra Emulator ou ambientes de teste controlados.
- `[ ]` **Redução dos infos Flutter:** existem 191 infos, sem erros nem warnings; priorizar `use_build_context_synchronously` e depois a dívida de estilo.

## Release mobile ainda pendente

- `[ ]` **Android:** instalar Android SDK/Gradle, validar `flutter build apk`/AAB e configurar assinatura de release.
- `[ ]` **iOS:** executar em macOS com Xcode/CocoaPods, validar `flutter build ios`, assinatura, APNs e configuração de distribuição.
- `[ ]` **Firebase mobile:** confirmar `google-services.json`, `GoogleService-Info.plist`, bundle/package identifiers, notificações e permissões em dispositivos reais; não versionar segredos.

## Resolvido e não deve voltar à lista de pendências

- `[x]` Os 23 métodos legados não referenciados foram removidos.
- `[x]` O analyzer Flutter não apresenta erros nem warnings.
- `[x]` Os 239 testes Flutter atuais passam.
- `[x]` Os quatro catálogos administrativos principais já usam paginação por cursor.
- `[x]` Novos uploads Storage persistem paths privados e usam resolução autenticada transitória.
