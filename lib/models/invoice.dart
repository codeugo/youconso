import 'json.dart';

class Invoice {
  const Invoice({
    this.id,
    this.name,
    this.date,
    this.amount,
    this.remaining,
    this.status,
  });

  final String? id;
  final String? name;
  final DateTime? date;
  final double? amount;
  final double? remaining;
  final String? status;

  factory Invoice.fromJson(Map json) => Invoice(
    id: jsonTextOrNull(json['id']),
    name: jsonTextOrNull(json['invoiceName']),
    date: DateTime.tryParse(json['invoiceDate']?.toString() ?? ''),
    amount: jsonNumber(json['montantTTC']),
    remaining: jsonNumber(json['montantRestant']),
    status: jsonTextOrNull(json['invoiceStatus']),
  );

  bool get isPaid {
    final s = status?.toLowerCase() ?? '';
    // « Impayé » contient « pay » : les statuts négatifs se testent en premier.
    if (s.contains('impay') || s.contains('non pay') || s.contains('partiel')) {
      return false;
    }
    if (s.contains('pay')) return true;
    return remaining != null && remaining! <= 0;
  }
}
