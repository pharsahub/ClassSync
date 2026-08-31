import 'package:flutter/material.dart';

class TimerDisplay extends StatelessWidget {
  final int remainingSeconds;
  final int totalSeconds;

  const TimerDisplay({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final formattedTime =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final isUrgent = remainingSeconds <= 60 && remainingSeconds > 0;
    final isTimeUp = remainingSeconds <= 0;

    Color badgeColor;
    Color textColor;
    if (isTimeUp) {
      badgeColor = Colors.red.shade100;
      textColor = Colors.red.shade900;
    } else if (isUrgent) {
      badgeColor = Colors.amber.shade100;
      textColor = Colors.amber.shade900;
    } else {
      badgeColor = Theme.of(context).colorScheme.primaryContainer;
      textColor = Theme.of(context).colorScheme.onPrimaryContainer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUrgent || isTimeUp ? Icons.warning_amber_rounded : Icons.timer_outlined,
            size: 18,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Text(
            isTimeUp ? 'Time Up!' : formattedTime,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
