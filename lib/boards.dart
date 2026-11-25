import 'authored_boards.dart';

enum RuleKind {
  renban('Renban', 'The line contains consecutive digits in any order.'),
  thermometer('Thermometer', 'Digits increase from the bulb to the tip.'),
  kropkiWhite('White Kropki dot', 'The two digits differ by one.'),
  kropkiBlack('Black Kropki dot', 'One digit is twice the other.'),
  germanWhispers('German Whispers', 'Adjacent digits differ by at least five.'),
  killer('Killer cage', 'The digits are all different and add to the total.'),
  arrow('Arrow', 'The digits on the shaft add to the circled digit.'),
  palindrome('Palindrome', 'The digits read the same from either end.'),
  regionSum('Region Sum Line', 'The segments in each region have equal sums.'),
  sandwich('Sandwich', 'Digits between 1 and 9 add to the outside clue.'),
  xSums('X-Sums', 'The first digit X tells how many digits add to the clue.'),
  diagonal('Diagonal', 'Each marked diagonal contains every digit once.'),
  antiKnight('Anti-Knight', 'Cells a chess knight move apart differ.');

  const RuleKind(this.label, this.explanation);
  final String label;
  final String explanation;
}

enum FogKind { none, halo, trail, linked }

class VariantRule {
  const VariantRule(this.kind, this.cells, {this.target});

  final RuleKind kind;
  final List<int> cells;
  final int? target;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'cells': cells,
    if (target != null) 'target': target,
  };

  factory VariantRule.fromJson(Map<String, dynamic> json) => VariantRule(
    RuleKind.values.byName(json['kind'] as String),
    (json['cells'] as List).cast<int>(),
    target: json['target'] as int?,
  );

  bool allows(List<int> values, int size, List<int> regions) {
    final digits = cells.map((index) => values[index]).toList();
    final filled = digits.where((digit) => digit != 0).toList();
    switch (kind) {
      case RuleKind.renban:
        if (filled.length != filled.toSet().length) return false;
        if (filled.length < 2) return true;
        filled.sort();
        return filled.last - filled.first < digits.length;
      case RuleKind.thermometer:
        var previous = 0;
        var previousIndex = -1;
        for (var index = 0; index < digits.length; index++) {
          final value = digits[index];
          if (value == 0) continue;
          if (value - previous < index - previousIndex ||
              value > size - digits.length + index + 1) {
            return false;
          }
          previous = value;
          previousIndex = index;
        }
        return true;
      case RuleKind.kropkiWhite:
      case RuleKind.kropkiBlack:
        if (filled.length < 2) return true;
        final a = digits.first;
        final b = digits.last;
        return kind == RuleKind.kropkiWhite
            ? (a - b).abs() == 1
            : a == b * 2 || b == a * 2;
      case RuleKind.germanWhispers:
        for (var index = 1; index < digits.length; index++) {
          final a = digits[index - 1];
          final b = digits[index];
          if (a != 0 && b != 0 && (a - b).abs() < 5) return false;
        }
        return true;
      case RuleKind.killer:
        if (filled.length != filled.toSet().length) return false;
        final missing = digits.length - filled.length;
        final attained = filled.fold(0, (sum, digit) => sum + digit);
        final possible = [
          for (var digit = 1; digit <= size; digit++)
            if (!filled.contains(digit)) digit,
        ];
        if (possible.length < missing) return false;
        final low = possible.take(missing).fold(attained, (a, b) => a + b);
        final high = possible.reversed
            .take(missing)
            .fold(attained, (a, b) => a + b);
        return target! >= low && target! <= high;
      case RuleKind.arrow:
        final shaft = digits.skip(1);
        final sum = shaft.fold(0, (sum, digit) => sum + digit);
        final missing = shaft.where((digit) => digit == 0).length;
        final head = digits.first;
        if (head == 0) return sum + missing <= size;
        return sum + missing <= head && sum + missing * size >= head;
      case RuleKind.palindrome:
        for (var left = 0; left < digits.length ~/ 2; left++) {
          final a = digits[left];
          final b = digits[digits.length - left - 1];
          if (a != 0 && b != 0 && a != b) return false;
        }
        return true;
      case RuleKind.regionSum:
        var minimum = 0;
        var maximum = size * size;
        var currentRegion = -1;
        var sum = 0;
        var missing = 0;
        for (var index = 0; index <= cells.length; index++) {
          final region = index == cells.length ? -1 : regions[cells[index]];
          if (region != currentRegion) {
            if (currentRegion != -1) {
              if (sum + missing > minimum) minimum = sum + missing;
              if (sum + missing * size < maximum)
                maximum = sum + missing * size;
            }
            currentRegion = region;
            sum = 0;
            missing = 0;
          }
          if (index == cells.length) break;
          if (digits[index] == 0) missing++;
          sum += digits[index];
        }
        return minimum <= maximum;
      case RuleKind.sandwich:
        for (var first = 0; first < size; first++) {
          if (digits[first] != 0 && digits[first] != 1) continue;
          for (var last = 0; last < size; last++) {
            if (last == first || (digits[last] != 0 && digits[last] != size))
              continue;
            if (digits.contains(1) && digits[first] != 1) continue;
            if (digits.contains(size) && digits[last] != size) continue;
            var low = 0;
            var high = 0;
            final start = first < last ? first : last;
            final end = first < last ? last : first;
            for (var index = start + 1; index < end; index++) {
              final digit = digits[index];
              low += digit == 0 ? 2 : digit;
              high += digit == 0 ? size - 1 : digit;
            }
            if (target! >= low && target! <= high) return true;
          }
        }
        return false;
      case RuleKind.xSums:
        final first = digits.first;
        for (var length = 1; length <= size; length++) {
          if (first != 0 && length != first) continue;
          var minimum = length;
          var maximum = length;
          for (final value in digits.skip(1).take(length - 1)) {
            minimum += value == 0 ? 1 : value;
            maximum += value == 0 ? size : value;
          }
          if (target! >= minimum && target! <= maximum) return true;
        }
        return false;
      case RuleKind.diagonal:
      case RuleKind.antiKnight:
        return filled.length == filled.toSet().length;
    }
  }
}

