import 'archetype.dart';
import 'commander_card.dart';
import 'deck_bucket.dart';

class CommanderDeck {
  final String id;
  final String name;
  final CommanderCard? commander;
  final Archetype archetype;
  final List<CommanderCard> cards;
  final DateTime updatedAt;

  const CommanderDeck({
    required this.id,
    required this.name,
    this.commander,
    this.archetype = Archetype.midrange,
    this.cards = const [],
    required this.updatedAt,
  });

  /// Conteggio totale: 99 carte nel mazzo + 1 comandante (target: 100)
  int get totalCards => cards.length + (commander != null ? 1 : 0);

  /// 99 carte escluso comandante
  int get mainDeckCount => cards.length;

  List<CommanderCard> cardsInBucket(DeckBucket bucket) =>
      cards.where((c) => c.bucket == bucket).toList();

  int countInBucket(DeckBucket bucket) => cardsInBucket(bucket).length;

  bool containsCard(String cardName) =>
      cards.any((c) => c.name.toLowerCase() == cardName.toLowerCase()) ||
      (commander?.name.toLowerCase() == cardName.toLowerCase());

  /// Conta quanti pips di mana di ciascun colore (W, U, B, R, G) compaiono nelle carte non-terra
  Map<String, int> get manaPips {
    final counts = {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0};
    for (final card in cards) {
      if (card.isLand) continue;
      final cost = card.manaCost.toUpperCase();
      for (final color in counts.keys) {
        // Conta occorrenze di {W}, {U}, ecc.
        final regex = RegExp('\\{$color(\\/[A-Z0-9])?\\}');
        counts[color] = (counts[color] ?? 0) + regex.allMatches(cost).length;
      }
    }
    return counts;
  }

  /// Distribuzione dei Mana Value per le carte non-terra
  Map<int, int> get manaCurve {
    final curve = <int, int>{0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
    for (final card in cards) {
      if (card.isLand) continue;
      final cmcInt = card.cmc.floor();
      if (cmcInt >= 6) {
        curve[6] = (curve[6] ?? 0) + 1;
      } else {
        curve[cmcInt] = (curve[cmcInt] ?? 0) + 1;
      }
    }
    return curve;
  }

  /// Mana Value medio delle carte non-terra
  double get averageNonLandCmc {
    final nonLands = cards.where((c) => !c.isLand).toList();
    if (nonLands.isEmpty) return 0.0;
    final totalCmc = nonLands.fold<double>(0.0, (sum, c) => sum + c.cmc);
    return totalCmc / nonLands.length;
  }

  /// Costo totale stimato in EUR (carte nel mazzo + comandante)
  double get totalPriceEur {
    double total = commander?.numericPriceEur ?? 0.0;
    for (final c in cards) {
      total += c.numericPriceEur ?? 0.0;
    }
    return total;
  }

  /// Costo totale stimato in USD (carte nel mazzo + comandante)
  double get totalPriceUsd {
    double total = commander?.numericPriceUsd ?? 0.0;
    for (final c in cards) {
      total += c.numericPriceUsd ?? 0.0;
    }
    return total;
  }

  /// Stringa prezzo stimato mazzo formattata (priorità EUR)
  String get formattedTotalPrice {
    if (totalPriceEur > 0) return '€${totalPriceEur.toStringAsFixed(2)}';
    if (totalPriceUsd > 0) return '\$${totalPriceUsd.toStringAsFixed(2)}';
    return '—';
  }

  CommanderDeck copyWith({
    String? id,
    String? name,
    CommanderCard? commander,
    Archetype? archetype,
    List<CommanderCard>? cards,
    DateTime? updatedAt,
  }) {
    return CommanderDeck(
      id: id ?? this.id,
      name: name ?? this.name,
      commander: commander ?? this.commander,
      archetype: archetype ?? this.archetype,
      cards: cards ?? this.cards,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'commander': commander?.toJson(),
      'archetype': archetype.name,
      'cards': cards.map((c) => c.toJson()).toList(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CommanderDeck.fromJson(Map<String, dynamic> json) {
    return CommanderDeck(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Nuovo Mazzo',
      commander: json['commander'] != null
          ? CommanderCard.fromJson(json['commander'] as Map<String, dynamic>)
          : null,
      archetype: Archetype.values.firstWhere(
        (a) => a.name == json['archetype'],
        orElse: () => Archetype.midrange,
      ),
      cards: (json['cards'] as List<dynamic>?)
              ?.map((c) => CommanderCard.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}
