import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/commander_card.dart';
import '../../providers/deck_builder_provider.dart';
import '../theme/app_theme.dart';

class CommanderSelectorDialog extends ConsumerStatefulWidget {
  const CommanderSelectorDialog({super.key});

  @override
  ConsumerState<CommanderSelectorDialog> createState() => _CommanderSelectorDialogState();
}

class _CommanderSelectorDialogState extends ConsumerState<CommanderSelectorDialog> {
  final TextEditingController _controller = TextEditingController();
  List<CommanderCard> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Default popular commanders
    _search('Atraxa');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _loading = true);
    final scryfall = ref.read(scryfallServiceProvider);
    final list = await scryfall.searchCommanders(query);
    if (mounted) {
      setState(() {
        _results = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 550,
        height: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppTheme.primaryGold),
                const SizedBox(width: 8),
                Text(
                  'Scegli il Comandante',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cerca per nome (es. Atraxa, Krenko, Urza, Korvold)...',
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: AppTheme.primaryGold),
                  onPressed: () => _search(_controller.text),
                ),
                isDense: true,
                filled: true,
                fillColor: AppTheme.cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.borderDark),
                ),
              ),
              onSubmitted: _search,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
                  : _results.isEmpty
                      ? const Center(
                          child: Text(
                            'Nessun comandante trovato.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, i) {
                            final card = _results[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.cardDark,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.borderDark),
                              ),
                              child: ListTile(
                                leading: card.artCropUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          card.artCropUrl!,
                                          width: 48,
                                          height: 36,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(Icons.person, color: AppTheme.primaryGold),
                                title: Text(card.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text(
                                  '${card.manaCost} • ${card.typeLine}',
                                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primaryGold),
                                onTap: () {
                                  ref.read(deckProvider.notifier).setCommander(card);
                                  Navigator.of(context).pop();
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
