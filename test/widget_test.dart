import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youconso/api/youprice_api.dart';
import 'package:youconso/models/conso.dart';
import 'package:youconso/models/invoice.dart';
import 'package:youconso/models/line_info.dart';
import 'package:youconso/screens/login_screen.dart';
import 'package:youconso/storage/secure_store.dart';
import 'package:youconso/widgets/arc_gauge.dart';
import 'package:youconso/widgets/conso_card.dart';

const _realConso = {
  'categories': [
    {
      'libelle': 'En France métropolitaine',
      'sousCategories': [
        {
          'libelle': 'Internet mobile',
          'detais': [
            {
              'libelle': 'En  France',
              'valeur': '4,6 GO',
              'valeurRef': "50 GO Ajustable jusqu'à 50 GO",
            },
          ],
        },
        {
          'libelle': 'Appels',
          'detais': [
            {
              'libelle': "Heures d'appel en France",
              'valeur': '00:00:48',
              'valeurRef': null,
            },
          ],
        },
      ],
    },
    {
      'libelle': "Depuis l'international",
      'sousCategories': [
        {
          'libelle': 'Internet mobile',
          'detais': [
            {'libelle': 'Depuis  Zone1', 'valeur': '1,4 GO', 'valeurRef': null},
          ],
        },
      ],
    },
  ],
};

void main() {
  test('Conso parse la vraie réponse Youprice', () {
    final conso = Conso.fromJson(_realConso);
    expect(conso.categories, hasLength(2));

    final france = conso.categories.first;
    expect(france.isInternational, isFalse);
    final data = france.subCategories.first.details.first;
    expect(data.hasQuota, isTrue);
    expect(data.displayValue, '4,6 Go');
    expect(data.quota, '50 Go');
    expect(data.quotaNote, "Ajustable jusqu'à 50 Go");
    expect(data.ratio, closeTo(0.092, 0.001));
    final calls = france.subCategories[1];
    expect(calls.kind, ConsoKind.calls);
    expect(calls.details.first.hasQuota, isFalse);
    expect(calls.details.first.displayValue, '48 s');
    expect(calls.details.first.label, "Temps d'appel en France");

    expect(conso.categories[1].isInternational, isTrue);

    final groups = conso.groups;
    expect(groups.map((g) => g.label), ['Internet mobile', 'Appels']);
    expect(groups.first.items, hasLength(2));
    expect(groups.first.withQuota, hasLength(1));
    expect(groups.first.simple.single.international, isTrue);
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 48)), '48 s');
    expect(
      formatDuration(const Duration(minutes: 5, seconds: 3)),
      '5 min 03 s',
    );
    expect(formatDuration(const Duration(hours: 1, minutes: 32)), '1 h 32 min');
  });

  test('Invoice parse les champs Youprice', () {
    final invoice = Invoice.fromJson({
      'id': 13540411,
      'invoiceName': 'Facture mensuelle',
      'invoiceDate': '2026-08-31T00:00:00',
      'montantTTC': 4.99,
      'invoiceStatus': 'Payé',
      'montantRestant': 0.0,
    });
    expect(invoice.id, '13540411');
    expect(invoice.date?.month, 8);
    expect(invoice.amount, 4.99);
    expect(invoice.isPaid, isTrue);
  });

  test('LineInfo parse getLigneGsm', () {
    final info = LineInfo.fromJson({
      'etatLigne': 'Active',
      'ypProductName': '50Go',
      'operateur': 'SFR',
      'typeSim': 'Sim',
      'isOption5G': false,
    });
    expect(info.isActive, isTrue);
    expect(info.planLabel, '50 Go');
    expect(info.operator, 'SFR');
  });

  testWidgets('LoginScreen affiche le logo et le bouton', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(api: YoupriceApi(SecureStore()))),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('ConsoCard affiche une jauge pour le quota', (tester) async {
    final conso = Conso.fromJson(_realConso);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConsoCard(group: conso.groups.first),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Internet mobile'), findsOneWidget);
    expect(find.text('4,6 Go'), findsOneWidget);
    expect(find.text('sur 50 Go'), findsOneWidget);
    expect(find.byType(ArcGauge), findsOneWidget);
    expect(find.text('1,4 Go'), findsOneWidget);
    expect(find.byIcon(Icons.public), findsOneWidget);
  });
}
