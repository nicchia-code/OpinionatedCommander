import 'commander_deck.dart';
import 'deck_bucket.dart';

enum AlertSeverity {
  info,
  warning,
  critical,
}

class GuardrailAlert {
  final String title;
  final String message;
  final AlertSeverity severity;
  final String ruleReference;

  const GuardrailAlert({
    required this.title,
    required this.message,
    required this.severity,
    required this.ruleReference,
  });
}

class GuardrailReport {
  final CommanderDeck deck;
  final List<GuardrailAlert> alerts;
  final Map<DeckBucket, int> currentCounts;
  final Map<DeckBucket, int> targetCounts;
  final double averageNonLandCmc;
  final int highCostCount;
  final int lowCostSpotInstantCount;
  final int instantSpotCount;
  final int definitiveRemovalCount;

  const GuardrailReport({
    required this.deck,
    required this.alerts,
    required this.currentCounts,
    required this.targetCounts,
    required this.averageNonLandCmc,
    required this.highCostCount,
    required this.lowCostSpotInstantCount,
    required this.instantSpotCount,
    required this.definitiveRemovalCount,
  });

  bool get isClean => alerts.where((a) => a.severity == AlertSeverity.critical).isEmpty;

  factory GuardrailReport.fromDeck(CommanderDeck deck) {
    final alerts = <GuardrailAlert>[];
    final current = <DeckBucket, int>{};
    final targets = <DeckBucket, int>{};

    for (final bucket in DeckBucket.values) {
      current[bucket] = deck.countInBucket(bucket);
      targets[bucket] = deck.archetype.targetFor(bucket);
    }

    // 1. Controllo totale carte
    final mainCount = deck.mainDeckCount;
    if (mainCount < 99) {
      alerts.add(GuardrailAlert(
        title: 'Mazzo incompleto',
        message: 'Attualmente hai $mainCount/99 carte non-comandante (mancano ${99 - mainCount} carte).',
        severity: AlertSeverity.info,
        ruleReference: 'BASE.md § Regola 99 carte singleton',
      ));
    } else if (mainCount > 99) {
      alerts.add(GuardrailAlert(
        title: 'Eccesso di carte',
        message: 'Hai $mainCount/99 carte non-comandante. Taglia ${mainCount - 99} carte per rispettare la regola 99+1.',
        severity: AlertSeverity.critical,
        ruleReference: 'BASE.md § Pipeline e checklist finale',
      ));
    }

    // 2. Controllo Comandante
    if (deck.commander == null) {
      alerts.add(const GuardrailAlert(
        title: 'Comandante non impostato',
        message: 'Seleziona un comandante per definire l\'identità di colore e caricare le sinergie EDHREC.',
        severity: AlertSeverity.warning,
        ruleReference: 'BASE.md § Scelta del comandante',
      ));
    }

    // 3. Controllo Terre
    final landCount = current[DeckBucket.lands] ?? 0;
    final landTarget = targets[DeckBucket.lands] ?? 36;
    if (landCount < 34) {
      alerts.add(GuardrailAlert(
        title: 'Terre sotto soglia minima',
        message: 'Hai solo $landCount terre (target $landTarget). Sotto le 34 terre rischi forte inconsistenza di mana.',
        severity: AlertSeverity.critical,
        ruleReference: 'BASE.md § Regola 1: Parti da 36 terre',
      ));
    } else if (landCount < landTarget) {
      alerts.add(GuardrailAlert(
        title: 'Quota terre sotto target',
        message: 'Hai $landCount terre rispetto al target di $landTarget per l\'archetipo ${deck.archetype.name}.',
        severity: AlertSeverity.warning,
        ruleReference: 'BASE.md § Quote per archetipo',
      ));
    }

    // 4. Controllo Ramp e Draw
    final rampCount = current[DeckBucket.ramp] ?? 0;
    final rampTarget = targets[DeckBucket.ramp] ?? 10;
    if (rampCount < 8) {
      alerts.add(GuardrailAlert(
        title: 'Accelerazione insufficiente',
        message: 'Solo $rampCount fonti di ramp (target $rampTarget). Meno di 8 riduce la probabilità di vedere ramp nei primi 3 turni.',
        severity: AlertSeverity.warning,
        ruleReference: 'BASE.md § Regola 2: Almeno 10 ramp',
      ));
    }

    final drawCount = current[DeckBucket.draw] ?? 0;
    final drawTarget = targets[DeckBucket.draw] ?? 10;
    if (drawCount < 8) {
      alerts.add(GuardrailAlert(
        title: 'Pescaggio insufficiente',
        message: 'Solo $drawCount fonti di draw/vantaggio carte (target $drawTarget). Rischio svuotamento mano.',
        severity: AlertSeverity.warning,
        ruleReference: 'BASE.md § Regola 2: Almeno 10 draw',
      ));
    }

    // 5. Metriche Spot Removal
    final spotCards = deck.cardsInBucket(DeckBucket.spotRemoval);
    final lowCostSpot = spotCards.where((c) => c.cmc <= 2.0).length;
    final instantSpot = spotCards.where((c) => c.isInstant).length;
    final definitive = spotCards.where((c) => c.isDefinitiveRemoval).length;

    if (spotCards.length >= 4 && lowCostSpot < 4) {
      alerts.add(GuardrailAlert(
        title: 'Spot removal poco efficiente',
        message: 'Hai solo $lowCostSpot rimozioni a costo ≤2 mana (target: almeno 4, idealmente 5–6).',
        severity: AlertSeverity.warning,
        ruleReference: 'BASE.md § Quanta interazione giocare (costo ≤2)',
      ));
    }

    if (spotCards.isNotEmpty && instantSpot < (spotCards.length / 2).ceil()) {
      alerts.add(GuardrailAlert(
        title: 'Poco removal a velocità istantanea',
        message: 'Solo $instantSpot/${spotCards.length} spot removal sono Instant (target: almeno 50%).',
        severity: AlertSeverity.warning,
        ruleReference: 'BASE.md § Quanta interazione giocare (Instant speed)',
      ));
    }

    if (spotCards.length >= 6 && definitive < 2) {
      alerts.add(GuardrailAlert(
        title: 'Mancanza di rimozioni definitive',
        message: 'Hai solo $definitive risposte che esiliano/rimuovono senza distruggere (target: almeno 2).',
        severity: AlertSeverity.info,
        ruleReference: 'BASE.md § Exile contro destroy',
      ));
    }

    // 6. Curva di mana
    final avgCmc = deck.averageNonLandCmc;
    if (avgCmc > 3.5 && deck.cards.length >= 30) {
      alerts.add(GuardrailAlert(
        title: 'Curva di mana troppo pesante',
        message: 'Il Mana Value medio non-terra è ${avgCmc.toStringAsFixed(2)} (guardrail BASE.md: 2.8–3.5 max).',
        severity: AlertSeverity.warning,
        ruleReference: 'BASE.md § Guardrail della curva',
      ));
    }

    final highCost = deck.cards.where((c) => !c.isLand && c.cmc >= 5.0).length;
    if (highCost > 10) {
      alerts.add(GuardrailAlert(
        title: 'Troppe carte ad alto costo (MV 5+)',
        message: 'Hai $highCost carte a costo 5+ (guardrail BASE.md: massimo 8–10 carte ad alto costo).',
        severity: AlertSeverity.warning,
        ruleReference: 'BASE.md § Guardrail della curva',
      ));
    }

    return GuardrailReport(
      deck: deck,
      alerts: alerts,
      currentCounts: current,
      targetCounts: targets,
      averageNonLandCmc: avgCmc,
      highCostCount: highCost,
      lowCostSpotInstantCount: lowCostSpot,
      instantSpotCount: instantSpot,
      definitiveRemovalCount: definitive,
    );
  }
}
