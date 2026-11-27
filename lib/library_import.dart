import 'dart:convert';
import 'dart:math' as math;

import 'boards.dart';
import 'library_digest.dart';
import 'library_models.dart';
import 'library_source.dart';

class LibraryImport {
  static const resolverVersion = 4;

  static Future<LibraryDownload?> read(
    LibraryEntry entry,
    LibraryFetch fetch, {
    LibraryTrace? trace,
  }) async {
    final resolution = await resolve(entry, fetch, trace: trace);
    if (resolution == null) return null;
    final decoded = decode(entry, resolution.payload);
    if (decoded == null) {
      trace?.call(
        'Decode',
        'Retained the puzzle package. Its format is unsupported by the offline player.',
        resolution.resolved,
      );
      return LibraryDownload(
        entry,
        supportReasons: const [
          'The verified puzzle package uses a format or capability that is not yet supported.',
        ],
        provenance: _provenance(resolution),
      );
    }
    final native = decoded.nativeDefinition;
    trace?.call(
      'Decode',
      decoded.availability == LibraryAvailability.play && native != null
          ? 'Decoded a ${native.width} × ${native.height} native puzzle.'
          : decoded.supportReasons.join(' '),
      resolution.resolved,
    );
    final cached = await _cacheAssets(decoded.refs, fetch);
    final definition = decoded.definition == null
        ? null
        : _definitionWithAssets(decoded.definition!, cached.$1, cached.$2);
    return LibraryDownload(
      decoded.entry,
      board: decoded.board,
      refs: cached.$1,
      diagram: decoded.diagram,
      manual: decoded.manual,
      finalCheck: decoded.finalCheck,
      definition: definition,
      supportReasons: decoded.supportReasons,
      assetManifest: [...decoded.assetManifest, ...cached.$2],
      provenance: _provenance(resolution),
    );
  }

  /// Resolves a supported share URL into puzzle bytes without ever treating a
  /// player HTML shell as a package. The original URL remains available to the
  /// caller as a stable retry/provenance key.
  static Future<LibraryResolution?> resolve(
    LibraryEntry entry,
    LibraryFetch fetch, {
    int maxRedirects = 5,
    LibraryTrace? trace,
  }) async {
    final links = {
      if (entry.content case final String link) link,
      ...entry.alternativeContent,
    };
    LibraryResolution? reference;
    LibraryRequestFailure? temporaryFailure;
    for (final link in links.take(8)) {
      final original = Uri.tryParse(link);
      if (original == null || !isLibraryPayloadLink(original)) {
        trace?.call(
          'Resolve',
          'Skipped a destination outside supported puzzle sources.',
          original,
        );
        continue;
      }
      trace?.call(
        'Resolve',
        'Trying an authored puzzle destination.',
        original,
      );
      try {
        final found = await _resolveLink(
          entry,
          fetch,
          original,
          maxRedirects,
          trace,
        );
        if (found == null) continue;
        if (links.length == 1 ||
            decode(entry, found.payload)?.availability ==
                LibraryAvailability.play) {
          return found;
        }
        trace?.call(
          'Resolve',
          'Kept a reference package while checking the next authored edition for native play.',
          found.resolved,
        );
        reference ??= found;
      } on LibraryRequestFailure catch (error) {
        trace?.call('Resolve', error.message, original);
        if (error.retry) {
          // Respect a host's explicit rate limit before trying another URL.
          if (error.seconds > 0) rethrow;
          temporaryFailure ??= error;
        }
      } on FormatException {
        trace?.call(
          'Resolve',
          'The share address or payload is malformed.',
          original,
        );
      }
    }
    if (temporaryFailure != null && reference == null) throw temporaryFailure;
    if (reference == null) {
      trace?.call(
        'Resolve',
        'No authored player destination yielded an identifiable puzzle package.',
        entry.portal,
      );
    }
    return reference;
  }

