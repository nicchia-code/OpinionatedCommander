import 'deck_bucket.dart';

class CommanderCard {
  final String id;
  final String name;
  final String manaCost;
  final double cmc;
  final String typeLine;
  final String oracleText;
  final List<String> colors;
  final List<String> colorIdentity;
  final String? imageUrl;
  final String? artCropUrl;
  final double? edhrecSynergy;
  final double? edhrecInclusion;
  final String? priceEur;
  final String? priceUsd;
  final double? similarityScore;
  final DeckBucket? bucket;
  final bool isCommander;

  const CommanderCard({
    required this.id,
    required this.name,
    this.manaCost = '',
    this.cmc = 0.0,
    this.typeLine = '',
    this.oracleText = '',
    this.colors = const [],
    this.colorIdentity = const [],
    this.imageUrl,
    this.artCropUrl,
    this.edhrecSynergy,
    this.edhrecInclusion,
    this.priceEur,
    this.priceUsd,
    this.similarityScore,
    this.bucket,
    this.isCommander = false,
  });

  bool get isLand => typeLine.toLowerCase().contains('land');
  bool get isBasicLand =>
      typeLine.toLowerCase().contains('basic land') ||
      ['plains', 'island', 'swamp', 'mountain', 'forest', 'wastes']
          .contains(name.toLowerCase());
  bool get isInstant => typeLine.toLowerCase().contains('instant');
  bool get isSorcery => typeLine.toLowerCase().contains('sorcery');
  bool get isCreature => typeLine.toLowerCase().contains('creature');
  bool get isArtifact => typeLine.toLowerCase().contains('artifact');
  bool get isEnchantment => typeLine.toLowerCase().contains('enchantment');
  bool get isPlaneswalker => typeLine.toLowerCase().contains('planeswalker');

  /// Identifica se la rimozione è a costo ≤ 2 instant (regola BASE.md: spot economico)
  bool get isLowCostInstantRemoval =>
      isInstant && cmc <= 2.0 && bucket == DeckBucket.spotRemoval;

  /// Identifica risposte non-destroy definitive (exile, sacrifice, -X/-X, bounce)
  bool get isDefinitiveRemoval {
    final text = oracleText.toLowerCase();
    return text.contains('exile') ||
        text.contains('sacrifice') ||
        text.contains('-%') ||
        text.contains('return target') ||
        text.contains('put target') && text.contains('library');
  }

  /// Stringa prezzo formattata con preferenza EUR e fallback USD
  String? get formattedPrice {
    if (priceEur != null && priceEur!.isNotEmpty) return '€$priceEur';
    if (priceUsd != null && priceUsd!.isNotEmpty) return '\$$priceUsd';
    return null;
  }

  CommanderCard copyWith({
    String? id,
    String? name,
    String? manaCost,
    double? cmc,
    String? typeLine,
    String? oracleText,
    List<String>? colors,
    List<String>? colorIdentity,
    String? imageUrl,
    String? artCropUrl,
    double? edhrecSynergy,
    double? edhrecInclusion,
    String? priceEur,
    String? priceUsd,
    double? similarityScore,
    DeckBucket? bucket,
    bool? isCommander,
  }) {
    return CommanderCard(
      id: id ?? this.id,
      name: name ?? this.name,
      manaCost: manaCost ?? this.manaCost,
      cmc: cmc ?? this.cmc,
      typeLine: typeLine ?? this.typeLine,
      oracleText: oracleText ?? this.oracleText,
      colors: colors ?? this.colors,
      colorIdentity: colorIdentity ?? this.colorIdentity,
      imageUrl: imageUrl ?? this.imageUrl,
      artCropUrl: artCropUrl ?? this.artCropUrl,
      edhrecSynergy: edhrecSynergy ?? this.edhrecSynergy,
      edhrecInclusion: edhrecInclusion ?? this.edhrecInclusion,
      priceEur: priceEur ?? this.priceEur,
      priceUsd: priceUsd ?? this.priceUsd,
      similarityScore: similarityScore ?? this.similarityScore,
      bucket: bucket ?? this.bucket,
      isCommander: isCommander ?? this.isCommander,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'manaCost': manaCost,
      'cmc': cmc,
      'typeLine': typeLine,
      'oracleText': oracleText,
      'colors': colors,
      'colorIdentity': colorIdentity,
      'imageUrl': imageUrl,
      'artCropUrl': artCropUrl,
      'edhrecSynergy': edhrecSynergy,
      'edhrecInclusion': edhrecInclusion,
      'priceEur': priceEur,
      'priceUsd': priceUsd,
      'similarityScore': similarityScore,
      'bucket': bucket?.name,
      'isCommander': isCommander,
    };
  }

  factory CommanderCard.fromJson(Map<String, dynamic> json) {
    return CommanderCard(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      manaCost: json['manaCost'] as String? ?? '',
      cmc: (json['cmc'] as num?)?.toDouble() ?? 0.0,
      typeLine: json['typeLine'] as String? ?? '',
      oracleText: json['oracleText'] as String? ?? '',
      colors: (json['colors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      colorIdentity: (json['colorIdentity'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      imageUrl: json['imageUrl'] as String?,
      artCropUrl: json['artCropUrl'] as String?,
      edhrecSynergy: (json['edhrecSynergy'] as num?)?.toDouble(),
      edhrecInclusion: (json['edhrecInclusion'] as num?)?.toDouble(),
      priceEur: json['priceEur'] as String?,
      priceUsd: json['priceUsd'] as String?,
      similarityScore: (json['similarityScore'] as num?)?.toDouble(),
      bucket: json['bucket'] != null
          ? DeckBucket.values.firstWhere(
              (b) => b.name == json['bucket'],
              orElse: () => DeckBucket.synergyEngine,
            )
          : null,
      isCommander: json['isCommander'] as bool? ?? false,
    );
  }
}
