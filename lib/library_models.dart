import 'boards.dart';

enum LibraryAvailability {
  original('Open original'),
  view('View offline'),
  play('Play offline');

  const LibraryAvailability(this.label);
  final String label;
}

enum LibrarySort {
  publication('Publication date'),
  difficulty('Difficulty'),
  rating('Rating'),
  title('Title'),
  played('Last played'),
  featured('Featured on CtC');

  const LibrarySort(this.label);
  final String label;
}

enum LibraryProgress { unplayed, started, solved, manual }

enum LibraryJobState { queued, downloading, paused, failed }

class LibraryRule {
  const LibraryRule(
    this.id,
    this.label,
    this.explanation,
    this.aliases, [
    this.tags = const [],
  ]);

  final String id;
  final String label;
  final String explanation;
  final List<String> aliases;
  final List<String> tags;

  bool matches(String text) {
    final lower = text.toLowerCase();
    return [
      label,
      ...aliases,
    ].any((phrase) => lower.contains(phrase.toLowerCase()));
  }
}

const libraryRules = [
  LibraryRule(
    'renban',
    'Renban',
    'Digits on the line make up a set of consecutive digits, without repeats.',
    ['consecutive digits in any order'],
    ['9031'],
  ),
  LibraryRule(
    'thermometer',
    'Thermometer',
    'Digits increase from the bulb to the tip.',
    ['thermo', 'thermometerlinie'],
    ['4054'],
  ),
  LibraryRule(
    'whispers',
    'German Whispers',
    'Neighboring digits on the line differ by at least the stated amount.',
    ['deutsches flüstern', 'german whisper'],
    ['9222'],
  ),
  LibraryRule(
    'killer',
    'Killer cage',
    'The cage total is the sum of its digits. The author specifies whether repeats are allowed.',
    ['killer cage', 'killerkäfig', 'killer käfig'],
  ),
  LibraryRule(
    'parity',
    'Even / Odd',
    'A parity clue restricts a digit to odd or even as specified.',
    [
      'even/odd',
      'parity',
      'odd digit',
      'digits are odd',
      'gray circles are odd',
      'gerade / ungerade',
    ],
    ['9021'],
  ),
  LibraryRule(
    'diagonal',
    'Diagonal',
    'Digits along a designated diagonal do not repeat.',
    ['negative diagonal', 'positive diagonal', 'diagonale'],
    ['9002'],
  ),
  LibraryRule(
    'xv',
    'XV pairs',
    'Two digits across an X total 10. Two across a V total 5.',
    ['x/v', 'xv pairs', 'separated by x'],
    ['9115'],
  ),
  LibraryRule(
    'arrow',
    'Arrow',
    'The circle equals the sum of the digits on its arrow.',
    ['arrow', 'pfeil'],
  ),
  LibraryRule(
    'palindrome',
    'Palindrome',
    'Read the same sequence of digits in either direction.',
    ['palindrome', 'palindrom'],
  ),
  LibraryRule(
    'kropki',
    'Kropki',
    'A white dot marks a difference of 1. A black dot marks a ratio of 2.',
    ['kropki', 'consecutive dot', 'ratio dot'],
  ),
  LibraryRule(
    'regionSum',
    'Region Sum Line',
    'Each segment within a region has the same sum.',
    ['region sum', 'regionssummen'],
  ),
  LibraryRule(
    'sandwich',
    'Sandwich',
    'The clue gives the sum of the digits between the two end values.',
    ['sandwich'],
  ),
  LibraryRule(
    'xSums',
    'X-Sums',
    'The clue gives the sum of the first X digits, where X is the nearest digit.',
    ['x-sum', 'x sum'],
  ),
  LibraryRule(
    'antiKnight',
    'Anti-knight',
    'Digits a chess knight move apart must be different.',
    [
      'anti-knight',
      'antiknight',
      'schachspringer',
      'knight’s move',
      "knight's move",
    ],
  ),
  LibraryRule(
    'fog',
    'Fog',
    'Reveal new clues as you place correct digits under the stated reveal rule.',
    ['fog', 'nebel'],
  ),
  LibraryRule(
    'jigsaw',
    'Jigsaw regions',
    'Each outlined irregular region contains every digit once.',
    ['jigsaw', 'irregular region', 'unregelmäßige regionen'],
  ),
];

Set<String> matchLibraryRules(String description, Map<String, String> tags) => {
  for (final rule in libraryRules)
    if (rule.matches(description) ||
        tags.keys.any(rule.tags.contains) ||
        tags.values.any(rule.matches))
      rule.id,
};

