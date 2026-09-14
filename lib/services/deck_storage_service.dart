import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/commander_deck.dart';
import '../models/deck_bucket.dart';

class DeckStorageService {
  static const String _deckListKey = 'opinionated_commander_deck_ids';
  static const String _deckPrefix = 'opinionated_deck_';

  /// Salva il mazzo nel LocalStorage
  Future<void> saveDeck(CommanderDeck deck) async {
    final prefs = await SharedPreferences.getInstance();
    final deckJson = json.encode(deck.toJson());
    await prefs.setString('$_deckPrefix${deck.id}', deckJson);

    // Aggiorna l'indice dei mazzi
    final ids = prefs.getStringList(_deckListKey) ?? [];
    if (!ids.contains(deck.id)) {
      ids.add(deck.id);
      await prefs.setStringList(_deckListKey, ids);
    }
  }

  /// Recupera tutti i mazzi salvati
  Future<List<CommanderDeck>> loadAllDecks() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_deckListKey) ?? [];
    final decks = <CommanderDeck>[];

    for (final id in ids) {
      final raw = prefs.getString('$_deckPrefix$id');
      if (raw != null) {
        try {
          final map = json.decode(raw) as Map<String, dynamic>;
          decks.add(CommanderDeck.fromJson(map));
        } catch (_) {}
      }
    }

    decks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return decks;
  }

  /// Cancella un mazzo
  Future<void> deleteDeck(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_deckPrefix$id');
    final ids = prefs.getStringList(_deckListKey) ?? [];
    ids.remove(id);
    await prefs.setStringList(_deckListKey, ids);
  }

  /// Esporta il mazzo in formato testo standard MTG con sezioni opzionali dei bucket
  static String exportToText(CommanderDeck deck, {bool includeBuckets = true}) {
    final buffer = StringBuffer();

    if (deck.commander != null) {
      buffer.writeln('// Commander');
      buffer.writeln('1 ${deck.commander!.name}');
      buffer.writeln();
    }

    if (includeBuckets) {
      for (final bucket in DeckBucket.values) {
        final cards = deck.cardsInBucket(bucket);
        if (cards.isEmpty) continue;

        buffer.writeln('// ${bucket.label} (${cards.length})');
        // Raggruppa copie multiple (ad es. terre base)
        final counts = <String, int>{};
        for (final c in cards) {
          counts[c.name] = (counts[c.name] ?? 0) + 1;
        }

        for (final entry in counts.entries) {
          buffer.writeln('${entry.value} ${entry.key}');
        }
        buffer.writeln();
      }
    } else {
      final counts = <String, int>{};
      for (final c in deck.cards) {
        counts[c.name] = (counts[c.name] ?? 0) + 1;
      }
      for (final entry in counts.entries) {
        buffer.writeln('${entry.value} ${entry.key}');
      }
    }

    return buffer.toString().trim();
  }

  /// Parser semplice per importare una lista di testo standard
  static List<ParsedImportLine> parseImportText(String text) {
    final lines = text.split('\n');
    final results = <ParsedImportLine>[];
    DeckBucket? currentBucket;
    bool isCommanderSection = false;

    for (var rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('//') || line.startsWith('#')) {
        final header = line.replaceAll(RegExp(r'^[/#\s]+'), '').toLowerCase();
        if (header.contains('commander')) {
          isCommanderSection = true;
          currentBucket = null;
        } else {
          isCommanderSection = false;
          currentBucket = _matchBucketFromHeader(header);
        }
        continue;
      }

      // Estrai quantità e nome (es. "1 Sol Ring", "1x Sol Ring", "Sol Ring")
      final match = RegExp(r'^(\d+)\s*[xX]?\s+(.+)$').firstMatch(line);
      int quantity = 1;
      String cardName = line;

      if (match != null) {
        quantity = int.tryParse(match.group(1) ?? '1') ?? 1;
        cardName = match.group(2)?.trim() ?? line;
      }

      // Rimuovi set code trailing se presente: "Card Name (SET) 123"
      cardName = cardName.replaceAll(RegExp(r'\([A-Za-z0-9]+\)\s*[A-Za-z0-9]*$'), '').trim();

      results.add(ParsedImportLine(
        name: cardName,
        quantity: quantity,
        explicitBucket: currentBucket,
        isCommander: isCommanderSection,
      ));
    }

    return results;
  }

  static DeckBucket? _matchBucketFromHeader(String header) {
    for (final bucket in DeckBucket.values) {
      if (header.contains(bucket.label.toLowerCase()) ||
          header.contains(bucket.shortLabel.toLowerCase())) {
        return bucket;
      }
    }
    return null;
  }
}

class ParsedImportLine {
  final String name;
  final int quantity;
  final DeckBucket? explicitBucket;
  final bool isCommander;

  const ParsedImportLine({
    required this.name,
    required this.quantity,
    this.explicitBucket,
    this.isCommander = false,
  });
}
