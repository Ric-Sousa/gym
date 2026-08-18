# CONTEXTO PARA OUTRA IA — Bug na aba "Clientes" (admin, desktop/web)

> Documento de handoff criado a pedido do utilizador para entregar a outra IA o
> contexto da conversa e do problema atual, sem perder nada do que já foi feito.
> Lê tudo antes de mexer no código. Não alteres a paleta de cores nem a lógica de negócio.
> Última atualização: **2026-08-18**.

---

## 1. Identificação do projeto

- **Projeto:** Aplicação de ginásio/personal trainer ("GYMBT") com área de **Aluno** e área de **Admin**.
- **Framework:** Flutter (Dart) — target principal **Web (Chrome)** + mobile (Android/iOS).
- **Caminho do projeto:** `gym_app/` (dentro do repositório git na raiz deste ficheiro).
- **Branch atual:** `main` (há também branch `marcus` referida em docs antigos).
- **Backend:** Firebase — Auth, Firestore, Storage, Cloud Functions, Messaging (FCM), Stripe (pagamentos).

### Dependências principais (gym_app/pubspec.yaml)
- Dart SDK `>=3.12.0 <4.0.0`, Flutter `>=3.44.0`.
- `flutter_riverpod` / `riverpod` v3 (estado/DI), `google_fonts`, `intl`, `fl_chart`,
  `image_picker`, `cloud_firestore`, `firebase_auth`, `cloud_functions`, `firebase_messaging`,
  `firebase_storage`, `firebase_crashlytics`.

---

## 2. Estrutura relevante (lib/)

```
lib/
  main.dart
  app.dart
  core/
    config/admin_theme.dart      -> AdminThemeColors (lime, surface, text, muted, danger, border, limeDim, surface2)
  data/
    models/  -> user_model.dart (fotoPerfil, nome, email, tipoCliente, isAccessAllowed, contractEndsAt),
                payment_model.dart (effectiveStatus, descricao, userId, data),
                booking_model.dart
  features/
    admin/
      screens/
        admin_panel_screen.dart        -> FICHEIRO GIGANTE (~12 400 linhas) — painel admin completo
        student_detail_screen.dart
        global_workout_plans_screen.dart
        questionnaire_management_screen.dart
      widgets/
        floating_chat_button.dart      -> botão flutuante do chat (~1 979 linhas)
        admin_messages_view.dart
  shared/
    widgets/
      app_design_system.dart           -> FadeSlideSwitcher (AnimatedSwitcher), AppPageFrame, AppPageIntro
      app_page_frame.dart
  test/
    widget/admin_panel_test.dart       -> testes do painel admin (13 testes)
```

**IMPORTANTE:** o ficheiro `admin_panel_screen.dart` é enorme. Usa sempre `grep`/pesquisa
antes de o ler por inteiro. As secções principais (linhas aproximadas na versão atual):

- `~1380` `class _AdminClientsList` — **a nova lista de clientes** (a que rebenta).
- `~9228` `class _AdminPaymentsView` — página de Pagamentos.
- `~10899` `class _AdminPaymentsCompactList` — lista compacta de pagamentos (filtro, pesquisa, paginação de 6).
- `~230` e `~279` `Stack(fit: StackFit.expand)` com `FadeSlideSwitcher` + `FloatingChatButton` (body mobile e desktop).

---

## 3. Resumo da conversa recente (trabalho já feito)

Tudo feito na secção **Admin** (e uma proteção no shell do aluno). Não foi alterada lógica de negócio.

1. **Dashboard — cards de métricas:** ficaram 2 lado a lado no mobile, compactos (~132px), e retangulares no desktop (como antes).
2. **Card "Agenda da semana":** cada marcação passou a ser um bloco separado com hora, aluno, data, modalidade e estado.
3. **Modal "Escolher aluno"** (planos de treino): novo layout com fotografia quando disponível (inicial só como fallback), pesquisa e cartões.
4. **Botão flutuante do chat:** fixo ao viewport (não acompanha o scroll), 48px no mobile, arrastável no mobile, fixo no desktop.
5. **Secção Pagamentos:** reescrita — resumo no topo, pesquisa, filtro por estado, lista compacta com paginação (6 por página), dropdown no estilo do questionário ("Vamos conhecer-te melhor", `MenuAnchor`). Depois de várias iterações o utilizador escolheu **lista compacta diretamente na página** (sem modal sobreposto).
6. **Alinhamento ao topo:** corrigido espaço vazio vertical quando a página tem pouco conteúdo — todas as views do admin ficam alinhadas ao topo (`Align(alignment: Alignment.topCenter)` + `StackFit.expand` no body), e o mesmo foi aplicado ao shell do aluno (`lib/app.dart`).
7. **Secção Clientes — novo layout:** cartões modernos com fotografia, estado (Ativo/Bloqueado), tipo (Online/Presencial), fim de contrato, pesquisa renovada, filtros, responsivo (1/2/3 cartões conforme largura). Removido o alternador antigo Lista/Cartões.

