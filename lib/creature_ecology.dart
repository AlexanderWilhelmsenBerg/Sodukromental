part of 'creatures.dart';

/// The six fantasy developmental roots. Names are serialized; do not reorder.
enum CreatureFounder {
  plant,
  mammalian,
  arthropod,
  reptilian,
  fungal,
  gelColony,
}

extension CreatureFounderText on CreatureFounder {
  String get label => switch (this) {
    CreatureFounder.plant => 'Plant',
    CreatureFounder.mammalian => 'Mammalian',
    CreatureFounder.arthropod => 'Arthropod',
    CreatureFounder.reptilian => 'Reptilian',
    CreatureFounder.fungal => 'Fungal',
    CreatureFounder.gelColony => 'Gel colony',
  };
}

enum DecisionFamily { digit, roof, light, coordination }

extension DecisionFamilyText on DecisionFamily {
  String get question => switch (this) {
    DecisionFamily.digit => 'A digit gets loose',
    DecisionFamily.roof => 'The colony needs a roof',
    DecisionFamily.light => 'A path goes dark',
    DecisionFamily.coordination => 'Neighbors need to coordinate',
  };
}

/// Sixteen stable response nodes: four mechanically and visibly distinct
/// answers in each family.
enum EcologyChoice {
  chase(
    'digit.chase',
    DecisionFamily.digit,
    'Race after the first',
    'Digit travel ×0.75',
    GrowthMilestone.five,
    'response-chase',
  ),
  gatherPair(
    'digit.gather-pair',
    DecisionFamily.digit,
    'Catch both',
    'Carries one extra copy of the requested digit',
    GrowthMilestone.five,
    'paired-sockets',
  ),
  braceSlope(
    'digit.brace-slope',
    DecisionFamily.digit,
    'Brace against a slope',
    'Tilt digit travel ×0.65',
    GrowthMilestone.six,
    'slope-brace',
  ),
  keepFavorite(
    'digit.keep-favorite',
    DecisionFamily.digit,
    'Keep a favorite nearby',
    '+1 selected favorite restock target',
    GrowthMilestone.six,
    'favorite-pocket',
  ),
  collectBundles(
    'roof.collect-bundles',
    DecisionFamily.roof,
    'Collect in bundles',
    '+1 same-project glyph',
    GrowthMilestone.seven,
    'bundle-rack',
  ),
  hurryLoads(
    'roof.hurry-loads',
    DecisionFamily.roof,
    'Hurry every load',
    'Glyph travel ×0.80',
    GrowthMilestone.seven,
    'load-sling',
  ),
  fitSupports(
    'roof.fit-supports',
    DecisionFamily.roof,
    'Fit the supports',
    'Support travel ×0.70',
    GrowthMilestone.eight,
    'bracing-joint',
  ),
  readNotice(
    'roof.read-notice',
    DecisionFamily.roof,
    'Read the settlement notice',
    'Notice-glyph travel ×0.70',
    GrowthMilestone.eight,
    'notice-lens',
  ),
  hurryFlame(
    'light.hurry-flame',
    DecisionFamily.light,
    'Hurry the flame',
    'Torch travel ×0.75',
    GrowthMilestone.halo,
    'forward-lamp',
  ),
  linkedSignal(
    'light.linked-signal',
    DecisionFamily.light,
    'Follow a linked signal',
    'Linked travel ×0.65',
    GrowthMilestone.halo,
    'signal-antenna',
  ),
  scoutEntrance(
    'light.scout-entrance',
    DecisionFamily.light,
    'Scout the entrance',
    'Post-tutorial starter travel ×0.65',
    GrowthMilestone.halo,
    'scout-lamp',
  ),
  carryTwoLights(
    'light.carry-two',
    DecisionFamily.light,
    'Carry two earned lights',
    'Batch at most two compatible earned patches',
    GrowthMilestone.halo,
    'twin-lamps',
  ),
  inspectConflict(
    'coord.inspect-conflict',
    DecisionFamily.coordination,
    'Inspect a visible conflict',
    'Inspect a visible conflict on request',
    GrowthMilestone.eight,
    'inspection-lens',
  ),
  holdOffer(
    'coord.hold-offer',
    DecisionFamily.coordination,
    'Hold an offer',
    'Hold an offer two seconds longer',
    GrowthMilestone.eight,
    'patient-grip',
  ),
  relayLoad(
    'coord.relay-load',
    DecisionFamily.coordination,
    'Relay a load',
    'Next same-project handoff ×0.85',
    GrowthMilestone.arrows,
    'handoff-joint',
  ),
  coverUrgent(
    'coord.cover-urgent',
    DecisionFamily.coordination,
    'Cover an urgent assignment',
    'Outside-preference urgent travel ×0.85',
    GrowthMilestone.arrows,
    'urgent-sash',
  );

