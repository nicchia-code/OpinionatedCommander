import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/deck_builder_provider.dart';
import '../../services/deck_storage_service.dart';
import '../theme/app_theme.dart';

class ImportExportDialog extends ConsumerStatefulWidget {
  const ImportExportDialog({super.key});

  @override
  ConsumerState<ImportExportDialog> createState() => _ImportExportDialogState();
}

class _ImportExportDialogState extends ConsumerState<ImportExportDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _importCtrl = TextEditingController();
  bool _includeCategories = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _importCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deck = ref.watch(deckProvider);
    final exportText = DeckStorageService.exportToText(deck, includeBuckets: _includeCategories);

    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600,
        height: 580,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_alt, color: AppTheme.primaryGold),
                const SizedBox(width: 8),
                Text(
                  'Importa / Esporta Mazzo',
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
            TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryGold,
              labelColor: AppTheme.primaryGold,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(text: 'Esporta Formato MTG'),
                Tab(text: 'Importa Lista Testo'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab Esporta
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _includeCategories,
                            activeColor: AppTheme.primaryGold,
                            onChanged: (val) => setState(() => _includeCategories = val ?? true),
                          ),
                          const Text('Includi intestazioni categorie BASE.md (// Ramp, // Draw...)'),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: exportText));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Lista copiata negli appunti!'),
                                    backgroundColor: AppTheme.accentGreen,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copia'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGold,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.bgDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderDark),
                          ),
                          child: SelectableText(
                            exportText.isEmpty ? '// Mazzo vuoto' : exportText,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Tab Importa
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Incolla una lista formato MTGA/Moxfield/Archidekt (es. "1 Sol Ring"):',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _importCtrl,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          decoration: InputDecoration(
                            hintText: '// Commander\n1 Atraxa, Praetors\' Voice\n\n// Ramp\n1 Sol Ring\n1 Arcane Signet...',
                            filled: true,
                            fillColor: AppTheme.bgDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppTheme.borderDark),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _importing
                            ? null
                            : () async {
                                if (_importCtrl.text.trim().isEmpty) return;
                                setState(() => _importing = true);
                                final count = await ref
                                    .read(deckProvider.notifier)
                                    .importFromText(_importCtrl.text);
                                setState(() => _importing = false);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Importate $count carte con successo!'),
                                      backgroundColor: AppTheme.accentGreen,
                                    ),
                                  );
                                }
                              },
                        icon: _importing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.file_upload_outlined),
                        label: Text(_importing ? 'Importazione in corso...' : 'Importa nel Mazzo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
