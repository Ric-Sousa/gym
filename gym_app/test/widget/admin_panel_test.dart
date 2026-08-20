import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gym_app/data/models/user_model.dart';
import 'package:gym_app/data/models/booking_model.dart';
import 'package:gym_app/data/models/food_model.dart';
import 'package:gym_app/data/models/questionnaire_config_model.dart';
import 'package:gym_app/features/auth/providers/auth_provider.dart';
import 'package:gym_app/features/admin/screens/admin_panel_screen.dart';
import 'package:gym_app/shared/providers/global_providers.dart';
import 'package:gym_app/shared/providers/admin_providers.dart';
import 'package:gym_app/core/services/fcm_service.dart';

import 'test_helpers.dart';

class MockFCMService extends Mock implements FCMService {}

void main() {
  late MockFCMService mockFcm;

  setUp(() async {
    await initLocaleForTests();
    mockFcm = MockFCMService();
    registerFallbackValue('');
    when(() => mockFcm.initialize(any())).thenAnswer((_) async {});
    when(() => mockFcm.removeToken()).thenAnswer((_) async {});
    when(() => mockFcm.dispose()).thenReturn(null);
  });

  Future<void> _pumpLargeAdmin(
    WidgetTester tester, {
    Size viewport = const Size(4800, 3600),
    AdminPagedList<FoodModel>? foodsPager,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final trainerId = adminAuthState.user!.uid;
    await tester.pumpWidget(
      createTestApp(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(adminAuthState)),
          fcmServiceProvider.overrideWith((ref) => mockFcm),
          alunosListProvider.overrideWith((ref) => Stream.value(<UserModel>[])),
          adminDashboardStatsProvider.overrideWith(
            (ref) => Stream.value(
              const AdminDashboardStats(
                totalAlunos: 0,
                activeAlunos: 0,
                sessoesMes: 0,
                sessoesTotal: 0,
              ),
            ),
          ),
          adminTrainerBookingsProvider(
            trainerId,
          ).overrideWith((ref) => Stream.value(<BookingModel>[])),
          adminStudentNamesProvider(
            trainerId,
          ).overrideWith((ref) => Stream.value(<String, String>{})),
          questionnaireConfigProvider.overrideWith(
            (ref) => Stream.value(QuestionnaireConfig.defaultConfig()),
          ),
          if (foodsPager != null)
            adminFoodsPagerProvider.overrideWith((ref) => foodsPager),
        ],
        child: const AdminPanelScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> _pumpMobileAdmin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final trainerId = adminAuthState.user!.uid;
    await tester.pumpWidget(
      createTestApp(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(adminAuthState)),
          fcmServiceProvider.overrideWith((ref) => mockFcm),
          alunosListProvider.overrideWith((ref) => Stream.value(<UserModel>[])),
          adminDashboardStatsProvider.overrideWith(
            (ref) => Stream.value(
              const AdminDashboardStats(
                totalAlunos: 0,
                activeAlunos: 0,
                sessoesMes: 0,
                sessoesTotal: 0,
              ),
            ),
          ),
          adminTrainerBookingsProvider(
            trainerId,
          ).overrideWith((ref) => Stream.value(<BookingModel>[])),
          adminStudentNamesProvider(
            trainerId,
          ).overrideWith((ref) => Stream.value(<String, String>{})),
          questionnaireConfigProvider.overrideWith(
            (ref) => Stream.value(QuestionnaireConfig.defaultConfig()),
          ),
        ],
        child: const AdminPanelScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AdminPanelScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await _pumpLargeAdmin(tester);
      expect(find.text('GYMBT'), findsOneWidget);
    });

    testWidgets('renders sidebar with navigation items', (tester) async {
      await _pumpLargeAdmin(tester);
      expect(find.text('GESTÃO'), findsOneWidget);
      expect(find.text('Clientes'), findsOneWidget);
      expect(find.text('Exercícios'), findsOneWidget);
      expect(find.text('Alimentos'), findsOneWidget);
      expect(find.text('Sair'), findsOneWidget);
    });

    testWidgets('renders fitness icon in sidebar logo', (tester) async {
      await _pumpLargeAdmin(tester);
      expect(find.byIcon(Icons.fitness_center), findsWidgets);
    });

    testWidgets('renders theme toggle button', (tester) async {
      await _pumpLargeAdmin(tester);
      expect(find.byType(IconButton), findsWidgets);
    });

    testWidgets('renders Dashboard view by default', (tester) async {
      await _pumpLargeAdmin(tester);
      expect(find.textContaining('DASHBOARD'), findsWidgets);
    });

    testWidgets('sidebar shows logout icon', (tester) async {
      await _pumpLargeAdmin(tester);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    // ─── Agenda Tests ──────────────────────────────────────

    testWidgets('dashboard renders AGENDA DA SEMANA card title', (
      tester,
    ) async {
      await _pumpLargeAdmin(tester);
      expect(find.text('AGENDA DA SEMANA'), findsOneWidget);
    });

    testWidgets('sidebar has Agenda navigation item', (tester) async {
      await _pumpLargeAdmin(tester);
      expect(find.text('Agenda'), findsOneWidget);
    });

    testWidgets('fonte longa do alimento não provoca overflow no cartão', (
      tester,
    ) async {
      const source =
          'Fonte: Base de Dados da Composição de Alimentos. Instituto Nacional de Saúde Doutor Ricardo Jorge, I. P. - INSA. v7.1 - 2026';
      final foodsPager = AdminPagedList<FoodModel>(
        loadPage: (_, __) async => const FirestorePage<FoodModel>(
          items: [
            FoodModel(
              id: 'insa_v71_test',
              nome: 'Abacate, Hass',
              caloriasPor100g: 176,
              proteinasPor100g: 1.1,
              hidratosPor100g: 2.3,
              gordurasPor100g: 17.4,
              categoria: 'fruta',
              origem: source,
            ),
          ],
          cursor: null,
          hasMore: false,
        ),
      );
      await foodsPager.loadMore();

      await _pumpLargeAdmin(
        tester,
        viewport: const Size(1500, 900),
        foodsPager: foodsPager,
      );
      await tester.tap(find.text('Alimentos'));
      await tester.pumpAndSettle();

      final sourceText = tester.widget<Text>(find.text(source));
      expect(sourceText.maxLines, 1);
      expect(sourceText.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('navigating to Agenda view renders AGENDA title', (
      tester,
    ) async {
      await _pumpLargeAdmin(tester);
      // Tocar no item Agenda da sidebar
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      // A view de agenda deve mostrar o título 'AGENDA'
      expect(find.text('AGENDA'), findsWidgets);
    });

    testWidgets('agenda apresenta horários das 06:00 às 23:00', (
      tester,
    ) async {
      await _pumpLargeAdmin(tester);
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();

      expect(find.text('06:00'), findsOneWidget);
      expect(find.text('23:00'), findsOneWidget);
      expect(find.byType(Scrollbar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile drawer and Agenda fit a 320px viewport', (
      tester,
    ) async {
      await _pumpMobileAdmin(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Agenda'), findsOneWidget);
      await tester.ensureVisible(find.text('Agenda'));

      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();

      expect(find.text('Agenda'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fecha o modal de tópico com ESC sem usar estado destruído', (
      tester,
    ) async {
      await _pumpLargeAdmin(tester);

      await tester.tap(find.text('Questionário'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Novo tópico'));
      await tester.pumpAndSettle();

      expect(find.text('Novo tópico'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('editor de menu adiciona opções e permite pré-visualizar uma escolha', (
      tester,
    ) async {
      await _pumpLargeAdmin(tester);

      await tester.tap(find.text('Questionário'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar pergunta').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Texto livre'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Menu com opções').last);
      await tester.pumpAndSettle();

      expect(find.text('Opção 1'), findsOneWidget);
      expect(find.text('Pré-visualização para o aluno'), findsOneWidget);

      await tester.tap(find.text('Adicionar opção'));
      await tester.pumpAndSettle();
      expect(find.text('Opção 2'), findsOneWidget);

      final optionFields = find.byType(TextFormField);
      await tester.enterText(optionFields.at(1), 'Sim');
      await tester.enterText(optionFields.at(2), 'Não');
      await tester.pumpAndSettle();

      final menus = find.byKey(const ValueKey('admin-question-preview-menu'));
      await tester.tap(menus);
      await tester.pumpAndSettle();
      expect(find.text('Sim'), findsWidgets);
      await tester.tap(find.text('Sim').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
