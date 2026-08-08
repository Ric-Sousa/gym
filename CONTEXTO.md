# CONTEXTO DO PROJETO — Handoff para continuar o trabalho

> Documento criado para entregar a outra IA e continuar o desenvolvimento sem perder contexto.
> Lê tudo antes de mexer no código. Não alteres a paleta de cores nem a lógica de negócio.
> Última atualização: **2026-08-08** (sessão que corrigiu a Comparação de Progresso — ver secção 6).

---

## 1. Identificação

- **Projeto:** Aplicação de ginásio ("Kinetic") com área de **Aluno** e área de **Admin**.
- **Framework:** Flutter (Dart), com target **Web (Chrome)** e mobile (Android/iOS).
- **Caminho do projeto:** `gym_app/` dentro de `C:\Users\Cardoso\Documents\PROGRAMAS\projetos trabalho\gym`.
- **Branch atual:** `marcus` (merge para `main`).
- **Backend:** Firebase — Auth, Firestore, Storage, Cloud Functions, Messaging (FCM).

### Dependências principais (pubspec.yaml)
- `flutter_riverpod` (estado/DI), `google_fonts` (tipografia), `intl` (datas), `fl_chart` (gráficos), `image_picker`, `just_audio`, `record` (áudio), `url_launcher`, `share_plus`, `firebase_core/auth/firestore/storage/messaging/functions/analytics/crashlytics`, `connectivity_plus`, `pedometer`, `printing`, `wakelock_plus`, `video_player`.

---

## 2. Estrutura de pastas relevante (lib/)

```
lib/
  main.dart
  app.dart
  core/
    config/          -> app_colors.dart, app_constants.dart, app_strings.dart, admin_theme.dart, notification_sounds.dart
    services/        -> audio_recording_service*, sound_service*, fcm_service.dart
    utils/           -> connectivity_service.dart, validators.dart, progress_photo_normalizer.dart,
                        progress_photo_resolver.dart          <-- NOVO (ver secção 5/6)
    errors/          -> exceptions.dart, failures.dart
  data/
    datasources/     -> auth_datasource.dart, firestore_datasource.dart, storage_datasource.dart
    models/          -> progress_model.dart, workout_plan_model.dart, user_model.dart, booking_model.dart,
                        diary_model.dart, food_model.dart, group_model.dart, message_model.dart,
                        nutrition_plan_model.dart, payment_model.dart, workout_log_model.dart
    repositories/    -> progress_repository.dart, workout_repository.dart, user_repository.dart, etc.
  features/
    admin/
      screens/       -> admin_panel_screen.dart (gigante, ~5800+ linhas), student_detail_screen.dart
      widgets/       -> workout_editor.dart, nutrition_editor.dart, report_generator.dart, admin_messages_view.dart,
                        floating_chat_button.dart, admin_group_notification_provider.dart
    aluno/
      home/screens/        -> aluno_home_screen.dart
      treino/screens/      -> workout_screen.dart
      nutricao/screens/    -> nutrition_screen.dart
      perfil/screens/      -> profile_screen.dart, progress_submission_screen.dart
      agenda/screens/      -> calendar_screen.dart
      chat/screens/        -> chat_screen.dart, group_chat_screen.dart
    auth/            -> login_screen.dart, providers/auth_provider.dart
  shared/
    providers/       -> global_providers.dart, admin_providers.dart, chat_notification_providers.dart
    widgets/         -> image_comparison_slider.dart, audio_record_button.dart, audio_message_player.dart,
                        app_notification.dart, loading_button.dart, empty_state.dart, error_display.dart,
                        circular_progress_widget.dart, offline_banner.dart, star_rating.dart, etc.
```

---

## 3. Design system (NÃO ALTERAR a paleta)