  static Future<LibraryResolution?> _resolveLink(
    LibraryEntry entry,
    LibraryFetch fetch,
    Uri original,
    int maxRedirects,
    LibraryTrace? trace,
  ) async {
    var current = original;
    var inspectedLanding = false;
    final visited = <Uri>{};
    LibraryResolution? reject(String message) {
      trace?.call('Resolve', message, current);
      return null;
    }

    LibraryResolution? verify(String payload, Uri from, int hop) {
      final issue = _puzzlePayloadIssue(entry, payload);
      if (issue != null) {
        trace?.call('Verification', issue, from);
        return null;
      }
      trace?.call(
        'Verification',
        'Accepted a puzzle package from the authored share.',
        from,
      );
      return LibraryResolution(original, from, payload, hop);
    }

    for (var hop = 0; hop <= maxRedirects; hop++) {
      final fpuzzlesId = current.queryParameters['id'];
      if (current.host.endsWith('f-puzzles.com') && fpuzzlesId != null) {
        if (!RegExp(r'^[\w-]+$').hasMatch(fpuzzlesId))
          return reject('The f-puzzles share identifier is invalid.');
        current = Uri.https('tinyurl.com', '/$fpuzzlesId');
      }
      if (!_safeShareUri(current))
        return reject(
          'The source returned a destination outside supported puzzle routes.',
        );
      if (!visited.add(current)) return reject('The share links form a loop.');
      if (isLibrarySetterLanding(current) || _aliasUri(current)) {
        if (hop == maxRedirects)
          return reject('Reached the share redirect limit.');
        final response = await fetch(current);
        if (response.status >= 300 && response.status < 400) {
          final location = response.headers['location'];
          if (location == null || location.isEmpty)
            return reject('The redirect had no destination.');
          final next = current.resolve(location);
          if (!_safeShareUri(next))
            return reject(
              'The source redirected outside supported puzzle routes.',
            );
          trace?.call(
            'Redirect',
            'Following the authored share redirect.',
            next,
          );
          current = next;
          continue;
        }
        requireLibraryResponse(response);
        if (_aliasUri(current))
          return reject('The short link did not redirect to a player.');
        if (inspectedLanding)
          return reject('Reached the limit for intermediate puzzle pages.');
        inspectedLanding = true;
        final target = librarySetterPageTarget(
          response.text,
          current,
          entry,
          trace,
        );
        if (target == null) return null;
        current = target;
        continue;
      }
      final inline = _inlinePayload(current);
      if (inline != null) return verify(inline, current, hop);
      final lookup = _lookupKey(current);
      if (lookup == null)
        return reject(
          'The player URL contains no supported puzzle identifier.',
        );
      final api = Uri.https(
        'sudokupad.app',
        '/api/puzzle/${lookup.map(Uri.encodeComponent).join('/')}',
      );
      final response = requireLibraryResponse(await fetch(api));
      return verify(response.text.trim(), api, hop);
    }
    return reject('Reached the share redirect limit.');
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
      'foglight',
      'fogLights',
      'fog',
      'triggers',
      'foglink',
      'triggereffect',
      'settings',
      'symbols',
      'width',
      'height',
    };
    if (json.keys.any((key) => !supported.contains(key) && _hasData(json[key])))
      return null;
    final raw = json['cells'] as List;
    final size = raw.length;
    if (size < 1 ||
        size > 25 ||
        raw.any((row) => row is! List || row.length != size))
      return null;
    final metadata = (json['metadata'] as Map? ?? {}).cast<String, dynamic>();
    final rules = metadata['rules']?.toString() ?? entry.rules;
    final declaredStandard = RegExp(
      r'normal sudoku|standard sudoku|sudoku rules apply|sudoku-regeln|classic sudoku',
      caseSensitive: false,
    ).hasMatch(rules);
    final allowsRowRepeats = RegExp(
      r'(?:rows? may repeat|empty cell \(which|no normal sudoku|normal sudoku rules do not apply|digits may be repeated within a row)',
      caseSensitive: false,
    ).hasMatch(rules);
    final allowsColumnRepeats = RegExp(
      r'(?:columns? may repeat|digits may be repeated within a column)',
      caseSensitive: false,
    ).hasMatch(rules);
    final givens = <int>[];
    final symbolicGivens = <String?>[];
    for (final row in raw.cast<List>()) {
      for (final cell in row) {
        if (cell is! Map) return null;
        final given = cell['given'] == false || cell['value'] == null
            ? null
            : '${cell['value']}';
        symbolicGivens.add(given);
        givens.add(int.tryParse(given ?? '') ?? 0);
      }
    }
    final rawRegions = json['regions'] as List? ?? [];
    final symbolicRegions = List<int?>.filled(size * size, null);
    final regions = List<int>.filled(size * size, -1);
    for (final (region, members) in rawRegions.indexed) {
      if (members is! List) return null;
      for (final position in members) {
        final cell = _sclCell(position, size);
        if (regions[cell] != -1) return null;
        regions[cell] = region;
        symbolicRegions[cell] = region;
      }
    }
    final refs = <Map<String, dynamic>>[];
    final constraints = <VariantRule>[];
    final legacyFogMetadata = <Map<String, dynamic>>[];
    final unit = (json['cellSize'] as num?)?.toDouble() ?? 64;
    if (!unit.isFinite || unit <= 0) return null;
    for (final layer in ['underlays', 'cages', 'lines', 'arrows', 'overlays']) {
      for (final raw in (json[layer] as List? ?? [])) {
        final item = (raw as Map).cast<String, dynamic>();
        if (layer == 'cages' &&
            RegExp(
              r'^foglight(?:\s*:|$)',
              caseSensitive: false,
            ).hasMatch('${item['value'] ?? ''}')) {
          legacyFogMetadata.add(item);
          continue;
        }
        if (layer == 'cages' &&
            (!item.containsKey('cells') || (item['cells'] as List).isEmpty)) {
          if (RegExp(
            r'fog|trigger|foglight',
            caseSensitive: false,
          ).hasMatch('${item['value'] ?? item['text'] ?? ''}')) {
            legacyFogMetadata.add(item);
          }
          continue; // Text-only compact metadata.
        }
        final ref = {...item, 'layer': layer, 'unit': unit};
        refs.add({...ref, 'order': refs.length});
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
    final symbols = _sclSymbols(json, metadata, rules, size);
    var symbolicSolution = _symbolSolution(metadata['solution'], symbols, size);
    final fogData =
        json['foglight'] ??
        json['fogLights'] ??
        json['fog'] ??
        json['triggers'] ??
        metadata['foglight'] ??
        metadata['fogLights'] ??
        metadata['fog'] ??
        metadata['triggers'] ??
        (legacyFogMetadata.isEmpty ? null : legacyFogMetadata) ??
        (json['foglink'] != null || json['triggereffect'] != null
            ? const <dynamic>[]
            : null);
    final playable = rawRegions.isEmpty
        ? {for (var i = 0; i < size * size; i++) i}
        : {
            for (final (index, region) in symbolicRegions.indexed)
              if (region != null) index,
          };
    if (!_validSymbolSolution(
      symbolicSolution,
      playable,
      symbolicRegions,
      size,
      allowRowRepeats: allowsRowRepeats,
      allowColumnRepeats: allowsColumnRepeats,
      allowRegionRepeats: allowsRowRepeats || allowsColumnRepeats,
    )) {
      symbolicSolution = const [];
    }
    final fog = _readFog(
      fogData,
      size,
      symbolicSolution,
      playable,
      givens: symbolicGivens,
      foglink: json['foglink'],
      triggerEffects: json['triggereffect'],
    );
    final supportReasons = <String>[
      if (fogData != null && fog == null)
        'This edition uses fog reveal rules that are not yet reproducible.',
      if (refs.any((ref) => !_supportedRef(ref, size)))
        'This edition contains clue geometry that cannot be rendered safely.',
    ];
    final deliberateBlanks = <int>{
      if (RegExp(
        r'\b(?:intentional|deliberate) (?:empty|blank)|one empty cell',
        caseSensitive: false,
      ).hasMatch(rules))
        for (final (index, value) in symbolicSolution.indexed)
          if (value == null) index,
    };
    final definition = LibraryPuzzleDefinition(
      width: size,
      height: size,
      symbols: symbols,
      playable: playable,
      givens: symbolicGivens,
      regions: symbolicRegions,
      solution: symbolicSolution,
      deliberateBlanks: deliberateBlanks,
      initiallyVisible: fog?.$1,
      fogTriggers: fog?.$2 ?? const [],
      layers: refs,
      presentation: {
        ...?((metadata['settings'] as Map?)?.cast<String, dynamic>()),
        ...?((json['settings'] as Map?)?.cast<String, dynamic>()),
        'cellSize': json['cellSize'] ?? 64,
      }.cast<String, dynamic>(),
      allowRowRepeats: allowsRowRepeats,
      allowColumnRepeats: allowsColumnRepeats,
      allowRegionRepeats: allowsRowRepeats || allowsColumnRepeats,
    );
    final legacyCompatible =
        symbols.indexed.every((pair) => pair.$2 == '${pair.$1 + 1}') &&
        rawRegions.length == size &&
        regions.every((region) => region >= 0) &&
        !allowsRowRepeats &&
        !allowsColumnRepeats &&
        size <= 9 &&
        fogData == null;
    if (!legacyCompatible) {
      final record = entry.withData({
        'size': size,
        'rules': entry.rules.isEmpty ? rules : entry.rules,
        'ruleIds': {
          ...entry.ruleIds,
          ...matchLibraryRules(rules, entry.tags),
        }.toList(),
        'completeRules': supportReasons.isEmpty,
      });
      return LibraryDownload(
        record,
        definition: definition,
        refs: refs,
        manual: !declaredStandard,
        finalCheck: symbolicSolution.length == size * size,
        supportReasons: supportReasons,
      );
    }
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
      definition: definition,
      supportReasons: supportReasons,
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
      'arrow',
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
    final refs = <Map<String, dynamic>>[];
    final hasArrows = _hasData(json['arrow']);
    List<double> center(int cell) => [cell ~/ size + .5, cell % size + .5];
    final givens = <int>[];
    final regions = _boxRegions(size);
    for (final row in raw.cast<List>()) {
      for (final cell in row.cast<Map>()) {
        final position = givens.length;
        if (cell.keys.any(
          (key) => ![
            'value',
            'given',
            'c',
            'color',
            'region',
            'candidates',
            'centerPencilMarks',
            'cornerPencilMarks',
          ].contains(key),
        ))
          return null;
        final color = cell['c'] ?? cell['color'];
        if (color != null) {
          if (color is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color))
            return null;
          refs.add({
            'layer': 'underlays',
            'center': center(position),
            'backgroundColor': color,
          });
        }
        givens.add(cell['given'] == true ? int.parse('${cell['value']}') : 0);
        if (cell['region'] case final int region when region >= 0)
          regions[position] = region;
      }
    }
    final constraints = <VariantRule>[];
    if (hasArrows) {
      if ([
        'thermometer',
        'palindrome',
        'killercage',
        'difference',
        'ratio',
      ].any((key) => _hasData(json[key]))) {
        return LibraryDownload(
          entry,
          supportReasons: const [
            'This F-Puzzles edition combines arrows with another clue layer that needs drawing support.',
          ],
        );
      }
      for (final arrow in (json['arrow'] as List).cast<Map>()) {
        final bulbs = (arrow['cells'] as List)
            .map((cell) => _fpuzCell(cell, size))
            .toList();
        if (bulbs.length != 1) {
          return LibraryDownload(
            entry,
            supportReasons: const [
              'This F-Puzzles edition uses an arrow with a multi-cell bulb.',
            ],
          );
        }
        final bulb = bulbs.single;
        final lines = arrow['lines'] as List;
        if (lines.isEmpty) return null;
        for (final line in lines.cast<List>()) {
          final cells = line.map((cell) => _fpuzCell(cell, size)).toList();
          if (cells.length < 2 ||
              cells.first != bulb ||
              cells.toSet().length != cells.length)
            return null;
          constraints.add(VariantRule(RuleKind.arrow, cells));
          final points = cells.map(center).toList();
          final dr = points[1][0] - points[0][0];
          final dc = points[1][1] - points[0][1];
          final length = math.sqrt(dr * dr + dc * dc);
          // Start at the rim so the transparent bulb preserves the cell tint.
          points[0] = [
            points[0][0] + .35 * dr / length,
            points[0][1] + .35 * dc / length,
          ];
          refs.add({
            'layer': 'arrows',
            'wayPoints': points,
            'color': '#707070',
            'thickness': 3,
            'headLength': .23,
          });
        }
        refs.add({
          'layer': 'overlays',
          'center': center(bulb),
          'width': .7,
          'height': .7,
          'rounded': true,
          'borderColor': '#707070',
          'stroke-width': 3,
        });
      }
    }
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
    final knownRules = hasArrows
        ? _standardArrowRules(rules) && normalized.containsAll(entry.ruleIds)
        : _classicRules(rules, entry) ||
              (rules.isNotEmpty &&
                  rules.length < 180 &&
                  !RegExp(
                    r'\b(no|all|negative|unmarked|other)\b',
                    caseSensitive: false,
                  ).hasMatch(rules) &&
                  normalized.containsAll(
                    matchLibraryRules(rules, entry.tags),
                  ) &&
                  normalized.containsAll(entry.ruleIds));
    return _build(
      entry,
      size,
      givens,
      regions,
      constraints,
      refs,
      knownRules: knownRules,
      solution: json['solution'],
      authorRules: rules,
      inferSolution: !hasArrows,
    );
  }

