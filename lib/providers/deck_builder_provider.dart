import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/archetype.dart';
import '../models/commander_card.dart';
import '../models/commander_deck.dart';
import '../models/deck_bucket.dart';
import '../models/guardrail_report.dart';
import '../services/card_classifier.dart';
import '../services/deck_storage_service.dart';
import '../services/edhrec_service.dart';
import '../services/mana_base_calculator.dart';
import '../services/scryfall_service.dart';

final edhrecServiceProvider = Provider<EdhrecService>((ref) => EdhrecService());
final scryfallServiceProvider = Provider<ScryfallService>((ref) => ScryfallService());
final deckStorageServiceProvider = Provider<DeckStorageService>((ref) => DeckStorageService());

/// Modalità di ordinamento dei suggerimenti nell'explorer
enum ExplorerSortMode {
  edhrecDistance('Affinità EDHREC'),
  priceAsc('Prezzo € ↗'),
  priceDesc('Prezzo € ↘'),
  cmc('Mana Value');

  final String label;
  const ExplorerSortMode(this.label);
}

final explorerSortModeProvider = StateProvider<ExplorerSortMode>((ref) => ExplorerSortMode.edhrecDistance);

/// Bucket attualmente selezionato nel pannello di sinistra per filtrare l'explorer a destra
final selectedBucketProvider = StateProvider<DeckBucket>((ref) => DeckBucket.synergyEngine);

/// Query di ricerca nell'explorer a destra
final explorerSearchQueryProvider = StateProvider<String>((ref) => '');

final savedDecksProvider = FutureProvider.autoDispose<List<CommanderDeck>>((ref) async {
  ref.watch(deckProvider.select((d) => d.updatedAt));
  final storage = ref.watch(deckStorageServiceProvider);
  return storage.loadAllDecks();
});

/// Notifier per la gestione dello stato del mazzo corrente
class DeckNotifier extends StateNotifier<CommanderDeck> {
  final DeckStorageService _storage;
  final ScryfallService _scryfall;

  DeckNotifier(this._storage, this._scryfall)
      : super(CommanderDeck(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Nuovo Mazzo Commander',
          updatedAt: DateTime.now(),
        )) {
    _autoRestoreLastDeck();
  }

  Future<void> _autoRestoreLastDeck() async {
    final lastDeck = await _storage.loadLastActiveDeck();
    if (lastDeck != null && lastDeck.commander != null) {
      state = lastDeck;
      hydrateMissingPrices();
    }
  }

  void setCommander(CommanderCard commander) {
    state = state.copyWith(
      commander: commander.copyWith(isCommander: true),
      name: 'Mazzo ${commander.name}',
      updatedAt: DateTime.now(),
    );
    _storage.saveDeck(state);
  }

  void setArchetype(Archetype archetype) {
    state = state.copyWith(archetype: archetype, updatedAt: DateTime.now());
    _storage.saveDeck(state);
  }

  void setDeckName(String name) {
    state = state.copyWith(name: name, updatedAt: DateTime.now());
    _storage.saveDeck(state);
  }

  /// Aggiunge una carta rispettando la Single Slot Rule di BASE.md
  bool addCard(CommanderCard card, {DeckBucket? targetBucket}) {
    // Controllo singleton (tranne terre base)
    if (!card.isBasicLand && state.containsCard(card.name)) {
      return false;
    }

    final role = targetBucket ?? card.bucket ?? CardClassifier.classify(card);
    final cardToAdd = card.copyWith(
      id: card.id.isNotEmpty ? card.id : 'card-${DateTime.now().microsecondsSinceEpoch}',
      bucket: role,
    );

    state = state.copyWith(
      cards: [...state.cards, cardToAdd],
      updatedAt: DateTime.now(),
    );

    _storage.saveDeck(state);
    return true;
  }

  void removeCard(String cardId) {
    state = state.copyWith(
      cards: state.cards.where((c) => c.id != cardId).toList(),
      updatedAt: DateTime.now(),
    );
    _storage.saveDeck(state);
  }

  void moveCardToBucket(String cardId, DeckBucket newBucket) {
    state = state.copyWith(
      cards: state.cards.map((c) {
        if (c.id == cardId) {
          return c.copyWith(bucket: newBucket);
        }
        return c;
      }).toList(),
      updatedAt: DateTime.now(),
    );
    _storage.saveDeck(state);
  }

