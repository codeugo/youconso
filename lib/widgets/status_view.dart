import 'package:flutter/material.dart';

import '../api/youprice_api.dart';

/// Empty or error state. A [ListView] so it works inside a [RefreshIndicator].
class StatusView extends StatelessWidget {
  const StatusView.empty({super.key, required this.icon, required this.text})
    : onRetry = null;

  StatusView.error({
    super.key,
    required Object error,
    required VoidCallback this.onRetry,
  }) : icon = Icons.cloud_off,
       text = error is ApiException ? error.message : '$error';

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onRetry = this.onRetry;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        Icon(
          icon,
          size: 56,
          color: onRetry != null ? scheme.error : scheme.outline,
        ),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ),
        ],
      ],
    );
  }
}
