import 'package:flutter/material.dart';
import '../../models/guardrail_report.dart';
import '../theme/app_theme.dart';

class GuardrailsBar extends StatelessWidget {
  final GuardrailReport report;
  final VoidCallback onOpenAlerts;

  const GuardrailsBar({
    super.key,
    required this.report,
    required this.onOpenAlerts,
  });

  @override
  Widget build(BuildContext context) {
    final deck = report.deck;
    final totalMain = deck.mainDeckCount;
    final avgCmc = report.averageNonLandCmc;

    final hasCritical = report.alerts.any((a) => a.severity == AlertSeverity.critical);
    final hasWarning = report.alerts.any((a) => a.severity == AlertSeverity.warning);

    final statusColor = hasCritical
        ? AppTheme.accentRed
        : (hasWarning ? Colors.orangeAccent : AppTheme.accentGreen);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: const Border(bottom: BorderSide(color: AppTheme.borderDark)),
      ),
      child: Row(
        children: [
          // Conteggio totale mazzo
          _buildPill(
            label: 'Deck',
            value: '$totalMain/99',
            color: totalMain == 99 ? AppTheme.accentGreen : (totalMain > 99 ? AppTheme.accentRed : Colors.white70),
            icon: Icons.layers_outlined,
          ),
          const SizedBox(width: 12),

          // CMC medio
          _buildPill(
            label: 'CMC Medio',
            value: avgCmc > 0 ? avgCmc.toStringAsFixed(2) : '--',
            color: (avgCmc >= 2.2 && avgCmc <= 3.5) ? AppTheme.accentGreen : (avgCmc > 3.5 ? Colors.orangeAccent : Colors.white70),
            icon: Icons.speed,
          ),
          const SizedBox(width: 12),

          // Terre
          _buildPill(
            label: 'Terre',
            value: '${report.currentCounts[report.deck.archetype.targets.keys.first]}/'
                '${report.deck.archetype.targetFor(report.deck.archetype.targets.keys.first)}',
            color: Colors.white70,
            icon: Icons.landscape_outlined,
          ),

          const Spacer(),

          // Pulsante Avvisi Guardrail
          TextButton.icon(
            onPressed: onOpenAlerts,
            icon: Icon(
              hasCritical ? Icons.error_outline : (hasWarning ? Icons.warning_amber_rounded : Icons.check_circle_outline),
              size: 18,
              color: statusColor,
            ),
            label: Text(
              '${report.alerts.length} Audit BASE.md',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            style: TextButton.styleFrom(
              backgroundColor: statusColor.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
