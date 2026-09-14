import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/archetype.dart';
import '../../models/deck_bucket.dart';
import '../../providers/deck_builder_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/bucket_card_tile.dart';
import '../widgets/commander_selector_dialog.dart';
import '../widgets/edhrec_explorer_panel.dart';
import '../widgets/guardrail_audit_dialog.dart';
import '../widgets/guardrails_bar.dart';
import '../widgets/import_export_dialog.dart';
import '../widgets/mana_curve_chart.dart';

class DeckBuilderScreen extends ConsumerWidget {
  const DeckBuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deck = ref.watch(deckProvider);
    final report = ref.watch(guardrailReportProvider);
    final activeBucket = ref.watch(selectedBucketProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: AppTheme.primaryGold, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'OpinionatedCommander',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          // Selettore Archetipo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Archetype>(
                value: deck.archetype,
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(fontSize: 12, color: Colors.white),
                icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryGold),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(deckProvider.notifier).setArchetype(val);
                  }
                },
                items: [
                  for (final a in Archetype.values)
                    DropdownMenuItem(
                      value: a,
                      child: Text('Archetipo: ${a.name}'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Auto-Fill Basic Lands button
          ElevatedButton.icon(
            onPressed: () {
              final added = ref.read(deckProvider.notifier).autoFillBasicLands();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    added > 0
                        ? 'Aggiunte $added terre base proporzionali al mazzo!'
                        : 'Quota terre già raggiunta (${deck.countInBucket(DeckBucket.lands)}/${deck.archetype.targetFor(DeckBucket.lands)}).',
                  ),
                  backgroundColor: added > 0 ? AppTheme.accentGreen : AppTheme.cardHover,
                ),
              );
            },
            icon: const Icon(Icons.auto_fix_high, size: 16),
            label: const Text('Riempi Terre Base', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cardHover,
              foregroundColor: AppTheme.accentBlue,
              side: const BorderSide(color: AppTheme.borderDark),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),

          // Import/Export button
          IconButton(
            icon: const Icon(Icons.sync_alt, size: 20, color: Colors.white70),
            tooltip: 'Importa / Esporta',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const ImportExportDialog(),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // Barra Guardrails & Audit
          GuardrailsBar(
            report: report,
            onOpenAlerts: () {
              showDialog(
                context: context,
                builder: (_) => GuardrailAuditDialog(report: report),
              );
            },
          ),

          // Area di lavoro Split-Screen
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pannello Sinistro: Board a Bucket & Curva
                Expanded(
                  flex: 3,
                  child: _buildDeckBoard(context, ref, deck, activeBucket),
                ),

                // Pannello Destro: Explorer EDHREC & Scryfall
                const Expanded(
                  flex: 2,
                  child: EdhrecExplorerPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckBoard(
    BuildContext context,
    WidgetRef ref,
    dynamic deck,
    DeckBucket activeBucket,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Comandante Card Banner
        _buildCommanderBanner(context, ref, deck),
        const SizedBox(height: 16),

        // Curva di mana e Pips
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: ManaCurveChart(curve: deck.manaCurve)),
            const SizedBox(width: 12),
            _buildPipsSummary(deck),
          ],
        ),
        const SizedBox(height: 20),

        // Lista Bucket rigidi secondo BASE.md
        for (final bucket in DeckBucket.values)
          _buildBucketSection(context, ref, deck, bucket, activeBucket == bucket),
      ],
    );
  }

  Widget _buildCommanderBanner(BuildContext context, WidgetRef ref, dynamic deck) {
    final commander = deck.commander;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          if (commander?.artCropUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                commander!.artCropUrl!,
                width: 72,
                height: 52,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 72,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield, color: AppTheme.primaryGold, size: 28),
            ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'COMANDANTE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (commander != null)
                      Text(
                        commander.manaCost,
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  commander?.name ?? 'Nessun Comandante selezionato',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                if (commander != null)
                  Text(
                    commander.typeLine,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
              ],
            ),
          ),

          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const CommanderSelectorDialog(),
              );
            },
            icon: const Icon(Icons.search, size: 16),
            label: Text(commander == null ? 'Scegli' : 'Cambia'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipsSummary(dynamic deck) {
    final pips = deck.manaPips as Map<String, int>;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Simboli Mana (Pips)', style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final color in ['W', 'U', 'B', 'R', 'G']) ...[
                _buildPipBadge(color, pips[color] ?? 0),
                if (color != 'G') const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPipBadge(String color, int count) {
    Color badgeColor;
    switch (color) {
      case 'W':
        badgeColor = const Color(0xFFF9FAFB);
        break;
      case 'U':
        badgeColor = AppTheme.accentBlue;
        break;
      case 'B':
        badgeColor = const Color(0xFF6B7280);
        break;
      case 'R':
        badgeColor = AppTheme.accentRed;
        break;
      case 'G':
        badgeColor = AppTheme.accentGreen;
        break;
      default:
        badgeColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(color, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor)),
          const SizedBox(width: 4),
          Text('$count', style: const TextStyle(fontSize: 11, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildBucketSection(
    BuildContext context,
    WidgetRef ref,
    dynamic deck,
    DeckBucket bucket,
    bool isActive,
  ) {
    final cards = deck.cardsInBucket(bucket);
    final count = cards.length;
    final target = deck.archetype.targetFor(bucket);
    final isFull = count == target;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.cardHover.withValues(alpha: 0.6) : AppTheme.cardDark.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? AppTheme.primaryGold : (isFull ? AppTheme.accentGreen.withValues(alpha: 0.3) : AppTheme.borderDark),
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header del bucket
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            onTap: () {
              ref.read(selectedBucketProvider.notifier).state = bucket;
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              bucket.label,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            // Badge conteggio
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isFull
                                    ? AppTheme.accentGreen.withValues(alpha: 0.2)
                                    : (count > target ? AppTheme.accentRed.withValues(alpha: 0.2) : Colors.white10),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$count / $target',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isFull ? AppTheme.accentGreen : (count > target ? AppTheme.accentRed : Colors.white70),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bucket.description,
                          style: const TextStyle(fontSize: 11, color: Colors.white38),
                        ),
                      ],
                    ),
                  ),

                  // Bottone "Esplora sinergie per questo slot"
                  TextButton.icon(
                    onPressed: () {
                      ref.read(selectedBucketProvider.notifier).state = bucket;
                    },
                    icon: Icon(
                      Icons.filter_list,
                      size: 14,
                      color: isActive ? AppTheme.primaryGold : Colors.white54,
                    ),
                    label: Text(
                      isActive ? 'Attivo' : 'Cerca',
                      style: TextStyle(
                        fontSize: 11,
                        color: isActive ? AppTheme.primaryGold : Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Elenco carte del bucket
          if (cards.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                children: [
                  for (final card in cards)
                    BucketCardTile(
                      card: card,
                      onRemove: () => ref.read(deckProvider.notifier).removeCard(card.id),
                      onMoveBucket: (newBucket) =>
                          ref.read(deckProvider.notifier).moveCardToBucket(card.id, newBucket),
                    ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(selectedBucketProvider.notifier).state = bucket;
                },
                icon: const Icon(Icons.add, size: 14),
                label: Text('Slot vuoto — visualizza raccomandazioni EDHREC per ${bucket.label}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: AppTheme.borderDark, style: BorderStyle.solid),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