### Alterações recentes no git (não commitadas)
O `admin_panel_screen.dart` tem uma alteração enorme (≈4 273 linhas de diff) e o
`floating_chat_button.dart` também (≈344). Isto inclui todo o trabalho acima **e** muito
código antigo que ficou por limpar (ex.: `_buildClientsToolbar` antiga, `_viewMode = 'list'`,
`_buildPaymentsLauncher`/`_showPaymentsModal` antigos podem ainda existir sem uso).

---

## 4. PROBLEMA ATUAL (a resolver)

**Sintoma do utilizador:**
> "Me dá estes erros: [logs abaixo] e quando eu tento abrir a aba **Clientes** no
> desktop não funciona."

- A aba **Clientes** no desktop (web) **não abre / rebenta** — provável ecrã em branco ou congelado.
- Na consola do browser aparecem erros repetidos de layout/hit-testing, mesmo noutras secções (a imagem mostra a página de **Pagamentos** com os erros na consola).
- No mobile a aba parece funcionar (o problema é especificamente **desktop/web**).

### Logs de erro (console do browser)

Erro principal, repetido dezenas de vezes:

```
_error_dumper_web.dart:15 Another exception was thrown: Assertion failed:
file:///C:/Flutter/flutter/packages/flutter/lib/src/rendering/box.dart:2251:12
```

E depois:

```
_error_dumper_web.dart:15 Another exception was thrown: Cannot hit test a render box with no size.
```

A stack trace (compilação web minificada — `text_form_field_row.dart.lib.js` é o nome
minificado de um ficheiro com `TextField`/formulário) mostra:

- `handleTapDown` -> `_startNewSplash` -> `setState` (splash de um botão/card)
- `markNeedsBuild` -> layout -> `performLayout` repetido numa cadeia de widgets
- `RenderFlex` (Column/Row) -> `layoutChild` -> `_computeSize(s)` -> **assertion em box.dart:2251**
- Na fase de pintura: `Cannot hit test a render box with no size`

**Interpretação provável:** durante a layout de um `RenderFlex` (provavelmente dentro de um
cartão ou da toolbar de pesquisa com `TextField`), um filho não foi dimensionado
(`_size == null`, "RenderBox was not laid out") e é depois hit-testado sem tamanho.
Isto costuma acontecer quando um widget é colocado num `Stack`/`Align`/`FadeSlideSwitcher`
sem restrições de tamanho corretas, ou quando um `Positioned`/`SizedBox` com largura
calculada fica com tamanho zero/inválido durante uma transição.

---

## 5. Pontos de código relevantes para o bug

### 5.1. Body do painel (mobile e desktop) — `admin_panel_screen.dart`

Ambos os `Scaffold` (mobile ~linha 230 e desktop ~linha 279) têm:

```dart
body: Stack(
  fit: StackFit.expand,
  children: [
    _selectedClient != null
        ? _ClientDetailView(...)
        : Align(
            alignment: Alignment.topCenter,
            child: FadeSlideSwitcher(
              child: KeyedSubtree(
                key: ValueKey('admin_view_${_view.name}'),
                child: _buildView(),
              ),
            ),
          ),
    FloatingChatButton(...),
  ],
),
```

- `_buildView()` devolve, para `AdminView.clients`, `_AdminClientsList(onSelect: ...)`.
- `FadeSlideSwitcher` = `AnimatedSwitcher` com `FadeTransition` + `SlideTransition`.
- `FloatingChatButton` devolve **`Positioned.fill`** com um `LayoutBuilder` lá dentro (ver 5.3).

### 5.2. Nova lista de clientes — `admin_panel_screen.dart` (~linha 1380)

```dart
class _AdminClientsList extends ConsumerStatefulWidget { ... }

class _AdminClientsListState extends ConsumerState<_AdminClientsList> {
  String _search = '';
  String _filter = 'all';
  String _viewMode = 'list';   // <- antigo, já não é usado (código morto)

  Widget build(...) {
    final alunosAsync = ref.watch(alunosSearchProvider(_search));
    return SingleChildScrollView(
      padding: ...,
      child: Column(
        children: [
          Row(... titulo "Clientes" + _newClientButton(compact: true) no desktop ...),
          _buildNewClientsToolbar(isMobile, colors),   // pesquisa + filtro PopupMenu
          alunosAsync.when(
            data: (alunos) => _buildNewClientDirectory(alunos, colors),  // LayoutBuilder + Wrap
            ...
          ),
        ],
      ),
    );
  }
```

`_buildNewClientDirectory` usa:

