import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/core/config/app_strings.dart';
import 'package:gym_app/data/models/diary_model.dart';
import 'package:gym_app/data/models/food_model.dart';
import 'package:gym_app/data/models/nutrition_plan_model.dart';
import 'package:gym_app/features/aluno/nutricao/screens/nutrition_screen.dart';
import 'package:gym_app/features/auth/providers/auth_provider.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('remove por swipe apenas o alimento adicionado pelo aluno', (
    tester,
  ) async {
    await initLocaleForTests();
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final userId = alunoAuthState.user!.uid;
    final diaSemana = AppStrings.daysOfWeek[DateTime.now().weekday - 1];
    const alimentoDoAdmin = Alimento(
      nome: 'Arroz definido pelo admin',
      quantidade: '100g',
      calorias: 130,
    );
    final plano = NutritionPlanModel(
      dia: diaSemana,
      userId: userId,
      metaCalorias: 2000,
      refeicoes: const [
        PlannedMeal(tipo: 'Almoço', alimentos: [alimentoDoAdmin]),
      ],
    );
    const alimentoParaAdicionar = FoodModel(
      id: 'food-aluno-test',
      nome: 'Banana adicionada pelo aluno',
      caloriasPor100g: 89,
      proteinasPor100g: 1.1,
      hidratosPor100g: 22.8,
      gordurasPor100g: 0.3,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(alunoAuthState)),
          nutritionPlanProvider((
            userId,
            diaSemana,
          )).overrideWith((ref) => Stream.value(plano)),
          todayConsumedCaloriesProvider(
            userId,
          ).overrideWith((ref) => Stream.value(0.0)),
          todayCompletedMealTypesProvider(
            userId,
          ).overrideWith((ref) => Stream.value(<String>{})),
          todayDiaryProvider(
            userId,
          ).overrideWith((ref) => Stream<DiaryModel?>.value(null)),
          foodSearchProvider('').overrideWith(
            (ref) => Future.value(<FoodModel>[alimentoParaAdicionar]),
          ),
        ],
        child: const MaterialApp(home: NutritionScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(alimentoDoAdmin.nome), findsOneWidget);
    expect(find.byType(Dismissible), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Adicionar alimento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(alimentoParaAdicionar.nome));
    await tester.pumpAndSettle();

    expect(find.text(alimentoParaAdicionar.nome), findsOneWidget);
    expect(find.byType(Dismissible), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Eliminar alimento?'), findsOneWidget);
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(find.text(alimentoParaAdicionar.nome), findsNothing);
    expect(find.text(alimentoDoAdmin.nome), findsOneWidget);
    expect(find.byType(Dismissible), findsNothing);
  });
}
