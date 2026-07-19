// Test de fumée basique : vérifie que le SplashScreen se construit sans erreur.
// (CityGuideApp complet nécessite Firebase, non disponible en test widget.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cityguide/main.dart';

void main() {
  testWidgets('SplashScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
