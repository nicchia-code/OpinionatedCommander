import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/commander_card.dart';
import '../models/deck_bucket.dart';
import 'card_classifier.dart';

class EdhrecService {
  final http.Client _client;

  EdhrecService({http.Client? client}) : _client = client ?? http.Client();

  static String slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r"['’,/]"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// Recupera l'albero completo delle raccomandazioni per un comandante da EDHREC
  Future<List<CommanderCard>> fetchCommanderRecommendations(String commanderName) async {
    final slug = slugify(commanderName);
    final uri = Uri.parse('https://json.edhrec.com/pages/commanders/$slug.json');

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return [];
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final cardlists = (data['container']?['json_dict']?['cardlists'] as List<dynamic>?) ?? [];

      final seenIds = <String>{};
      final results = <CommanderCard>[];

      for (final cl in cardlists) {
        final listMap = cl as Map<String, dynamic>;
        final views = (listMap['cardviews'] as List<dynamic>?) ?? [];

        for (final v in views) {
          final vm = v as Map<String, dynamic>;
          final id = vm['id'] as String? ?? '';
          final name = vm['name'] as String? ?? '';
          if (id.isEmpty || name.isEmpty || seenIds.contains(id)) continue;
          seenIds.add(id);

          final synergy = (vm['synergy'] as num?)?.toDouble();
          final numDecks = (vm['num_decks'] as num?)?.toDouble() ?? 0;
          final potential = (vm['potential_decks'] as num?)?.toDouble() ?? 1;
          final inclusion = potential > 0 ? (numDecks / potential) : 0.0;

          // Immagine istantanea derivata dal pattern Scryfall CDN
          String? img;
          String? artCrop;
          if (id.length >= 2) {
            final f1 = id[0];
            final f2 = id[1];
            img = 'https://cards.scryfall.io/normal/front/$f1/$f2/$id.jpg';
            artCrop = 'https://cards.scryfall.io/art_crop/front/$f1/$f2/$id.jpg';
          }

          var card = CommanderCard(
            id: id,
            name: name,
            imageUrl: img,
            artCropUrl: artCrop,
            edhrecSynergy: synergy,
            edhrecInclusion: inclusion,
          );

          // Pre-classificazione euristica o da database staple
          final role = CardClassifier.classify(card);
          results.add(card.copyWith(bucket: role));
        }
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  /// Filtra le raccomandazioni EDHREC per il bucket selezionato
  List<CommanderCard> filterForBucket(List<CommanderCard> recommendations, DeckBucket bucket) {
    return recommendations.where((card) => card.bucket == bucket).toList();
  }
}
