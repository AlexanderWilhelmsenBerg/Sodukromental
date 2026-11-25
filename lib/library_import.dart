import 'dart:convert';

import 'boards.dart';
import 'library_models.dart';
import 'library_source.dart';

class LibraryImport {
  static Future<LibraryDownload?> read(
    LibraryEntry entry,
    LibraryFetch fetch,
  ) async {
    final content = Uri.tryParse(entry.content ?? '');
    if (content == null || !isLibraryPayloadLink(content)) return null;
    final id =
        content.queryParameters['puzzleid'] ??
        content.queryParameters['load'] ??
        content.pathSegments.join('/');
    if (id.isEmpty) return null;
    var encoded = id;
    if (content.host.endsWith('f-puzzles.com')) {
      encoded = 'fpuz$id';
    } else if (!RegExp(r'^(scl|ctc|fpuz|classic)').hasMatch(id)) {
      if (!RegExp(r'^[\w-]+(/[\w-]+)*$').hasMatch(id)) return null;
      final url = Uri.https('sudokupad.app', '/api/puzzle/$id');
      final response = await fetch(url);
      if (response.status == 404 || response.status == 410) return null;
      encoded = requireLibraryResponse(response).text.trim();
    }
    return decode(entry, encoded);
  }

  static LibraryDownload? decode(LibraryEntry entry, String encoded) {
    try {
      final format = RegExp(
        r'^(fpuzzles|fpuz|scl|ctc|classic)',
      ).firstMatch(encoded);
      if (format?.group(0) == 'classic')
        return _classic(entry, encoded.substring(7));
      final body = format == null ? encoded : encoded.substring(format.end);
      final unpacked = body.startsWith('{') ? body : _decompress(body);
      final json = _decodeJson(unpacked);
      if (json.containsKey('grid') ||
          ['fpuz', 'fpuzzles'].contains(format?.group(0))) {
        return _fpuz(entry, json);
      }
      return _scl(entry, json);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    } on TypeError {
      return null;
    }
  }

  static LibraryDownload? _classic(LibraryEntry entry, String grid) {
    if (!RegExp(r'^[0-9.]{81}$').hasMatch(grid)) return null;
    return _build(
      entry,
      9,
      [for (final value in grid.split('')) int.tryParse(value) ?? 0],
      _boxRegions(9),
      [],
      [],
      knownRules: _classicRules(entry.rules, entry),
    );
  }

