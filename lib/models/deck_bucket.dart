enum DeckBucket {
  lands,
  ramp,
  draw,
  spotRemoval,
  boardWipe,
  protection,
  recursion,
  tutors,
  wincons,
  synergyEngine;

  String get label {
    switch (this) {
      case DeckBucket.lands:
        return 'Terre';
      case DeckBucket.ramp:
        return 'Ramp';
      case DeckBucket.draw:
        return 'Card Draw & Vantaggio';
      case DeckBucket.spotRemoval:
        return 'Spot Removal';
      case DeckBucket.boardWipe:
        return 'Board Wipe';
      case DeckBucket.protection:
        return 'Protezione / Counter';
      case DeckBucket.recursion:
        return 'Recursion';
      case DeckBucket.tutors:
        return 'Tutor';
      case DeckBucket.wincons:
        return 'Win Condition';
      case DeckBucket.synergyEngine:
        return 'Engine & Sinergia';
    }
  }

  String get shortLabel {
    switch (this) {
      case DeckBucket.lands:
        return 'Terre';
      case DeckBucket.ramp:
        return 'Ramp';
      case DeckBucket.draw:
        return 'Draw';
      case DeckBucket.spotRemoval:
        return 'Spot';
      case DeckBucket.boardWipe:
        return 'Wipe';
      case DeckBucket.protection:
        return 'Protection';
      case DeckBucket.recursion:
        return 'Recursion';
      case DeckBucket.tutors:
        return 'Tutor';
      case DeckBucket.wincons:
        return 'Wincon';
      case DeckBucket.synergyEngine:
        return 'Engine';
    }
  }

  String get description {
    switch (this) {
      case DeckBucket.lands:
        return 'Mana base: terre stabili e utility (default 36)';
      case DeckBucket.ramp:
        return 'Accelerazione oltre la terra per turno (mana rock, land ramp, dork)';
      case DeckBucket.draw:
        return 'Motori di vantaggio carte netti (+1 carta o selection profonda)';
      case DeckBucket.spotRemoval:
        return 'Interazione mirata su singole minacce (priorità instant e costo ≤2)';
      case DeckBucket.boardWipe:
        return 'Rimozioni di massa simmetriche o asimmetriche per resettare il tavolo';
      case DeckBucket.protection:
        return 'Difesa del comandante o del board (hexproof, indestructible, phase out, counter)';
      case DeckBucket.recursion:
        return 'Recupero o riutilizzo di risorse dal cimitero';
      case DeckBucket.tutors:
        return 'Tutori per cercare risposte o chiusure (0-2 casual, 2-4 mid/high)';
      case DeckBucket.wincons:
        return 'Carte o pacchetti che convertono il vantaggio in vittoria';
      case DeckBucket.synergyEngine:
        return 'Minacce, payoff, carte a tema e sinergie specifiche del comandante';
    }
  }
}
