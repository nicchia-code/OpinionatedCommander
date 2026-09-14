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

/// Bucket attualmente selezionato nel pannello di sinistra per filtrare l'explorer a destra
final selectedBucketProvider = StateProvider<DeckBucket>((ref) => DeckBucket.synergyEngine);

/// Query di ricerca nell'explorer a destra
final explorerSearchQueryProvider = StateProvider<String>((ref) => '');

/// Notifier per la gestione dello stato del mazzo corrente
class DeckNotifier extends StateNotifier<CommanderDeck> {
  final DeckStorageService _storage;
  final ScryfallService _scryfall;

  DeckNotifier(this._storage, this._scryfall)
      : super(CommanderDeck(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Nuovo Mazzo Commander',
          updatedAt: DateTime.now(),
        ));

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

/// Raccomandazioni EDHREC per il comandante corrente
final edhrecRecommendationsProvider = FutureProvider<List<CommanderCard>>((ref) async {
  final deck = ref.watch(deckProvider);
  if (deck.commander == null) return [];
  final edhrec = ref.watch(edhrecServiceProvider);
  return await edhrec.fetchCommanderRecommendations(deck.commander!.name);
});

/// Suggerimenti arricchiti per il bucket selezionato (EDHREC + Scryfall Functional Equivalents + Deck Synergy Sorter)
final bucketSuggestionsProvider = FutureProvider.family<List<CommanderCard>, DeckBucket>((ref, bucket) async {
  final deck = ref.watch(deckProvider);
  if (deck.commander == null) return [];

  final edhrecAsync = await ref.watch(edhrecRecommendationsProvider.future);
  final edhrecCardsForBucket = edhrecAsync.where((c) => c.bucket == bucket).toList();

  final scryfall = ref.watch(scryfallServiceProvider);
  final scryfallCards = await scryfall.fetchFunctionalEquivalentsForBucket(
    bucket: bucket,
    colorIdentity: deck.commander!.colorIdentity,
  );

  // Unione senza duplicati: EDHREC mantiene la priorità con i dati di sinergia
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

  // Profilo lessicale e meccanico delle carte EDHREC per questo comandante
  final edhrecVocab = <String>{};
  for (final card in edhrecAsync) {
    final tokens = '${card.name} ${card.typeLine} ${card.oracleText}'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3);
    edhrecVocab.addAll(tokens);
  }

  // Cross-deck synergy analysis: parole chiave dal mazzo attuale
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

  // Calcola punteggio di similarità/distanza con EDHREC per ogni carta
  final scoredCards = merged.map((card) {
    final cardTokens = '${card.name} ${card.typeLine} ${card.oracleText}'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3)
        .toSet();

    double similarity;
    if (card.edhrecSynergy != null) {
      // Se proviene da EDHREC, baseline alta + bonus sinergia/inclusione
      similarity = 0.70 + (card.edhrecSynergy! * 0.20) + ((card.edhrecInclusion ?? 0.0) * 0.10);
    } else {
      // Misura distanza / sovrapposizione lessicale con l'insieme EDHREC
      final overlap = cardTokens.intersection(edhrecVocab).length;
      final ratio = edhrecVocab.isNotEmpty ? (overlap / (cardTokens.length + 3)).clamp(0.0, 1.0) : 0.0;
      similarity = 0.40 + (ratio * 0.50);
    }

    // Bonus sinergia con il mazzo attuale
    final cardFullText = '${card.name} ${card.typeLine} ${card.oracleText}'.toLowerCase();
    for (final entry in deckKeywords.entries) {
      if (cardFullText.contains(entry.key)) {
        similarity += (entry.value * 0.03);
      }
    }

    similarity = similarity.clamp(0.05, 0.99);
    return card.copyWith(similarityScore: similarity);
  }).toList();

  // Ordina per similarity score decrescente
  scoredCards.sort((a, b) => (b.similarityScore ?? 0.0).compareTo(a.similarityScore ?? 0.0));

  return scoredCards;
});
