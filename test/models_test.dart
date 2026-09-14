import 'package:flutter_test/flutter_test.dart';
import 'package:youconso/models/conso.dart';
import 'package:youconso/models/invoice.dart';
import 'package:youconso/models/json.dart';
import 'package:youconso/models/line_info.dart';

import 'fixtures.dart';

void main() {
  group('Conso', () {
    test('parse la vraie réponse Youprice', () {
      final conso = Conso.fromJson(realConso);
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
    });

    test('regroupe France et international par sous-catégorie', () {
      final conso = Conso.fromJson(realConso);
      final groups = conso.groups;
      expect(groups.map((g) => g.label), ['Internet mobile', 'Appels']);
      expect(groups.first.items, hasLength(2));
      expect(groups.first.withQuota, hasLength(1));
      expect(groups.first.simple.single.international, isTrue);
      expect(
        identical(conso.groups, groups),
        isTrue,
        reason: 'calculé une fois',
      );
    });

    test('tolère une réponse vide ou mal formée', () {
      expect(Conso.fromJson(null).groups, isEmpty);
      expect(Conso.fromJson('oops').groups, isEmpty);
      expect(
        Conso.fromJson({
          'categories': [
            1,
            {'libelle': 'X', 'sousCategories': 'pas une liste'},
          ],
        }).categories.single.subCategories,
        isEmpty,
      );
    });

    test('ratio borné et durées converties en minutes', () {
      const over = ConsoDetail(label: '', value: '60 GO', refValue: '50 GO');
      expect(over.ratio, 1);
      const calls = ConsoDetail(
        label: '',
        value: '01:00:00',
        refValue: '02:00:00',
      );
      expect(calls.ratio, 0.5);
      expect(calls.displayValue, '1 h 00 min');
      expect(calls.quota, '2 h 00 min');
      expect(calls.quotaNote, isNull);
      const noQuota = ConsoDetail(label: '', value: '1 GO', refValue: '');
      expect(noQuota.ratio, isNull);
      expect(noQuota.quota, isNull);
    });
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 48)), '48 s');
    expect(
      formatDuration(const Duration(minutes: 5, seconds: 3)),
      '5 min 03 s',
    );
    expect(formatDuration(const Duration(hours: 1, minutes: 32)), '1 h 32 min');
  });

  group('Invoice', () {
    test('parse les champs Youprice', () {
      final invoice = Invoice.fromJson(realInvoice);
      expect(invoice.id, '13540411');
      expect(invoice.name, 'Facture mensuelle');
      expect(invoice.date?.month, 8);
      expect(invoice.amount, 4.99);
      expect(invoice.remaining, 0);
      expect(invoice.isPaid, isTrue);
    });

    Invoice withStatus(String? status, {double? remaining}) =>
        Invoice(status: status, remaining: remaining);

    test('isPaid selon le statut', () {
      expect(withStatus('Payé').isPaid, isTrue);
      expect(withStatus('Payée').isPaid, isTrue);
      expect(withStatus('Impayé').isPaid, isFalse);
      expect(withStatus('Impayée').isPaid, isFalse);
      expect(withStatus('Non payée').isPaid, isFalse);
      expect(withStatus('Payée partiellement').isPaid, isFalse);
    });

    test('isPaid selon le reste à payer si le statut est inconnu', () {
      expect(withStatus(null, remaining: 0).isPaid, isTrue);
      expect(withStatus('En cours', remaining: 4.99).isPaid, isFalse);
      expect(withStatus(null).isPaid, isFalse);
    });
  });

  group('LineInfo', () {
    test('parse getLigneGsm', () {
      final info = LineInfo.fromJson(realLine);
      expect(info.isActive, isTrue);
      expect(info.planLabel, '50 Go');
      expect(info.operator, 'SFR');
      expect(info.simType, 'Sim');
      expect(info.has5G, isFalse);
    });

    test('champs absents', () {
      final info = LineInfo.fromJson(const {});
      expect(info.status, isNull);
      expect(info.isActive, isTrue, reason: 'inconnu vaut actif');
      expect(info.planLabel, isNull);
    });

    test('isActive', () {
      expect(const LineInfo(status: 'Activée').isActive, isTrue);
      expect(const LineInfo(status: 'Résiliée').isActive, isFalse);
    });
  });

  test('formatPhone', () {
    expect(formatPhone('0612345678'), '06 12 34 56 78');
    expect(formatPhone('+33612345678'), '+33612345678');
  });

  test('helpers JSON', () {
    expect(jsonText('  a  b '), 'a b');
    expect(jsonText(null), '');
    expect(jsonText(12), '12');
    expect(jsonTextOrNull('  '), isNull);
    expect(jsonNumber(3), 3.0);
    expect(jsonNumber('3'), isNull);
    expect(jsonList([1, {}, 'x'], (m) => m.length), [0]);
    expect(jsonList(null, (m) => m), isEmpty);
  });
}
