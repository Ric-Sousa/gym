import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/features/auth/providers/auth_provider.dart';
import 'package:gym_app/features/aluno/perfil/screens/profile_screen.dart';
import 'package:gym_app/shared/widgets/focused_text_field.dart';
import 'package:gym_app/core/config/app_colors.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('campo do aluno fica cinza quando recebe foco', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: FocusedTextField(
            key: const ValueKey('student-focused-field'),
            focusedFillColor: AppColors.surfaceHighest,
            decoration: const InputDecoration(labelText: 'Campo'),
          ),
        ),
      ),
    );

    final decoratorFinder = find.byType(InputDecorator);
    final before = tester.widget<InputDecorator>(decoratorFinder);
    expect(before.isFocused, isFalse);
    expect(
      (before.decoration as InputDecoration).fillColor,
      isNot(AppColors.surfaceHighest),
    );

    await tester.tap(find.byKey(const ValueKey('student-focused-field')));
    await tester.pumpAndSettle();

    final after = tester.widget<InputDecorator>(decoratorFinder);
    expect(after.isFocused, isTrue);
    expect(
      (after.decoration as InputDecoration).fillColor,
      AppColors.surfaceHighest,
    );
  });

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
      final totalWidgets = find
          .byWidgetPredicate((_) => true)
          .evaluate()
          .length;
      expect(
        totalWidgets,
        greaterThan(5),
        reason: 'Profile screen should render multiple widgets',
      );
    });

    testWidgets('perfil não cria overflow horizontal em 320px', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapProfile());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
