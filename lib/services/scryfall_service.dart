import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/commander_card.dart';
import '../models/deck_bucket.dart';

class ScryfallService {
  final http.Client _client;

  ScryfallService({http.Client? client}) : _client = client ?? http.Client();

  /// Cerca comandanti eleggibili (is:commander) per query
  Future<List<CommanderCard>> searchCommanders(String query) async {
    if (query.trim().isEmpty) return [];
    final encoded = Uri.encodeComponent('is:commander $query');
    final uri = Uri.parse('https://api.scryfall.com/cards/search?q=$encoded&order=edhrec');

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return [];
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>?) ?? [];
      return list.map((item) => _parseCard(item as Map<String, dynamic>, isCommander: true)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Cerca carte libere con filtri Scryfall (ad es. per colore identità o tag)
  Future<List<CommanderCard>> searchCards(String query, {List<String>? colorIdentity}) async {
    if (query.trim().isEmpty) return [];
    var fullQuery = query;
    if (colorIdentity != null && colorIdentity.isNotEmpty) {
      final idStr = colorIdentity.join('').toLowerCase();
      fullQuery += ' id<=$idStr';
    }

    final encoded = Uri.encodeComponent(fullQuery);
    final uri = Uri.parse('https://api.scryfall.com/cards/search?q=$encoded&order=edhrec');

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return [];
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>?) ?? [];
      return list.map((item) => _parseCard(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  final Map<String, CommanderCard> _cardCache = {};

  /// Recupera carte in blocco da Scryfall per ID (fino a 75 per batch /cards/collection)
  Future<Map<String, CommanderCard>> fetchCardsByIds(List<String> ids) async {
    final validIds = ids.where((id) => id.isNotEmpty).toSet().toList();
    if (validIds.isEmpty) return {};

    final missingIds = validIds.where((id) => !_cardCache.containsKey(id)).toList();

    // Elabora a blocchi di 75 (limite Scryfall collection API)
    for (int i = 0; i < missingIds.length; i += 75) {
      final chunk = missingIds.sublist(i, i + 75 > missingIds.length ? missingIds.length : i + 75);
      final uri = Uri.parse('https://api.scryfall.com/cards/collection');
      final body = json.encode({
        'identifiers': chunk.map((id) => {'id': id}).toList(),
      });

      try {
        final response = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        );
        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final list = (data['data'] as List<dynamic>?) ?? [];
          for (final item in list) {
            final card = _parseCard(item as Map<String, dynamic>);
            _cardCache[card.id] = card;
            _cardCache[card.name.toLowerCase()] = card;
          }
        }
      } catch (_) {
        // Fallback silenzioso su timeout/offline
      }
    }

    final result = <String, CommanderCard>{};
    for (final id in validIds) {
      if (_cardCache.containsKey(id)) {
        result[id] = _cardCache[id]!;
      }
    }
    return result;
  }

  /// Recupera dettagli completi di una carta tramite nome o Scryfall ID
  Future<CommanderCard?> getCardByName(String name) async {
    final lowerName = name.toLowerCase();
    if (_cardCache.containsKey(lowerName)) {
      return _cardCache[lowerName];
    }

    final encoded = Uri.encodeComponent(name);
    final uri = Uri.parse('https://api.scryfall.com/cards/named?exact=$encoded');

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return null;
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final card = _parseCard(data);
      _cardCache[card.id] = card;
      _cardCache[lowerName] = card;
      return card;
    } catch (_) {
      return null;
    }
  }

  /// Recupera equivalenti funzionali e carte simili per un determinato bucket
  Future<List<CommanderCard>> fetchFunctionalEquivalentsForBucket({
    required DeckBucket bucket,
    required List<String> colorIdentity,
  }) async {
    final idStr = colorIdentity.isNotEmpty ? colorIdentity.join('').toLowerCase() : 'c';
    String tagPart;

    switch (bucket) {
      case DeckBucket.lands:
        tagPart = 'is:land -is:digital';
        break;
      case DeckBucket.ramp:
        tagPart = '(otag:ramp or otag:mana-rock or otag:mana-dork) -is:digital';
        break;
      case DeckBucket.draw:
        tagPart = '(otag:draw or otag:card-advantage) -is:digital';
        break;
      case DeckBucket.spotRemoval:
        tagPart = '(otag:removal or otag:spot-removal or otag:counterspell) -is:digital';
        break;
      case DeckBucket.boardWipe:
        tagPart = '(otag:board-wipe or otag:wrath) -is:digital';
        break;
      case DeckBucket.protection:
        tagPart = '(otag:protection or otag:hexproof-granter or otag:indestructible-granter) -is:digital';
        break;
      case DeckBucket.recursion:
        tagPart = '(otag:recursion or otag:reanimation) -is:digital';
        break;
      case DeckBucket.tutors:
        tagPart = 'otag:tutor -is:digital';
        break;
      case DeckBucket.wincons:
        tagPart = '(otag:finisher or otag:overrun or otag:alternate-win-condition) -is:digital';
        break;
      case DeckBucket.synergyEngine:
        tagPart = '-is:land -is:digital';
        break;
    }

    final query = 'id<=$idStr $tagPart';
    final encoded = Uri.encodeComponent(query);
    final uri = Uri.parse('https://api.scryfall.com/cards/search?q=$encoded&order=edhrec');

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return [];
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>?) ?? [];
      return list.map((item) {
        final card = _parseCard(item as Map<String, dynamic>);
        return card.copyWith(bucket: bucket);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  CommanderCard _parseCard(Map<String, dynamic> json, {bool isCommander = false}) {
    String manaCost = json['mana_cost'] as String? ?? '';
    String oracleText = json['oracle_text'] as String? ?? '';
    String? imageUrl;
    String? artCropUrl;

    if (json['image_uris'] != null) {
      final uris = json['image_uris'] as Map<String, dynamic>;
      imageUrl = uris['normal'] as String? ?? uris['small'] as String?;
      artCropUrl = uris['art_crop'] as String?;
    } else if (json['card_faces'] != null) {
      final faces = json['card_faces'] as List<dynamic>;
      if (faces.isNotEmpty) {
        final firstFace = faces[0] as Map<String, dynamic>;
        manaCost = firstFace['mana_cost'] as String? ?? manaCost;
        oracleText = firstFace['oracle_text'] as String? ?? oracleText;
        if (firstFace['image_uris'] != null) {
          final uris = firstFace['image_uris'] as Map<String, dynamic>;
          imageUrl = uris['normal'] as String? ?? uris['small'] as String?;
          artCropUrl = uris['art_crop'] as String?;
        }
      }
    }

    final prices = json['prices'] as Map<String, dynamic>?;
    final priceEur = prices?['eur'] as String?;
    final priceUsd = prices?['usd'] as String?;

    return CommanderCard(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      manaCost: manaCost,
      cmc: (json['cmc'] as num?)?.toDouble() ?? 0.0,
      typeLine: json['type_line'] as String? ?? '',
      oracleText: oracleText,
      colors: (json['colors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      colorIdentity: (json['color_identity'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      imageUrl: imageUrl,
      artCropUrl: artCropUrl,
      priceEur: priceEur,
      priceUsd: priceUsd,
      isCommander: isCommander,
    );
  }
}
