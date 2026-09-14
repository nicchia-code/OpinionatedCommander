import '../models/commander_card.dart';
import '../models/deck_bucket.dart';
import 'staples_database.dart';

class CardClassifier {
  /// Classifica deterministicamente una carta in un unico ruolo primario (Single Slot Rule di BASE.md)
  static DeckBucket classify(CommanderCard card, {List<String>? scryfallTags}) {
    // 1. Controllo nel database staple curato
    final stapleMatch = StaplesDatabase.lookup(card.name);
    if (stapleMatch != null) {
      return stapleMatch;
    }

    // 2. Controllo Terre
    if (card.isLand) {
      return DeckBucket.lands;
    }

    // 3. Scryfall Tagger tags (se presenti)
    if (scryfallTags != null && scryfallTags.isNotEmpty) {
      final tags = scryfallTags.map((t) => t.toLowerCase()).toSet();
      if (tags.contains('board-wipe') || tags.contains('sweeper') || tags.contains('wrath')) {
        return DeckBucket.boardWipe;
      }
      if (tags.contains('removal') || tags.contains('counterspell') || tags.contains('spot-removal')) {
        return DeckBucket.spotRemoval;
      }
      if (tags.contains('ramp') || tags.contains('mana-rock') || tags.contains('mana-dork')) {
        return DeckBucket.ramp;
      }
      if (tags.contains('draw') || tags.contains('card-advantage') || tags.contains('cantrip')) {
        return DeckBucket.draw;
      }
      if (tags.contains('tutor')) {
        return DeckBucket.tutors;
      }
      if (tags.contains('protection') || tags.contains('hexproof') || tags.contains('indestructible')) {
        return DeckBucket.protection;
      }
      if (tags.contains('recursion') || tags.contains('reanimate')) {
        return DeckBucket.recursion;
      }
      if (tags.contains('finisher') || tags.contains('win-condition') || tags.contains('overrun')) {
        return DeckBucket.wincons;
      }
    }

    // 4. Analisi euristica su Oracle text e Type line
    final text = card.oracleText.toLowerCase();

    // Board Wipe
    if (RegExp(r'(destroy|exile)\s+(all|each)\s+(creatures|nonland|permanents)', caseSensitive: false).hasMatch(text) ||
        text.contains('each creature gets -') ||
        text.contains('deals damage to each creature and each')) {
      return DeckBucket.boardWipe;
    }

    // Tutor
    if (text.contains('search your library for a card') ||
        text.contains('search your library for an instant') ||
        text.contains('search your library for an enchantment') ||
        text.contains('search your library for an artifact card')) {
      return DeckBucket.tutors;
    }

    // Ramp
    if (text.contains('search your library for a land card') ||
        text.contains('search your library for a basic land') ||
        text.contains('search your library for up to two basic land') ||
        (card.isArtifact && (text.contains('add {') || text.contains('add one mana'))) ||
        (card.isCreature && (text.contains('{t}: add {') || text.contains('{t}: add one mana')))) {
      return DeckBucket.ramp;
    }

    // Spot Removal / Interaction
    if (RegExp(r'(destroy|exile|counter|return)\s+target\s+(creature|permanent|nonland|spell|artifact|enchantment)', caseSensitive: false).hasMatch(text) ||
        text.contains('target opponent sacrifices a creature') ||
        text.contains('target player sacrifices a creature') ||
        (card.isInstant && (text.contains('counter target') || text.contains('destroy target') || text.contains('exile target')))) {
      return DeckBucket.spotRemoval;
    }

    // Card Draw & Advantage
    if (text.contains('draw two cards') ||
        text.contains('draw three cards') ||
        text.contains('draw cards equal to') ||
        text.contains('draws a card, you may') ||
        text.contains('whenever a creature enters, draw') ||
        text.contains('whenever you cast, draw') ||
        (text.contains('draw a card') && (text.contains('whenever') || text.contains('at the beginning of your')))) {
      return DeckBucket.draw;
    }

    // Protection
    if (text.contains('hexproof') ||
        text.contains('gain indestructible until end of turn') ||
        text.contains('phase out') ||
        text.contains('protection from each color') ||
        text.contains('protection from everything')) {
      return DeckBucket.protection;
    }

    // Recursion
    if (text.contains('return target') && text.contains('from your graveyard') ||
        text.contains('onto the battlefield under your control from') ||
        text.contains('put target creature card from a graveyard onto the battlefield')) {
      return DeckBucket.recursion;
    }

    // Wincons
    if (text.contains('you win the game') ||
        text.contains('opponent loses the game') ||
        text.contains('creatures you control get +') && text.contains('trample')) {
      return DeckBucket.wincons;
    }

    // Default: Engine / Sinergia del comandante
    return DeckBucket.synergyEngine;
  }
}