class FogReveal {
  const FogReveal(this.id, this.requires, this.patch);
  final String id;
  final List<int> requires;
  final List<int> patch;

  Map<String, dynamic> toJson() => {
    'id': id,
    'requires': requires,
    'patch': patch,
  };

  factory FogReveal.fromJson(Map<String, dynamic> json) => FogReveal(
    json['id'] as String,
    (json['requires'] as List).cast<int>(),
    (json['patch'] as List).cast<int>(),
  );
}

class BoardSpec {
  BoardSpec({
    required this.id,
    required this.title,
    required this.size,
    required List<int> regions,
    required List<int> givens,
    required List<int> solution,
    this.description = '',
    List<VariantRule> rules = const [],
    this.fog = FogKind.none,
    List<int> starterPatch = const [],
    List<FogReveal> reveals = const [],
    this.gravity = false,
    Map<int, int> eaten = const {},
    this.route,
    this.finale = false,
    this.expedition = false,
  }) : regions = List.unmodifiable(regions),
       givens = List.unmodifiable(givens),
       solution = List.unmodifiable(solution),
       rules = List.unmodifiable(rules),
       starterPatch = List.unmodifiable(starterPatch),
       reveals = List.unmodifiable(reveals),
       eaten = Map.unmodifiable(eaten) {
    if (size < 4 ||
        size > 9 ||
        givens.length != size * size ||
        solution.length != size * size ||
        regions.length != size * size ||
        regions.any((region) => region < 0 || region >= size) ||
        [...givens, ...solution].any((digit) => digit < 0 || digit > size)) {
      throw ArgumentError('Invalid dimensions or values for $id');
    }
    bool onBoard(int index) => index >= 0 && index < size * size;
    if (starterPatch.any((index) => !onBoard(index)) ||
        reveals.any(
          (reveal) => [
            ...reveal.requires,
            ...reveal.patch,
          ].any((index) => !onBoard(index)),
        ) ||
        rules.any(
          (rule) =>
              !rule.cells.every(onBoard) ||
              rule.cells.toSet().length != rule.cells.length ||
              !_validRuleLength(rule, size),
        )) {
      throw ArgumentError('Invalid rule or reveal geometry for $id');
    }
  }