  /// Riempimento proporzionale automatico delle terre base mancanti
  int autoFillBasicLands() {
    final missing = ManaBaseCalculator.calculateMissingBasics(state);
    if (missing.isEmpty) return 0;

    state = state.copyWith(
      cards: [...state.cards, ...missing],
      updatedAt: DateTime.now(),
    );

    _storage.saveDeck(state);
    return missing.length;
  }

  void clearDeck() {
    state = CommanderDeck(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Nuovo Mazzo Commander',
      updatedAt: DateTime.now(),
    );
  }

  void loadDeck(CommanderDeck loadedDeck) {
    state = loadedDeck;
    _storage.saveDeck(state);
    hydrateMissingPrices();
  }

  Future<void> deleteDeck(String id) async {
    await _storage.deleteDeck(id);
    if (state.id == id) {
      clearDeck();
    }
  }

  /// Recupera in background i prezzi Scryfall per le carte pre-esistenti prive di prezzo
  Future<void> hydrateMissingPrices() async {
    final missingCards = state.cards.where((c) => c.priceEur == null && c.priceUsd == null).toList();
    final missingCmd = state.commander != null && state.commander!.priceEur == null && state.commander!.priceUsd == null;

    if (missingCards.isEmpty && !missingCmd) return;

    final ids = [
      if (missingCmd) state.commander!.id,
      for (final c in missingCards) c.id,
    ].where((id) => id.isNotEmpty).toList();

    if (ids.isEmpty) return;

    final details = await _scryfall.fetchCardsByIds(ids);

    var updatedCmd = state.commander;
    if (updatedCmd != null && details.containsKey(updatedCmd.id)) {
      final d = details[updatedCmd.id]!;
      updatedCmd = updatedCmd.copyWith(
        priceEur: d.priceEur,
        priceUsd: d.priceUsd,
        imageUrl: d.imageUrl ?? updatedCmd.imageUrl,
        artCropUrl: d.artCropUrl ?? updatedCmd.artCropUrl,
      );
    }

    final updatedCards = state.cards.map((c) {
      if (details.containsKey(c.id)) {
        final d = details[c.id]!;
        return c.copyWith(
          priceEur: d.priceEur,
          priceUsd: d.priceUsd,
          imageUrl: d.imageUrl ?? c.imageUrl,
          artCropUrl: d.artCropUrl ?? c.artCropUrl,
          oracleText: d.oracleText.isNotEmpty ? d.oracleText : c.oracleText,
          typeLine: d.typeLine.isNotEmpty ? d.typeLine : c.typeLine,
        );
      }
      return c;
    }).toList();

    state = state.copyWith(
      commander: updatedCmd,
      cards: updatedCards,
      updatedAt: DateTime.now(),
    );
    await _storage.saveDeck(state);
  }

  /// Importazione testo standard MTG
  Future<int> importFromText(String text) async {
    final lines = DeckStorageService.parseImportText(text);
    int addedCount = 0;

    CommanderCard? newCommander;
    final importedCards = <CommanderCard>[];

    for (final line in lines) {
      // Dettagli carta da Scryfall o template placeholder
      var card = await _scryfall.getCardByName(line.name);
      card ??= CommanderCard(
        id: 'imported-${line.name.toLowerCase().replaceAll(' ', '-')}',
        name: line.name,
      );

      if (line.isCommander && newCommander == null) {
        newCommander = card.copyWith(isCommander: true);
        continue;
      }

      final bucket = line.explicitBucket ?? CardClassifier.classify(card);

      for (int i = 0; i < line.quantity; i++) {
        // Regola singleton per non-basic
        if (!card.isBasicLand &&
            importedCards.any((c) => c.name.toLowerCase() == card!.name.toLowerCase())) {
          continue;
        }

        importedCards.add(card.copyWith(
          id: '${card.id}-$i-${DateTime.now().microsecondsSinceEpoch}',
          bucket: bucket,
        ));
        addedCount++;
      }
    }

    state = state.copyWith(
      commander: newCommander ?? state.commander,
      name: newCommander != null ? 'Mazzo ${newCommander.name}' : state.name,
      cards: [...state.cards, ...importedCards],
      updatedAt: DateTime.now(),
    );

    await _storage.saveDeck(state);
    return addedCount;
  }
}