  const EcologyChoice(
    this.id,
    this.family,
    this.label,
    this.effect,
    this.milestone,
    this.rigPart,
  );
  final String id;
  final DecisionFamily family;
  final String label;
  final String effect;
  final GrowthMilestone milestone;
  final String rigPart;

  static EcologyChoice? byId(String id) {
    for (final choice in values) {
      if (choice.id == id) return choice;
    }
    return null;
  }
}

class EcologyNiche {
  const EcologyNiche({
    required this.id,
    required this.founder,
    required this.label,
    required this.question,
    required this.effect,
    required this.rigParts,
    required this.gait,
  });
  final String id;
  final CreatureFounder founder;
  final String label;
  final String question;
  final String effect;
  final List<String> rigParts;
  final String gait;
}

const ecologyNiches = <EcologyNiche>[
  EcologyNiche(
    id: 'plant.brace',
    founder: CreatureFounder.plant,
    label: 'Brace beneath a floorboard',
    question: 'Where does it wait out the wind?',
    effect: 'First project glyph trip ×0.88',
    rigParts: ['root-trunk', 'bipedal', 'long', 'paper'],
    gait: 'root-walk',
  ),
  EcologyNiche(
    id: 'plant.runner',
    founder: CreatureFounder.plant,
    label: 'Follow the cracks',
    question: 'Where does it wait out the wind?',
    effect: 'Final outstanding glyph trip ×0.88',
    rigParts: ['trailing-runners', 'tiny-feet', 'flat', 'paper'],
    gait: 'runner',
  ),
  EcologyNiche(
    id: 'mammal.trails',
    founder: CreatureFounder.mammalian,
    label: 'Hunt along open trails',
    question: 'What does it do with a clear trail?',
    effect: 'Favorite-digit request ×0.88',
    rigParts: ['quadrupedal', 'long', 'fur', 'trail-nose'],
    gait: 'bound',
  ),
  EcologyNiche(
    id: 'mammal.shelter',
    founder: CreatureFounder.mammalian,
    label: 'Shelter what you find',
    question: 'What does it do with a clear trail?',
    effect: 'Prioritized digit trip ×0.88',
    rigParts: ['bipedal', 'round', 'fur', 'pouch'],
    gait: 'upright',
  ),
  EcologyNiche(
    id: 'arthropod.heap',
    founder: CreatureFounder.arthropod,
    label: 'Gather from a heap',
    question: 'How does it cross the clutter?',
    effect: 'Multi-copy order ×0.88',
    rigParts: ['six-legs', 'segmented', 'plates', 'pincers'],
    gait: 'tripod',
  ),
  EcologyNiche(
    id: 'arthropod.silk',
    founder: CreatureFounder.arthropod,
    label: 'Span the gap with silk',
    question: 'How does it cross the clutter?',
    effect: 'Marked sentence-letter collection ×0.88',
    rigParts: ['six-legs', 'flat', 'smooth', 'silk-spinner'],
    gait: 'silk-step',
  ),
  EcologyNiche(
    id: 'reptile.ledge',
    founder: CreatureFounder.reptilian,
    label: 'Follow a tipping ledge',
    question: 'Where does it bask near the work?',
    effect: 'Tilt digit trips ×0.88',
    rigParts: ['quadrupedal', 'long', 'scales', 'skink-tail'],
    gait: 'skink',
  ),
  EcologyNiche(
    id: 'reptile.site',
    founder: CreatureFounder.reptilian,
    label: 'Shelter beside the work site',
    question: 'Where does it bask near the work?',
    effect: 'Urgent work outside preference ×0.88',
    rigParts: ['quadrupedal', 'squat', 'plates', 'shell-back'],
    gait: 'shell-plod',
  ),
  EcologyNiche(
    id: 'fungus.lantern',
    founder: CreatureFounder.fungal,
    label: 'Fruit in lantern light',
    question: 'Where does the hidden network fruit?',
    effect: 'Starter-torch travel ×0.88',
    rigParts: ['bipedal', 'round', 'smooth', 'walking-cap'],
    gait: 'cap-step',
  ),
  EcologyNiche(
    id: 'fungus.thread',
    founder: CreatureFounder.fungal,
    label: 'Follow a buried thread',
    question: 'Where does the hidden network fruit?',
    effect: 'Multi-anchor reveal ×0.88',
    rigParts: ['slime', 'long', 'paper', 'mycelium-cord'],
    gait: 'corded-glide',
  ),
  EcologyNiche(
    id: 'gel.current',
    founder: CreatureFounder.gelColony,
    label: 'Follow a changing current',
    question: 'How does it cross a divided pool?',
    effect: 'First trip after changing work ×0.88',
    rigParts: ['slime', 'round', 'gel', 'ripple-edge'],
    gait: 'ripple',
  ),
  EcologyNiche(
    id: 'gel.divide',
    founder: CreatureFounder.gelColony,
    label: 'Divide across two trails',
    question: 'How does it cross a divided pool?',
    effect: 'Trip with two eligible waiting jobs ×0.88',
    rigParts: ['slime', 'lobes', 'gel', 'linked-lobes'],
    gait: 'lobe-pull',
  ),
];

