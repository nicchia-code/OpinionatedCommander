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
    final suggestionsAsync = ref.watch(bucketSuggestionsProvider(activeBucket));

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
                if (!_isScryfallMode) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Ordina:',
                        style: TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ExplorerSortMode.values.map((mode) {
                              final activeSort = ref.watch(explorerSortModeProvider);
                              final isSelected = mode == activeSort;
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: () {
                                    ref.read(explorerSortModeProvider.notifier).state = mode;
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isSelected ? Colors.white24 : Colors.transparent,
                                      ),
                                    ),
                                    child: Text(
                                      mode.label,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? Colors.white : Colors.white54,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderDark),

          // Risultati
          Expanded(
            child: _isScryfallMode
                ? _buildScryfallList(deck, activeBucket)
                : _buildSuggestionsList(suggestionsAsync, deck, activeBucket),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(
    AsyncValue<List<CommanderCard>> suggestionsAsync,
    dynamic deck,
    DeckBucket activeBucket,
  ) {
    return suggestionsAsync.when(
      loading: () => const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
        ),
      ),
      error: (err, _) => Center(
        child: Text('Errore suggerimenti: $err', style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ),
      data: (allCards) {
        final query = _searchCtrl.text.trim().toLowerCase();
        final filtered = allCards.where((c) {
          return query.isEmpty || c.name.toLowerCase().contains(query);
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
                Row(
                  children: [
                    if (card.edhrecSynergy != null) ...[
                      Text(
                        '${card.edhrecSynergy! >= 0 ? '+' : ''}${(card.edhrecSynergy! * 100).toStringAsFixed(0)}% sinergia',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: card.edhrecSynergy! >= 0 ? AppTheme.accentGreen : Colors.white38,
                        ),
                      ),
                      const Text(
                        ' • ',
                        style: TextStyle(fontSize: 10, color: Colors.white24),
                      ),
                      Text(
                        '${(card.calculatedAffinity * 100).toStringAsFixed(0)}% affinità',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.accentBlue,
                        ),
                      ),
                    ] else ...[
                      Text(
                        '${(card.calculatedAffinity * 100).toStringAsFixed(0)}% affinità',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentBlue,
                        ),
                      ),
                      if (card.edhrecDistance != null) ...[
                        const Text(
                          ' • ',
                          style: TextStyle(fontSize: 10, color: Colors.white24),
                        ),
                        Text(
                          'dist. ${card.edhrecDistance!.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 10, color: Colors.white38),
                        ),
                      ],
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Badge Prezzo (EUR / USD) in evidenza prima dell'aggiunta
          Builder(
            builder: (context) {
              final priceEur = card.numericPriceEur;
              Color priceBg = Colors.white.withValues(alpha: 0.08);
              Color priceTextColor = Colors.white70;
              if (priceEur != null) {
                if (priceEur < 1.0) {
                  priceBg = AppTheme.accentGreen.withValues(alpha: 0.16);
                  priceTextColor = AppTheme.accentGreen;
                } else if (priceEur > 7.0) {
                  priceBg = Colors.amber.withValues(alpha: 0.16);
                  priceTextColor = Colors.amber.shade200;
                }
              }

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: priceBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: priceTextColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  card.formattedPrice ?? '—',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: priceTextColor,
                  ),
                ),
              );
            },
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