  static bool _standardArrowRules(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final remaining = normalized
        .replaceAll(
          RegExp(r'(?:normal|standard|classic) sudoku rules apply[.!]?'),
          '',
        )
        .replaceAll(
          RegExp(
            r"digits along an arrow add up to the digit in that arrow's circle[.!]?",
          ),
          '',
        )
        .replaceAll(RegExp(r'digits may repeat on an arrow[.!]?'), '');
    return normalized.isNotEmpty && remaining.trim().isEmpty;
  }

  static LibraryDownload? _build(
    LibraryEntry entry,
    int size,
    List<int> givens,
    List<int> regions,
    List<VariantRule> constraints,
    List<Map<String, dynamic>> refs, {
    required bool knownRules,
    bool inferSolution = true,
    Object? solution,
    String authorRules = '',
    LibraryPuzzleDefinition? definition,
    List<String> supportReasons = const [],
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
    } else if (knownRules && inferSolution) {
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
      definition:
          definition ?? LibraryPuzzleDefinition.fromBoard(board, layers: refs),
      supportReasons: supportReasons,
    );
  }
}

Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)> _cacheAssets(
  List<Map<String, dynamic>> layers,
  LibraryFetch fetch,
) async {
  final manifest = <Map<String, dynamic>>[];
  final cache = <String, String>{};
  Future<dynamic> visit(dynamic value, [String? key]) async {
    if (value is List) return Future.wait(value.map((item) => visit(item)));
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        result['${entry.key}'] = await visit(entry.value, '${entry.key}');
      }
      return result;
    }
    if (value is! String ||
        !const {
          'image',
          'imageUrl',
          'src',
          'url',
          'backgroundImage',
        }.contains(key)) {
      return value;
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
      return value;
    }
    if (!const {
      'logic-masters.de',
      'www.logic-masters.de',
      'sudokupad.app',
      'www.sudokupad.app',
      'images.ctc-puzzles.com',
    }.contains(uri.host)) {
      throw const FormatException('Puzzle artwork uses an untrusted host.');
    }
    if (cache[value] case final installed?) return 'asset:$installed';
    final response = requireLibraryResponse(await fetch(uri));
    if (response.bytes.isEmpty) {
      throw const FormatException('Puzzle artwork is empty.');
    }
    final encoded = base64Encode(response.bytes);
    final fingerprint = librarySha256(encoded);
    cache[value] = fingerprint;
    manifest.add({
      'id': fingerprint,
      'source': value,
      'fingerprint': fingerprint,
      'mime': response.headers['content-type'] ?? 'application/octet-stream',
      'data': encoded,
    });
    return 'asset:$fingerprint';
  }

  final installed = <Map<String, dynamic>>[];
  for (final layer in layers) {
    installed.add((await visit(layer) as Map).cast<String, dynamic>());
  }
  return (installed, manifest);
}

