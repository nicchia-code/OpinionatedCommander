import 'deck_bucket.dart';

enum Archetype {
  midrange(
    name: 'Midrange',
    description: 'Punto zero: valore intrinseco, interazione bilanciata, resilienti senza comandante.',
    targets: {
      DeckBucket.lands: 36,
      DeckBucket.ramp: 10,
      DeckBucket.draw: 11,
      DeckBucket.spotRemoval: 9,
      DeckBucket.boardWipe: 3,
      DeckBucket.protection: 4,
      DeckBucket.recursion: 4,
      DeckBucket.tutors: 3,
      DeckBucket.wincons: 5,
      DeckBucket.synergyEngine: 14,
    },
  ),
  aggro(
    name: 'Aggro',
    description: 'Sviluppo rapido, curva bassa, protezione prioritaria sui wipe per salvaguardare il board.',
    targets: {
      DeckBucket.lands: 35,
      DeckBucket.ramp: 10,
      DeckBucket.draw: 9,
      DeckBucket.spotRemoval: 7,
      DeckBucket.boardWipe: 2,
      DeckBucket.protection: 5,
      DeckBucket.recursion: 2,
      DeckBucket.tutors: 1,
      DeckBucket.wincons: 6,
      DeckBucket.synergyEngine: 22,
    },
  ),
  control(
    name: 'Control',
    description: 'Più pescaggio che removal, 5+ wipe, interazione instant economica (≤2 MV).',
    targets: {
      DeckBucket.lands: 37,
      DeckBucket.ramp: 9,
      DeckBucket.draw: 12,
      DeckBucket.spotRemoval: 12,
      DeckBucket.boardWipe: 5,
      DeckBucket.protection: 8,
      DeckBucket.recursion: 2,
      DeckBucket.tutors: 3,
      DeckBucket.wincons: 3,
      DeckBucket.synergyEngine: 8,
    },
  ),
  combo(
    name: 'Combo',
    description: 'Tutori dedicati, card selection e accelerazione massimizzate per assemblare la chiusura.',
    targets: {
      DeckBucket.lands: 34,
      DeckBucket.ramp: 13,
      DeckBucket.draw: 13,
      DeckBucket.spotRemoval: 7,
      DeckBucket.boardWipe: 2,
      DeckBucket.protection: 9,
      DeckBucket.recursion: 3,
      DeckBucket.tutors: 8,
      DeckBucket.wincons: 6,
      DeckBucket.synergyEngine: 4,
    },
  ),
  groupHug(
    name: 'Group Hug',
    description: 'Manipolazione politica ed economica del tavolo, ma con 4 wincon personali vere.',
    targets: {
      DeckBucket.lands: 37,
      DeckBucket.ramp: 9,
      DeckBucket.draw: 10,
      DeckBucket.spotRemoval: 6,
      DeckBucket.boardWipe: 2,
      DeckBucket.protection: 4,
      DeckBucket.recursion: 2,
      DeckBucket.tutors: 1,
      DeckBucket.wincons: 4,
      DeckBucket.synergyEngine: 24,
    },
  ),
  stax(
    name: 'Stax',
    description: 'Rottura asimmetrica delle risorse: tassazione e blocco delle sequenze avversarie.',
    targets: {
      DeckBucket.lands: 36,
      DeckBucket.ramp: 10,
      DeckBucket.draw: 10,
      DeckBucket.spotRemoval: 9,
      DeckBucket.boardWipe: 3,
      DeckBucket.protection: 5,
      DeckBucket.recursion: 3,
      DeckBucket.tutors: 4,
      DeckBucket.wincons: 4,
      DeckBucket.synergyEngine: 15,
    },
  );

  const Archetype({
    required this.name,
    required this.description,
    required this.targets,
  });

  final String name;
  final String description;
  final Map<DeckBucket, int> targets;

  int targetFor(DeckBucket bucket) => targets[bucket] ?? 0;
}