String libraryRuleFor(RuleKind kind) => switch (kind.name) {
  'germanWhispers' => 'whispers',
  'kropkiWhite' || 'kropkiBlack' => 'kropki',
  _ => kind.name,
};

class LibraryVideo {
  const LibraryVideo(
    this.id,
    this.source,
    this.reviewDate, {
    this.date,
    this.note,
    this.available = true,
  });

  final String id;
  final String source;
  final String reviewDate;
  final DateTime? date;
  final String? note;
  final bool available;
  Uri get watch => Uri.https('www.youtube.com', '/watch', {'v': id});

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'review': reviewDate,
    'date': date?.toIso8601String(),
    'note': note,
    'available': available,
  };

  static LibraryVideo fromJson(Map<String, dynamic> json) => LibraryVideo(
    json['id'] as String,
    json['source'] as String,
    json['review'] as String,
    date: DateTime.tryParse(json['date'] as String? ?? ''),
    note: json['note'] as String?,
    available: json['available'] as bool? ?? true,
  );
}

class LibraryEntry {
  const LibraryEntry({
    required this.id,
    required this.title,
    required this.author,
    this.published,
    this.difficulty,
    this.estimated = false,
    this.rating,
    this.rules = '',
    this.ruleIds = const {},
    this.tags = const {},
    this.completeRules = false,
    this.content,
    this.diagram,
    this.revision = '',
    this.language = 'en',
    this.requestedLanguage,
    this.languages = const [],
    this.videos = const [],
    this.size,
    this.authored = false,
    this.detailRead,
    this.withdrawn = false,
  });

  final String id;
  final String title;
  final String author;
  final DateTime? published;
  final int? difficulty;
  final bool estimated;
  final int? rating;
  final String rules;
  final Set<String> ruleIds;
  final Map<String, String> tags;
  final bool completeRules;
  final String? content;
  final String? diagram;
  final String revision;
  final String language;
  final String? requestedLanguage;
  final List<String> languages;
  final List<LibraryVideo> videos;
  final int? size;
  final bool authored;
  final DateTime? detailRead;
  final bool withdrawn;

  Uri get portal => Uri.https(
    'logic-masters.de',
    '/Raetselportal/Raetsel/zeigen.php',
    {'chlang': language, 'id': id},
  );

  DateTime? get featuredDate {
    DateTime? latest;
    for (final video in videos) {
      final date = video.date;
      if (date != null && (latest == null || date.isAfter(latest)))
        latest = date;
    }
    return latest;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'published': published?.toIso8601String(),
    'difficulty': difficulty,
    'estimated': estimated,
    'rating': rating,
    'rules': rules,
    'ruleIds': ruleIds.toList(),
    'tags': tags,
    'completeRules': completeRules,
    'content': content,
    'diagram': diagram,
    'revision': revision,
    'language': language,
    'requestedLanguage': requestedLanguage,
    'languages': languages,
    'videos': videos.map((video) => video.toJson()).toList(),
    'size': size,
    'authored': authored,
    'detailRead': detailRead?.toIso8601String(),
    'withdrawn': withdrawn,
  };

  static LibraryEntry fromJson(Map<String, dynamic> json) => LibraryEntry(
    id: json['id'] as String,
    title: json['title'] as String,
    author: json['author'] as String,
    published: DateTime.tryParse(json['published'] as String? ?? ''),
    difficulty: json['difficulty'] as int?,
    estimated: json['estimated'] as bool? ?? false,
    rating: json['rating'] as int?,
    rules: json['rules'] as String? ?? '',
    ruleIds: (json['ruleIds'] as List? ?? const []).cast<String>().toSet(),
    tags: (json['tags'] as Map? ?? const {}).cast<String, String>(),
    completeRules: json['completeRules'] as bool? ?? false,
    content: json['content'] as String?,
    diagram: json['diagram'] as String?,
    revision: json['revision'] as String? ?? '',
    language: json['language'] as String? ?? 'en',
    requestedLanguage: json['requestedLanguage'] as String?,
    languages: (json['languages'] as List? ?? const []).cast<String>(),
    videos: (json['videos'] as List? ?? const [])
        .map(
          (item) =>
              LibraryVideo.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList(),
    size: json['size'] as int?,
    authored: json['authored'] as bool? ?? false,
    detailRead: DateTime.tryParse(json['detailRead'] as String? ?? ''),
    withdrawn: json['withdrawn'] as bool? ?? false,
  );

  LibraryEntry withData(Map<String, dynamic> values) =>
      fromJson({...toJson(), ...values});
}

class LibraryDownload {
  const LibraryDownload(
    this.entry, {
    this.board,
    this.refs = const [],
    this.diagram,
    this.manual = false,
    this.finalCheck = false,
  });

