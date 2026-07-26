import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/features/auth/providers/auth_provider.dart';
import 'package:gym_app/features/admin/screens/admin_panel_screen.dart';

import 'test_helpers.dart';

void main() {
  setUp(() async {
    await initLocaleForTests();
  });

  /// Configura viewport grande para evitar layout overflow no admin panel.
  Future<void> _pumpLargeAdmin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(4800, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestApp(
      overrides: [
        authProvider.overrideWith((ref) => MockAuthNotifier(adminAuthState)),
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
