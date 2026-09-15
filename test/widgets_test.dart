import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:youconso/api/youprice_api.dart';
import 'package:youconso/models/conso.dart';
import 'package:youconso/models/invoice.dart';
import 'package:youconso/models/line_info.dart';
import 'package:youconso/screens/login_screen.dart';
import 'package:youconso/storage/secure_store.dart';
import 'package:youconso/widgets/arc_gauge.dart';
import 'package:youconso/widgets/conso_card.dart';
import 'package:youconso/widgets/invoice_tile.dart';
import 'package:youconso/widgets/line_header.dart';
import 'package:youconso/widgets/status_view.dart';

import 'fixtures.dart';

Widget wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets('LoginScreen affiche le logo, le message et le bouton', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          api: YoupriceApi(SecureStore()),
          message: 'Session expirée',
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Session expirée'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('ConsoCard affiche une jauge pour le quota', (tester) async {
    final conso = Conso.fromJson(realConso);
    await tester.pumpWidget(wrap(ConsoCard(group: conso.groups.first)));
    await tester.pumpAndSettle();
    expect(find.text('Internet mobile'), findsOneWidget);
    expect(find.text('4,6 Go'), findsOneWidget);
    expect(find.text('sur 50 Go'), findsOneWidget);
    expect(find.byType(ArcGauge), findsOneWidget);
    expect(find.text('1,4 Go'), findsOneWidget);
    expect(find.byIcon(Icons.public), findsOneWidget);
  });

  testWidgets('InvoiceTile : facture payée', (tester) async {
    await tester.pumpWidget(
      wrap(InvoiceTile(invoice: Invoice.fromJson(realInvoice))),
    );
    expect(find.text('Août 2026'), findsOneWidget);
    expect(find.textContaining('4,99'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
  });

  testWidgets('InvoiceTile : facture impayée avec reste à payer', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        InvoiceTile(
          invoice: Invoice.fromJson({
            ...realInvoice,
            'invoiceStatus': 'Impayée',
            'montantRestant': 4.99,
          }),
        ),
      ),
    );
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('reste à payer'), findsOneWidget);
  });

  testWidgets('LineHeader affiche forfait, numéro et réseau', (tester) async {
    await tester.pumpWidget(
      wrap(
        const LineHeader(
          number: phoneNumber,
          info: LineInfo(
            status: 'Active',
            planName: '50Go',
            operator: 'SFR',
            simType: 'eSim',
            has5G: true,
          ),
        ),
      ),
    );
    expect(find.text('Forfait 50 Go'), findsOneWidget);
    expect(find.text('06 12 34 56 78'), findsOneWidget);
    expect(find.text('Réseau SFR'), findsOneWidget);
    expect(find.text('5G'), findsOneWidget);
    expect(find.text('eSIM'), findsOneWidget);
  });

  testWidgets('LineHeader sans info de ligne', (tester) async {
    await tester.pumpWidget(wrap(const LineHeader(number: phoneNumber)));
    expect(find.text('Ma ligne'), findsOneWidget);
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('StatusView.error propose de réessayer', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatusView.error(
            error: ApiException('Boum'),
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    expect(find.text('Boum'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    expect(retried, isTrue);
  });

  testWidgets('StatusView.empty sans bouton', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusView.empty(icon: Icons.inbox, text: 'Rien'),
        ),
      ),
    );
    expect(find.text('Rien'), findsOneWidget);
    expect(find.text('Réessayer'), findsNothing);
  });
}
