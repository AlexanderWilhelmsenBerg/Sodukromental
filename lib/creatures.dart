import 'dart:math' as math;

part 'creature_ecology.dart';

enum GrowthMilestone { opening, five, six, seven, eight, halo, arrows }

enum GrowthGroup {
  locomotion('Locomotion'),
  shape('Body shape'),
  coat('Coat'),
  senses('Senses'),
  carrying('Carrying'),
  building('Building'),
  torch('Torch handling'),
  gestures('Gestures'),
  oddity('Odd changes');

  const GrowthGroup(this.label);
  final String label;
}

enum WorkPerk {
  quickSteps(
    'Quick steps',
    GrowthMilestone.five,
    'Digit trips take 25% less time.',
  ),
  extraDigitGrip(
    'Extra digit grip',
    GrowthMilestone.five,
    'Carry one extra copy of the requested digit.',
  ),
  stableFooting(
    'Stable footing',
    GrowthMilestone.six,
    'Digit trips during tilt take 35% less time.',
  ),
  favoriteStock(
    'Favorite stock',
    GrowthMilestone.six,
    'Restock one extra copy of this favorite digit.',
  ),
  letterCarrier(
    'Letter carrier',
    GrowthMilestone.seven,
    'Carry one extra letter for the same project.',
  ),
  fastBuilder(
    'Fast builder',
    GrowthMilestone.seven,
    'Letter trips take 20% less time.',
  ),
  visibleConflictCheck(
    'Visible conflict check',
    GrowthMilestone.eight,
    'Look for conflicts supported by visible clues.',
  ),
  longerOffer(
    'Longer offer',
    GrowthMilestone.eight,
    'Hold up digits for two extra seconds.',
  ),
  fastTorchTrip(
    'Fast torch trip',
    GrowthMilestone.halo,
    'Torch trips take 25% less time.',
  );

  const WorkPerk(this.label, this.milestone, this.description);
  final String label;
  final GrowthMilestone milestone;
  final String description;
}

enum Personality { curious, collector, tinkerer }

enum TaskKind { digit, torch, building }

class GrowthNode {
  const GrowthNode(
    this.id,
    this.group,
    this.label,
    this.milestone,
    this.effect, [
    this.requires = const <String>[],
  ]);

  final String id;
  final GrowthGroup group;
  final String label;
  final GrowthMilestone milestone;
  final String effect;
  final List<String> requires;

  bool isAvailable(GrowthMilestone reached, Iterable<String> selected) =>
      reached.index >= milestone.index && requires.every(selected.contains);
}

