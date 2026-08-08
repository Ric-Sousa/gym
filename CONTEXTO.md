# CONTEXTO DO PROJETO — Handoff para continuar o trabalho

> Documento criado para entregar a outra IA e continuar o desenvolvimento sem perder contexto.
> Lê tudo antes de mexer no código. Não alteres a paleta de cores nem a lógica de negócio.

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
    utils/           -> connectivity_service.dart, validators.dart, progress_photo_normalizer.dart
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
4. **Perfil do aluno** (`profile_screen.dart`):
   - Card fixo **"Comparação de progresso"** com:
     - Dropdowns "Data inicial" / "Data final".
     - Botões de ângulo: **Frente, Costas, Lado 1, Lado 2** (ordem visual `_progressAngles`).
     - `ImageComparisonSlider` (slider com divisor) mostrando em tempo real a diferença.
   - Botões de ângulo só ficam ativos se **ambas** as datas tiverem foto naquela posição.
   - Comparador sempre visível, sem botão "Comparar Progresso" (removido a pedido).

### Modelo (`lib/data/models/progress_model.dart`)
- Campos: `id`, `userId`, `data`, `peso`, `medidas` (Map), `fotos` (List<String>), `fotosPorPosicao` (Map<String,String>).
- `fromMap`/`toMap` já leem/escrevem `fotosPorPosicao`.

---

## 6. ÚLTIMA ALTERAÇÃO (comparação de progresso) — E O BUG ATUAL

### O que foi feito
Em `profile_screen.dart`, foram adicionados métodos para resolver a foto de cada ângulo:

- `_photoAt(progress, angleIndex)` — prioriza `fotosPorPosicao`; só usa fallback da lista `fotos` se for seguro.
- `_explicitPhotoAt(...)` — procura no mapa de forma **normalizada** (aceita `frente`, `Frente`, `costas`, `lado1`, `lado-1`, `Lado 2`, etc. via `_normalizePositionKey`).
- `_hasRecognizedPositionPhoto(...)` — verifica se existe pelo menos uma posição reconhecida preenchida no mapa.
- `_hasAnyProgressPhoto(...)` — inclui fotos que existem só no mapa.
- `_legacyPhotoIndex(angleIndex, photoCount)` — **apenas devolve índice quando `photoCount >= 4`** (ordem antiga Frente, Lado 1, Lado 2, Costas → `[0, 3, 1, 2]`). Para listas de 1–3 fotos devolve `null` (para não "adivinhar" posições).
- Regra: se a lista `fotos` tiver < 4 elementos E o mapa tiver posição reconhecida → não faz fallback (evita trocar Lado por Costas).

### ⚠️ BUG ATUAL (reportado pelo utilizador após esta alteração)
- **Sintoma:** no perfil, a comparação de progresso mostra: **"As fotos selecionadas não estão disponíveis para comparação."** e **não aparece nenhum botão para voltar/corrigir**.
- **Onde ocorre:** `_buildProgressComparisonCard` → quando `!hasComparison && (beforeImage == null || afterImage == null)` → `_buildProgressComparisonState(...)` que mostra apenas ícone + mensagem (sem ação).
- **Causa provável nº 1 (a mais provável):** registos **antigos** de progresso têm apenas 2–3 fotos na lista `fotos` (sem `fotosPorPosicao`). Com a nova regra `_legacyPhotoIndex` devolve `null` para < 4 fotos → **nenhum ângulo resolve** → todas as datas dão erro. Ou seja: a comparação deixa de funcionar para o histórico já existente.
- **Causa provável nº 2:** registos com `fotosPorPosicao` parcial (ex.: só Frente) e datas escolhidas que não partilham esse ângulo explícito → fallback bloqueado pela regra do mapa parcial → erro.
- **Falta de ação no estado de erro:** `_buildProgressComparisonState` não tem botão; o utilizador fica preso na mensagem.

### Sugestão de correção para a próxima IA (ainda NÃO aplicada)
1. **Restaurar fallback seguro para registos antigos** com 1–3 fotos, respeitando a ordem antiga conhecida do formulário (ex.: 2 fotos → Frente, Lado 1; 3 fotos → Frente, Lado 1, Costas...). Atenção à ambiguidade Costas vs Lado — validar com o utilizador ou desativar apenas o ângulo duvidoso.
2. **Permitir sair do estado de erro:** adicionar botões de ação no `_buildProgressComparisonState` (ex.: "Escolher outras datas" / reset para primeira+última) para nunca deixar o utilizador preso.
3. Considerar mostrar o comparador mesmo que só uma posição exista (fallback "todas as fotos" sem botões de ângulo desativados).
4. **Testar** com dados: (a) 2 fotos antigas sem mapa, (b) 3 fotos antigas, (c) 4 slots novos com mapa completo, (d) mapa parcial + lista de 4.

---

## 7. Estado do repositório / git

- **Branch:** `marcus` (PR para `main`). Houve conflitos históricos (já resolvidos) em `admin_panel_screen.dart`, `profile_screen.dart`, `image_comparison_slider.dart`, `pubspec.*`, `.flutter-plugins-dependencies`.
- **Ficheiros modificados nesta sessão (sem commit):**
  - `lib/core/config/app_constants.dart`
  - `lib/data/models/progress_model.dart`
  - `lib/data/repositories/progress_repository.dart`
  - `lib/features/aluno/perfil/screens/profile_screen.dart`
  - `lib/features/aluno/perfil/screens/progress_submission_screen.dart`
  - `lib/shared/widgets/image_comparison_slider.dart`
  - `test/unit/progress_model_test.dart`
- **Ficheiros novos (untracked):**
  - `lib/core/utils/progress_photo_normalizer.dart`
  - `test/unit/progress_photo_normalizer_test.dart`
- **Sem conflitos de merge em aberto** (`git diff --name-only --diff-filter=U` vazio).

---

## 8. Testes e validação

- Testes existentes: `test/unit/` (core, models, validators, normalizer) e `test/widget/` (admin_panel, aluno_screens, login_screen, image_comparison_slider, test_helpers).
- Comandos usados na validação:
  - `dart format <files>`
  - `git diff --check`
  - `flutter test test/unit/progress_model_test.dart test/unit/progress_photo_normalizer_test.dart test/widget/image_comparison_slider_test.dart test/widget/aluno_screens_test.dart`
  - `flutter analyze --no-fatal-infos`
- Estado: 13 testes focados passam; `git diff --check` OK; analyzer tem 182 avisos/infos (maioria pré-existentes, ex.: métodos não usados `_buildWeightChart`, `_buildProgressPhotos`, `_changeProfilePhoto`, `_addProgressPhoto` — podiam ser removidos, mas são pré-existentes).

---

## 9. Regras importantes (do cliente)

- **Não alterar a paleta de cores** — só os detalhes a rosa; o resto neutro.
- **Não alterar lógica/regras de negócio/estrutura de dados** — só UI/UX.
- UI minimalista, moderna, consistente entre Admin e Aluno (uniformizar componentes).
- Modais bonitos, responsivos e minimalistas.
- Animações suaves em todo o site (fade in/out, modais, navegação) — mas sem travar a app.
- Chat: lista de conversas → clicar para entrar; gravação de áudio a ocupar toda a largura do footer; anexos.
- Ao entregar alterações: testar (flutter test + analyze) e não deixar conflitos.