final deckProvider = StateNotifierProvider<DeckNotifier, CommanderDeck>((ref) {
  final storage = ref.watch(deckStorageServiceProvider);
  final scryfall = ref.watch(scryfallServiceProvider);
  return DeckNotifier(storage, scryfall);
});

/// Report calcolato in tempo reale su conformità guardrail di BASE.md
final guardrailReportProvider = Provider<GuardrailReport>((ref) {
  final deck = ref.watch(deckProvider);
  return GuardrailReport.fromDeck(deck);
});

/// Raccomandazioni EDHREC per il comandante corrente arricchite con Scryfall (prezzi, testo, ruoli)
final edhrecRecommendationsProvider = FutureProvider<List<CommanderCard>>((ref) async {
  final deck = ref.watch(deckProvider);
  if (deck.commander == null) return [];
  final edhrec = ref.watch(edhrecServiceProvider);
  final rawCards = await edhrec.fetchCommanderRecommendations(deck.commander!.name);
  if (rawCards.isEmpty) return [];

  // Batch enrichment Scryfall: prezzi EUR/USD reali e testo completo per TUTTE le carte EDHREC
  final scryfall = ref.watch(scryfallServiceProvider);
  final allIds = rawCards.map((c) => c.id).where((id) => id.isNotEmpty).toList();
  final detailsMap = await scryfall.fetchCardsByIds(allIds);

  return rawCards.map((c) {
    final details = detailsMap[c.id];
    if (details != null) {
      final enriched = c.copyWith(
        manaCost: details.manaCost.isNotEmpty ? details.manaCost : c.manaCost,
        cmc: details.cmc > 0 ? details.cmc : c.cmc,
        typeLine: details.typeLine.isNotEmpty ? details.typeLine : c.typeLine,
        oracleText: details.oracleText.isNotEmpty ? details.oracleText : c.oracleText,
        imageUrl: details.imageUrl ?? c.imageUrl,
        artCropUrl: details.artCropUrl ?? c.artCropUrl,
        priceEur: details.priceEur ?? c.priceEur,
        priceUsd: details.priceUsd ?? c.priceUsd,
        colors: details.colors.isNotEmpty ? details.colors : c.colors,
        colorIdentity: details.colorIdentity.isNotEmpty ? details.colorIdentity : c.colorIdentity,
      );
      // Ri-classifica con precisione tramite Oracle text e types completi
      final role = CardClassifier.classify(enriched);
      return enriched.copyWith(bucket: role);
    }
    return c;
  }).toList();
});