  static bool _validRuleLength(VariantRule rule, int size) {
    switch (rule.kind) {
      case RuleKind.kropkiWhite:
      case RuleKind.kropkiBlack:
      case RuleKind.antiKnight:
        return rule.cells.length == 2;
      case RuleKind.diagonal:
        return rule.cells.length == size;
      case RuleKind.sandwich:
      case RuleKind.xSums:
        return rule.cells.length == size && rule.target != null;
      case RuleKind.killer:
        return rule.cells.isNotEmpty && rule.target != null;
      case RuleKind.thermometer:
      case RuleKind.renban:
        return rule.cells.length >= 2 && rule.cells.length <= size;
      default:
        return rule.cells.length >= 2;
    }
  }

  final String id;
  final String title;
  final int size;
  final List<int> regions;
  final List<int> givens;
  final List<int> solution;
  final String description;
  final List<VariantRule> rules;
  final FogKind fog;
  final List<int> starterPatch;
  final List<FogReveal> reveals;
  final bool gravity;
  final Map<int, int> eaten;
  final String? route;
  final bool finale;
  final bool expedition;

  late final List<List<int>> peers = [
    for (var index = 0; index < size * size; index++)
      [
        for (var other = 0; other < size * size; other++)
          if (index != other &&
              (index ~/ size == other ~/ size ||
                  index % size == other % size ||
                  regions[index] == regions[other]))
            other,
      ],
  ];

  late final List<int> indices = List.unmodifiable(
    List.generate(size * size, (index) => index),
  );

  List<int> adjacent(int index) => [
    if (index >= size) index - size,
    if (index % size != size - 1) index + 1,
    if (index + size < size * size) index + size,
    if (index % size != 0) index - 1,
  ];

  List<VariantRule> visibleRules(Set<int> visible) => [
    for (final rule in rules)
      if (rule.cells.every(visible.contains)) rule,
  ];

  List<int> conflicts(List<int> entries, {Set<int>? visible}) {
    final conflicts = <int>{};
    final values = visible == null
        ? entries
        : [
            for (final index in indices)
              visible.contains(index) ? entries[index] : 0,
          ];
    for (final index in indices) {
      final value = values[index];
      if (value == 0) continue;
      if (value < 0 ||
          value > size ||
          peers[index].any((peer) => values[peer] == value)) {
        conflicts.add(index);
      }
    }
    for (final rule in visible == null ? rules : visibleRules(visible)) {
      if (!rule.allows(values, size, regions)) {
        conflicts.addAll(rule.cells.where((index) => values[index] != 0));
      }
    }
    return conflicts.toList()..sort();
  }

  bool accepts(List<int> entries) =>
      entries.length == size * size &&
      !entries.contains(0) &&
      conflicts(entries).isEmpty &&
      indices.every(
        (index) => givens[index] == 0 || entries[index] == givens[index],
      );

  List<int> candidates(
    List<int> entries,
    int index, {
    List<VariantRule>? constraints,
  }) {
    final relevant = (constraints ?? rules)
        .where((rule) => rule.cells.contains(index))
        .toList();
    return _candidates(List.of(entries), index, relevant);
  }

  List<int> _candidates(
    List<int> entries,
    int index,
    List<VariantRule> relevant,
  ) {
    var used = 0;
    for (final peer in peers[index]) {
      used |= 1 << entries[peer];
    }
    final original = entries[index];
    final result = <int>[];
    for (var digit = 1; digit <= size; digit++) {
      if (used & (1 << digit) != 0) continue;
      entries[index] = digit;
      if (relevant.every((rule) => rule.allows(entries, size, regions)))
        result.add(digit);
    }
    entries[index] = original;
    return result;
  }

  int countSolutions({
    int limit = 2,
    List<int>? entries,
    List<VariantRule>? constraints,
  }) => _solve(limit, entries, constraints).length;

  List<int>? solve({List<int>? entries, List<VariantRule>? constraints}) =>
      _solve(1, entries, constraints).firstOrNull;