const growthNodes = <GrowthNode>[
  GrowthNode(
    'bipedal',
    GrowthGroup.locomotion,
    'Grow two legs',
    GrowthMilestone.five,
    'Alternating strides',
  ),
  GrowthNode(
    'quadrupedal',
    GrowthGroup.locomotion,
    'Grow four legs',
    GrowthMilestone.five,
    'Paired footfalls',
  ),
  GrowthNode(
    'slime',
    GrowthGroup.locomotion,
    'Grow a glide foot',
    GrowthMilestone.five,
    'Stretch and glide',
  ),
  GrowthNode(
    'six-legs',
    GrowthGroup.locomotion,
    'Grow six legs',
    GrowthMilestone.six,
    'Tripod footfalls',
  ),
  GrowthNode(
    'tiny-feet',
    GrowthGroup.locomotion,
    'Grow many tiny feet',
    GrowthMilestone.six,
    'Rippling footfalls',
  ),
  GrowthNode(
    'hover',
    GrowthGroup.locomotion,
    'Learn to hover',
    GrowthMilestone.eight,
    'Lift clear of the ground',
  ),
  GrowthNode(
    'round',
    GrowthGroup.shape,
    'Grow round',
    GrowthMilestone.five,
    'Round shell',
  ),
  GrowthNode(
    'long',
    GrowthGroup.shape,
    'Grow long',
    GrowthMilestone.five,
    'Long shell',
  ),
  GrowthNode(
    'squat',
    GrowthGroup.shape,
    'Grow squat',
    GrowthMilestone.five,
    'Low shell',
  ),
  GrowthNode(
    'flat',
    GrowthGroup.shape,
    'Grow wide and flat',
    GrowthMilestone.seven,
    'Wide silhouette',
  ),
  GrowthNode(
    'segmented',
    GrowthGroup.shape,
    'Grow segments',
    GrowthMilestone.eight,
    'Overlapping segments',
  ),
  GrowthNode(
    'lobes',
    GrowthGroup.shape,
    'Grow connected lobes',
    GrowthMilestone.eight,
    'Two bobbing lobes',
  ),
  GrowthNode(
    'smooth',
    GrowthGroup.coat,
    'Grow smooth skin',
    GrowthMilestone.five,
    'Clear shell edge',
  ),
  GrowthNode(
    'fur',
    GrowthGroup.coat,
    'Grow short fur',
    GrowthMilestone.five,
    'Tufted shell edge',
  ),
  GrowthNode(
    'gel',
    GrowthGroup.coat,
    'Grow a gel coat',
    GrowthMilestone.five,
    'Gleaming shell',
  ),
  GrowthNode(
    'scales',
    GrowthGroup.coat,
    'Grow scales',
    GrowthMilestone.six,
    'Diamond scale pattern',
  ),
  GrowthNode(
    'plates',
    GrowthGroup.coat,
    'Grow overlapping plates',
    GrowthMilestone.six,
    'Band pattern',
  ),
  GrowthNode(
    'paper',
    GrowthGroup.coat,
    'Grow paper fibers',
    GrowthMilestone.eight,
    'Thread pattern',
  ),
  GrowthNode(
    'whiskers',
    GrowthGroup.senses,
    'Grow whiskers',
    GrowthMilestone.six,
    'Cheek whiskers',
  ),
  GrowthNode(
    'ears',
    GrowthGroup.senses,
    'Grow upright ears',
    GrowthMilestone.six,
    'Upright ears',
  ),
  GrowthNode(
    'stalks',
    GrowthGroup.senses,
    'Grow eye stalks',
    GrowthMilestone.six,
    'Elevated eyes',
  ),
  GrowthNode(
    'rotating-eye',
    GrowthGroup.senses,
    'Grow a rotating eye',
    GrowthMilestone.six,
    'Traveling pupil',
  ),
  GrowthNode(
    'feelers',
    GrowthGroup.senses,
    'Grow feelers',
    GrowthMilestone.six,
    'Flexible feelers',
  ),
  GrowthNode(
    'ankle-ears',
    GrowthGroup.senses,
    'Grow ears on ankles',
    GrowthMilestone.six,
    'Listeners near the ground',
  ),
  GrowthNode(
    'hands',
    GrowthGroup.carrying,
    'Grow hands',
    GrowthMilestone.six,
    'Hand grips',
  ),
  GrowthNode(
    'pincers',
    GrowthGroup.carrying,
    'Grow pincers',
    GrowthMilestone.six,
    'Two claw grips',
  ),
  GrowthNode(
    'hooked-tail',
    GrowthGroup.carrying,
    'Grow a hooked tail',
    GrowthMilestone.six,
    'Rear cargo mount',
  ),
  GrowthNode(
    'lip-pocket',
    GrowthGroup.carrying,
    'Grow a lip pocket',
    GrowthMilestone.six,
    'Low front cargo mount',
  ),
  GrowthNode(
    'sticky-pad',
    GrowthGroup.carrying,
    'Grow a sticky pad',
    GrowthMilestone.six,
    'Flat cargo mount',
  ),
  GrowthNode(
    'cradle',
    GrowthGroup.carrying,
    'Grow an overhead cradle',
    GrowthMilestone.six,
    'High cargo mount',
  ),
  GrowthNode(
    'fold',
    GrowthGroup.building,
    'Fold letters',
    GrowthMilestone.seven,
    'Angle each letter',
  ),
  GrowthNode(
    'stack',
    GrowthGroup.building,
    'Stack letters',
    GrowthMilestone.seven,
    'Lift each letter',
  ),
  GrowthNode(
    'weave',
    GrowthGroup.building,
    'Weave strips',
    GrowthMilestone.seven,
    'Rock strips from side to side',
  ),
  GrowthNode(
    'press',
    GrowthGroup.building,
    'Press pieces together',
    GrowthMilestone.seven,
    'Press letters close',
  ),
  GrowthNode(
    'wedge',
    GrowthGroup.building,
    'Wedge pieces into place',
    GrowthMilestone.seven,
    'Nudge letters down',
  ),
  GrowthNode(
    'polish',
    GrowthGroup.building,
    'Polish each piece',
    GrowthMilestone.seven,
    'Bring out a glint',
  ),
  GrowthNode(
    'hooded-lamp',
    GrowthGroup.torch,
    'Carry a hooded lamp',
    GrowthMilestone.halo,
    'Shade the lamp above',
  ),
  GrowthNode(
    'sling-lantern',
    GrowthGroup.torch,
    'Sling a lantern',
    GrowthMilestone.halo,
    'Swing the lamp',
  ),
  GrowthNode(
    'candle',
    GrowthGroup.torch,
    'Balance a candle',
    GrowthMilestone.halo,
    'Balance a tall flame',
  ),
  GrowthNode(
    'tail-lamp',
    GrowthGroup.torch,
    'Trail a lamp on your tail',
    GrowthMilestone.halo,
    'Trail the light',
  ),
  GrowthNode(
    'fin-torch',
    GrowthGroup.torch,
    'Lift a torch on fins',
    GrowthMilestone.halo,
    'Lift the light',
  ),
  GrowthNode(
    'chin-light',
    GrowthGroup.torch,
    'Carry a light under your chin',
    GrowthMilestone.halo,
    'Light the ground',
  ),
  GrowthNode(
    'wide-swing',
    GrowthGroup.gestures,
    'Swing arms widely',
    GrowthMilestone.seven,
    'Wide arm sweep',
  ),
  GrowthNode(
    'head-bob',
    GrowthGroup.gestures,
    'Bob your head',
    GrowthMilestone.seven,
    'Quick head dip',
  ),
  GrowthNode(
    'tail-tap',
    GrowthGroup.gestures,
    'Tap your tail',
    GrowthMilestone.seven,
    'Tail taps the floor',
  ),
  GrowthNode(
    'side-flap',
    GrowthGroup.gestures,
    'Flap your sides',
    GrowthMilestone.seven,
    'Fluttering sides',
  ),
  GrowthNode(
    'fan-feelers',
    GrowthGroup.gestures,
    'Fan your feelers',
    GrowthMilestone.seven,
    'Sweeping feelers',
  ),
  GrowthNode(
    'salute',
    GrowthGroup.gestures,
    'Salute with both hands',
    GrowthMilestone.seven,
    'Raised hands',
  ),
  GrowthNode(
    'tail-feet',
    GrowthGroup.oddity,
    'Grow a tail with feet',
    GrowthMilestone.arrows,
    'Independently trotting tail',
    ['slime', 'hooked-tail'],
  ),
  GrowthNode(
    'knee-fin',
    GrowthGroup.oddity,
    'Grow a fin on your knee',
    GrowthMilestone.seven,
    'Low side fin',
  ),
  GrowthNode(
    'belly-hinge',
    GrowthGroup.oddity,
    'Grow a hinge in your belly',
    GrowthMilestone.seven,
    'Opening seam',
  ),
  GrowthNode(
    'elbow-fur',
    GrowthGroup.oddity,
    'Grow fur on one elbow',
    GrowthMilestone.seven,
    'Single side tuft',
  ),
  GrowthNode(
    'floating-hand',
    GrowthGroup.oddity,
    'Grow a floating hand',
    GrowthMilestone.arrows,
    'Hand circles the body',
  ),
  GrowthNode(
    'yawning-mouth',
    GrowthGroup.oddity,
    'Grow a mouth that only yawns',
    GrowthMilestone.arrows,
    'Second sleepy mouth',
  ),
  GrowthNode(
    'under-fur',
    GrowthGroup.oddity,
    'Grow fur on the underside',
    GrowthMilestone.eight,
    'Tufts hang below the body',
    ['fur', 'hover'],
  ),
  GrowthNode(
    'clear-paws',
    GrowthGroup.oddity,
    'Grow translucent paws',
    GrowthMilestone.five,
    'Clear feet',
    ['quadrupedal', 'gel'],
  ),
  GrowthNode(
    'sideways',
    GrowthGroup.oddity,
    'Carry things sideways',
    GrowthMilestone.seven,
    'Side cargo mount',
    ['flat', 'cradle'],
  ),
];