LibraryPuzzleDefinition _definitionWithAssets(
  LibraryPuzzleDefinition source,
  List<Map<String, dynamic>> layers,
  List<Map<String, dynamic>> assets,
) => LibraryPuzzleDefinition(
  version: source.version,
  width: source.width,
  height: source.height,
  symbols: source.symbols,
  playable: source.playable,
  givens: source.givens,
  regions: source.regions,
  solution: source.solution,
  deliberateBlanks: source.deliberateBlanks,
  initiallyVisible: source.initiallyVisible,
  fogTriggers: source.fogTriggers,
  layers: layers,
  presentation: source.presentation,
  assets: assets,
  allowRowRepeats: source.allowRowRepeats,
  allowColumnRepeats: source.allowColumnRepeats,
  allowRegionRepeats: source.allowRegionRepeats,
);

class LibraryResolution {
  const LibraryResolution(
    this.original,
    this.resolved,
    this.payload,
    this.redirects,
  );
  final Uri original;
  final Uri resolved;
  final String payload;
  final int redirects;
}

bool _looksLikeHtml(String value) => RegExp(
  r'^\s*(?:<!doctype\s+html|<html|<head|<body)\b',
  caseSensitive: false,
).hasMatch(value);

bool _aliasUri(Uri uri) => const {
  'tinyurl.com',
  'www.tinyurl.com',
  'shorturl.at',
  'www.shorturl.at',
}.contains(uri.host);

