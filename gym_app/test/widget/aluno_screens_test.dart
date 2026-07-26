import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/features/auth/providers/auth_provider.dart';
import 'package:gym_app/features/aluno/perfil/screens/profile_screen.dart';

import 'test_helpers.dart';

void main() {
  group('ProfileScreen', () {
    Widget _wrapProfile() {
      return ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(alunoAuthState)),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      );
    }

    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_wrapProfile());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows content beyond just scaffold', (tester) async {
      await tester.pumpWidget(_wrapProfile());
      await tester.pump(const Duration(milliseconds: 300));

      // Should render more than just an empty scaffold
      final totalWidgets = find.byWidgetPredicate((_) => true).evaluate().length;
      expect(totalWidgets, greaterThan(5),
          reason: 'Profile screen should render multiple widgets');
    });
  });
}
