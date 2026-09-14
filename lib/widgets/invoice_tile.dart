import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/invoice.dart';

class InvoiceTile extends StatelessWidget {
  const InvoiceTile({
    super.key,
    required this.invoice,
    this.onTap,
    this.busy = false,
  });

  final Invoice invoice;
  final VoidCallback? onTap;
  final bool busy;

  static final _month = DateFormat.yMMMM('fr_FR');
  static final _day = DateFormat.yMd('fr_FR');
  static final _euro = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = invoice.date;
    final paid = invoice.isPaid;

    final title = date != null
        ? _capitalize(_month.format(date))
        : (invoice.name ?? 'Facture');
    final firstLine = [
      if (invoice.name != null && date != null) invoice.name!,
      if (date != null) 'du ${_day.format(date)}',
    ].join(' ');
    final secondLine = [
      if (invoice.status != null) invoice.status!,
      if (!paid && invoice.remaining != null && invoice.remaining! > 0)
        'reste à payer ${_euro.format(invoice.remaining)}',
    ].join(', ');
    final subtitleLines = [
      if (firstLine.isNotEmpty) firstLine,
      if (secondLine.isNotEmpty) secondLine,
    ];

    return ListTile(
      onTap: busy ? null : onTap,
      leading: CircleAvatar(
        backgroundColor: paid
            ? theme.colorScheme.primary
            : theme.colorScheme.error,
        child: busy
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onPrimary,
                ),
              )
            : Icon(
                paid ? Icons.receipt_long_outlined : Icons.error_outline,
                color: paid
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onError,
              ),
      ),
      title: Text(title),
      subtitle: subtitleLines.isEmpty ? null : Text(subtitleLines.join('\n')),
      isThreeLine: subtitleLines.length > 1,
      trailing: Text(
        invoice.amount != null ? _euro.format(invoice.amount) : '—',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: paid ? null : theme.colorScheme.error,
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