final growthById = Map<String, GrowthNode>.unmodifiable({
  for (final node in growthNodes) node.id: node,
});

class CreatureRecipe {
  CreatureRecipe({
    Map<GrowthGroup, String> choices = const {},
    Iterable<WorkPerk> perks = const [],
    this.ecologyPath,
  }) : choices = Map.unmodifiable(choices),
       perks = List.unmodifiable(perks);

  factory CreatureRecipe.starter() => CreatureRecipe(
    choices: {
      GrowthGroup.locomotion: 'bipedal',
      GrowthGroup.shape: 'round',
      GrowthGroup.coat: 'smooth',
    },
    perks: [WorkPerk.quickSteps],
  );

  final Map<GrowthGroup, String> choices;
  final List<WorkPerk> perks;
  final EcologyPath? ecologyPath;

  /// Phase 2's guided hatch. Unlike the legacy body editor, every visible
  /// body feature is a projection of a stable life-path decision.
  factory CreatureRecipe.ecology({
    required CreatureFounder founder,
    required String nicheId,
    EcologyChoice? firstDecision,
  }) {
    var path = EcologyPath(founder: founder, nicheId: nicheId);
    if (firstDecision != null) path = path.choose(firstDecision);
    return CreatureRecipe(ecologyPath: path);
  }

