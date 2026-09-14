import 'package:flutter/material.dart';
import '../../models/deck_bucket.dart';
import '../../models/guardrail_report.dart';
import '../theme/app_theme.dart';

class GuardrailAuditDialog extends StatelessWidget {
  final GuardrailReport report;

  const GuardrailAuditDialog({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 650,
        height: 620,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check_outlined, color: AppTheme.primaryGold),
                const SizedBox(width: 8),
                Text(
                  'Audit di Conformità BASE.md',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Archetipo attivo: ${report.deck.archetype.name} • Sistema prescrittivo casual-ottimizzato',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const Divider(height: 24, color: AppTheme.borderDark),

            // Controlli e Alert
            Expanded(
              child: ListView(
                children: [
                  // Sezione Alert attivi
                  if (report.alerts.isNotEmpty) ...[
                    const Text(
                      'AVVISI E SEGNALAZIONI ATTIVE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    for (final alert in report.alerts) _buildAlertTile(alert),
                    const SizedBox(height: 16),
                  ],

                  // Tabella di controllo quote
                  const Text(
                    'CHECKLIST QUOTE PER RUOLO',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  Table(
                    border: TableBorder.all(color: AppTheme.borderDark, borderRadius: BorderRadius.circular(6)),
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(1.5),
                    },
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: AppTheme.cardDark),
                        children: const [
                          Padding(padding: EdgeInsets.all(8), child: Text('Ruolo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(8), child: Text('Attuale', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(8), child: Text('Target', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(8), child: Text('Stato', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ),
                      for (final bucket in DeckBucket.values)
                        _buildTableRow(
                          bucket.label,
                          report.currentCounts[bucket] ?? 0,
                          report.targetCounts[bucket] ?? 0,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Regole qualitative su interazione e curva
                  const Text(
                    'QUALITÀ INTERAZIONE & CURVA',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  _buildRuleStatusTile(
                    'Spot removal economico (≤2 MV)',
                    '${report.lowCostSpotInstantCount} / min 4',
                    report.lowCostSpotInstantCount >= 4,
                  ),
                  _buildRuleStatusTile(
                    'Spot removal a velocità Instant',
                    '${report.instantSpotCount} / min ${(report.currentCounts[DeckBucket.spotRemoval] ?? 0) ~/ 2}',
                    report.instantSpotCount >= ((report.currentCounts[DeckBucket.spotRemoval] ?? 0) / 2).ceil(),
                  ),
                  _buildRuleStatusTile(
                    'Risposte definitive (esilio/sacrificio/rimozione)',
                    '${report.definitiveRemovalCount} / min 2',
                    report.definitiveRemovalCount >= 2,
                  ),
                  _buildRuleStatusTile(
                    'Mana value medio non-terra',
                    '${report.averageNonLandCmc.toStringAsFixed(2)} (guardrail: 2.80–3.50)',
                    report.averageNonLandCmc >= 2.2 && report.averageNonLandCmc <= 3.5,
                  ),
                  _buildRuleStatusTile(
                    'Carte pesanti a costo 5+ MV',
                    '${report.highCostCount} / max 10',
                    report.highCostCount <= 10,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertTile(GuardrailAlert alert) {
    Color color;
    IconData icon;
    switch (alert.severity) {
      case AlertSeverity.critical:
        color = AppTheme.accentRed;
        icon = Icons.error_outline;
        break;
      case AlertSeverity.warning:
        color = Colors.orangeAccent;
        icon = Icons.warning_amber_rounded;
        break;
      case AlertSeverity.info:
        color = AppTheme.accentBlue;
        icon = Icons.info_outline;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                const SizedBox(height: 2),
                Text(alert.message, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 4),
                Text(alert.ruleReference, style: const TextStyle(fontSize: 10, color: Colors.white38, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String label, int current, int target) {
    final isOk = current == target;
    final diff = current - target;
    final diffStr = diff > 0 ? '+$diff' : (diff < 0 ? '$diff' : 'OK');
    final diffColor = isOk ? AppTheme.accentGreen : (diff < 0 ? Colors.orangeAccent : Colors.cyanAccent);

    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(8), child: Text(label, style: const TextStyle(fontSize: 12))),
        Padding(padding: const EdgeInsets.all(8), child: Text('$current', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
        Padding(padding: const EdgeInsets.all(8), child: Text('$target', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white54))),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            diffStr,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: diffColor),
          ),
        ),
      ],
    );
  }

  Widget _buildRuleStatusTile(String title, String detail, bool compliant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Row(
        children: [
          Icon(
            compliant ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            size: 16,
            color: compliant ? AppTheme.accentGreen : Colors.orangeAccent,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 12, color: Colors.white))),
          Text(detail, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: compliant ? AppTheme.accentGreen : Colors.orangeAccent)),
        ],
      ),
    );
  }
}