  List<List<int>> _solve(
    int limit,
    List<int>? entries,
    List<VariantRule>? constraints,
  ) {
    if (limit < 1) return [];
    final grid = List<int>.of(entries ?? givens);
    final active = constraints ?? rules;
    if (grid.length != size * size ||
        grid.any((digit) => digit < 0 || digit > size))
      return [];
    for (final index in indices) {
      if (grid[index] != 0 &&
          peers[index].any((peer) => grid[index] == grid[peer]))
        return [];
    }
    if (active.any((rule) => !rule.allows(grid, size, regions))) return [];
    final byCell = [
      for (final index in indices)
        active.where((rule) => rule.cells.contains(index)).toList(),
    ];
    final solutions = <List<int>>[];
    void visit() {
      var target = -1;
      var candidates = <int>[];
      for (final index in indices) {
        if (grid[index] != 0) continue;
        final choices = _candidates(grid, index, byCell[index]);
        if (choices.isEmpty) return;
        if (target < 0 || choices.length < candidates.length) {
          target = index;
          candidates = choices;
        }
        if (choices.length == 1) break;
      }
      if (target < 0) {
        solutions.add(List.of(grid));
        return;
      }
      for (final digit in candidates) {
        grid[target] = digit;
        visit();
        if (solutions.length >= limit) break;
      }
      grid[target] = 0;
    }

    visit();
    return solutions;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'title': title,
    'size': size,
    'regions': regions,
    'givens': givens,
    'solution': solution,
    'description': description,
    'rules': rules.map((rule) => rule.toJson()).toList(),
    'fog': fog.name,
    'starterPatch': starterPatch,
    'reveals': reveals.map((reveal) => reveal.toJson()).toList(),
    'gravity': gravity,
    'eaten': {for (final item in eaten.entries) '${item.key}': item.value},
    'route': route,
    'finale': finale,
    'expedition': expedition,
  };

  factory BoardSpec.fromJson(Map<String, dynamic> json) {
    if ((json['version'] ?? 1) != 1)
      throw const FormatException('Unsupported board schema');
    return BoardSpec(
      id: json['id'] as String,
      title: json['title'] as String,
      size: json['size'] as int,
      regions: (json['regions'] as List).cast<int>(),
      givens: (json['givens'] as List).cast<int>(),
      solution: (json['solution'] as List).cast<int>(),
      description: json['description'] as String? ?? '',
      rules: [
        for (final rule in json['rules'] as List? ?? [])
          VariantRule.fromJson(rule as Map<String, dynamic>),
      ],
      fog: FogKind.values.byName(json['fog'] as String? ?? 'none'),
      starterPatch: (json['starterPatch'] as List? ?? []).cast<int>(),
      reveals: [
        for (final reveal in json['reveals'] as List? ?? [])
          FogReveal.fromJson(reveal as Map<String, dynamic>),
      ],
      gravity: json['gravity'] as bool? ?? false,
      eaten: {
        for (final item
            in (json['eaten'] as Map<String, dynamic>? ?? {}).entries)
          int.parse(item.key): item.value as int,
      },
      route: json['route'] as String?,
      finale: json['finale'] as bool? ?? false,
      expedition: json['expedition'] as bool? ?? false,
    );
  }
}

const openingTiles = [1, 0, 3, 0, 0, 2, 1, 2, 2, 3, 1, 3, 0, 3, 2, 1];
const openingAnchors = {0, 6, 13};

List<int> parseGrid(String rows) => [
  for (final char in rows.replaceAll(RegExp(r'\s'), '').split(''))
    int.parse(char),
];

List<int> boxRegions(int size, int height, int width) => [
  for (var row = 0; row < size; row++)
    for (var column = 0; column < size; column++)
      (row ~/ height) * (size ~/ width) + column ~/ width,
];

List<int> irregularRegions(String rows) => [
  for (final char in rows.replaceAll(RegExp(r'\s'), '').codeUnits) char - 65,
];

Map<String, BoardSpec> get boardsById => _boardsById;
final _boardsById = Map<String, BoardSpec>.unmodifiable({
  for (final board in campaignBoards) board.id: board,
});

final List<BoardSpec> campaignBoards = List.unmodifiable(authoredBoards());