EcologyNiche? ecologyNicheById(String id) {
  for (final niche in ecologyNiches) {
    if (niche.id == id) return niche;
  }
  return null;
}

/// A founder-specific physical performance of one response. The complete
/// 12×16 manifest prevents distinct answers from collapsing to the same rig.
class EcologyExpression {
  const EcologyExpression({
    required this.id,
    required this.nicheId,
    required this.choice,
    required this.verb,
    required this.rigPart,
    required this.pose,
  });
  final String id;
  final String nicheId;
  final EcologyChoice choice;
  final String verb;
  final String rigPart;
  final String pose;
}

final ecologyExpressions = List<EcologyExpression>.unmodifiable([
  for (final niche in ecologyNiches)
    for (final choice in EcologyChoice.values)
      EcologyExpression(
        id: '${niche.id}/${choice.id}',
        nicheId: niche.id,
        choice: choice,
        verb:
            '${switch (niche.founder) {
              CreatureFounder.plant => 'Root',
              CreatureFounder.mammalian => 'Pounce',
              CreatureFounder.arthropod => 'Clasp',
              CreatureFounder.reptilian => 'Brace',
              CreatureFounder.fungal => 'Thread',
              CreatureFounder.gelColony => 'Flow',
            }} · ${choice.label}',
        rigPart: '${niche.id}.${choice.rigPart}',
        pose: switch (choice.family) {
          DecisionFamily.digit => 'pursue-${choice.index % 4}',
          DecisionFamily.roof => 'build-${choice.index % 4}',
          DecisionFamily.light => 'light-${choice.index % 4}',
          DecisionFamily.coordination => 'neighbor-${choice.index % 4}',
        },
      ),
]);

EcologyExpression ecologyExpression(String nicheId, EcologyChoice choice) =>
    ecologyExpressions.firstWhere(
      (expression) =>
          expression.nicheId == nicheId && expression.choice == choice,
    );

class EcologyPath {
  EcologyPath({
    this.version = 1,
    required this.founder,
    required this.nicheId,
    Map<DecisionFamily, EcologyChoice> decisions = const {},
    Iterable<String> witnessedEvents = const [],
    this.secretId,
  }) : decisions = Map.unmodifiable(decisions),
       witnessedEvents = Set.unmodifiable(witnessedEvents);

  final int version;
  final CreatureFounder founder;
  final String nicheId;
  final Map<DecisionFamily, EcologyChoice> decisions;
  final Set<String> witnessedEvents;
  final String? secretId;

