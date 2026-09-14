import 'package:flutter/material.dart';

import '../models/line_info.dart';
import '../theme.dart';

/// Bandeau bleu en tête de l'onglet Conso : forfait, numéro, réseau, SIM, 5G.
class LineHeader extends StatelessWidget {
  const LineHeader({super.key, required this.number, this.info});

  final String number;
  final LineInfo? info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = this.info;
    final status = info?.status;
    final operator = info?.operator;
    final simType = info?.simType;
    final planLabel = info?.planLabel;
    const onBanner = Colors.white;
    final chips = <(String, Color?)>[
      if (operator != null) ('Réseau $operator', _operatorColor(operator)),
      if (simType != null)
        (simType.toUpperCase() == 'ESIM' ? 'eSIM' : 'SIM', null),
      if (info?.has5G ?? false) ('5G', null),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [youpriceBlue, youpriceBlue.withValues(alpha: 0.78)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  planLabel != null ? 'Forfait $planLabel' : 'Ma ligne',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: onBanner,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (status != null)
                Tooltip(
                  message: status,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (info?.isActive ?? true)
                          ? const Color(0xFF4CD964)
                          : const Color(0xFFFF3B30),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatPhone(number),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: onBanner,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final (label, color) in chips)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      border: color == null
                          ? Border.all(color: onBanner.withValues(alpha: 0.5))
                          : null,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: onBanner,
                        fontWeight: color != null ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Color? _operatorColor(String operator) {
  final op = operator.toLowerCase();
  if (op.contains('sfr')) return const Color(0xFFD0021B);
  if (op.contains('orange')) return const Color(0xFFFF7900);
  if (op.contains('bouygues') || op == 'bt') return const Color(0xFF1FA2E0);
  return null;
}
