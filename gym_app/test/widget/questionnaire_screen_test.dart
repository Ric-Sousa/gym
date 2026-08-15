import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('Continuar'), findsOneWidget);
  });
}