  EcologyNiche? get niche => ecologyNicheById(nicheId);
  bool get isAdult => DecisionFamily.values.every(decisions.containsKey);
  int get responseCount => decisions.length;

  EcologyPath choose(EcologyChoice choice) => EcologyPath(
    version: version,
    founder: founder,
    nicheId: nicheId,
    decisions: {...decisions, choice.family: choice},
    witnessedEvents: witnessedEvents,
    secretId: secretId,
  );

  EcologyPath witness(String eventId) => EcologyPath(
    version: version,
    founder: founder,
    nicheId: nicheId,
    decisions: decisions,
    witnessedEvents: {...witnessedEvents, eventId},
    secretId: secretId,
  );

  EcologyPath discover(String id) {
    final secret = ecologySecretById(id);
    if (secret == null || !secret.matches(this)) return this;
    return EcologyPath(
      version: version,
      founder: founder,
      nicheId: nicheId,
      decisions: decisions,
      witnessedEvents: witnessedEvents,
      secretId: id,
    );
  }

  List<String> validate(GrowthMilestone milestone) {
    final errors = <String>[];
    if (version != 1) errors.add('This life path uses an unsupported version.');
    if (niche == null || niche!.founder != founder)
      errors.add('Choose a valid ${founder.label.toLowerCase()} habitat.');
    final cap = ecologyDecisionCap(milestone);
    if (decisions.length > cap)
      errors.add('This creature can express at most $cap responses now.');
    for (final entry in decisions.entries) {
      if (entry.key != entry.value.family)
        errors.add('A response is filed under the wrong situation.');
      if (entry.value.milestone.index > milestone.index)
        errors.add('${entry.value.label} is still locked.');
    }
    if (secretId != null && ecologySecretById(secretId!)?.matches(this) != true)
      errors.add('This discovery has not been witnessed.');
    return errors;
  }

  List<EcologyChoice> availableChoices(
    GrowthMilestone milestone,
    DecisionFamily family,
  ) => [
    for (final choice in EcologyChoice.values)
      if (choice.family == family && choice.milestone.index <= milestone.index)
        choice,
  ];

  List<String> get projectedParts => [
    ...?niche?.rigParts,
    for (final family in DecisionFamily.values)
      if (decisions[family] case final EcologyChoice choice)
        ecologyExpression(nicheId, choice).rigPart,
    ...?ecologySecretById(secretId ?? '')?.rigParts,
  ];

  List<WorkPerk> get projectedPerks {
    final result = <WorkPerk>[];
    for (final family in DecisionFamily.values) {
      final choice = decisions[family];
      if (choice == null) continue;
      final perk = switch (choice) {
        EcologyChoice.chase => WorkPerk.quickSteps,
        EcologyChoice.gatherPair => WorkPerk.extraDigitGrip,
        EcologyChoice.braceSlope => WorkPerk.stableFooting,
        EcologyChoice.keepFavorite => WorkPerk.favoriteStock,
        EcologyChoice.collectBundles => WorkPerk.letterCarrier,
        EcologyChoice.hurryLoads => WorkPerk.fastBuilder,
        EcologyChoice.hurryFlame => WorkPerk.fastTorchTrip,
        EcologyChoice.inspectConflict => WorkPerk.visibleConflictCheck,
        EcologyChoice.holdOffer => WorkPerk.longerOffer,
        _ => null,
      };
      if (perk != null) result.add(perk);
    }
    return List.unmodifiable(result);
  }

  String get canonicalSignature {
    final choices = DecisionFamily.values
        .map((family) => decisions[family]?.id ?? '-')
        .join('|');
    return 'v$version|${founder.name}|$nicheId|$choices';
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'founder': founder.name,
    'niche': nicheId,
    'decisions': {
      for (final family in DecisionFamily.values)
        if (decisions[family] case final EcologyChoice choice)
          family.name: choice.id,
    },
    'witnessedEvents': witnessedEvents.toList()..sort(),
    if (secretId != null) 'secret': secretId,
  };

