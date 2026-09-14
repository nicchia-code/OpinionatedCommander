import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/archetype.dart';
import '../../models/commander_card.dart';
import '../../models/deck_bucket.dart';
import '../../providers/deck_builder_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/bucket_card_tile.dart';
import '../widgets/edhrec_explorer_panel.dart';
import '../widgets/guardrail_audit_dialog.dart';
import '../widgets/import_export_dialog.dart';

class DeckBuilderScreen extends ConsumerStatefulWidget {
  const DeckBuilderScreen({super.key});

  @override
  ConsumerState<DeckBuilderScreen> createState() => _DeckBuilderScreenState();
}

class _DeckBuilderScreenState extends ConsumerState<DeckBuilderScreen> {
  final TextEditingController _commanderSearchCtrl = TextEditingController();
  List<CommanderCard> _commanderSearchResults = [];
  bool _isSearchingCommander = false;

  @override
  void dispose() {
    _commanderSearchCtrl.dispose();
    super.dispose();
  }

  void _searchCommanders(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _commanderSearchResults = [];
        _isSearchingCommander = false;
      });
      return;
    }

    setState(() => _isSearchingCommander = true);
    final scryfall = ref.read(scryfallServiceProvider);
    final results = await scryfall.searchCommanders(query);
    if (mounted) {
      setState(() {
        _commanderSearchResults = results;
        _isSearchingCommander = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final deck = ref.watch(deckProvider);
    final activeBucket = ref.watch(selectedBucketProvider);

    // ZERO STATE: Se non c'è comandante, mostra una schermata minimalista con un unico focus
    if (deck.commander == null) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'OpinionatedCommander',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Costruzione mazzi guidata a slot rigidi (BASE.md) e sinergie EDHREC.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.white54),
                  ),
                  const SizedBox(height: 36),

                  // Search bar comandante
                  TextField(
                    controller: _commanderSearchCtrl,
                    autofocus: true,
                    style: const TextStyle(fontSize: 15, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Cerca comandante (es. Atraxa, Krenko, Urza)...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38),
                      suffixIcon: _isSearchingCommander
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                              ),
                            )
                          : (_commanderSearchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: Colors.white38),
                                  onPressed: () {
                                    _commanderSearchCtrl.clear();
                                    _searchCommanders('');
                                  },
                                )
                              : null),
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderDark),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderDark),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white54),
                      ),
                    ),
                    onChanged: _searchCommanders,
                  ),
                  const SizedBox(height: 16),

                  // Risultati ricerca
                  if (_commanderSearchResults.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 320),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _commanderSearchResults.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, color: AppTheme.borderDark),
                        itemBuilder: (context, i) {
                          final card = _commanderSearchResults[i];
                          return ListTile(
                            dense: true,
                            leading: card.artCropUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      card.artCropUrl!,
                                      width: 40,
                                      height: 30,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(Icons.shield, size: 20, color: Colors.white38),
                            title: Text(card.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
                            subtitle: Text('${card.manaCost} • ${card.typeLine}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                            onTap: () {
                              ref.read(deckProvider.notifier).setCommander(card);
                            },
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 24),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const ImportExportDialog(),
                        );
                      },
                      icon: const Icon(Icons.file_upload_outlined, size: 16, color: Colors.white54),
                      label: const Text('Oppure importa una decklist esistente', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // BUILDER VIEW: Comandante scelto. Layout minimalista a 2 colonne pulito
    final totalCards = deck.mainDeckCount;
    final report = ref.watch(guardrailReportProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            // Thumbnail Comandante
            if (deck.commander?.artCropUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  deck.commander!.artCropUrl!,
                  width: 32,
                  height: 24,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(width: 10),
            Text(
              deck.commander!.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              '${deck.commander!.manaCost} • ${deck.archetype.name}',
              style: const TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ],
        ),
        actions: [
          // Progresso conteggio discreto
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: totalCards == 99 ? AppTheme.accentGreen.withValues(alpha: 0.2) : AppTheme.cardDark,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: totalCards == 99 ? AppTheme.accentGreen : AppTheme.borderDark),
              ),
              child: Text(
                '$totalCards / 99',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: totalCards == 99 ? AppTheme.accentGreen : Colors.white70,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Pulsante Auto-Fill Terre Base
          IconButton(
            icon: const Icon(Icons.auto_fix_high, size: 18, color: Colors.white70),
            tooltip: 'Riempi Terre Base mancanti',
            onPressed: () {
              final added = ref.read(deckProvider.notifier).autoFillBasicLands();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(added > 0 ? 'Aggiunte $added terre base proporzionali.' : 'Quota terre già raggiunta.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),

          // Menu Altre Azioni (Minimalista: raccoglie archetipo, audit, import/export e reset)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20, color: Colors.white70),
            tooltip: 'Opzioni mazzo',
            onSelected: (action) {
              if (action == 'audit') {
                showDialog(
                  context: context,
                  builder: (_) => GuardrailAuditDialog(report: report),
                );
              } else if (action == 'import_export') {
                showDialog(
                  context: context,
                  builder: (_) => const ImportExportDialog(),
                );
              } else if (action == 'change_commander') {
                ref.read(deckProvider.notifier).clearDeck();
              } else if (action.startsWith('archetype_')) {
                final archName = action.replaceFirst('archetype_', '');
                final arch = Archetype.values.firstWhere((a) => a.name == archName);
                ref.read(deckProvider.notifier).setArchetype(arch);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                enabled: false,
                child: Text('ARCHETIPO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38)),
              ),
              for (final a in Archetype.values)
                PopupMenuItem(
                  value: 'archetype_${a.name}',
                  child: Row(
                    children: [
                      if (deck.archetype == a)
                        const Icon(Icons.check, size: 14, color: AppTheme.primaryGold)
                      else
                        const SizedBox(width: 14),
                      const SizedBox(width: 8),
                      Text(a.name, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'audit',
                child: Row(
                  children: [
                    const Icon(Icons.fact_check_outlined, size: 16),
                    const SizedBox(width: 8),
                    Text('Audit BASE.md (${report.alerts.length} avvisi)', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import_export',
                child: Row(
                  children: [
                    Icon(Icons.sync_alt, size: 16),
                    SizedBox(width: 8),
                    Text('Importa / Esporta', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'change_commander',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 16, color: AppTheme.accentRed),
                    SizedBox(width: 8),
                    Text('Cambia Comandante', style: TextStyle(fontSize: 12, color: AppTheme.accentRed)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pannello Sinistro: I 10 Bucket compatti e lineari
          Expanded(
            flex: 3,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                for (final bucket in DeckBucket.values)
                  _buildMinimalBucketSection(context, ref, deck, bucket, activeBucket == bucket),
              ],
            ),
          ),

          // Pannello Destro: Explorer EDHREC minimale per il bucket attivo
          const Expanded(
            flex: 2,
            child: EdhrecExplorerPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalBucketSection(
    BuildContext context,
    WidgetRef ref,
    dynamic deck,
    DeckBucket bucket,
    bool isActive,
  ) {
    final cards = deck.cardsInBucket(bucket);
    final count = cards.length;
    final target = deck.archetype.targetFor(bucket);
    final isDone = count == target;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.surfaceDark : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AppTheme.borderDark : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Riga d'intestazione bucket: pulita, scura, senza pulsantoni
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              ref.read(selectedBucketProvider.notifier).state = bucket;
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isActive ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 14,
                    color: isActive ? AppTheme.primaryGold : Colors.white24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    bucket.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive ? Colors.white : Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$count / $target',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDone ? AppTheme.accentGreen : (count > target ? AppTheme.accentRed : Colors.white38),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Se ci sono carte, mostrale in modo super compatto
          if (cards.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 8, bottom: 6),
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
            ),
        ],
      ),
    );
  }
}
