import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gym_app/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PersonalFitApp());
    expect(find.byType(PersonalFitApp), findsOneWidget);
  });
}