  factory EcologyPath.fromJson(Map<String, dynamic> json) {
    final raw = json['decisions'] as Map? ?? const {};
    return EcologyPath(
      version: json['version'] as int? ?? 1,
      founder: CreatureFounder.values.byName(json['founder'] as String),
      nicheId: json['niche'] as String,
      decisions: {
        for (final family in DecisionFamily.values)
          if (raw[family.name] is String)
            if (EcologyChoice.byId(raw[family.name] as String)
                case final EcologyChoice choice)
              family: choice,
      },
      witnessedEvents: (json['witnessedEvents'] as List? ?? const [])
          .whereType<String>(),
      secretId: json['secret'] as String?,
    );
  }

  static Iterable<EcologyPath> enumerateAdultBuilds() sync* {
    for (final niche in ecologyNiches) {
      final byFamily = {
        for (final family in DecisionFamily.values)
          family: EcologyChoice.values
              .where((choice) => choice.family == family)
              .toList(),
      };
      for (final digit in byFamily[DecisionFamily.digit]!) {
        for (final roof in byFamily[DecisionFamily.roof]!) {
          for (final light in byFamily[DecisionFamily.light]!) {
            for (final coordination in byFamily[DecisionFamily.coordination]!) {
              yield EcologyPath(
                founder: niche.founder,
                nicheId: niche.id,
                decisions: {
                  DecisionFamily.digit: digit,
                  DecisionFamily.roof: roof,
                  DecisionFamily.light: light,
                  DecisionFamily.coordination: coordination,
                },
              );
            }
          }
        }
      }
    }
  }
}

int ecologyDecisionCap(GrowthMilestone milestone) => switch (milestone) {
  GrowthMilestone.opening => 0,
  GrowthMilestone.five || GrowthMilestone.six => 1,
  GrowthMilestone.seven || GrowthMilestone.eight => 2,
  GrowthMilestone.halo => 3,
  GrowthMilestone.arrows => 4,
};

class EcologySecret {
  const EcologySecret({
    required this.id,
    required this.label,
    required this.eventId,
    required this.clue,
    required this.nicheId,
    required this.requiredChoices,
    required this.rigParts,
  });
  final String id;
  final String label;
  final String eventId;
  final String clue;
  final String nicheId;
  final Set<EcologyChoice> requiredChoices;
  final List<String> rigParts;
  bool matches(EcologyPath path) =>
      path.nicheId == nicheId &&
      path.witnessedEvents.contains(eventId) &&
      requiredChoices.every(path.decisions.values.contains);
}

const ecologySecrets = <EcologySecret>[
  EcologySecret(
    id: 'tool-user',
    label: 'Humanlike tool user',
    eventId: 'neighbor-finished-beam',
    clue: 'A neighbor freed a hand when the beam was ready.',
    nicheId: 'mammal.shelter',
    requiredChoices: {
      EcologyChoice.gatherPair,
      EcologyChoice.fitSupports,
      EcologyChoice.relayLoad,
    },
    rigParts: ['free-forelimbs', 'lever-grip', 'tool-user'],
  ),
  EcologySecret(
    id: 'walking-tree',
    label: 'Walking tree',
    eventId: 'roof-raised',
    clue: 'A living brace watched a roof go up.',
    nicheId: 'plant.brace',
    requiredChoices: {EcologyChoice.fitSupports, EcologyChoice.coverUrgent},
    rigParts: ['crown-brace', 'branch-bearing'],
  ),
  EcologySecret(
    id: 'lantern-cap',
    label: 'Lantern cap',
    eventId: 'starter-torch-delivered',
    clue: 'A cap watched the first flame reach shelter.',
    nicheId: 'fungus.lantern',
    requiredChoices: {EcologyChoice.scoutEntrance, EcologyChoice.relayLoad},
    rigParts: ['lit-gills', 'shade-flame'],
  ),
  EcologySecret(
    id: 'backward-gel',
    label: 'The second footprint',
    eventId: 'trail-doubled-footprint',
    clue: 'Two prints in the fog face different ways.',
    nicheId: 'gel.divide',
    requiredChoices: {
      EcologyChoice.braceSlope,
      EcologyChoice.collectBundles,
      EcologyChoice.carryTwoLights,
    },
    rigParts: ['knee-mouth', 'backward-hand', 'disputed-front'],
  ),
];

EcologySecret? ecologySecretById(String id) {
  for (final secret in ecologySecrets) {
    if (secret.id == id) return secret;
  }
  return null;
}