  /// A deterministic, lineage-appropriate basic resident for colony grants.
  factory CreatureRecipe.communal(
    CreatureFounder founder, {
    int nicheIndex = 0,
  }) {
    final niches = ecologyNiches
        .where((niche) => niche.founder == founder)
        .toList(growable: false);
    final niche = niches[nicheIndex.abs() % niches.length];
    return CreatureRecipe.ecology(
      founder: founder,
      nicheId: niche.id,
      firstDecision: EcologyChoice.values
          .where((choice) => choice.family == DecisionFamily.digit)
          .elementAt(nicheIndex.abs() % 2),
    );
  }

  List<WorkPerk> get effectivePerks =>
      List.unmodifiable({...perks, ...?ecologyPath?.projectedPerks});

  CreatureWorkProfile get workProfile => CreatureWorkProfile.fromRecipe(this);

  static int perkLimit(GrowthMilestone milestone) => switch (milestone) {
    GrowthMilestone.opening => 0,
    GrowthMilestone.five || GrowthMilestone.six || GrowthMilestone.seven => 1,
    GrowthMilestone.eight || GrowthMilestone.halo => 2,
    GrowthMilestone.arrows => 3,
  };

  CreatureRecipe withChoice(GrowthNode node) => CreatureRecipe(
    choices: {...choices, node.group: node.id},
    perks: perks,
    ecologyPath: ecologyPath,
  );

  CreatureRecipe withoutChoice(GrowthGroup group) => CreatureRecipe(
    choices: {...choices}..remove(group),
    perks: perks,
    ecologyPath: ecologyPath,
  );

  CreatureRecipe withPerks(Iterable<WorkPerk> values) =>
      CreatureRecipe(choices: choices, perks: values, ecologyPath: ecologyPath);

  CreatureRecipe withEcologyPath(EcologyPath path) =>
      CreatureRecipe(choices: choices, perks: perks, ecologyPath: path);

  List<String> validate(GrowthMilestone milestone) {
    if (ecologyPath case final EcologyPath path) {
      return path.validate(milestone);
    }
    final errors = <String>[];
    for (final group in GrowthGroup.values.take(3)) {
      if (!choices.containsKey(group))
        errors.add('Choose ${group.label.toLowerCase()}.');
    }
    for (final choice in choices.entries) {
      final node = growthById[choice.value];
      if (node == null || node.group != choice.key) {
        errors.add('Choose a valid ${choice.key.label.toLowerCase()} feature.');
      } else if (!node.isAvailable(milestone, choices.values)) {
        final missing = node.requires.where(
          (id) => !choices.values.contains(id),
        );
        errors.add(
          missing.isEmpty
              ? '${node.label} is still locked.'
              : '${node.label} requires ${missing.map((id) => growthById[id]!.label.toLowerCase()).join(' and ')}.',
        );
      }
    }
    final limit = perkLimit(milestone);
    if (perks.length > limit ||
        perks.isEmpty ||
        perks.toSet().length != perks.length) {
      errors.add(
        limit == 0
            ? 'Clear 5×5 to choose a work perk.'
            : 'Choose 1 to $limit different work perks.',
      );
    }
    if (perks.any((perk) => perk.milestone.index > milestone.index)) {
      errors.add('One or more work perks are still locked.');
    }
    return errors;
  }

