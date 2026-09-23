import 'package:flutter/material.dart';

class NirvaStatusBadge extends StatelessWidget {
  const NirvaStatusBadge({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = _statusPalette(context, status);
    return Semantics(
      label: 'Status $status',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: palette.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(palette.icon, size: 16, color: palette.color),
            const SizedBox(width: 6),
            Text(
              status,
              style: TextStyle(
                color: palette.color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _StatusPalette _statusPalette(BuildContext context, String value) {
    switch (value.toUpperCase()) {
      case 'APPROVED':
      case 'FINALIZED':
        return _StatusPalette(Colors.green.shade700, Icons.check_circle_outline);
      case 'FLAGGED':
      case 'INVALID':
        return _StatusPalette(Colors.deepOrange.shade700, Icons.flag_outlined);
      case 'RETURNED':
        return _StatusPalette(Colors.orange.shade800, Icons.assignment_return_outlined);
      case 'RUNNING':
        return _StatusPalette(Theme.of(context).colorScheme.primary, Icons.play_circle_outline);
      case 'ANALYZED':
        return _StatusPalette(Colors.indigo.shade700, Icons.analytics_outlined);
      case 'CAPTURED':
        return _StatusPalette(Colors.teal.shade700, Icons.camera_alt_outlined);
      case 'CREATED':
      case 'PENDING':
      default:
        return _StatusPalette(Colors.amber.shade800, Icons.pending_actions);
    }
  }
}

class _StatusPalette {
  const _StatusPalette(this.color, this.icon);

  final Color color;
  final IconData icon;
}
