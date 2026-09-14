import '../models/commander_card.dart';
import '../models/commander_deck.dart';
import '../models/deck_bucket.dart';

class ManaBaseCalculator {
  static const Map<String, String> basicLandNames = {
    'W': 'Plains',
    'U': 'Island',
    'B': 'Swamp',
    'R': 'Mountain',
    'G': 'Forest',
  };

  static const Map<String, String> basicLandImages = {
    'Plains': 'https://cards.scryfall.io/normal/front/e/0/e06bfb8e-fb67-4d43-a612-42171128df62.jpg',
    'Island': 'https://cards.scryfall.io/normal/front/1/9/1944da22-5441-4566-a36c-2f3b90033100.jpg',
    'Swamp': 'https://cards.scryfall.io/normal/front/3/9/39f0ef77-a9a3-4a17-bb96-6d6015c7cb17.jpg',
    'Mountain': 'https://cards.scryfall.io/normal/front/3/b/3b45a6c3-1d09-40ea-a4e9-11c216c87514.jpg',
    'Forest': 'https://cards.scryfall.io/normal/front/9/6/9605333f-6ce0-4c28-971c-7fcfe5c2a11b.jpg',
    'Wastes': 'https://cards.scryfall.io/normal/front/5/8/5812e912-1f4a-4d73-b348-18e001850fc4.jpg',
  };

  /// Calcola e genera le terre base mancanti per raggiungere la quota stabilita da BASE.md
  static List<CommanderCard> calculateMissingBasics(CommanderDeck deck) {
    final targetLandCount = deck.archetype.targetFor(DeckBucket.lands);
    final currentLands = deck.countInBucket(DeckBucket.lands);
    final needed = targetLandCount - currentLands;

    if (needed <= 0) {
      return [];
    }

    // Identità di colore dal comandante (oppure dai pips presenti)
    final identity = (deck.commander?.colorIdentity.isNotEmpty ?? false)
        ? deck.commander!.colorIdentity
        : ['W', 'U', 'B', 'R', 'G'];

    if (identity.isEmpty) {
      // Mazzo incolore: distribuisce Wastes
      return List.generate(
        needed,
        (i) => CommanderCard(
          id: 'basic-wastes-$i',
          name: 'Wastes',
          typeLine: 'Basic Land',
          bucket: DeckBucket.lands,
          imageUrl: basicLandImages['Wastes'],
        ),
      );
    }

    final pips = deck.manaPips;
    // Filtra i pips per l'identità del comandante
    final activePips = <String, int>{};
    int totalActivePips = 0;
    for (final color in identity) {
      final count = pips[color] ?? 0;
      activePips[color] = count;
      totalActivePips += count;
    }

    final landAllocations = <String, int>{};

    if (totalActivePips == 0) {
      // Se non ci sono ancora carte colorate, dividi equamente tra i colori dell'identità
      final perColor = needed ~/ identity.length;
      int remainder = needed % identity.length;
      for (final color in identity) {
        landAllocations[color] = perColor + (remainder > 0 ? 1 : 0);
        if (remainder > 0) remainder--;
      }
    } else {
      // Largest Remainder Method per arrotondamento perfetto a `needed`
      final fractional = <String, double>{};
      int allocated = 0;

      for (final color in identity) {
        final ratio = (activePips[color] ?? 0) / totalActivePips;
        final exactCount = ratio * needed;
        final floorCount = exactCount.floor();
        landAllocations[color] = floorCount;
        allocated += floorCount;
        fractional[color] = exactCount - floorCount;
      }

      int remaining = needed - allocated;
      final sortedColors = identity.toList()
        ..sort((a, b) => (fractional[b] ?? 0).compareTo(fractional[a] ?? 0));

      for (int i = 0; i < remaining; i++) {
        final color = sortedColors[i % sortedColors.length];
        landAllocations[color] = (landAllocations[color] ?? 0) + 1;
      }
    }

    // Costruisci le carte risultanti
    final result = <CommanderCard>[];
    int counter = 0;
    for (final entry in landAllocations.entries) {
      final color = entry.key;
      final count = entry.value;
      final landName = basicLandNames[color] ?? 'Wastes';

      for (int i = 0; i < count; i++) {
        result.add(CommanderCard(
          id: 'auto-basic-$color-${counter++}',
          name: landName,
          typeLine: 'Basic Land — $landName',
          colorIdentity: [color],
          colors: const [],
          bucket: DeckBucket.lands,
          imageUrl: basicLandImages[landName],
        ));
      }
    }

    return result;
  }
}
