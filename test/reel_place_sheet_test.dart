import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cityguide/controllers/places_controller.dart';
import 'package:cityguide/models/place.dart';
import 'package:cityguide/views/reels/widgets/reel_place_sheet.dart';

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        home: Scaffold(body: ReelPlaceSheet(placeId: 'p1')),
      ),
    );

void main() {
  testWidgets('affiche le nom et la description du lieu', (tester) async {
    // latitude/longitude à 0 => mini-carte masquée (pas de platform view en test)
    const place = Place(
      id: 'p1',
      categoryKey: 'restaurants',
      nom: 'Chez Ntemba',
      description: 'Le meilleur poulet de la Gombe.',
      rating: 4.5,
    );
    final c = ProviderContainer(overrides: [
      reelPlaceProvider('p1').overrideWith((ref) async => place),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.text('Chez Ntemba'), findsOneWidget);
    expect(find.textContaining('poulet'), findsOneWidget);
    expect(find.text("S'y rendre"), findsOneWidget);
    expect(find.text('Voir la fiche complète'), findsOneWidget);
  });

  testWidgets('lieu introuvable => message dédié', (tester) async {
    final c = ProviderContainer(overrides: [
      reelPlaceProvider('p1').overrideWith((ref) async => null),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.text('Lieu indisponible'), findsOneWidget);
  });
}
