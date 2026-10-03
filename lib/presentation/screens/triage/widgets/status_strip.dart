import 'package:flutter/material.dart';

/// Thin header showing which model is loaded, device headroom and that the
/// app is running offline.
class StatusStrip extends StatelessWidget {
  final String modelName;
  final int? freeRamMb;
  final bool offline;
  final Duration? lastTimeToFirstToken;

  const StatusStrip({
    super.key,
    this.modelName = 'No model loaded',
    this.freeRamMb,
    this.offline = true,
    this.lastTimeToFirstToken,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ram = freeRamMb == null ? '--' : '$freeRamMb MB';
    final ttft = lastTimeToFirstToken == null
        ? '--'
        : '${lastTimeToFirstToken!.inMilliseconds} ms';

    return Semantics(
      container: true,
      label: 'Status',
      child: Container(
        width: double.infinity,
        color: theme.colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 16,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _item(Icons.memory, 'Model: $modelName'),
            _item(Icons.storage, 'Free RAM: $ram'),
            _item(Icons.timer_outlined, 'First token: $ttft'),
            if (offline) const _OfflineBadge(),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 14)),
    ],
  );
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 16, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Offline',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
