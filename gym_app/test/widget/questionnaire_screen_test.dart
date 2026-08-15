import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/core/config/app_colors.dart';
import 'package:gym_app/data/models/user_model.dart';
import 'package:gym_app/features/auth/screens/questionnaire_screen.dart';

void main() {
  testWidgets('apresenta a ficha inicial antes do início', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuestionnaireScreen(
          user: UserModel(
            uid: 'student-1',
            nome: 'Aluno',
            email: 'aluno@example.com',
          ),
        ),
      ),
    );

    expect(find.text('Vamos conhecer-te melhor'), findsOneWidget);
    expect(find.textContaining('Antes de começares, responde a esta ficha rápida.'), findsOneWidget);
    expect(find.text('Data de nascimento'), findsOneWidget);
    expect(find.text('Qual é o teu sexo?'), findsWidgets);
    expect(find.text('Continuar'), findsOneWidget);

    final questionnaireTheme = Theme.of(
      tester.element(find.byType(Card)),
    );
    expect(questionnaireTheme.colorScheme.primary, AppColors.surfaceHighest);
    expect(
      questionnaireTheme.textSelectionTheme.cursorColor,
      Colors.white,
    );
    final firstInput = tester.widget<TextField>(find.byType(TextField).first);
    expect(firstInput.cursorColor, Colors.white);
  });

  testWidgets('mantém a ficha utilizável em 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: QuestionnaireScreen(
          user: UserModel(
            uid: 'student-mobile',
            nome: 'Aluno Mobile',
            email: 'mobile@example.com',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final card = tester.renderObject<RenderBox>(find.byType(Card));
    expect(card.size.width, lessThanOrEqualTo(320));
    expect(find.text('Vamos conhecer-te melhor'), findsOneWidget);
  });
}