class CreatureWorkProfile {
  const CreatureWorkProfile({required this.activeEffects});
  final Set<String> activeEffects;
  factory CreatureWorkProfile.fromRecipe(CreatureRecipe recipe) =>
      CreatureWorkProfile(
        activeEffects: {
          if (recipe.ecologyPath case final EcologyPath path) ...[
            path.nicheId,
            for (final choice in path.decisions.values) choice.id,
          ],
          for (final perk in recipe.perks) 'legacy.${perk.name}',
        },
      );
  bool has(String effectId) => activeEffects.contains(effectId);
  int get sameDigitCapacity =>
      has(EcologyChoice.gatherPair.id) || has('legacy.extraDigitGrip') ? 2 : 1;
  int get sameProjectGlyphCapacity =>
      has(EcologyChoice.collectBundles.id) || has('legacy.letterCarrier')
      ? 2
      : 1;
  int get favoriteRestockBonus =>
      has(EcologyChoice.keepFavorite.id) || has('legacy.favoriteStock') ? 1 : 0;
  int get lightBatchCapacity => has(EcologyChoice.carryTwoLights.id) ? 2 : 1;
  int get revealAnchorCapacity => has('fungus.thread') ? 2 : 1;
  bool get canInspectVisibleConflict =>
      has(EcologyChoice.inspectConflict.id) ||
      has('legacy.visibleConflictCheck');
  int get offerExtensionMs =>
      has(EcologyChoice.holdOffer.id) || has('legacy.longerOffer') ? 2000 : 0;
  double multiplierFor({
    required TaskKind task,
    bool tilt = false,
    bool support = false,
    bool notice = false,
    bool linked = false,
    bool starter = false,
    bool handoff = false,
    bool urgentOutsidePreference = false,
    bool firstProjectTrip = false,
    bool finalProjectTrip = false,
    bool favoriteDigit = false,
    bool manuallyPrioritized = false,
    bool multiCopy = false,
    bool markedLetter = false,
    bool multiAnchor = false,
    bool changedWorkType = false,
    bool twoWaitingJobs = false,
  }) {
    var value = 1.0;
    if (task == TaskKind.digit && has(EcologyChoice.chase.id)) value *= .75;
    if (task == TaskKind.digit && tilt && has(EcologyChoice.braceSlope.id))
      value *= .65;
    if (task == TaskKind.building && has(EcologyChoice.hurryLoads.id))
      value *= .80;
    if (task == TaskKind.building &&
        support &&
        has(EcologyChoice.fitSupports.id))
      value *= .70;
    if (task == TaskKind.building && notice && has(EcologyChoice.readNotice.id))
      value *= .70;
    if (task == TaskKind.torch && has(EcologyChoice.hurryFlame.id))
      value *= .75;
    if (linked && has(EcologyChoice.linkedSignal.id)) value *= .65;
    if (starter && has(EcologyChoice.scoutEntrance.id)) value *= .65;
    if (handoff && has(EcologyChoice.relayLoad.id)) value *= .85;
    if (urgentOutsidePreference && has(EcologyChoice.coverUrgent.id))
      value *= .85;
    if (firstProjectTrip && has('plant.brace')) value *= .88;
    if (finalProjectTrip && has('plant.runner')) value *= .88;
    if (favoriteDigit && has('mammal.trails')) value *= .88;
    if (manuallyPrioritized && has('mammal.shelter')) value *= .88;
    if (multiCopy && has('arthropod.heap')) value *= .88;
    if (markedLetter && has('arthropod.silk')) value *= .88;
    if (tilt && has('reptile.ledge')) value *= .88;
    if (urgentOutsidePreference && has('reptile.site')) value *= .88;
    if (starter && has('fungus.lantern')) value *= .88;
    if (multiAnchor && has('fungus.thread')) value *= .88;
    if (changedWorkType && has('gel.current')) value *= .88;
    if (twoWaitingJobs && has('gel.divide')) value *= .88;
    return value;
  }
}