bool _safeShareUri(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.fragment.isNotEmpty) {
    return false;
  }
  if (isLibrarySetterLanding(uri)) return true;
  return switch (uri.host) {
    'tinyurl.com' ||
    'www.tinyurl.com' ||
    'shorturl.at' ||
    'www.shorturl.at' => isLibraryPayloadLink(uri),
    'sudokupad.app' ||
    'www.sudokupad.app' ||
    'app.crackingthecryptic.com' ||
    'app.crackingthecryptic.tv' ||
    'sudokupad.svencodes.com' ||
    'f-puzzles.com' ||
    'www.f-puzzles.com' => true,
    _ => false,
  };
}

String? _rawQueryValue(Uri uri, String name) {
  for (final field in uri.query.split('&')) {
    final split = field.indexOf('=');
    final key = split < 0 ? field : field.substring(0, split);
    if (Uri.decodeQueryComponent(key) != name) continue;
    final raw = split < 0 ? '' : field.substring(split + 1);
    // decodeComponent intentionally preserves literal '+'.
    return Uri.decodeComponent(raw);
  }
  return null;
}

String? _inlinePayload(Uri uri) {
  String? value;
  if (uri.host.endsWith('f-puzzles.com')) {
    value = _rawQueryValue(uri, 'load');
    if (value != null && value.isNotEmpty) return 'fpuz$value';
  }
  value = _rawQueryValue(uri, 'puzzleid');
  if (value != null && value.isNotEmpty && _payloadPrefix.hasMatch(value)) {
    return value;
  }
  final segments = uri.pathSegments;
  final start =
      uri.host == 'sudokupad.svencodes.com' && segments.firstOrNull == 'puzzle'
      ? 1
      : (segments.firstOrNull == 'sudoku' ? 1 : 0);
  if (segments.length > start) {
    final value = segments.sublist(start).join('/');
    if (_payloadPrefix.hasMatch(value)) return value;
  }
  return null;
}

final _payloadPrefix = RegExp(r'^(?:scl|ctc|fpuz|fpuzzles|classic|scf|pack)');

Map<String, dynamic> _provenance(LibraryResolution resolution) => {
  'originalUrl': resolution.original.toString(),
  'resolvedUrl': resolution.resolved.toString(),
  'sourcePayload': resolution.payload,
  'fingerprint': librarySha256(resolution.payload),
  'format':
      _payloadPrefix.firstMatch(resolution.payload)?.group(0) ?? 'sudokupad',
  'resolverVersion': LibraryImport.resolverVersion,
  'redirects': resolution.redirects,
  'identity': 'author-source',
};

