import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/commander_card.dart';
import '../theme/app_theme.dart';

/// Stato della carta attualmente puntata dal mouse
class HoverCardState {
  final CommanderCard card;
  final Offset globalPosition;

  const HoverCardState({
    required this.card,
    required this.globalPosition,
  });
}

/// Provider per tracciare la carta hoverata e la posizione del puntatore
final hoveredCardProvider = StateProvider<HoverCardState?>((ref) => null);

/// Widget wrapper per rilevare l'hover del mouse su qualsiasi riga di carta
class CardHoverTarget extends ConsumerWidget {
  final CommanderCard card;
  final Widget child;

  const CardHoverTarget({
    super.key,
    required this.card,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MouseRegion(
      onEnter: (event) {
        ref.read(hoveredCardProvider.notifier).state = HoverCardState(
          card: card,
          globalPosition: event.position,
        );
      },
      onHover: (event) {
        ref.read(hoveredCardProvider.notifier).state = HoverCardState(
          card: card,
          globalPosition: event.position,
        );
      },
      onExit: (_) {
        final current = ref.read(hoveredCardProvider);
        if (current?.card.id == card.id || current?.card.name == card.name) {
          ref.read(hoveredCardProvider.notifier).state = null;
        }
      },
      child: child,
    );
  }
}

/// Overlay fluttuante che visualizza l'anteprima ad alta risoluzione della carta vicino al puntatore
class CardHoverOverlay extends ConsumerWidget {
  const CardHoverOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoverState = ref.watch(hoveredCardProvider);
    if (hoverState == null) return const SizedBox.shrink();

    final screenSize = MediaQuery.of(context).size;
    final card = hoverState.card;
    final mousePos = hoverState.globalPosition;

    // Dimensioni card MTG standard per il popup
    const cardWidth = 230.0;
    const cardHeight = 322.0;
    const offsetFromMouse = 18.0;

    // Viewport clamping orizzontale
    double left = mousePos.dx + offsetFromMouse;
    if (left + cardWidth > screenSize.width - 12) {
      left = mousePos.dx - cardWidth - offsetFromMouse;
    }
    if (left < 10) left = 10;

    // Viewport clamping verticale
    double top = mousePos.dy - (cardHeight / 2);
    if (top + cardHeight > screenSize.height - 12) {
      top = screenSize.height - cardHeight - 12;
    }
    if (top < 12) top = 12;

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          elevation: 20,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              color: const Color(0xFF14161B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.85),
                  blurRadius: 28,
                  spreadRadius: 4,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.5),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Immagine ad alta risoluzione da Scryfall
                  if (card.imageUrl != null)
                    Image.network(
                      card.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildTextFallback(card),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildTextFallback(card),
                            const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white38,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  else
                    _buildTextFallback(card),

                  // Barra informativa elegante in basso
                  Positioned(
                    bottom: 6,
                    left: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          // Prezzo
                          if (card.formattedPrice != null) ...[
                            Text(
                              card.formattedPrice!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentGreen,
                              ),
                            ),
                          ] else
                            const Text(
                              'Prezzo: —',
                              style: TextStyle(fontSize: 10, color: Colors.white38),
                            ),
                          const Spacer(),
                          // Metrica affinità o sinergia
                          if (card.edhrecSynergy != null)
                            Text(
                              '${card.edhrecSynergy! >= 0 ? '+' : ''}${(card.edhrecSynergy! * 100).toStringAsFixed(0)}% sinergia',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            )
                          else if (card.similarityScore != null)
                            Text(
                              '${(card.calculatedAffinity * 100).toStringAsFixed(0)}% affinità',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentBlue,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFallback(CommanderCard card) {
    return Container(
      color: AppTheme.surfaceDark,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  card.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                card.manaCost,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            card.typeLine,
            style: const TextStyle(fontSize: 10, color: Colors.white38, fontStyle: FontStyle.italic),
          ),
          const Divider(color: Colors.white12, height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                card.oracleText.isNotEmpty ? card.oracleText : 'Nessun testo oracolo disponibile.',
                style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
