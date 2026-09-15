import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/deck_builder_provider.dart';
import '../theme/app_theme.dart';

class SavedDecksDialog extends ConsumerWidget {
  const SavedDecksDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedDecksAsync = ref.watch(savedDecksProvider);

    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'I Miei Mazzi Salvati',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: savedDecksAsync.when(
                  data: (decks) {
                    if (decks.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nessun mazzo salvato nel browser.',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: decks.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: AppTheme.borderDark),
                      itemBuilder: (context, index) {
                        final deck = decks[index];
                        final cmd = deck.commander;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: cmd?.artCropUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    cmd!.artCropUrl!,
                                    width: 40,
                                    height: 30,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.shield, size: 24, color: Colors.white38),
                          title: Text(
                            deck.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                          ),
                          subtitle: Text(
                            '${deck.mainDeckCount}/99 carte • ${deck.archetype.name} • ${deck.formattedTotalPrice}',
                            style: const TextStyle(fontSize: 11, color: Colors.white54),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white38),
                                hoverColor: Colors.red.withValues(alpha: 0.1),
                                onPressed: () {
                                  ref.read(deckProvider.notifier).deleteDeck(deck.id);
                                },
                              ),
                              const SizedBox(width: 4),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  ref.read(deckProvider.notifier).loadDeck(deck);
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Carica', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text(
                      'Errore caricamento: $err',
                      style: const TextStyle(color: AppTheme.accentRed, fontSize: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      ref.read(deckProvider.notifier).clearDeck();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Crea Nuovo Mazzo', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
