import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prix_vif/screens/dashboard_screen.dart';
import 'package:prix_vif/models.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  testWidgets('DashboardScreen renders without crashing', (WidgetTester tester) async {
    final sessions = ScanSession.demoSessions;
    await tester.pumpWidget(MaterialApp(
      home: DashboardScreen(
        sessions: sessions,
        onSessionSelected: (_) {},
      ),
    ));
    expect(find.byKey(const ValueKey('dashboard_scaffold')), findsOneWidget);
  });

  testWidgets('Dashboard affiche la comparaison par type de produit', (WidgetTester tester) async {
    final now = DateTime.now();
    final sessions = [
      ScanSession(
        id: 'type_test_1',
        date: now,
        type: 'barcode',
        items: [
          ScannedItem(
            id: 'a1',
            name: 'Lait Demi-Ecreme',
            brand: 'Candia',
            price: 1.50,
            scanDate: now,
            categories: ['Foods', 'Beverages', 'Milks'],
          ),
          ScannedItem(
            id: 'a2',
            name: 'Lait Entier',
            brand: 'Candia',
            price: 1.70,
            scanDate: now,
            categories: ['Foods', 'Beverages', 'Milks'],
          ),
          ScannedItem(
            id: 'a3',
            name: 'Pain de Mie',
            brand: 'Brioche Dore',
            price: 2.99,
            scanDate: now,
            categories: ['Foods', 'Breads'],
          ),
        ],
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: DashboardScreen(
        sessions: sessions,
        onSessionSelected: (_) {},
      ),
    ));

    // La section est présente avec les types issus d'Open Food Facts
    expect(find.text('Comparaison par type de produit'), findsOneWidget);
    expect(find.text('Milks'), findsOneWidget);
    expect(find.text('Breads'), findsOneWidget);
    // Prix moyen du type Milks = (1.50 + 1.70) / 2 = 1.60
    expect(find.text('1.60 €/article'), findsOneWidget);
    expect(find.text('2.99 €/article'), findsOneWidget);
  });

  testWidgets('Dashboard affiche les articles non catégorisés à part', (WidgetTester tester) async {
    final now = DateTime.now();
    final sessions = [
      ScanSession(
        id: 'type_test_2',
        date: now,
        type: 'barcode',
        items: [
          ScannedItem(
            id: 'b1',
            name: 'Produit sans catégorie',
            price: 3.0,
            scanDate: now,
          ),
        ],
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: DashboardScreen(
        sessions: sessions,
        onSessionSelected: (_) {},
      ),
    ));

    expect(find.text('Comparaison par type de produit'), findsOneWidget);
    expect(find.text('1 article non catégorisé'), findsOneWidget);
  });
}
