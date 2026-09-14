import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/commander_card.dart';

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

  /// Recupera dettagli completi di una carta tramite nome o Scryfall ID
  Future<CommanderCard?> getCardByName(String name) async {
    final encoded = Uri.encodeComponent(name);
    final uri = Uri.parse('https://api.scryfall.com/cards/named?exact=$encoded');

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return null;
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return _parseCard(data);
    } catch (_) {
      return null;
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
      isCommander: isCommander,
    );
  }
}
