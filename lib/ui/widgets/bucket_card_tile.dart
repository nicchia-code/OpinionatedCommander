import 'package:flutter/material.dart';
import '../../models/commander_card.dart';
import '../../models/deck_bucket.dart';
import '../theme/app_theme.dart';

class BucketCardTile extends StatelessWidget {
  final CommanderCard card;
  final VoidCallback onRemove;
  final ValueChanged<DeckBucket> onMoveBucket;

  const BucketCardTile({
    super.key,
    required this.card,
    required this.onRemove,
    required this.onMoveBucket,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: card.typeLine,
      waitDuration: const Duration(milliseconds: 500),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Row(
          children: [
            // Art crop preview
            if (card.artCropUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  card.artCropUrl!,
                  width: 36,
                  height: 26,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.image_not_supported, size: 20),
                ),
              )
            else
              Container(
                width: 36,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.style_outlined, size: 16, color: Colors.white38),
              ),
            const SizedBox(width: 8),

            // Card name
            Expanded(
              child: Text(
                card.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Mana Cost o CMC
            if (card.manaCost.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  card.manaCost,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ),

            // Menu per spostamento rapido di bucket
            PopupMenuButton<DeckBucket>(
              icon: const Icon(Icons.swap_horiz, size: 16, color: Colors.white54),
              tooltip: 'Sposta ruolo (Single Slot Rule)',
              onSelected: onMoveBucket,
              itemBuilder: (ctx) => [
                for (final b in DeckBucket.values)
                  PopupMenuItem(
                    value: b,
                    child: Row(
                      children: [
                        if (b == card.bucket)
                          const Icon(Icons.check, size: 14, color: AppTheme.primaryGold)
                        else
                          const SizedBox(width: 14),
                        const SizedBox(width: 6),
                        Text(b.label, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),

            // Rimuovi carta
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.white38),
              hoverColor: AppTheme.accentRed.withValues(alpha: 0.2),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: onRemove,
              tooltip: 'Rimuovi dal mazzo',
            ),
          ],
        ),
      ),
    );
  }
}