String? _puzzlePayloadIssue(LibraryEntry entry, String encoded) {
  if (_looksLikeHtml(encoded))
    return 'The server returned a web page instead of puzzle data.';
  const malformed =
      'The response does not contain an identifiable puzzle grid or package.';
  try {
    final prefix = _payloadPrefix.firstMatch(encoded);
    final format = prefix?.group(0);
    if (format == 'scf' || format == 'pack')
      return encoded.length > prefix!.end ? null : malformed;
    if (format == 'classic') {
      return RegExp(r'^[0-9.]{81}$').hasMatch(encoded.substring(prefix!.end))
          ? null
          : malformed;
    }
    final body = prefix == null ? encoded : encoded.substring(prefix.end);
    final object = _decodeJson(body.startsWith('{') ? body : _decompress(body));
    final cells = object['cells'] ?? object['grid'];
    if (cells is! List ||
        cells.isEmpty ||
        cells.length > 25 ||
        cells.any((row) => row is! List || row.isEmpty || row.length > 25))
      return malformed;
    if (!_matchesEmbeddedTitle(entry, object))
      return 'The embedded title does not match this Logic Masters edition.';
    return null;
  } on FormatException {
    return malformed;
  } on ArgumentError {
    return malformed;
  } on TypeError {
    return malformed;
  }
}

bool _matchesEmbeddedTitle(LibraryEntry entry, Map<String, dynamic> object) {
  try {
    final metadata = object['metadata'];
    final cages = object['cages'];
    final legacyTitle = cages is List
        ? cages
              .whereType<Map>()
              .map((cage) => cage['value'])
              .whereType<String>()
              .map(
                (value) => RegExp(
                  r'^title\s*:\s*(.+)$',
                  caseSensitive: false,
                ).firstMatch(value)?.group(1),
              )
              .nonNulls
              .firstOrNull
        : null;
    final title =
        (metadata is Map ? metadata['title']?.toString() : null) ??
        object['title']?.toString() ??
        legacyTitle;
    if (title == null || title.trim().isEmpty || entry.title.trim().isEmpty) {
      return true;
    }
    String normalize(String value) => value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final expected = normalize(entry.title);
    final actual = normalize(title);
    return expected == actual ||
        (expected.length >= 8 &&
            actual.length >= 4 &&
            (expected.contains(actual) || actual.contains(expected)));
  } on FormatException {
    return false;
  }
}

List<String>? _lookupKey(Uri uri) {
  if (uri.host.endsWith('f-puzzles.com')) {
    return null;
  }
  final puzzleId = uri.queryParameters['puzzleid'];
  if (puzzleId != null && RegExp(r'^[\w-]+(?:/[\w-]+)*$').hasMatch(puzzleId)) {
    return puzzleId.split('/');
  }
  var segments = uri.pathSegments;
  if (segments.firstOrNull == 'sudoku') segments = segments.sublist(1);
  if (uri.host == 'sudokupad.svencodes.com' &&
      segments.firstOrNull == 'puzzle') {
    segments = segments.sublist(1);
  } else if ((uri.host == 'sudokupad.app' || uri.host == 'www.sudokupad.app') &&
      segments.firstOrNull == 'puzzle') {
    return null; // This route is a player shell, not the primary API slug.
  }
  if (segments.isEmpty ||
      segments.any((part) => !RegExp(r'^[\w-]+$').hasMatch(part))) {
    return null;
  }
  return segments;
}

bool _sameList(List<int> a, List<int> b) =>
    a.length == b.length && a.indexed.every((pair) => b[pair.$1] == pair.$2);

List<String> _sclSymbols(
  Map<String, dynamic> json,
  Map<String, dynamic> metadata,
  String rules,
  int size,
) {
  final raw = json['symbols'] ?? metadata['symbols'] ?? metadata['digits'];
  if (raw is List) {
    final result = raw.map((value) => '$value').toList();
    if (result.length == size && result.toSet().length == size) return result;
  }
  if (raw is String) {
    final separated = raw
        .split(RegExp(r'\s*[,;|]\s*|\s+'))
        .where((value) => value.isNotEmpty)
        .toList();
    if (separated.length == size && separated.toSet().length == size) {
      return separated;
    }
    final characters = raw.runes.map(String.fromCharCode).toList();
    if (characters.length == size && characters.toSet().length == size) {
      return characters;
    }
  }
  final set = RegExp(r'\{([^}]+)\}').firstMatch(rules)?.group(1);
  if (set != null) {
    final values = set
        .replaceAll('−', '-')
        .split(RegExp(r'\s*,\s*'))
        .where((value) => value.isNotEmpty)
        .toList();
    if (values.length == size && values.toSet().length == values.length) {
      return values;
    }
  }
  final range = RegExp(
    r'(-?\d+)\s*(?:-|through|to|bis|–|—)\s*(-?\d+)',
    caseSensitive: false,
  ).firstMatch(rules.replaceAll('−', '-'));
  if (range != null) {
    final start = int.parse(range.group(1)!);
    final end = int.parse(range.group(2)!);
    if ((end - start).abs() + 1 <= size) {
      return [
        for (
          var value = start;
          start <= end ? value <= end : value >= end;
          value += start <= end ? 1 : -1
        )
          '$value',
      ];
    }
  }
  return [for (var value = 1; value <= size; value++) '$value'];
}

