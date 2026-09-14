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
    id: _text(json['id']),
    name: _text(json['invoiceName']),
    date: DateTime.tryParse(json['invoiceDate']?.toString() ?? ''),
    amount: _number(json['montantTTC']),
    remaining: _number(json['montantRestant']),
    status: _text(json['invoiceStatus']),
  );

  bool get isPaid {
    final s = status?.toLowerCase() ?? '';
    if (s.contains('pay') && !s.contains('partiel') && !s.contains('non')) {
      return true;
    }
    if (s.contains('impay') || s.contains('non pay') || s.contains('partiel')) {
      return false;
    }
    return remaining != null && remaining! <= 0;
  }

  static String? _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static double? _number(dynamic value) =>
      value is num ? value.toDouble() : null;
}