class CreatureDisposition {
  const CreatureDisposition({
    required this.sociability,
    required this.curiosity,
    required this.tidiness,
    required this.patience,
    required this.boldness,
  });
  final int sociability;
  final int curiosity;
  final int tidiness;
  final int patience;
  final int boldness;
  factory CreatureDisposition.legacy(Personality personality) =>
      switch (personality) {
        Personality.curious => const CreatureDisposition(
          sociability: 55,
          curiosity: 80,
          tidiness: 50,
          patience: 55,
          boldness: 55,
        ),
        Personality.collector => const CreatureDisposition(
          sociability: 45,
          curiosity: 55,
          tidiness: 75,
          patience: 65,
          boldness: 45,
        ),
        Personality.tinkerer => const CreatureDisposition(
          sociability: 50,
          curiosity: 70,
          tidiness: 45,
          patience: 70,
          boldness: 60,
        ),
      };
  String get nuisance => curiosity >= 75
      ? 'pokes marked letters'
      : tidiness <= 25
      ? 'pockets loose glyphs'
      : boldness >= 75 && patience <= 40
      ? 'stomps at conflicts'
      : 'watches the work';
  Map<String, dynamic> toJson() => {
    'sociability': sociability,
    'curiosity': curiosity,
    'tidiness': tidiness,
    'patience': patience,
    'boldness': boldness,
  };
  factory CreatureDisposition.fromJson(Map<String, dynamic> json) =>
      CreatureDisposition(
        sociability: json['sociability'] as int? ?? 50,
        curiosity: json['curiosity'] as int? ?? 50,
        tidiness: json['tidiness'] as int? ?? 50,
        patience: json['patience'] as int? ?? 50,
        boldness: json['boldness'] as int? ?? 50,
      );
}

class CreatureBond {
  CreatureBond({
    required String firstId,
    required String secondId,
    required int score,
    this.cooperativeTrips = 0,
    this.disputes = 0,
    this.lastDisputeActiveMs,
  }) : firstId = firstId.compareTo(secondId) <= 0 ? firstId : secondId,
       secondId = firstId.compareTo(secondId) <= 0 ? secondId : firstId,
       score = score.clamp(-3, 3);
  final String firstId;
  final String secondId;
  int score;
  int cooperativeTrips;
  int disputes;
  int? lastDisputeActiveMs;
  factory CreatureBond.initial(Creature a, Creature b) {
    final ids = [a.id, b.id]..sort();
    var hash = 0x811c9dc5;
    for (final unit in '${ids[0]}\u0000${ids[1]}'.codeUnits)
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    var score = hash % 3 - 1;
    if (a.favorite == b.favorite) score++;
    if ((a.disposition.tidiness - b.disposition.tidiness).abs() >= 45) score++;
    if (a.memory.preferredTask != null &&
        b.memory.preferredTask != null &&
        a.memory.preferredTask != b.memory.preferredTask) {
      score++;
    }
    return CreatureBond(firstId: ids[0], secondId: ids[1], score: score);
  }
  bool get friends => score >= 2;
  bool get rivals => score <= -2;
  bool canDispute(int activeMs) =>
      rivals &&
      (lastDisputeActiveMs == null || activeMs - lastDisputeActiveMs! >= 60000);
  void recordCooperation() {
    cooperativeTrips++;
    score = math.min(3, score + 1);
  }

  bool recordDispute(int activeMs) {
    if (!canDispute(activeMs)) return false;
    lastDisputeActiveMs = activeMs;
    disputes++;
    score = math.max(-3, score - 1);
    return true;
  }

  Map<String, dynamic> toJson() => {
    'firstId': firstId,
    'secondId': secondId,
    'score': score,
    'cooperativeTrips': cooperativeTrips,
    'disputes': disputes,
    if (lastDisputeActiveMs != null) 'lastDisputeActiveMs': lastDisputeActiveMs,
  };
  factory CreatureBond.fromJson(Map<String, dynamic> json) => CreatureBond(
    firstId: json['firstId'] as String,
    secondId: json['secondId'] as String,
    score: json['score'] as int,
    cooperativeTrips: json['cooperativeTrips'] as int? ?? 0,
    disputes: json['disputes'] as int? ?? 0,
    lastDisputeActiveMs: json['lastDisputeActiveMs'] as int?,
  );
}