  // Keep attribution and rules tied to the revision the player downloaded.
  final LibraryEntry entry;
  final BoardSpec? board;
  final List<Map<String, dynamic>> refs;
  final String? diagram;
  final bool manual;
  final bool finalCheck;
  LibraryAvailability get availability => board != null
      ? LibraryAvailability.play
      : diagram != null
      ? LibraryAvailability.view
      : LibraryAvailability.original;

  Map<String, dynamic> toJson() => {
    'entry': entry.toJson(),
    'manual': manual,
    'finalCheck': finalCheck,
    'diagram': diagram,
    'refs': refs,
    if (board case final board?)
      'board': {
        'size': board.size,
        'givens': board.givens,
        'regions': board.regions,
        'solution': board.solution,
        'rules': board.rules
            .map(
              (rule) => {
                'kind': rule.kind.name,
                'cells': rule.cells,
                'target': rule.target,
              },
            )
            .toList(),
      },
  };

  static LibraryDownload fromJson(Map<String, dynamic> json) {
    final entry = LibraryEntry.fromJson(
      (json['entry'] as Map).cast<String, dynamic>(),
    );
    final board = json['board'] as Map?;
    return LibraryDownload(
      entry,
      manual: json['manual'] as bool? ?? false,
      finalCheck: json['finalCheck'] as bool? ?? false,
      diagram: json['diagram'] as String?,
      refs: (json['refs'] as List? ?? [])
          .map((ref) => (ref as Map).cast<String, dynamic>())
          .toList(),
      board: board == null
          ? null
          : BoardSpec(
              id: entry.id,
              title: entry.title,
              size: board['size'] as int,
              description: entry.rules,
              givens: (board['givens'] as List).cast<int>(),
              regions: (board['regions'] as List).cast<int>(),
              solution: (board['solution'] as List).cast<int>(),
              rules: (board['rules'] as List)
                  .map(
                    (item) => VariantRule(
                      RuleKind.values.byName(item['kind'] as String),
                      (item['cells'] as List).cast<int>(),
                      target: item['target'] as int?,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class LibraryJob {
  const LibraryJob(
    this.id,
    this.revision,
    this.manual,
    this.state, {
    this.reason,
  });
  final String id;
  final String revision;
  final bool manual;
  final LibraryJobState state;
  final String? reason;

  Map<String, dynamic> toJson() => {
    'id': id,
    'revision': revision,
    'manual': manual,
    'state': state.name,
    'reason': reason,
  };
  static LibraryJob fromJson(Map<String, dynamic> json) => LibraryJob(
    json['id'] as String,
    json['revision'] as String,
    json['manual'] as bool,
    LibraryJobState.values.byName(json['state'] as String),
    reason: json['reason'] as String?,
  );
}

class LibraryPosition {
  const LibraryPosition(this.digits, this.notes);
  final List<int> digits;
  final Map<int, Set<int>> notes;

  Map<String, dynamic> toJson() => {
    'digits': digits,
    'notes': notes.map((cell, values) => MapEntry('$cell', values.toList())),
  };
  static LibraryPosition fromJson(Map json) => LibraryPosition(
    (json['digits'] as List).cast<int>(),
    (json['notes'] as Map).map(
      (cell, values) => MapEntry(
        int.parse(cell as String),
        (values as List).cast<int>().toSet(),
      ),
    ),
  );
}

class LibrarySave {
  const LibrarySave(this.history, this.index, this.lastPlayed, this.progress);
  final List<LibraryPosition> history;
  final int index;
  final DateTime lastPlayed;
  final LibraryProgress progress;

  Map<String, dynamic> toJson() => {
    'history': history.map((entry) => entry.toJson()).toList(),
    'index': index,
    'lastPlayed': lastPlayed.toIso8601String(),
    'progress': progress.name,
  };
  static LibrarySave fromJson(Map<String, dynamic> json) => LibrarySave(
    (json['history'] as List)
        .map((entry) => LibraryPosition.fromJson(entry as Map))
        .toList(),
    json['index'] as int,
    DateTime.parse(json['lastPlayed'] as String),
    LibraryProgress.values.byName(json['progress'] as String),
  );
}
