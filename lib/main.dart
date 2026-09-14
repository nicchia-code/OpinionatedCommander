import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/screens/deck_builder_screen.dart';
import 'ui/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: OpinionatedCommanderApp()));
}

class OpinionatedCommanderApp extends StatelessWidget {
  const OpinionatedCommanderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpinionatedCommander',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const DeckBuilderScreen(),
    );
  }
}
