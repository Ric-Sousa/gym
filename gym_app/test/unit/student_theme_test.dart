import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/core/config/app_colors.dart';
import 'package:gym_app/core/config/student_theme.dart';

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