/// Suggerimenti arricchiti per il bucket selezionato (EDHREC + Scryfall Functional Equivalents + Deck Synergy Sorter)
final bucketSuggestionsProvider = FutureProvider.family<List<CommanderCard>, DeckBucket>((ref, bucket) async {
  final deck = ref.watch(deckProvider);
  if (deck.commander == null) return [];

  final edhrecAsync = await ref.watch(edhrecRecommendationsProvider.future);
  final edhrecCardsForBucket = edhrecAsync.where((c) => c.bucket == bucket).toList();

  final scryfall = ref.watch(scryfallServiceProvider);

  // Equivalenti funzionali da Scryfall per espandere lo slot se EDHREC ha pochi suggerimenti
  final scryfallCards = await scryfall.fetchFunctionalEquivalentsForBucket(
    bucket: bucket,
    colorIdentity: deck.commander!.colorIdentity,
  );

  // Unione deduplicata mantenendo la priorità delle metriche EDHREC
  final seenNames = <String>{};
  final merged = <CommanderCard>[];

  for (final card in edhrecCardsForBucket) {
    seenNames.add(card.name.toLowerCase());
    merged.add(card);
  }

  for (final card in scryfallCards) {
    if (!seenNames.contains(card.name.toLowerCase())) {
      seenNames.add(card.name.toLowerCase());
      merged.add(card);
    }
  }

  // Profilo lessicale e meccanico dell'insieme raccomandato da EDHREC per questo comandante
  final edhrecVocab = <String>{};
  for (final card in edhrecAsync) {
    final tokens = '${card.name} ${card.typeLine} ${card.oracleText}'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3);
    edhrecVocab.addAll(tokens);
  }

  // Se edhrecVocab è scarno, includi anche i token del comandante
  if (deck.commander != null) {
    final cmdTokens = '${deck.commander!.name} ${deck.commander!.typeLine} ${deck.commander!.oracleText}'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3);
    edhrecVocab.addAll(cmdTokens);
  }

  // Cross-deck synergy analysis: frequenza temi e keyword attive nel mazzo corrente
  final deckKeywords = <String, int>{};
  final allDeckTexts = [
    if (deck.commander != null) '${deck.commander!.name} ${deck.commander!.typeLine} ${deck.commander!.oracleText}',
    for (final c in deck.cards) '${c.name} ${c.typeLine} ${c.oracleText}',
  ].join(' ').toLowerCase();

  const candidateKeywords = [
    'token', 'tokens', '+1/+1', 'counter', 'counters', 'sacrifice', 'sacrifices',
    'graveyard', 'dies', 'artifact', 'artifacts', 'enchantment', 'enchantments',
    'draw', 'discard', 'flying', 'trample', 'lifelink', 'deathtouch', 'haste',
    'goblin', 'goblins', 'elf', 'elves', 'dragon', 'dragons', 'zombie', 'zombies',
    'vampire', 'vampires', 'phyrexian', 'wizard', 'spellslinger', 'instant', 'sorcery'
  ];

  for (final kw in candidateKeywords) {
    final count = RegExp(r'\b' + RegExp.escape(kw) + r'\b').allMatches(allDeckTexts).length;
    if (count > 0) {
      deckKeywords[kw] = count;
    }
  }

  // Calcolo deterministico della distanza e del punteggio per ogni carta
  final scoredCards = merged.map((card) {
    final cardTokens = '${card.name} ${card.typeLine} ${card.oracleText}'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3)
        .toSet();

    double deckSynergyBonus = 0.0;
    final cardFullText = '${card.name} ${card.typeLine} ${card.oracleText}'.toLowerCase();
    for (final entry in deckKeywords.entries) {
      if (cardFullText.contains(entry.key)) {
        deckSynergyBonus += (entry.value.clamp(1, 3) * 0.03);
      }
    }

    double distance;
    if (card.edhrecSynergy != null) {
      // Carta ufficiale EDHREC: distanza minima modulata da sinergia e frequenza di inclusione
      final synBonus = (card.edhrecSynergy! * 0.08);
      final incBonus = ((card.edhrecInclusion ?? 0.0) * 0.04);
      distance = (0.12 - synBonus - incBonus - deckSynergyBonus).clamp(0.01, 0.25);
    } else {
      // Equivalente funzionale Scryfall: distanza basata su sovrapposizione lessicale con l'insieme EDHREC
      final overlap = cardTokens.intersection(edhrecVocab).length;
      final jaccardRatio = edhrecVocab.isNotEmpty ? (overlap / (cardTokens.length + 3)).clamp(0.0, 1.0) : 0.0;
      final jaccardDistance = 1.0 - jaccardRatio;

      double cmcAdjustment = 0.0;
      if (bucket == DeckBucket.ramp || bucket == DeckBucket.spotRemoval) {
        if (card.cmc <= 2) cmcAdjustment = -0.04;
        if (card.cmc > 4) cmcAdjustment = 0.06;
      }

      distance = (0.28 + (jaccardDistance * 0.42) - deckSynergyBonus + cmcAdjustment).clamp(0.18, 0.95);
    }

    final affinity = (1.0 - distance).clamp(0.05, 0.99);

    return card.copyWith(
      edhrecDistance: distance,
      similarityScore: affinity,
    );
  }).toList();

  // Ordinamento configurabile secondo explorerSortModeProvider
  final sortMode = ref.watch(explorerSortModeProvider);
  scoredCards.sort((a, b) {
    switch (sortMode) {
      case ExplorerSortMode.edhrecDistance:
        // Distanza EDHREC minore = carta più affine
        return (a.edhrecDistance ?? 1.0).compareTo(b.edhrecDistance ?? 1.0);
      case ExplorerSortMode.priceAsc:
        // Più economica prima; le carte senza prezzo finiscono in fondo
        final pa = a.primaryNumericPrice ?? 9999.0;
        final pb = b.primaryNumericPrice ?? 9999.0;
        return pa.compareTo(pb);
      case ExplorerSortMode.priceDesc:
        // Più costosa prima
        final pa = a.primaryNumericPrice ?? -1.0;
        final pb = b.primaryNumericPrice ?? -1.0;
        return pb.compareTo(pa);
      case ExplorerSortMode.cmc:
        // Mana value crescente
        return a.cmc.compareTo(b.cmc);
    }
  });

  return scoredCards;
});
