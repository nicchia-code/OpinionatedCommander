import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ManaCurveChart extends StatelessWidget {
  final Map<int, int> curve;

  const ManaCurveChart({super.key, required this.curve});

  @override
  Widget build(BuildContext context) {
    final maxCount = curve.values.fold<int>(1, (max, val) => val > max ? val : max);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int cmc = 0; cmc <= 6; cmc++) ...[
            _buildBar(
              cmc == 6 ? '6+' : '$cmc',
              curve[cmc] ?? 0,
              maxCount,
            ),
            if (cmc < 6) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildBar(String label, int count, int max) {
    final heightRatio = max > 0 ? (count / max).clamp(0.05, 1.0) : 0.05;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 3),
        Container(
          width: 16,
          height: 36 * heightRatio,
          decoration: BoxDecoration(
            color: count > 0 ? AppTheme.accentBlue : Colors.white12,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white38),
        ),
      ],
    );
  }
}