  static LibraryDownload? _scl(LibraryEntry entry, Map<String, dynamic> json) {
    const supported = {
      'id',
      'metadata',
      'cells',
      'regions',
      'cellSize',
      'cages',
      'lines',
      'arrows',
      'underlays',
      'overlays',
    };
    if (json.keys.any((key) => !supported.contains(key) && _hasData(json[key])))
      return null;
    final raw = json['cells'] as List;
    final size = raw.length;
    if (size < 4 ||
        size > 9 ||
        raw.any((row) => row is! List || row.length != size))
      return null;
    final metadata = (json['metadata'] as Map? ?? {}).cast<String, dynamic>();
    if (metadata.keys.any(
      (key) =>
          RegExp(
            'fog|trigger|background',
            caseSensitive: false,
          ).hasMatch(key) &&
          _hasData(metadata[key]),
    ))
      return null;
    final rules = metadata['rules']?.toString() ?? entry.rules;
    final declaredStandard = RegExp(
      r'normal sudoku|standard sudoku|sudoku rules apply|sudoku-regeln|classic sudoku',
      caseSensitive: false,
    ).hasMatch(rules);
    if (RegExp(
      r'(?:rows? may repeat|empty cell \(which|no normal sudoku|normal sudoku rules do not apply|digits may be repeated within a row)',
      caseSensitive: false,
    ).hasMatch(rules))
      return null;
    final givens = <int>[];
    for (final row in raw.cast<List>()) {
      for (final cell in row) {
        if (cell is! Map ||
            cell.keys.any((key) => !['value', 'given'].contains(key)))
          return null;
        givens.add(
          cell['given'] == false
              ? 0
              : int.tryParse('${cell['value'] ?? ''}') ?? 0,
        );
      }
    }
    final rawRegions = json['regions'] as List? ?? [];
    if (rawRegions.length != size) return null;
    final regions = List<int>.filled(size * size, -1);
    for (final (region, members) in rawRegions.indexed) {
      if (members is! List || members.length != size) return null;
      for (final position in members) {
        final cell = _sclCell(position, size);
        if (regions[cell] != -1) return null;
        regions[cell] = region;
      }
    }
    final refs = <Map<String, dynamic>>[];
    final constraints = <VariantRule>[];
    final unit = (json['cellSize'] as num?)?.toDouble() ?? 64;
    if (!unit.isFinite || unit <= 0) return null;
    for (final layer in ['underlays', 'cages', 'lines', 'arrows', 'overlays']) {
      for (final raw in (json[layer] as List? ?? [])) {
        final item = (raw as Map).cast<String, dynamic>();
        if (layer == 'cages' && !item.containsKey('cells'))
          continue; // Text-only metadata.
        final ref = {...item, 'layer': layer, 'unit': unit};
        if (!_supportedRef(ref, size)) return null;
        refs.add(ref);
        if (layer == 'cages' && item['unique'] == true) {
          final cells = (item['cells'] as List)
              .map((cell) => _sclCell(cell, size))
              .toList();
          final target = int.tryParse('${item['value'] ?? ''}');
          if (target != null)
            constraints.add(
              VariantRule(RuleKind.killer, cells, target: target),
            );
          if (item['hidden'] == true &&
              cells.length == size &&
              cells.every((i) => i ~/ size == i % size)) {
            constraints.add(VariantRule(RuleKind.diagonal, cells));
          }
        }
      }
    }
    if (!declaredStandard && (refs.isNotEmpty || rules.isNotEmpty)) return null;
    final knownRules = refs.isEmpty && _classicRules(rules, entry);
    return _build(
      entry,
      size,
      givens,
      regions,
      constraints,
      refs,
      knownRules: knownRules,
      solution: metadata['solution'],
      authorRules: rules,
    );
  }