List<String?> _symbolSolution(Object? raw, List<String> symbols, int size) {
  final count = size * size;
  List<Object?> values;
  if (raw is List) {
    values = raw
        .expand<Object?>((value) => value is List ? value : [value])
        .toList();
  } else if (raw is String) {
    final separated = raw
        .trim()
        .split(RegExp(r'\s*[,;|]\s*|\s+'))
        .where((value) => value.isNotEmpty)
        .toList();
    values = separated.length == count
        ? separated
        : (symbols.every((symbol) => symbol.length == 1) && raw.length == count
              ? raw.split('')
              : const []);
  } else {
    values = const [];
  }
  if (values.length != count) return const [];
  final result = <String?>[
    for (final value in values)
      if (value == null || value == '' || value == '.') null else '$value',
  ];
  if (result.any((value) => value != null && !symbols.contains(value))) {
    return const [];
  }
  return result;
}

bool _validSymbolSolution(
  List<String?> solution,
  Set<int> playable,
  List<int?> regions,
  int size, {
  required bool allowRowRepeats,
  required bool allowColumnRepeats,
  required bool allowRegionRepeats,
}) {
  if (solution.length != size * size) return solution.isEmpty;
  bool unique(Iterable<int> cells, bool repeats) {
    if (repeats) return true;
    final values = [
      for (final cell in cells)
        if (playable.contains(cell) && solution[cell] != null) solution[cell],
    ];
    return values.toSet().length == values.length;
  }

  for (var row = 0; row < size; row++) {
    if (!unique([
      for (var col = 0; col < size; col++) row * size + col,
    ], allowRowRepeats)) {
      return false;
    }
  }
  for (var col = 0; col < size; col++) {
    if (!unique([
      for (var row = 0; row < size; row++) row * size + col,
    ], allowColumnRepeats)) {
      return false;
    }
  }
  for (final region in regions.whereType<int>().toSet()) {
    if (!unique(
      playable.where((cell) => regions[cell] == region),
      allowRegionRepeats,
    )) {
      return false;
    }
  }
  return true;
}

