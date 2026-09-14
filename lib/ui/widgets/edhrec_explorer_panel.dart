import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/commander_card.dart';
import '../../models/deck_bucket.dart';
import '../../providers/deck_builder_provider.dart';
import '../theme/app_theme.dart';

class EdhrecExplorerPanel extends ConsumerStatefulWidget {
  const EdhrecExplorerPanel({super.key});

  @override
  ConsumerState<EdhrecExplorerPanel> createState() => _EdhrecExplorerPanelState();
}

class _EdhrecExplorerPanelState extends ConsumerState<EdhrecExplorerPanel> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isScryfallMode = false;
  List<CommanderCard> _scryfallResults = [];
  bool _isSearchingScryfall = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _searchScryfall(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _scryfallResults = [];
        _isSearchingScryfall = false;
      });
      return;
    }

    setState(() => _isSearchingScryfall = true);
    final deck = ref.read(deckProvider);
    final scryfall = ref.read(scryfallServiceProvider);
    final results = await scryfall.searchCards(
      query,
      colorIdentity: deck.commander?.colorIdentity,
    );

    if (mounted) {
      setState(() {
        _scryfallResults = results;
        _isSearchingScryfall = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBucket = ref.watch(selectedBucketProvider);
    final deck = ref.watch(deckProvider);
    final edhrecAsync = ref.watch(edhrecRecommendationsProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: const Border(left: BorderSide(color: AppTheme.borderDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header explorer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.borderDark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.explore_outlined, size: 18, color: AppTheme.primaryGold),
                    const SizedBox(width: 8),
                    Text(
                      'Sinergie EDHREC & Search',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15),
                    ),
                    const Spacer(),
                    // Toggle modalità EDHREC / Ricerca libera Scryfall
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('EDHREC', style: TextStyle(fontSize: 11))),
                        ButtonSegment(value: true, label: Text('Scryfall', style: TextStyle(fontSize: 11))),
                      ],
                      selected: {_isScryfallMode},
                      onSelectionChanged: (set) {
                        setState(() {
                          _isScryfallMode = set.first;
                          if (_isScryfallMode && _searchCtrl.text.isNotEmpty) {
                            _searchScryfall(_searchCtrl.text);
                          }
                        });
                      },
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Search field
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: _isScryfallMode
                        ? 'Cerca su Scryfall (rispetta identità colori)...'
                        : 'Filtra sinergie per ${activeBucket.label}...',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white38),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.cardDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderDark),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {});
                    if (_isScryfallMode) {
                      _searchScryfall(val);
                    }
                  },
                ),
                const SizedBox(height: 8),

                // Badge destinazione slot attivo
                Row(
                  children: [
                    const Text(
                      'Aggiunta diretta allo slot: ',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        activeBucket.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista risultati
          Expanded(
            child: _isScryfallMode
                ? _buildScryfallList(deck, activeBucket)
                : _buildEdhrecList(edhrecAsync, deck, activeBucket),
          ),
        ],
      ),
    );
  }

  Widget _buildEdhrecList(
    AsyncValue<List<CommanderCard>> edhrecAsync,
    dynamic deck,
    DeckBucket activeBucket,
  ) {
    if (deck.commander == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Seleziona prima un comandante in alto per caricare le sinergie EDHREC.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return edhrecAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGold),
      ),
      error: (err, _) => Center(
        child: Text('Impossibile caricare EDHREC: $err', style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (allCards) {
        // Filtra per bucket o cerca per testo
        final query = _searchCtrl.text.trim().toLowerCase();
        final filtered = allCards.where((c) {
          final matchesQuery = query.isEmpty || c.name.toLowerCase().contains(query);
          final matchesBucket = query.isNotEmpty || (c.bucket == activeBucket);
          return matchesQuery && matchesBucket;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 36, color: Colors.white38),
                  const SizedBox(height: 8),
                  Text(
                    'Nessuna carta EDHREC trovata per ${activeBucket.label}.',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Usa la modalità "Scryfall" in alto per cercare qualsiasi carta dell\'identità di colore.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.white38),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: filtered.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, i) {
            final card = filtered[i];
            final isInDeck = deck.containsCard(card.name);

            return _buildRecommendationTile(card, isInDeck, activeBucket);
          },
        );
      },
    );
  }

  Widget _buildScryfallList(dynamic deck, DeckBucket activeBucket) {
    if (_isSearchingScryfall) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentBlue),
      );
    }

    if (_scryfallResults.isEmpty) {
      return const Center(
        child: Text(
          'Digita un nome di carta per cercare nel catalogo Scryfall.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      itemCount: _scryfallResults.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, i) {
        final card = _scryfallResults[i];
        final isInDeck = deck.containsCard(card.name);

        return _buildRecommendationTile(card, isInDeck, activeBucket);
      },
    );
  }

  Widget _buildRecommendationTile(CommanderCard card, bool isInDeck, DeckBucket activeBucket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isInDeck ? AppTheme.accentGreen.withValues(alpha: 0.4) : AppTheme.borderDark),
      ),
      child: Row(
        children: [
          // Art thumbnail
          if (card.artCropUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                card.artCropUrl!,
                width: 44,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.image_not_supported, size: 24),
              ),
            )
          else
            Container(
              width: 44,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.style, size: 18, color: Colors.white38),
            ),
          const SizedBox(width: 10),

          // Name and Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (card.edhrecSynergy != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: (card.edhrecSynergy! >= 0 ? AppTheme.accentGreen : AppTheme.accentRed).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '${card.edhrecSynergy! >= 0 ? '+' : ''}${(card.edhrecSynergy! * 100).toStringAsFixed(0)}% sinergia',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: card.edhrecSynergy! >= 0 ? AppTheme.accentGreen : AppTheme.accentRed,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (card.edhrecInclusion != null)
                      Text(
                        '${(card.edhrecInclusion! * 100).toStringAsFixed(0)}% dei mazzi',
                        style: const TextStyle(fontSize: 10, color: Colors.white54),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Action button
          if (isInDeck)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.check_circle, size: 20, color: AppTheme.accentGreen),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                ref.read(deckProvider.notifier).addCard(card, targetBucket: activeBucket);
              },
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Slot', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(60, 30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
        ],
      ),
    );
  }
}