  factory CreatureRecipe.fromJson(Map<String, dynamic> json) {
    final choices = json['choices'] as Map? ?? const {};
    final perks = json['perks'] as List? ?? const [];
    return CreatureRecipe(
      choices: {
        for (final group in GrowthGroup.values)
          if (choices[group.name] case final String id) group: id,
      },
      perks: WorkPerk.values.where((perk) => perks.contains(perk.name)),
      ecologyPath: json['ecologyPath'] is Map
          ? EcologyPath.fromJson(
              Map<String, dynamic>.from(json['ecologyPath'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'choices': {
      for (final entry in choices.entries) entry.key.name: entry.value,
    },
    'perks': [for (final perk in perks) perk.name],
    if (ecologyPath != null) 'ecologyPath': ecologyPath!.toJson(),
  };
}

class HatchPrice {
  const HatchPrice(this.dna, this.rna);
  final int dna;
  final int rna;

  factory HatchPrice.quote(int designedNumber, int perkCount) {
    final scale = math.pow(1.45, math.max(0, designedNumber - 1));
    final extra = math.max(0, perkCount - 1);
    return HatchPrice(
      (4 * scale).ceil() + extra,
      (8 * scale).ceil() + 2 * extra,
    );
  }

  /// Each newly filled nurture family costs the response increment only.
  static const nurture = HatchPrice(1, 2);

  @override
  bool operator ==(Object other) =>
      other is HatchPrice && dna == other.dna && rna == other.rna;

  @override
  int get hashCode => Object.hash(dna, rna);
}

class CreatureDraft {
  const CreatureDraft({
    required this.commandId,
    required this.recipe,
    required this.reviewing,
  });

  final String commandId;
  final CreatureRecipe recipe;
  final bool reviewing;

  factory CreatureDraft.fromJson(Map<String, dynamic> json) => CreatureDraft(
    commandId: json['commandId'] as String,
    recipe: CreatureRecipe.fromJson(
      Map<String, dynamic>.from(json['recipe'] as Map),
    ),
    reviewing: json['reviewing'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'commandId': commandId,
    'recipe': recipe.toJson(),
    'reviewing': reviewing,
  };
}

class CreatureAppearance {
  CreatureAppearance({
    required Iterable<int> palette,
    required this.marking,
    required this.eyeCount,
    required this.cheeks,
    required Iterable<String> parts,
  }) : palette = List.unmodifiable(palette),
       parts = List.unmodifiable(parts);

  final List<int> palette;
  final String marking;
  final int eyeCount;
  final bool cheeks;
  final List<String> parts;

  static const outline = 0xff212832;
  static const previewPalette = [0xff79a9a3, 0xff487b76, 0xffd2efca];

  factory CreatureAppearance.fromJson(Map<String, dynamic> json) =>
      CreatureAppearance(
        palette: (json['palette'] as List?)?.cast<int>() ?? previewPalette,
        marking: json['marking'] as String? ?? 'dots',
        eyeCount: json['eyeCount'] as int? ?? 2,
        cheeks: json['cheeks'] as bool? ?? false,
        parts: (json['parts'] as List?)?.cast<String>() ?? [],
      );

  Map<String, dynamic> toJson() => {
    'palette': palette,
    'outline': outline,
    'marking': marking,
    'eyeCount': eyeCount,
    'cheeks': cheeks,
    'parts': parts,
  };
}

const _palettes = [
  [0xff90be6d, 0xff568454, 0xffecf2b9],
  [0xff79a9a3, 0xff487b76, 0xffd2efca],
  [0xffed9b54, 0xffad4d48, 0xffffdeb1],
  [0xff83a2df, 0xff4f5c9a, 0xffe0e8ff],
  [0xffd198d1, 0xff8f5591, 0xffffe4ef],
  [0xffe8bb43, 0xff9e6639, 0xfffcf0ac],
];

int _mix(int x) {
  x &= 0xffffffff;
  x ^= x >>> 16;
  x = (x * 0x7feb352d) & 0xffffffff;
  x ^= x >>> 15;
  x = (x * 0x846ca68b) & 0xffffffff;
  return (x ^ (x >>> 16)) & 0xffffffff;
}

class Creature {
  Creature({
    required this.id,
    required this.name,
    required this.favorite,
    required this.isAmoeba,
    required this.personality,
    required this.recipe,
    required this.appearance,
    CreatureDisposition? disposition,
    CompanionMemory? memory,
  }) : disposition = disposition ?? CreatureDisposition.legacy(personality),
       memory = memory ?? CompanionMemory();

  final String id;
  String name;
  final int favorite;
  final bool isAmoeba;
  final Personality personality;
  CreatureRecipe recipe;
  CreatureAppearance appearance;
  final CreatureDisposition disposition;
  final CompanionMemory memory;

  List<WorkPerk> get perks => recipe.effectivePerks;
  CreatureWorkProfile get workProfile => recipe.workProfile;

  bool canNurture(EcologyChoice choice, GrowthMilestone milestone) {
    final path = recipe.ecologyPath;
    if (path == null || path.decisions.containsKey(choice.family)) return false;
    return path.choose(choice).validate(milestone).isEmpty;
  }

  /// Fills one previously empty family. Replacing an expressed response is a
  /// branch for a future hatch, never an edit to this individual.
  bool nurture(EcologyChoice choice, GrowthMilestone milestone) {
    if (!canNurture(choice, milestone)) return false;
    recipe = recipe.withEcologyPath(recipe.ecologyPath!.choose(choice));
    appearance = CreatureAppearance(
      palette: appearance.palette,
      marking: appearance.marking,
      eyeCount: appearance.eyeCount,
      cheeks: appearance.cheeks,
      parts: {
        ...appearance.parts,
        ecologyExpression(recipe.ecologyPath!.nicheId, choice).rigPart,
      },
    );
    return true;
  }

  factory Creature.amoeba(int runSeed) => Creature.generate(
    runSeed: runSeed,
    sequence: 0,
    unlockedDigits: 4,
    recipe: CreatureRecipe(
      choices: {
        GrowthGroup.locomotion: 'slime',
        GrowthGroup.shape: 'squat',
        GrowthGroup.coat: 'gel',
      },
    ),
  );

  factory Creature.generate({
    required int runSeed,
    required int sequence,
    required int unlockedDigits,
    required CreatureRecipe recipe,
  }) {
    final seed = _mix(runSeed ^ _mix(sequence));
    int draw(int stream, int count) => _mix(seed ^ _mix(stream)) % count;
    final amoeba = sequence == 0;
    final digitCount = unlockedDigits.clamp(1, 9);
    var favoriteDraw = _mix(seed ^ _mix(4));
    final acceptedRange = (0x100000000 ~/ digitCount) * digitCount;
    while (favoriteDraw >= acceptedRange) {
      favoriteDraw = _mix(favoriteDraw + 1);
    }
    return Creature(
      id: '$runSeed-creature-$sequence',
      name: amoeba ? 'Amoeba' : 'Helper $sequence',
      favorite: amoeba ? 4 : favoriteDraw % digitCount + 1,
      isAmoeba: amoeba,
      personality: Personality.values[draw(5, Personality.values.length)],
      recipe: recipe,
      disposition: CreatureDisposition(
        sociability: draw(11, 101),
        curiosity: draw(12, 101),
        tidiness: draw(13, 101),
        patience: draw(14, 101),
        boldness: draw(15, 101),
      ),
      appearance: CreatureAppearance(
        palette: _palettes[draw(1, _palettes.length)],
        marking: const ['dots', 'stripe', 'diamond', 'freckles'][draw(2, 4)],
        eyeCount: draw(3, 2) + 1,
        cheeks: draw(6, 2) == 0,
        parts: [
          ...recipe.choices.values,
          ...?recipe.ecologyPath?.projectedParts,
          if (!recipe.choices.containsKey(GrowthGroup.senses))
            const ['cheek-dots', 'small-feeler', 'scallop'][draw(7, 3)],
        ],
      ),
    );
  }

  factory Creature.preview(CreatureRecipe recipe, GrowthMilestone milestone) =>
      Creature(
        id: 'preview',
        name: 'Creature preview',
        favorite: 0,
        isAmoeba: false,
        personality: Personality.curious,
        recipe: recipe,
        disposition: const CreatureDisposition(
          sociability: 65,
          curiosity: 70,
          tidiness: 50,
          patience: 55,
          boldness: 55,
        ),
        appearance: CreatureAppearance(
          palette: CreatureAppearance.previewPalette,
          marking: 'dots',
          eyeCount: 2,
          cheeks: true,
          parts: [
            for (final id in recipe.choices.values)
              if (growthById[id]?.isAvailable(
                    milestone,
                    recipe.choices.values,
                  ) ==
                  true)
                id,
            ...?recipe.ecologyPath?.projectedParts,
          ],
        ),
      );

  factory Creature.fromJson(Map<String, dynamic> json) => Creature(
    id: json['id'] as String,
    name: json['name'] as String,
    favorite: json['favorite'] as int,
    isAmoeba: json['isAmoeba'] as bool? ?? false,
    personality: Personality.values.byName(json['personality'] as String),
    recipe: CreatureRecipe.fromJson(
      Map<String, dynamic>.from(json['recipe'] as Map),
    ),
    appearance: CreatureAppearance.fromJson(
      Map<String, dynamic>.from(json['appearance'] as Map),
    ),
    disposition: json['disposition'] is Map
        ? CreatureDisposition.fromJson(
            Map<String, dynamic>.from(json['disposition'] as Map),
          )
        : null,
    memory: CompanionMemory.fromJson(
      Map<String, dynamic>.from(json['memory'] as Map? ?? {}),
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'favorite': favorite,
    'isAmoeba': isAmoeba,
    'personality': personality.name,
    'recipe': recipe.toJson(),
    'appearance': appearance.toJson(),
    'disposition': disposition.toJson(),
    'memory': memory.toJson(),
  };
}

class TaughtPhrase {
  TaughtPhrase(this.id, this.text, {this.allowOutside = false});

  final int id;
  final String text;
  bool allowOutside;

  factory TaughtPhrase.fromJson(Map<dynamic, dynamic> json) => TaughtPhrase(
    json['id'] as int,
    json['text'] as String,
    allowOutside: json['outside'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'outside': allowOutside,
  };
}

enum CompanionWaypoint { home, library, profile }

class CompanionMemory {
  final _contributions = <String, TaskKind>{};
  final _completedTasks = <String, TaskKind>{};
  final _sharedClears = <String>{};
  final _encouragements = <String>{};
  final _phrases = <TaughtPhrase>[];
  int _nextPhraseId = 1;
  int? _lastEchoMs;

  bool retained = false;
  bool muted = false;
  bool outsideOptIn = false;
  int? lastRequest;
  TaskKind? preferredTask;

  List<TaughtPhrase> get phrases => List.unmodifiable(_phrases);
  int get sharedClears => _sharedClears.length;
  bool get canSuggest => sharedClears >= 2;
  bool get canVisit => retained && sharedClears >= 4;
  bool get canAskOutside => retained && sharedClears >= 6;

  String _key(Object runId, Object encounterId) =>
      '${runId.toString().length}:$runId$encounterId';

  void recordContribution(Object runId, Object encounterId, TaskKind task) {
    _contributions[_key(runId, encounterId)] = task;
  }

  void recordTask(Object runId, Object encounterId, TaskKind task) {
    _completedTasks[_key(runId, encounterId)] = task;
  }

  bool recordClear(Object runId, Object encounterId) {
    final key = _key(runId, encounterId);
    return _contributions.containsKey(key) && _sharedClears.add(key);
  }

  bool encourage(Object runId, Object encounterId) {
    final key = _key(runId, encounterId);
    final task = _completedTasks[key] ?? _contributions[key];
    if (task == null || !_encouragements.add(key)) return false;
    preferredTask = task;
    return true;
  }

  int? suggestDigit(Map<int, int> stock, {int threshold = 1}) {
    final digit = lastRequest;
    return canSuggest && digit != null && (stock[digit] ?? 0) <= threshold
        ? digit
        : null;
  }

  CompanionWaypoint? waypoint(int epochMs, {required bool priorityWork}) {
    if (priorityWork || !canVisit) return null;
    return CompanionWaypoint.values[(epochMs ~/ 24000) %
        CompanionWaypoint.values.length];
  }

  TaughtPhrase? teach(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final phrase = TaughtPhrase(_nextPhraseId++, trimmed);
    _phrases.add(phrase);
    return phrase;
  }

  bool deletePhrase(int id) {
    final index = _phrases.indexWhere((entry) => entry.id == id);
    if (index < 0) return false;
    _phrases.removeAt(index);
    return true;
  }

  List<String> get approvedOutsidePhrases => muted
      ? const []
      : [
          for (final phrase in _phrases)
            if (phrase.allowOutside) _shortEcho(phrase.text),
        ];

  String? nextEcho(int epochMs) {
    final last = _lastEchoMs;
    if (muted || _phrases.isEmpty || (last != null && epochMs - last < 90000))
      return null;
    _lastEchoMs = epochMs;
    return _shortEcho(_phrases[(epochMs ~/ 90000) % _phrases.length].text);
  }

  static String _shortEcho(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ');
    final runes = normalized.runes;
    return runes.length <= 42
        ? normalized
        : '${String.fromCharCodes(runes.take(41))}…';
  }

  CompanionMemory();

  factory CompanionMemory.fromJson(Map<String, dynamic> json) {
    final memory = CompanionMemory()
      ..retained = json['retained'] as bool? ?? false
      ..muted = json['muted'] as bool? ?? false
      ..outsideOptIn = json['outsideOptIn'] as bool? ?? false
      ..lastRequest = json['lastRequest'] as int?
      ..preferredTask = TaskKind.values.asNameMap()[json['preferredTask']]
      .._nextPhraseId = json['nextPhraseId'] as int? ?? 1
      .._lastEchoMs = json['lastEchoMs'] as int?;
    memory._contributions.addAll(_savedTasks(json['contributions']));
    memory._completedTasks.addAll(_savedTasks(json['completedTasks']));
    memory._sharedClears.addAll(
      (json['sharedClears'] as List? ?? const []).cast<String>(),
    );
    memory._encouragements.addAll(
      (json['encouragements'] as List? ?? const []).cast<String>(),
    );
    memory._phrases.addAll(
      (json['phrases'] as List? ?? const []).map(
        (entry) => TaughtPhrase.fromJson(entry as Map),
      ),
    );
    return memory;
  }

  static Map<String, TaskKind> _savedTasks(Object? value) => {
    if (value is Map)
      for (final entry in value.entries)
        if (TaskKind.values.asNameMap()[entry.value] case final TaskKind task)
          entry.key as String: task,
  };

  Map<String, dynamic> toJson() => {
    'retained': retained,
    'muted': muted,
    'outsideOptIn': outsideOptIn,
    'lastRequest': lastRequest,
    'preferredTask': preferredTask?.name,
    'contributions': {
      for (final entry in _contributions.entries) entry.key: entry.value.name,
    },
    'completedTasks': {
      for (final entry in _completedTasks.entries) entry.key: entry.value.name,
    },
    'sharedClears': _sharedClears.toList(),
    'encouragements': _encouragements.toList(),
    'phrases': [for (final phrase in _phrases) phrase.toJson()],
    'nextPhraseId': _nextPhraseId,
    'lastEchoMs': _lastEchoMs,
  };
}

enum MaterialRole { roof, support, ring, beam }

class MaterialGlyph {
  const MaterialGlyph(this.id, this.glyph, this.role, [this.index]);
  final String id;
  final String glyph;
  final MaterialRole role;
  final int? index;
}

const starterMaterialSentence = 'A nest is a home.';
const starterGlyphs = [
  MaterialGlyph('nest-roof', 'A', MaterialRole.roof, 0),
  MaterialGlyph('nest-support-t', 't', MaterialRole.support, 5),
  MaterialGlyph('nest-support-i', 'i', MaterialRole.support, 7),
  MaterialGlyph('nest-ring', 'o', MaterialRole.ring, 13),
  MaterialGlyph('notice-beam-h', 'h', MaterialRole.beam, 12),
  MaterialGlyph('notice-beam-m', 'm', MaterialRole.beam, 14),
];