(Set<int>, List<LibraryFogTrigger>)? _readFog(
  Object? raw,
  int size,
  List<String?> solution,
  Set<int> playable, {
  required List<String?> givens,
  Object? foglink,
  Object? triggerEffects,
}) {
  if (raw == null) return null;
  int? cell(Object? value) {
    if (value is int && value >= 0 && value < size * size) return value;
    if (value is List && value.length == 2) {
      try {
        return _sclCell(value, size);
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  Set<int>? cells(Object? value) {
    if (value is! List) return null;
    final result = value.map(cell).toList();
    return result.any((item) => item == null) ? null : result.nonNulls.toSet();
  }

  Set<int>? expression(Object? value) {
    if (value is List) return cells(value);
    if (value is! String) return null;
    final result = <int>{};
    final coordinate = RegExp(
      r'\s*r(\d+)c(\d+)(?:\s*-\s*r(\d+)c(\d+))?',
      caseSensitive: false,
    );
    for (final group in value.split(RegExp('[,;]'))) {
      // SudokuPad also concatenates coordinates, for example r1c3r1c4.
      // Consume the whole expression so a partially understood link never
      // authorizes a reveal.
      final part = group.trim();
      if (part.isEmpty) return null;
      var offset = 0;
      while (offset < part.length) {
        final match = coordinate.matchAsPrefix(part, offset);
        if (match == null) return null;
        int index(int group) => (int.tryParse(match.group(group)!) ?? 0) - 1;
        final r1 = index(1), c1 = index(2);
        final r2 = match.group(3) == null ? r1 : index(3);
        final c2 = match.group(4) == null ? c1 : index(4);
        if ([r1, c1, r2, c2].any((i) => i < 0 || i >= size)) return null;
        for (var row = math.min(r1, r2); row <= math.max(r1, r2); row++) {
          for (var col = math.min(c1, c2); col <= math.max(c1, c2); col++) {
            result.add(row * size + col);
          }
        }
        offset = match.end;
      }
    }
    return result;
  }

  Set<int>? initial;
  List<dynamic>? normalizedLinks;

  if (raw is Map) {
    final map = raw.cast<String, dynamic>();
    final visible = cells(
      map['initiallyVisible'] ?? map['visible'] ?? map['start'],
    );
    final rawTriggers = map['triggers'];
    if (visible == null || rawTriggers is! List) return null;
    final triggers = <LibraryFogTrigger>[];
    for (final item in rawTriggers) {
      if (item is! Map) return null;
      final trigger = item.cast<String, dynamic>();
      final reveal = cells(trigger['reveals'] ?? trigger['cells']);
      if (reveal == null) return null;
      final requires = <int, String>{};
      final condition = trigger['requires'];
      if (condition is Map) {
        for (final entry in condition.entries) {
          final index = int.tryParse('${entry.key}');
          if (index == null || index < 0 || index >= size * size) return null;
          requires[index] = '${entry.value}';
        }
      } else {
        final index = cell(trigger['cell'] ?? condition);
        final value =
            trigger['value'] ??
            (index != null && index < solution.length ? solution[index] : null);
        if (index == null || value == null) return null;
        requires[index] = '$value';
      }
      triggers.add(
        LibraryFogTrigger(
          requires: requires,
          reveals: reveal,
          requiresLit: trigger['requiresLit'] == true,
          reversible: trigger['reversible'] as bool? ?? true,
        ),
      );
    }
    return (visible, triggers);
  } else if (raw is List) {
    // Direct SudokuPad foglight arrays are the authored initial lit cells.
    if (raw.every((item) => item is List && item.length == 2)) {
      initial = cells(raw);
    } else {
      // Legacy compact metadata uses cages labelled FOGLIGHT or
      // `FOGLIGHT: r1c1-r2c2`; combine the label and cage geometry.
      initial = <int>{};
      for (final item in raw) {
        if (item is! Map) return null;
        final cage = item.cast<String, dynamic>();
        final label = '${cage['value'] ?? ''}';
        final suffix = RegExp(
          r'^foglight\s*:\s*(.+)$',
          caseSensitive: false,
        ).firstMatch(label);
        final fromLabel = suffix == null
            ? const <int>{}
            : expression(suffix.group(1));
        final fromCage = cells(cage['cells'] ?? const <dynamic>[]);
        if (fromLabel == null || fromCage == null) return null;
        initial.addAll(fromLabel);
        initial.addAll(fromCage);
      }
    }
  } else {
    return null;
  }

  if (initial == null) return null;
  if (foglink is List) {
    normalizedLinks = foglink;
  } else if (triggerEffects is List) {
    normalizedLinks = <dynamic>[];
    for (final rawEffect in triggerEffects) {
      if (rawEffect is! Map) return null;
      final effect = rawEffect.cast<String, dynamic>();
      final trigger = effect['trigger'];
      final outcome = effect['effect'];
      if (trigger is! Map || outcome is! Map) return null;
      if (outcome['type'] != 'foglight' ||
          (trigger['type'] != null && trigger['type'] != 'cellvalue')) {
        return null; // Dynamic/non-fog effects remain pending support.
      }
      normalizedLinks.add([trigger['cell'], outcome['cells']]);
    }
  }

  final triggers = <LibraryFogTrigger>[];
  if (normalizedLinks != null) {
    for (final link in normalizedLinks) {
      if (link is! List || link.length != 2) return null;
      final requiredCells = expression(link[0]);
      final revealedCells = expression(link[1]);
      if (requiredCells == null || revealedCells == null) return null;
      final requires = <int, String>{};
      for (final index in requiredCells) {
        if (index >= solution.length || solution[index] == null) return null;
        requires[index] = solution[index]!;
      }
      triggers.add(
        LibraryFogTrigger(requires: requires, reveals: revealedCells),
      );
    }
  } else {
    // Standard SudokuPad fog: a correct placed value lights its clipped 3×3
    // neighborhood. Initial givens are lit as single cells (deep fog rule).
    initial.addAll([
      for (final (index, given) in givens.indexed)
        if (given != null && playable.contains(index)) index,
    ]);
    if (solution.length != size * size) return null;
    for (final index in playable) {
      final answer = solution[index];
      if (answer == null) continue;
      final row = index ~/ size;
      final col = index % size;
      triggers.add(
        LibraryFogTrigger(
          requires: {index: answer},
          reveals: {
            for (
              var r = math.max(0, row - 1);
              r <= math.min(size - 1, row + 1);
              r++
            )
              for (
                var c = math.max(0, col - 1);
                c <= math.min(size - 1, col + 1);
                c++
              )
                if (playable.contains(r * size + c)) r * size + c,
          },
        ),
      );
    }
  }
  return (initial, triggers);
}

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
  bool point(dynamic p, {bool exterior = false}) =>
      p is List &&
      p.length == 2 &&
      p.every(
        (v) =>
            v is num &&
            v.isFinite &&
            v >= (exterior ? -2 : 0) &&
            v <= size + (exterior ? 2 : 0),
      );
  bool finite(String key) =>
      item[key] == null || (item[key] is num && (item[key] as num).isFinite);
  switch (item['layer']) {
    case 'underlays':
    case 'overlays':
      return point(item['center'], exterior: true) &&
          finite('width') &&
          finite('height') &&
          finite('angle');
    case 'cages':
      return item['cells'] is List &&
          (item['cells'] as List).isNotEmpty &&
          (item['cells'] as List).every(point);
    case 'lines':
    case 'arrows':
      final points = item['wayPoints'];
      return points is List &&
          points.length >= 2 &&
          points.every((value) => point(value, exterior: true)) &&
          finite('thickness') &&
          finite('headLength');
    default:
      return false;
  }
}

String _decompress(String source) {
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
  // Some API responses preserve URL escapes in the compressed alphabet.
  // Decode only this field so original package bytes still identify the save.
  final raw = source.contains('%') ? Uri.decodeComponent(source) : source;
  final input = raw
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