  static LibraryDownload? _fpuz(LibraryEntry entry, Map<String, dynamic> json) {
    final raw = json['grid'] as List;
    final size = raw.length;
    if (size < 4 ||
        size > 9 ||
        raw.any((row) => row is! List || row.length != size))
      return null;
    final knownKeys = {
      'size',
      'title',
      'author',
      'ruleset',
      'grid',
      'solution',
      'antiknight',
      'diagonal+',
      'diagonal-',
      'thermometer',
      'palindrome',
      'killercage',
      'difference',
      'ratio',
      'disabledlogic',
      'truecandidatesoptions',
    };
    if (json.keys.any((key) => !knownKeys.contains(key) && _hasData(json[key])))
      return null;
    final givens = <int>[];
    final regions = _boxRegions(size);
    for (final row in raw.cast<List>()) {
      for (final cell in row.cast<Map>()) {
        final position = givens.length;
        if (cell.keys.any(
          (key) => ![
            'value',
            'given',
            'region',
            'candidates',
            'centerPencilMarks',
            'cornerPencilMarks',
          ].contains(key),
        ))
          return null;
        givens.add(cell['given'] == true ? int.parse('${cell['value']}') : 0);
        if (cell['region'] case final int region when region >= 0)
          regions[position] = region;
      }
    }
    final constraints = <VariantRule>[];
    if (json['antiknight'] == true)
      constraints.add(
        VariantRule(RuleKind.antiKnight, List.generate(size * size, (i) => i)),
      );
    if (json['diagonal+'] == true)
      constraints.add(
        VariantRule(
          RuleKind.diagonal,
          List.generate(size, (i) => (i + 1) * (size - 1)),
        ),
      );
    if (json['diagonal-'] == true)
      constraints.add(
        VariantRule(
          RuleKind.diagonal,
          List.generate(size, (i) => i * (size + 1)),
        ),
      );
    for (final (key, kind) in [
      ('thermometer', RuleKind.thermometer),
      ('palindrome', RuleKind.palindrome),
    ]) {
      for (final obj in (json[key] as List? ?? []).cast<Map>()) {
        for (final line in (obj['lines'] as List).cast<List>()) {
          constraints.add(
            VariantRule(
              kind,
              line.map((cell) => _fpuzCell(cell, size)).toList(),
            ),
          );
        }
      }
    }
    for (final (key, kind, defaultValue) in [
      ('killercage', RuleKind.killer, 0),
      ('difference', RuleKind.kropkiWhite, 1),
      ('ratio', RuleKind.kropkiBlack, 2),
    ]) {
      for (final obj in (json[key] as List? ?? []).cast<Map>()) {
        final cells = (obj['cells'] as List)
            .map((cell) => _fpuzCell(cell, size))
            .toList();
        final value = int.tryParse('${obj['value'] ?? ''}') ?? defaultValue;
        if (value <= 0 ||
            (key != 'killercage' &&
                (value != defaultValue || cells.length != 2)))
          return null;
        constraints.add(VariantRule(kind, cells, target: value));
      }
    }
    final rules = json['ruleset'] as String? ?? entry.rules;
    final normalized = constraints
        .map((rule) => libraryRuleFor(rule.kind))
        .toSet();
    final knownRules =
        _classicRules(rules, entry) ||
        (rules.isNotEmpty &&
            rules.length < 180 &&
            !RegExp(
              r'\b(no|all|negative|unmarked|other)\b',
              caseSensitive: false,
            ).hasMatch(rules) &&
            normalized.containsAll(matchLibraryRules(rules, entry.tags)) &&
            normalized.containsAll(entry.ruleIds));
    return _build(
      entry,
      size,
      givens,
      regions,
      constraints,
      [],
      knownRules: knownRules,
      solution: json['solution'],
      authorRules: rules,
    );
  }

  static LibraryDownload? _build(
    LibraryEntry entry,
    int size,
    List<int> givens,
    List<int> regions,
    List<VariantRule> constraints,
    List<Map<String, dynamic>> refs, {
    required bool knownRules,
    Object? solution,
    String authorRules = '',
  }) {
    if (regions.any((region) => region < 0 || region >= size) ||
        List.generate(
          size,
          (region) => regions.where((r) => r == region).length,
        ).any((count) => count != size))
      return null;
    final complete = switch (solution) {
      String value =>
        value.split('').map((digit) => int.tryParse(digit) ?? 0).toList(),
      List value => value.map((digit) => int.tryParse('$digit') ?? 0).toList(),
      _ => const <int>[],
    };
    BoardSpec boardWith(List<int> digits) => BoardSpec(
      id: entry.id,
      title: entry.title,
      size: size,
      description: entry.rules,
      givens: givens,
      regions: regions,
      rules: constraints,
      solution: digits,
    );
    var board = boardWith(List.filled(size * size, 0));
    if (board.conflicts(givens).isNotEmpty) return null;
    final hasSolution = board.accepts(complete);
    if (hasSolution) {
      board = boardWith(complete);
    } else if (knownRules) {
      final solved = board.solve();
      if (solved != null) board = boardWith(solved);
    }
    final rules = entry.rules.isEmpty ? authorRules : entry.rules;
    final ruleIds = {
      ...entry.ruleIds,
      ...matchLibraryRules(rules, entry.tags),
      ...constraints.map((constraint) => libraryRuleFor(constraint.kind)),
    };
    if (!_sameList(regions, _boxRegions(size))) ruleIds.add('jigsaw');
    final record = entry.withData({
      'size': size,
      'rules': rules,
      'ruleIds': ruleIds.toList(),
      'completeRules': knownRules,
    });
    return LibraryDownload(
      record,
      board: board,
      refs: refs,
      manual: !knownRules && !hasSolution,
      finalCheck: !knownRules && hasSolution,
    );
  }
}