- **Tema:** Dark ("Kinetic Dark"). Fundo escuro (`AppColors.background` ≈ #121212), superfícies `surface/surfaceHigh/surfaceHighest`, texto `onSurface/textSecondary/onSurfaceVariant`.
- **Cor primária (detalhes):** rosa/magenta (`AppColors.primary`). **Regra do cliente:** apenas os detalhes a rosa; botões, fontes e fundos devem ser neutros/cinza por padrão.
- **Estilo:** minimalista, moderno, arredondado (border-radius 12–18), sombras subtis, microinterações. Evitar quadrados rígidos e excesso de cor.
- **Outros:** `AppColors.error`, `AppColors.calories`, `AppColors.outline`.
- **Botões:** fundo cinza claro bem fraquinho + fonte branca (ex.: `surfaceHighest` + `onSurface`), sem gradientes rosa (exceto detalhes).
- **Fonte:** `GoogleFonts.montserrat` (títulos) e `GoogleFonts.inter` (texto/botões).

---

## 4. Funcionalidades principais

### Área Admin (`admin_panel_screen.dart`)
- Painel com sidebar/navegação por secções (clientes, treinos, nutrição, agenda, chat, grupos, notificações, relatórios).
- Gestão de clientes: criar (com ativar/desativar perfil), ver lista (vista default = **lista** com nome, data de início e tipo de plano presencial/online), ficha do cliente com nota, terminar contrato (agora ou com dia/hora), pedir avaliação de progresso.
- Treinos: **Planos → Sub-planos → Exercícios** (com vídeo). Admin pode criar/deletar planos, sub-planos e exercícios. Atribuir plano (o **plano inteiro**, não sub-plano) a aluno + dia da semana.
- Modais: reformulados para responsivos e minimalistas.
- Chat admin (mesmo formato do aluno, com lista de conversas).

### Área Aluno
- **Home**, **Treino** (planos/sub-planos/duração, séries/pesos/repetições), **Nutrição** (sem o card "Nutrição Diária"), **Agenda** (calendário), **Chat** (lista de conversas → entrar na conversa; áudio estilo WhatsApp; anexos; sem modal "Comunicação"), **Perfil**.
- **Perfil:** informações editáveis, métricas (Peso e Altura — sem card de IMC), **Comparação de progresso** (fixa no perfil, com slider), Som de notificação, pagamentos/faturas.

---

## 5. Fluxo de FOTOS DE PROGRESSO (feature mais recente — ATENÇÃO)

1. **Admin** pede avaliação de progresso ao aluno (`hasPendingProgress = true`).
2. **Aluno** abre "Avaliação de Progresso" (`ProgressSubmissionScreen`), com **4 posições fixas**:
   - Ordem dos slots: **Frente, Lado 1, Lado 2, Costas** (const `_photoPositions`).
   - Cada posição permite adicionar/substituir/remover a sua foto individualmente.
   - Fotos são normalizadas para **1024×1280 (4:5)** via `normalizeProgressPhoto` (`core/utils/progress_photo_normalizer.dart`).
3. **Persistência no Firestore** (`progress_submission_screen.dart` `_submitProgress`):
   - `fotos`: lista de **4 posições fixas**, com `''` nas posições vazias (mantém o índice identificável).
   - `fotosPorPosicao`: mapa `{ 'Frente': url, 'Lado 1': url, ... }` só com posições preenchidas.
4. **Perfil do aluno** (`profile_screen.dart`) — card fixo **"Comparação de progresso"**:
   - Dropdowns "Data inicial" / "Data final" **sempre visíveis** (o aluno nunca fica preso num estado sem ação).
   - Botões de ângulo: **Frente, Costas, Lado 1, Lado 2** (ordem visual = `progressAngleLabels` do resolver).
   - `ImageComparisonSlider` (slider com divisor) em tempo real; comparador sempre visível, sem botão "Comparar Progresso".
   - **Par de datas padrão inteligente** (`_bestComparisonPair`): escolhe a maior amplitude de datas que partilha pelo menos um ângulo (em vez de cegamente primeiro/último).
   - **Botões de ângulo sempre clicáveis** (correção de 2026-08-08, ver secção 6):
     - Ângulo disponível (foto nas **duas** datas) → seleciona e atualiza o slider.
     - Ângulo indisponível → visual esbatido (fundo 35%, texto 45%, borda fraca) e o toque mostra mensagem inline: `"Sem foto de X na data inicial/final (dd/MM/aaaa)."` ou `"Nenhuma das datas selecionadas tem foto de X."` (campo de estado `_angleFeedback`, limpo ao mudar datas/ângulo).
     - Quando algum ângulo está indisponível, legenda discreta: `"Só é possível comparar ângulos com fotos nas duas datas."`
   - Par sem ângulo comum → painel no lugar do slider (`_buildNoSharedAnglePanel`) com botão **"Escolher datas automaticamente"** (aplica o melhor par).
   - Mesma data nas duas dropdowns → banner de aviso com botão **"Corrigir"** (aplica o melhor par).
   - Falha de carregamento → estado com botão **"Tentar novamente"** (`ref.invalidate(progressHistoryProvider)`).

### Resolução de fotos por ângulo — `lib/core/utils/progress_photo_resolver.dart` (NOVO, 2026-08-08)

Toda a lógica de "que URL corresponde a que ângulo" está neste utilitário puro e testável (funções top-level). O ecrã só chama `resolveProgressPhotoAt(fotos:, fotosPorPosicao:, angleIndex:)`. Regras, por ordem:

1. **Mapa explícito** `fotosPorPosicao` com chaves **normalizadas** (`normalizeProgressPositionKey`: aceita `frente`, `Frente`, `lado-1`, `Lado_2`, `Lado Esquerdo`, `Posterior`, etc.).
2. **Formato novo** (lista de 4 slots; identificado por existirem placeholders `''` ou mapa reconhecido): ordem **Frente, Lado 1, Lado 2, Costas** (índices por ângulo `[0, 3, 1, 2]`).
3. **Registos antigos** (lista compacta de 1–4 fotos, sem mapa, sem placeholders) — **ordem decidida com o cliente em 2026-08-08**, seguindo a sugestão do formulário antigo *"frente, lado, costas, opcional"*:
   - 1 foto = **Frente**
   - 2 fotos = **Frente, Lado 1**
   - 3 fotos = **Frente, Lado 1, Costas**
   - 4 fotos = **Frente, Lado 1, Costas, Lado 2** (4.ª "opcional" tratada como Lado 2)
4. **Mapa parcial + lista compacta (< 4)** → não adivinha posições em falta (evita trocar Lado por Costas).

Outras funções: `explicitProgressPhotoAt`, `hasRecognizedProgressPositionPhoto`, `hasAnyProgressPhoto(fotos, mapa)`, `legacyProgressPhotoIndex`.

> ⚠️ **Nota histórica:** o formulário antigo (antes dos 4 slots fixos) era um "Adicionar foto" genérico, até 4 fotos, sem etiquetas — o texto sugeria *"Adiciona até 4 fotos (frente, lado, costas, opcional)"*. Daí a ambiguidade Costas↔Lado 2 na 3.ª/4.ª foto antiga, resolvida com a decisão acima.

### Modelo (`lib/data/models/progress_model.dart`)
- Campos: `id`, `userId`, `data`, `peso`, `medidas` (Map), `fotos` (List<String>), `fotosPorPosicao` (Map<String,String>).
- `fromMap`/`toMap` já leem/escrevem `fotosPorPosicao`.

---

## 6. ÚLTIMAS CORREÇÕES (2026-08-08) — Comparação de Progresso RESOLVIDA

### Bug 1 — utilizador preso em "As fotos selecionadas não estão disponíveis para comparação."
- **Causa:** registos antigos com 1–3 fotos (sem mapa) não resolviam nenhum ângulo (`_legacyPhotoIndex` só funcionava com 4 fotos) e o estado de erro não tinha ações.
- **Correção aplicada:**
  - Lógica extraída para `progress_photo_resolver.dart` com **fallback legado para 1–4 fotos antigas** (ordem da secção 5, decidida com o cliente).
  - O estado de erro "mudo" foi **eliminado**: dropdowns e botões de ângulo ficam sempre visíveis; painel substituto com "Escolher datas automaticamente"; "Tentar novamente" no erro de carregamento; "Corrigir" usa o melhor par.
  - Par padrão passou a ser o **melhor par com ângulo comum** (`_bestComparisonPair`).

### Bug 2 — botões Costas/Lado 1/Lado 2 "mortos" ao clique
- **Causa:** ficavam `onPressed: null` quando o ângulo faltava numa das datas, com estilo desativado quase idêntico ao ativo (só texto a 35%) → pareciam clicáveis mas não faziam nada.
- **Correção aplicada:** botões **sempre clicáveis**; indisponível = visual claramente esbatido + toque mostra mensagem inline a dizer **que foto falta e em que data**; legenda preventiva quando há ângulos indisponíveis.

### Bug 3 (encontrado e corrigido nesta sessão) — normalização de chaves
- O regex antigo `RegExp(r'[\\s_-]+')` removia a letra **"s"** das chaves (`"Costas"` → `"cota"`), ou seja **"Costas" nunca era reconhecida no mapa**. Corrigido para `RegExp(r'[\s_-]+')` no resolver.

### ⏳ PENDENTE — verificação de dados reais (utilizador)
- O utilizador vai confirmar no Firestore o conteúdo dos registos de teste (campos `fotos` e `fotosPorPosicao`).
- **Se a mensagem da app disser que falta uma foto que ele tem a certeza de ter enviado** → bug de leitura dos dados → pedir-lhe screenshot/texto do documento no Firestore e ajustar o mapeamento no resolver.
- Caso contrário (datas só com Frente, etc.) está correto: basta submeter avaliações com os 4 ângulos.

---

## 7. Estado do repositório / git

- **Branch:** `marcus` (PR para `main`). Houve conflitos históricos (já resolvidos) em `admin_panel_screen.dart`, `profile_screen.dart`, `image_comparison_slider.dart`, `pubspec.*`, `.flutter-plugins-dependencies`.
- **Ficheiros modificados (sem commit):**
  - `lib/core/config/app_constants.dart` (path de upload `.jpg` → `.png`)
  - `lib/data/models/progress_model.dart`
  - `lib/data/repositories/progress_repository.dart`
  - `lib/features/aluno/perfil/screens/profile_screen.dart` (comparação de progresso — ver secções 5/6)
  - `lib/features/aluno/perfil/screens/progress_submission_screen.dart`
  - `lib/shared/widgets/image_comparison_slider.dart`
  - `test/unit/progress_model_test.dart`
- **Ficheiros novos (untracked):**
  - `CONTEXTO.md` (este ficheiro, na raiz do workspace)
  - `lib/core/utils/progress_photo_normalizer.dart`
  - `lib/core/utils/progress_photo_resolver.dart`          <-- NOVO 2026-08-08
  - `test/unit/progress_photo_normalizer_test.dart`
  - `test/unit/progress_photo_resolver_test.dart`          <-- NOVO 2026-08-08
- **Sem conflitos de merge em aberto** (`git diff --name-only --diff-filter=U` vazio).

---

## 8. Testes e validação

- Testes: `test/unit/` (core, models, validators, normalizer, **resolver**) e `test/widget/` (admin_panel, aluno_screens, login_screen, image_comparison_slider, test_helpers).
- Comandos usados na validação:
  - `dart format <files>`
  - `git diff --check`
  - `flutter test` (suite completa)
  - `flutter analyze --no-fatal-infos`
- Estado em 2026-08-08: **177/177 testes passam** (inclui 13 do resolver: cenários a–d do handoff anterior + extras); `git diff --check` OK; analyzer com **183 issues** — todos pré-existentes (a sessão reduziu de 185 para 183), ex.: métodos não usados `_buildWeightChart`, `_buildProgressPhotos`, `_changeProfilePhoto`, `_addProgressPhoto` em `profile_screen.dart` (podem ser removidos numa limpeza futura — são pré-existentes).

---

## 9. Regras importantes (do cliente)

- **Não alterar a paleta de cores** — só os detalhes a rosa; o resto neutro.
- **Não alterar lógica/regras de negócio/estrutura de dados** — só UI/UX.
- UI minimalista, moderna, consistente entre Admin e Aluno (uniformizar componentes).
- Modais bonitos, responsivos e minimalistas.
- Animações suaves em todo o site (fade in/out, modais, navegação) — mas sem travar a app.
- Chat: lista de conversas → clicar para entrar; gravação de áudio a ocupar toda a largura do footer; anexos.
- Ao entregar alterações: testar (flutter test + analyze) e não deixar conflitos.
