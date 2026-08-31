import 'package:flutter/material.dart';
import '../../models/student.dart';

class StatusBadge extends StatelessWidget {
  final StudentStatus status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case StudentStatus.notStarted:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
        icon = Icons.radio_button_unchecked;
        break;
      case StudentStatus.inProgress:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        icon = Icons.pending_outlined;
        break;
      case StudentStatus.submitted:
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        icon = Icons.check_circle_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