```dart
return LayoutBuilder(
  builder: (context, constraints) {
    final columns = constraints.maxWidth >= 1050 ? 3 : (constraints.maxWidth >= 650 ? 2 : 1);
    final gap = 12.0;
    final cardWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: filtered.map((aluno) => SizedBox(width: cardWidth, child: _newClientCard(aluno))).toList(),
    );
  },
);
```

- `_newClientCard(aluno)` usa `CircleAvatar` com `NetworkImage(photo!)` quando há `fotoPerfil`,
  e `PopupMenuButton` para eliminar.
- Existe também `_buildClientsToolbar` antiga (~linha 1827) e `_viewMode` como código morto — candidatos a limpeza, mas não são a causa.

### 5.3. Botão flutuante do chat — `floating_chat_button.dart` (~linha 187)

```dart
return Positioned.fill(
  child: LayoutBuilder(
    builder: (context, constraints) {
      final maxRight = (constraints.maxWidth - buttonSize - 8).clamp(8.0, double.infinity).toDouble();
      final maxBottom = (constraints.maxHeight - buttonSize - 8).clamp(8.0, double.infinity).toDouble();
      ...
    },
  ),
);
```

- `buttonSize` = 48 (compacto/<600px) ou 60.
- Está dentro do `Stack(fit: StackFit.expand)` do painel. **Suspeito:** se em algum estado o
  `Stack` não tiver restrições concretas (ex.: durante `AnimatedSwitcher`), o `Positioned.fill`
  pode ficar com tamanho indefinido.

### 5.4. FadeSlideSwitcher — `shared/widgets/app_design_system.dart` (~linha 389)

`AnimatedSwitcher` com duração 220ms; ambos os filhos (a sair e a entrar) existem na árvore
durante a transição — é um local clássico para "render box with no size" se um dos filhos
não for dimensionado no meio da animação.

---

## 6. Hipóteses para investigar (por ordem de probabilidade)

1. **`FloatingChatButton` + `Stack(fit: StackFit.expand)`:** o `Positioned.fill` exige que o
   Stack tenha tamanho finito. Se o `AnimatedSwitcher`/`FadeSlideSwitcher` ou o `Align` deixar
   o Stack com restrições não finitas (ou o LayoutBuilder devolver valores infinitos quando o
   widget ainda não tem constraints), gera "render box with no size". Verificar se o problema
   desaparece ao remover/condicionar o `FloatingChatButton` na view de Clientes (desktop).
2. **`_AdminClientsList` (nova):** o `LayoutBuilder` + `Wrap` dentro do `SingleChildScrollView`
   (altura infinita) está OK, mas confirmar que `cardWidth` nunca fica <= 0. Também verificar
   o `CircleAvatar` com `NetworkImage` (erro de imagem não deve rebentar layout, mas vale confirmar).
3. **`FadeSlideSwitcher`/`AnimatedSwitcher`:** durante a transição para Clientes, o cartão de
   pagamentos (ou a página anterior) a sair pode ficar com 0×0 e ser hit-testado.
4. **Código morto antigo** (`_buildClientsToolbar`, `_viewMode`, `_showPaymentsModal`,
   `_buildPaymentsLauncher`): não causa o crash, mas dificulta a leitura — remover depois do fix.
5. Possível relação com a alteração "alinhar ao topo" (`Align(topCenter)` + `StackFit.expand`)
   feita na mesma sessão — testar reverter só esse wrapper para confirmar.

---

## 7. O que já foi tentado / verificado

- `flutter test test/widget/admin_panel_test.dart` — **13/13 passam** (testes não apanham o bug visual).
- `flutter analyze` — sem erros de compilação; apenas avisos de lint pré-existentes.
- O bug só aparece em runtime no **web/desktop** (não é apanhado por testes de widget).

---

## 8. Como reproduzir / validar

1. Correr a app web: `cd gym_app && flutter run -d chrome` (ou `flutter build web` e servir).
2. Fazer login como admin.
3. No desktop, clicar em **Clientes** na sidebar -> observar ecrã em branco + erros na consola.
4. Para validar um fix: repetir o passo 3 e confirmar que a lista abre sem erros na consola;
   correr depois `flutter test test/widget/admin_panel_test.dart`.

---

## 9. Pedido final ao utilizador

O utilizador pediu **este ficheiro de contexto** para enviar a outra IA. O ficheiro pode ser
enviado tal como está, ou resumido para: *"App Flutter web; aba Clientes do painel admin não
abre no desktop; erro 'RenderBox was not laid out' (box.dart:2251) + 'Cannot hit test a render
box with no size' repetidos; suspeita no Stack(fit: expand) + Positioned.fill do FloatingChatButton
ou no FadeSlideSwitcher durante a transição para a nova lista de Clientes."*
