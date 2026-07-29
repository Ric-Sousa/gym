import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gym_app/data/models/user_model.dart';
import 'package:gym_app/data/models/booking_model.dart';
import 'package:gym_app/features/auth/providers/auth_provider.dart';
import 'package:gym_app/features/admin/screens/admin_panel_screen.dart';
import 'package:gym_app/shared/providers/global_providers.dart';
import 'package:gym_app/shared/providers/admin_providers.dart';
import 'package:gym_app/core/services/fcm_service.dart';

import 'test_helpers.dart';

/// Mock do FCMService — evita dependência do Firebase nos testes.
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

  /// Configura viewport grande e providers mockados para o admin panel.
  Future<void> _pumpLargeAdmin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(4800, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestApp(
      overrides: [
        authProvider.overrideWith((ref) => MockAuthNotifier(adminAuthState)),
        fcmServiceProvider.overrideWith((ref) => mockFcm),
        alunosListProvider.overrideWith(
          (ref) => Future.value(<UserModel>[]),
        ),
        adminDashboardStatsProvider.overrideWith(
          (ref) => Future.value(
            const AdminDashboardStats(
              totalAlunos: 0,
              activeAlunos: 0,
              sessoesMes: 0,
              sessoesTotal: 0,
            ),
          ),
        ),
        // O _agendaCard() usa adminTrainerBookingsProvider(trainerId) via authProvider
        adminTrainerBookingsProvider('test-admin-123').overrideWith(
          (ref) => Future.value(<BookingModel>[]),
        ),
      ],
      child: const AdminPanelScreen(),
    ));
    await tester.pump();
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
  });
}
