import 'package:flutter_test/flutter_test.dart';
import 'package:opinionated_commander/models/archetype.dart';
import 'package:opinionated_commander/models/commander_card.dart';
import 'package:opinionated_commander/models/commander_deck.dart';
import 'package:opinionated_commander/models/deck_bucket.dart';
import 'package:opinionated_commander/models/guardrail_report.dart';
import 'package:opinionated_commander/services/card_classifier.dart';
import 'package:opinionated_commander/services/deck_storage_service.dart';
import 'package:opinionated_commander/services/mana_base_calculator.dart';

void main() {
  group('Classificazione deterministica BASE.md', () {
    test('Classifica staple noti dal database', () {
      expect(
        CardClassifier.classify(const CommanderCard(id: '1', name: 'Sol Ring')),
        DeckBucket.ramp,
      );
      expect(
        CardClassifier.classify(const CommanderCard(id: '2', name: 'Swords to Plowshares')),
        DeckBucket.spotRemoval,
      );
      expect(
        CardClassifier.classify(const CommanderCard(id: '3', name: 'Blasphemous Act')),
        DeckBucket.boardWipe,
      );
      expect(
        CardClassifier.classify(const CommanderCard(id: '4', name: 'Rhystic Study')),
        DeckBucket.draw,
      );
      expect(
        CardClassifier.classify(const CommanderCard(id: '5', name: 'Heroic Intervention')),
        DeckBucket.protection,
      );
      expect(
        CardClassifier.classify(const CommanderCard(id: '6', name: 'Demonic Tutor')),
        DeckBucket.tutors,
      );
      expect(
        CardClassifier.classify(const CommanderCard(id: '7', name: 'Craterhoof Behemoth')),
        DeckBucket.wincons,
      );
      expect(
        CardClassifier.classify(const CommanderCard(id: '8', name: 'Reanimate')),
        DeckBucket.recursion,
      );
    });

    test('Classifica tramite euristiche su Oracle Text', () {
      const customWipe = CommanderCard(
        id: 'w1',
        name: 'Custom Wrath',
        oracleText: 'Destroy all creatures. They can\'t be regenerated.',
      );
      expect(CardClassifier.classify(customWipe), DeckBucket.boardWipe);

      const customDraw = CommanderCard(
        id: 'd1',
        name: 'Custom Draw Spell',
        oracleText: 'Draw three cards, then discard a card.',
      );
      expect(CardClassifier.classify(customDraw), DeckBucket.draw);
    });
  });

  group('ManaBaseCalculator e distribuzione terre base', () {
    test('Calcola e distribuisce terre base residue in base ai pips', () {
      final deck = CommanderDeck(
        id: 'test-deck',
        name: 'Test Deck',
        commander: const CommanderCard(
          id: 'c1',
          name: 'Atraxa',
          colorIdentity: ['W', 'U', 'B', 'G'],
        ),
        cards: [
          // 4 non-basic lands
          const CommanderCard(id: 'l1', name: 'Command Tower', typeLine: 'Land', bucket: DeckBucket.lands),
          const CommanderCard(id: 'l2', name: 'Overgrown Tomb', typeLine: 'Land', bucket: DeckBucket.lands),
          const CommanderCard(id: 'l3', name: 'Watery Grave', typeLine: 'Land', bucket: DeckBucket.lands),
          const CommanderCard(id: 'l4', name: 'Temple Garden', typeLine: 'Land', bucket: DeckBucket.lands),
          // Spells with pips (Heavy Black and Green)
          const CommanderCard(id: 's1', name: 'Spell 1', manaCost: '{B}{B}{G}', cmc: 3, bucket: DeckBucket.synergyEngine),
          const CommanderCard(id: 's2', name: 'Spell 2', manaCost: '{B}{B}{U}', cmc: 3, bucket: DeckBucket.synergyEngine),
          const CommanderCard(id: 's3', name: 'Spell 3', manaCost: '{W}{G}', cmc: 2, bucket: DeckBucket.synergyEngine),
        ],
        archetype: Archetype.midrange, // Target: 36 lands
        updatedAt: DateTime.now(),
      );

      final basics = ManaBaseCalculator.calculateMissingBasics(deck);
      // Mancano 36 - 4 = 32 terre base
      expect(basics.length, 32);

      // Le terre generate devono essere assegnate al bucket lands
      expect(basics.every((c) => c.bucket == DeckBucket.lands), isTrue);

      // Più Swamps dovute ai pips neri predominanti
      final swamps = basics.where((c) => c.name == 'Swamp').length;
      final islands = basics.where((c) => c.name == 'Island').length;
      expect(swamps > islands, isTrue);
    });
  });

  group('GuardrailReport e vincoli BASE.md', () {
    test('Rileva mancati target e genera alert', () {
      final deck = CommanderDeck(
        id: 'test-deck-2',
        name: 'Incomplete Deck',
        commander: const CommanderCard(id: 'c1', name: 'Krenko', colorIdentity: ['R']),
        cards: [
          const CommanderCard(id: 's1', name: 'Lightning Bolt', manaCost: '{R}', cmc: 1, typeLine: 'Instant', bucket: DeckBucket.spotRemoval),
        ],
        updatedAt: DateTime.now(),
      );

      final report = GuardrailReport.fromDeck(deck);
      expect(report.isClean, isFalse);
      expect(report.alerts.any((a) => a.title == 'Mazzo incompleto'), isTrue);
      expect(report.alerts.any((a) => a.title == 'Terre sotto soglia minima'), isTrue);
    });
  });

  group('Import ed Export testuale MTG', () {
    test('Esporta ed effettua parsing con bucket categorizzati', () {
      final deck = CommanderDeck(
        id: 'export-test',
        name: 'Export Deck',
        commander: const CommanderCard(id: 'c1', name: 'Krenko, Mob Boss', isCommander: true),
        cards: [
          const CommanderCard(id: 'r1', name: 'Sol Ring', bucket: DeckBucket.ramp),
          const CommanderCard(id: 'sp1', name: 'Chaos Warp', bucket: DeckBucket.spotRemoval),
        ],
        updatedAt: DateTime.now(),
      );

      final exported = DeckStorageService.exportToText(deck, includeBuckets: true);
      expect(exported, contains('// Commander'));
      expect(exported, contains('1 Krenko, Mob Boss'));
      expect(exported, contains('// Ramp (1)'));
      expect(exported, contains('1 Sol Ring'));

      final parsed = DeckStorageService.parseImportText(exported);
      expect(parsed.length, 3);
      expect(parsed.first.isCommander, isTrue);
      expect(parsed.first.name, 'Krenko, Mob Boss');
      expect(parsed[1].name, 'Sol Ring');
      expect(parsed[1].explicitBucket, DeckBucket.ramp);
    });
  });

  group('Pricing e scoring per distanza EDHREC', () {
    test('Calcolo prezzi numerici e formattazione EUR/USD', () {
      const cardEur = CommanderCard(id: 'c1', name: 'Card 1', priceEur: '1.25');
      expect(cardEur.numericPriceEur, 1.25);
      expect(cardEur.formattedPrice, '€1.25');

      const cardUsd = CommanderCard(id: 'c2', name: 'Card 2', priceUsd: '0.99');
      expect(cardUsd.numericPriceUsd, 0.99);
      expect(cardUsd.formattedPrice, '\$0.99');

      final deck = CommanderDeck(
        id: 'deck-price-test',
        name: 'Price Test',
        commander: const CommanderCard(id: 'cmd', name: 'Cmd', priceEur: '5.00', isCommander: true),
        cards: [
          const CommanderCard(id: 'c1', name: 'Card 1', priceEur: '2.50'),
          const CommanderCard(id: 'c2', name: 'Card 2', priceEur: '1.50'),
        ],
        updatedAt: DateTime.now(),
      );
      expect(deck.totalPriceEur, 9.0);
      expect(deck.formattedTotalPrice, '€9.00');
    });

    test('Scoring e affinità basati su distanza EDHREC', () {
      // Carta EDHREC con distanza bassa (0.05) -> alta affinità (95%)
      const edhrecCard = CommanderCard(
        id: 'e1',
        name: 'High Synergy',
        edhrecDistance: 0.05,
      );
      expect(edhrecCard.calculatedAffinity, closeTo(0.95, 0.01));

      // Carta lontana (distanza 0.60) -> affinità 40%
      const distantCard = CommanderCard(
        id: 'e2',
        name: 'Distant Card',
        edhrecDistance: 0.60,
      );
      expect(distantCard.calculatedAffinity, closeTo(0.40, 0.01));
    });
  });
}
