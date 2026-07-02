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
}
