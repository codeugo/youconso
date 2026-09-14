import 'package:flutter/material.dart';

import '../models/conso.dart';
import 'arc_gauge.dart';

class ConsoCard extends StatelessWidget {
  const ConsoCard({super.key, required this.group});

  final ConsoGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quotaItems = group.withQuota;
    final simpleItems = group.simple;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _KindIcon(kind: group.kind),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    group.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            for (final item in quotaItems) _QuotaGauge(item: item),
            if (simpleItems.isNotEmpty) const SizedBox(height: 6),
            for (final item in simpleItems) _SimpleRow(item: item),
          ],
        ),
      ),
    );
  }
}

class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind});

  final ConsoKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (kind) {
      ConsoKind.data => Icons.wifi_rounded,
      ConsoKind.calls => Icons.call_rounded,
      ConsoKind.sms => Icons.chat_bubble_outline_rounded,
      ConsoKind.other => Icons.pie_chart_outline_rounded,
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: scheme.onPrimary, size: 22),
    );
  }
}

class _QuotaGauge extends StatelessWidget {
  const _QuotaGauge({required this.item});

  final ConsoItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = item.detail;
    final ratio = detail.ratio;
    final color = ArcGauge.colorFor(context, ratio);
    final caption = [
      if (ratio != null) '${(ratio * 100).round()} % utilisés',
      if (item.international) item.categoryLabel,
      if (detail.quotaNote != null) detail.quotaNote!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ArcGauge(
              ratio: ratio,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    detail.displayValue,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'sur ${detail.quota}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({required this.item});

  final ConsoItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = item.detail;
    final label = detail.label.isNotEmpty
        ? detail.label
        : (item.international ? item.categoryLabel : 'Consommé');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          if (item.international) ...[
            Icon(Icons.public, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            detail.displayValue,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
