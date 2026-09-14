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
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(left: BorderSide(color: AppTheme.borderDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header minimalista
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Suggeriti per: ${activeBucket.label}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    const Spacer(),
                    // Toggle compatto EDHREC / Scryfall
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        setState(() {
                          _isScryfallMode = !_isScryfallMode;
                          if (_isScryfallMode && _searchCtrl.text.isNotEmpty) {
                            _searchScryfall(_searchCtrl.text);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          _isScryfallMode ? 'Fonte: Scryfall' : 'Fonte: EDHREC',
                          style: const TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Search field compatto
                TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: _isScryfallMode
                        ? 'Cerca su Scryfall...'
                        : 'Filtra tra i suggeriti...',
                    hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white38),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14, color: Colors.white38),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.bgDark,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {});
                    if (_isScryfallMode) {
                      _searchScryfall(val);
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderDark),

          // Risultati
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
    return edhrecAsync.when(
      loading: () => const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
        ),
      ),
      error: (err, _) => Center(
        child: Text('Errore EDHREC: $err', style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ),
      data: (allCards) {
        final query = _searchCtrl.text.trim().toLowerCase();
        final filtered = allCards.where((c) {
          final matchesQuery = query.isEmpty || c.name.toLowerCase().contains(query);
          final matchesBucket = query.isNotEmpty || (c.bucket == activeBucket);
          return matchesQuery && matchesBucket;
        }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Text(
              'Nessuna carta per questo slot.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          );
        }

        return ListView.separated(
          itemCount: filtered.length,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          separatorBuilder: (context, index) => const SizedBox(height: 4),
          itemBuilder: (context, i) {
            final card = filtered[i];
            final isInDeck = deck.containsCard(card.name);

            return _buildMinimalTile(card, isInDeck, activeBucket);
          },
        );
      },
    );
  }

  Widget _buildScryfallList(dynamic deck, DeckBucket activeBucket) {
    if (_isSearchingScryfall) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
        ),
      );
    }

    if (_scryfallResults.isEmpty) {
      return const Center(
        child: Text(
          'Digita per cercare carte.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    return ListView.separated(
      itemCount: _scryfallResults.length,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final card = _scryfallResults[i];
        final isInDeck = deck.containsCard(card.name);

        return _buildMinimalTile(card, isInDeck, activeBucket);
      },
    );
  }

  Widget _buildMinimalTile(CommanderCard card, bool isInDeck, DeckBucket activeBucket) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // Mini thumbnail
          if (card.artCropUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Image.network(
                card.artCropUrl!,
                width: 32,
                height: 24,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.style, size: 16, color: Colors.white24),
              ),
            ),
          const SizedBox(width: 8),

          // Name and Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.name,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                if (card.edhrecSynergy != null)
                  Text(
                    '${card.edhrecSynergy! >= 0 ? '+' : ''}${(card.edhrecSynergy! * 100).toStringAsFixed(0)}% sinergia',
                    style: TextStyle(
                      fontSize: 10,
                      color: card.edhrecSynergy! >= 0 ? AppTheme.accentGreen : Colors.white38,
                    ),
                  ),
              ],
            ),
          ),

          // Pulsante discreto di aggiunta
          if (isInDeck)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.check, size: 16, color: AppTheme.accentGreen),
            )
          else
            IconButton(
              icon: const Icon(Icons.add, size: 16, color: Colors.white70),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Aggiungi a ${activeBucket.label}',
              onPressed: () {
                ref.read(deckProvider.notifier).addCard(card, targetBucket: activeBucket);
              },
            ),
        ],
      ),
    );
  }
}