bool _sameList(List<int> a, List<int> b) =>
    a.length == b.length && a.indexed.every((pair) => b[pair.$1] == pair.$2);

bool _classicRules(String rules, LibraryEntry entry) {
  if (entry.ruleIds.isNotEmpty ||
      matchLibraryRules(rules, entry.tags).isNotEmpty)
    return false;
  final norm = rules.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  return norm.isEmpty ||
      RegExp(
        r'^(?:(?:normal|standard|classic)(?: [4-9]\s*[x×]\s*[4-9])? sudoku rules(?: apply)?[.!]?|(?:es gelten die )?normalen? sudoku-regeln[.!]?|(?:fill|place) (?:each|the) (?:row|digits)[0-9a-z \-×,–]+(?:each|once)[.!]?)$',
      ).hasMatch(norm);
}

bool _hasData(dynamic value) =>
    value != null &&
    value != false &&
    value != '' &&
    (value is! List || value.isNotEmpty) &&
    (value is! Map || value.isNotEmpty);

int _sclCell(dynamic position, int size) {
  final row = position[0] as int;
  final col = position[1] as int;
  if (row < 0 || row >= size || col < 0 || col >= size)
    throw const FormatException('Invalid cell coordinates.');
  return row * size + col;
}

int _fpuzCell(dynamic coordinate, int size) {
  final match = RegExp(
    r'^R([1-9])C([1-9])$',
    caseSensitive: false,
  ).firstMatch(coordinate.toString());
  if (match == null) throw const FormatException('Invalid f-puzzles cell.');
  return _sclCell([
    int.parse(match.group(1)!) - 1,
    int.parse(match.group(2)!) - 1,
  ], size);
}

List<int> _boxRegions(int size) {
  final (height, width) = switch (size) {
    4 => (2, 2),
    6 => (2, 3),
    8 => (2, 4),
    9 => (3, 3),
    _ => (1, size),
  };
  return List.generate(
    size * size,
    (i) => (i ~/ size ~/ height) * (size ~/ width) + (i % size ~/ width),
  );
}

bool _supportedRef(Map<String, dynamic> item, int size) {
  bool point(dynamic p) =>
      p is List &&
      p.length == 2 &&
      p.every((v) => v is num && v.isFinite && v >= 0 && v <= size);
  final basics = {
    'layer',
    'unit',
    'color',
    'borderColor',
    'backgroundColor',
    'rounded',
    'thickness',
    'stroke',
    'stroke-width',
    'stroke-linejoin',
    'stroke-linecap',
    'stroke-dasharray',
    'fontSize',
    'textColor',
    'text',
    'angle',
    'fill',
    'class',
  };
  switch (item['layer']) {
    case 'underlays':
    case 'overlays':
      return item.keys.every(
            {...basics, 'center', 'width', 'height'}.contains,
          ) &&
          point(item['center']) &&
          ['width', 'height'].every(
            (key) =>
                item[key] == null ||
                (item[key] is num && (item[key] as num).toDouble().isFinite),
          );
    case 'cages':
      return item.keys.every(
            {
              ...basics,
              'value',
              'cells',
              'unique',
              'hidden',
              'outline',
              'label',
            }.contains,
          ) &&
          item['cells'] is List &&
          (item['cells'] as List).isNotEmpty &&
          (item['cells'] as List).every(point);
    case 'lines':
    case 'arrows':
      final points = item['wayPoints'];
      return item.keys.every({...basics, 'wayPoints', 'headLength'}.contains) &&
          points is List &&
          points.length >= 2 &&
          points.every(point);
    default:
      return false;
  }
}

