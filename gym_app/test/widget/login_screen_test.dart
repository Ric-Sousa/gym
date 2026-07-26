import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/core/config/app_strings.dart';
import 'package:gym_app/features/auth/providers/auth_provider.dart';
import 'package:gym_app/features/auth/screens/login_screen.dart';

import 'test_helpers.dart';

Widget _wrapLogin(AuthState authState) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith((ref) => MockAuthNotifier(authState)),
    ],
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  group('LoginScreen', () {
    // ── Rendering ────────────────────────────────

    testWidgets('renders app name and tagline', (tester) async {
      await tester.pumpWidget(_wrapLogin(unauthenticatedState));
      await tester.pump();

      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.appTagline), findsOneWidget);
    });

    testWidgets('renders email and password text fields', (tester) async {
      await tester.pumpWidget(_wrapLogin(unauthenticatedState));
      await tester.pump();

      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('renders login button', (tester) async {
      await tester.pumpWidget(_wrapLogin(unauthenticatedState));
      await tester.pump();

      expect(find.text(AppStrings.login), findsOneWidget);
    });

    testWidgets('renders forgot password button', (tester) async {
      await tester.pumpWidget(_wrapLogin(unauthenticatedState));
      await tester.pump();

      expect(find.text(AppStrings.forgotPassword), findsOneWidget);
    });

    testWidgets('renders fitness icon/logo', (tester) async {
      await tester.pumpWidget(_wrapLogin(unauthenticatedState));
      await tester.pump();

      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
    });

    // ── Password Toggle ──────────────────────────

    testWidgets('password field toggles visibility', (tester) async {
      await tester.pumpWidget(_wrapLogin(unauthenticatedState));
      await tester.pump();

      // Should have visibility_off icon initially (password hidden)
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      // Tap to show password
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      // Should now show visibility icon (password visible)
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    // ── Form Validation ──────────────────────────

    testWidgets('shows email validation error on empty submit', (tester) async {
      await tester.pumpWidget(_wrapLogin(unauthenticatedState));
      await tester.pump();

      // Tap login without entering anything
      await tester.tap(find.text(AppStrings.login));
      await tester.pump();

      expect(find.textContaining('obrigatório'), findsWidgets);
    });

    testWidgets('shows email validation error for invalid email', (tester) async {
      await tester.pumpWidget(_wrapLogin(unauthenticatedState));
      await tester.pump();

      // Enter invalid email
      await tester.enterText(find.byType(TextFormField).first, 'invalid-email');
      await tester.tap(find.text(AppStrings.login));
      await tester.pump();

      expect(find.textContaining('inválido'), findsOneWidget);
    });

    testWidgets('shows password validation error for short password', (tester) async {
      await tester.pumpWidget(_wrapLogin(unauthenticatedState));
      await tester.pump();

      // Enter valid email but short password
      await tester.enterText(find.byType(TextFormField).first, 'joao@email.com');
      await tester.enterText(find.byType(TextFormField).last, '123');
      await tester.tap(find.text(AppStrings.login));
      await tester.pump();

      expect(find.textContaining('6 caracteres'), findsOneWidget);
    });

    // ── Error State ──────────────────────────────

    testWidgets('shows error message when auth state has error', (tester) async {
      await tester.pumpWidget(_wrapLogin(errorState));
      await tester.pump();

      expect(find.text('Email ou palavra-passe inválidos.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('does NOT show error icon when no error', (tester) async {
      await tester.pumpWidget(_wrapLogin(unauthenticatedState));
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    // ── Loading State ────────────────────────────

    testWidgets('shows loading indicator when authenticating', (tester) async {
      await tester.pumpWidget(_wrapLogin(loadingState));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
