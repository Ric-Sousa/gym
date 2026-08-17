import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/core/config/admin_theme.dart';
import 'package:gym_app/core/config/app_colors.dart';
import 'package:gym_app/core/config/student_theme.dart';
import 'package:gym_app/shared/widgets/admin_design_system.dart';

void main() {
  group('StudentThemeColors', () {
    test('usa azul em alunos masculinos', () {
      final colors = StudentThemeColors.forGenero('masculino');

      expect(colors.primary, AppColors.malePrimary);
      expect(colors.primaryDim, AppColors.malePrimaryDim);
      expect(colors.primaryContainer, AppColors.malePrimaryContainer);
      expect(colors.primaryFixed, AppColors.malePrimaryFixed);
      expect(colors.primaryFixedDim, AppColors.malePrimaryFixedDim);
      expect(colors.primary, isNot(AppColors.femalePrimary));
    });

    test('usa rosa em alunos femininos', () {
      final colors = StudentThemeColors.forGenero('feminino');

      expect(colors.primary, AppColors.femalePrimary);
      expect(colors.primaryDim, AppColors.femalePrimaryDim);
      expect(colors.primaryContainer, AppColors.femalePrimaryContainer);
      expect(colors.primaryFixed, AppColors.femalePrimaryFixed);
      expect(colors.primaryFixedDim, AppColors.femalePrimaryFixedDim);
    });

    test('género desconhecido mantém o padrão feminino', () {
      expect(
        StudentThemeColors.forGenero(null).primary,
        AppColors.femalePrimary,
      );
      expect(
        StudentThemeColors.forGenero('outro').primary,
        AppColors.femalePrimary,
      );
    });
  });

  test('tema de workspace mantém ações de modal afastadas da borda', () {
    final theme = buildWorkspaceTheme(
      ThemeData.dark(useMaterial3: true),
      AdminThemeColors.dark,
    );

    expect(
      theme.dialogTheme.actionsPadding,
      const EdgeInsets.fromLTRB(24, 10, 24, 22),
    );
  });

  testWidgets('of(context) lê a extensão do tema atual', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [StudentThemeColors.forGenero('masculino')],
        ),
        home: Builder(
          builder: (context) => Text(
            StudentThemeColors.of(context).primary == AppColors.malePrimary
                ? 'azul'
                : 'rosa',
          ),
        ),
      ),
    );

    expect(find.text('azul'), findsOneWidget);
  });
}