String _decompress(String source) {
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
  final input = source
      .replaceAll(' ', '+')
      .replaceAll('-', '+')
      .replaceAll('_', '/');
  var offset = 0;
  int read(int length) {
    var result = 0;
    for (var bit = 0; bit < length; bit++, offset++) {
      if (offset ~/ 6 >= input.length)
        throw const FormatException('Incomplete LZ puzzle.');
      final char = alphabet.indexOf(input[offset ~/ 6]);
      if (char < 0) throw const FormatException('Invalid LZ alphabet.');
      if ((char & (32 >> (offset % 6))) != 0) result |= 1 << bit;
    }
    return result;
  }

  final tag = read(2);
  if (tag >= 2) throw const FormatException('Empty LZ puzzle.');
  var previous = String.fromCharCode(read(tag == 0 ? 8 : 16));
  final dictionary = ['', '', '', previous];
  final output = StringBuffer(previous);
  var bits = 3;
  var remaining = 4;
  void expand() {
    remaining--;
    if (remaining == 0) {
      remaining = 1 << bits;
      bits++;
    }
  }

  while (output.length < 2 * 1024 * 1024) {
    var code = read(bits);
    if (code == 2) return output.toString();
    if (code < 2) {
      dictionary.add(String.fromCharCode(read(code == 0 ? 8 : 16)));
      code = dictionary.length - 1;
      expand();
    }
    final entry = code < dictionary.length
        ? dictionary[code]
        : code == dictionary.length
        ? previous + previous[0]
        : '';
    if (entry.isEmpty)
      throw const FormatException('Invalid LZ dictionary entry.');
    output.write(entry);
    dictionary.add(previous + entry[0]);
    previous = entry;
    expand();
  }
  throw const FormatException('Expanded puzzle exceeds the size limit.');
}

const _shortKeys = {
  'c': 'color',
  'ca': 'cages',
  'ct': 'center',
  'c1': 'borderColor',
  'c2': 'backgroundColor',
  'ce': 'cells',
  'cs': 'cellSize',
  'a': 'arrows',
  'o': 'overlays',
  'u': 'underlays',
  'w': 'width',
  'h': 'height',
  'v': 'value',
  'vd': 'videos',
  'l': 'lines',
  'r': 'rounded',
  're': 'regions',
  'fs': 'fontSize',
  'th': 'thickness',
  'hl': 'headLength',
  'wp': 'wayPoints',
  't': 'title',
  'te': 'text',
  'd': 'duration',
  'd2': 'd',
};

Map<String, dynamic> _decodeJson(String input) {
  try {
    return (jsonDecode(input) as Map).cast<String, dynamic>();
  } on FormatException {
    final normalized = input.contains('"')
        ? input
        : input
              .replaceAll(r"\'", '\u0001')
              .replaceAll("'", '"')
              .replaceAll('\u0001', "'");
    final quoted = RegExp(r'"(?:[^"\\]|\\.)*"');
    final strings = <String>[];
    final emptyCells = normalized
        .replaceAllMapped(quoted, (match) {
          strings.add(match.group(0)!);
          return '"__s${strings.length - 1}__"';
        })
        .replaceAllMapped(
          RegExp(r'([,{\[])([a-zA-Z0-9]+):'),
          (m) => '${m[1]}"${m[2]}":',
        )
        .replaceAllMapped(RegExp(r'([,{\[])(?=[,}\]])'), (m) => '${m[1]}_')
        .replaceAll('{_}', '{}')
        .replaceAllMapped(RegExp(r'([,{\[])_'), (m) => '${m[1]}{}')
        .replaceAllMapped(
          RegExp(r':(t|f|#0|#F|[a-fA-F0-9]{6})(?=[,}\]])'),
          (m) => switch (m[1]) {
            't' => ':true',
            'f' => ':false',
            '#0' => ':"#000000"',
            '#F' => ':"#FFFFFF"',
            _ => ':"#${m[1]}"',
          },
        )
        .replaceAllMapped(
          RegExp(r'"__s(\d+)__"'),
          (m) => strings[int.parse(m[1]!)],
        );
    dynamic expand(dynamic item) {
      if (item is List) return item.map(expand).toList();
      if (item is Map)
        return {
          for (final MapEntry(:key, :value) in item.entries)
            _shortKeys[key] ?? key as String: expand(value),
        };
      return item;
    }

    return expand(jsonDecode(emptyCells)) as Map<String, dynamic>;
  }
}
