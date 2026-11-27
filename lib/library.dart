import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'board_view.dart';
import 'boards.dart';
import 'creatures.dart';
import 'library_artwork.dart';
import 'library_models.dart';
import 'library_player.dart';
import 'library_store.dart';

export 'library_models.dart';
export 'library_store.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.store,
    this.canColonyPlay,
    this.onColonyPlay,
    this.onBack,
    this.startSync = true,
    this.active = true,
    this.torchbearer,
    this.reduceMotion = false,
  });
  final LibraryStore store;
  final bool Function(BoardSpec)? canColonyPlay;
  final void Function(BoardSpec)? onColonyPlay;
  final VoidCallback? onBack;
  final bool startSync;
  final bool active;
  final ValueListenable<Creature?>? torchbearer;
  final bool reduceMotion;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  var _search = '';
  late bool _onlySaved = widget.store.opensSavedShelf;
  bool _started = false;
  final _selection = <String>{};
  var _selecting = false;
  LibrarySort _sort = LibrarySort.publication;
  _LibraryFilters _filters = const _LibraryFilters();

  @override
  void initState() {
    super.initState();
    _activateShelf();
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      _onlySaved = widget.store.opensSavedShelf;
      _started = false;
    }
    _activateShelf();
  }

  bool get _syncInBackground => widget.store.automatic;
  bool get _browseActive => widget.active && !_onlySaved;

  void _activateShelf() {
    if (_started || !widget.startSync || !(_browseActive || _syncInBackground))
      return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !(_browseActive || _syncInBackground)) {
        _started = false;
        return;
      }
      unawaited(widget.store.synchronize(language: _language(context)));
      unawaited(widget.store.resumeDownloads());
    });
  }

  void _shelf(bool saved) {
    setState(() => _onlySaved = saved);
    unawaited(widget.store.rememberShelf(saved));
    _activateShelf();
  }

  @override
  Widget build(BuildContext context) => !widget.active
      ? const SizedBox.shrink()
      : ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final store = widget.store;
            final results = store.browse(
              search: _search,
              requireRules: _filters.rules,
              excludeRules: _filters.excluded,
              all: _filters.all,
              classic: _filters.classic,
              onlySaved: _onlySaved,
              featured: _filters.featured,
              authored: _filters.authored,
              size: _filters.size,
              difficulty: _filters.difficulty == 0 ? null : _filters.difficulty,
              unknownDifficulty: _filters.difficulty == 0,
              progress: _filters.progress,
              sort: _sort,
            );
            return Scaffold(
              appBar: AppBar(
                leading: widget.onBack == null
                    ? null
                    : BackButton(onPressed: widget.onBack),
                title: Text(
                  _selecting
                      ? '${_selection.length} selected'
                      : 'Sudoku Library',
                ),
                actions: [
                  if (_selecting)
                    IconButton(
                      tooltip: 'Save selected puzzles',
                      icon: const Icon(Icons.download),
                      onPressed: _selection.isEmpty ? null : _downloadSelected,
                    ),
                  IconButton(
                    tooltip: _selecting ? 'Close selection' : 'Select puzzles',
                    icon: Icon(_selecting ? Icons.close : Icons.checklist),
                    onPressed: () => setState(() {
                      _selecting = !_selecting;
                      _selection.clear();
                    }),
                  ),
                  IconButton(
                    tooltip: 'Download queue',
                    icon: Badge(
                      isLabelVisible: store.jobs.isNotEmpty,
                      child: const Icon(Icons.file_download_outlined),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _DownloadQueue(store),
                      ),
                    ),
                  ),
                ],
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              labelText: 'Search title or author',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) =>
                                setState(() => _search = value),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Browse'),
                                selected: !_onlySaved,
                                onSelected: (_) => _shelf(false),
                              ),
                              ChoiceChip(
                                label: const Text('Saved'),
                                selected: _onlySaved,
                                onSelected: (_) => _shelf(true),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.filter_list),
                                label: Text(
                                  _filters.count == 0
                                      ? 'Filters'
                                      : 'Filters (${_filters.count})',
                                ),
                                onPressed: _openFilters,
                              ),
                              PopupMenuButton<LibrarySort>(
                                tooltip: 'Sort by',
                                initialValue: _sort,
                                onSelected: (sort) =>
                                    setState(() => _sort = sort),
                                itemBuilder: (_) => [
                                  for (final option in LibrarySort.values)
                                    PopupMenuItem(
                                      value: option,
                                      child: Text(option.label),
                                    ),
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    _sort.label,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!_onlySaved)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    store.syncMessage ??
                                        (store.syncing
                                            ? '${store.indexed} portal puzzles · ${store.detailed} details indexed'
                                            : '${store.indexed} portal puzzles · ${store.complete ? 'all listing pages synced' : '${store.pages} pages synced'}'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Refresh catalog',
                                  onPressed: store.syncing
                                      ? null
                                      : () => unawaited(
                                          store.synchronize(
                                            refresh: true,
                                            language: _language(context),
                                          ),
                                        ),
                                  icon: const Icon(Icons.refresh),
                                ),
                              ],
                            ),
                          if (!_onlySaved && store.syncing)
                            const LinearProgressIndicator(minHeight: 2),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: results.isEmpty
                          ? Center(
                              child: Text(
                                _onlySaved
                                    ? 'No saved puzzles match.'
                                    : 'No puzzles match.',
                              ),
                            )
                          : ListView.separated(
                              key: PageStorageKey<String>(
                                _onlySaved ? 'library-saved' : 'library-browse',
                              ),
                              itemCount: results.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final entry = results[index];
                                final pinned =
                                    store.download(entry.id)?.entry ?? entry;
                                final progress =
                                    store.getSave(entry.id)?.progress ??
                                    LibraryProgress.unplayed;
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 5,
                                  ),
                                  title: Text(entry.title),
                                  leading: _selecting && !entry.authored
                                      ? Checkbox(
                                          value: _selection.contains(entry.id),
                                          onChanged: (_) => _toggle(entry.id),
                                        )
                                      : null,
                                  trailing: !_selecting
                                      ? const Icon(Icons.chevron_right)
                                      : null,
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        [
                                          entry.author,
                                          _difficultyLabel(entry),
                                          _ratingLabel(entry),
                                          store.availability(entry.id).label,
                                          if (progress !=
                                              LibraryProgress.unplayed)
                                            _progressLabel(progress),
                                        ].join(' · '),
                                      ),
                                      _RuleChips(
                                        entry: pinned,
                                        featured: entry.videos.isNotEmpty,
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    if (_selecting) {
                                      if (!entry.authored) _toggle(entry.id);
                                      return;
                                    }
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => _LibraryDetails(
                                          id: entry.id,
                                          store: store,
                                          canColonyPlay: widget.canColonyPlay,
                                          onColonyPlay: widget.onColonyPlay,
                                          torchbearer: widget.torchbearer,
                                          reduceMotion: widget.reduceMotion,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );

  void _toggle(String id) => setState(() {
    if (!_selection.add(id)) _selection.remove(id);
  });

  Future<void> _downloadSelected() async {
    final ids = _selection.toList();
    setState(() {
      _selecting = false;
      _selection.clear();
    });
    for (final id in ids) {
      await widget.store.requestDownload(id);
    }
  }

  Future<void> _openFilters() async {
    final filters = await showModalBottomSheet<_LibraryFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FilterSheet(_filters),
    );
    if (mounted && filters != null) setState(() => _filters = filters);
  }
}

class _LibraryFilters {
  const _LibraryFilters({
    this.rules = const {},
    this.excluded = const {},
    this.all = false,
    this.classic = false,
    this.featured = false,
    this.authored,
    this.size,
    this.difficulty,
    this.progress,
  });
  final Set<String> rules;
  final Set<String> excluded;
  final bool all;
  final bool classic;
  final bool featured;
  final bool? authored;
  final int? size;
  final int? difficulty;
  final LibraryProgress? progress;
  int get count =>
      rules.length +
      excluded.length +
      [
        classic,
        featured,
        authored != null,
        size != null,
        difficulty != null,
        progress != null,
      ].where((flag) => flag).length;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet(this.initial);
  final _LibraryFilters initial;
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _rules = {...widget.initial.rules};
  late Set<String> _excluded = {...widget.initial.excluded};
  late bool _all = widget.initial.all;
  late bool _classic = widget.initial.classic;
  late bool _featured = widget.initial.featured;
  late bool? _authored = widget.initial.authored;
  late int? _size = widget.initial.size;
  late int? _difficulty = widget.initial.difficulty;
  late LibraryProgress? _progress = widget.initial.progress;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .88,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Filter puzzles',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _rules = {};
                  _excluded = {};
                  _all = false;
                  _classic = false;
                  _featured = false;
                  _authored = null;
                  _size = null;
                  _difficulty = null;
                  _progress = null;
                }),
                child: const Text('Clear'),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _menu<bool>(null, 'Catalog', _authored, {
                      true: 'Sodukromental',
                      false: 'Logic Masters',
                    }, (value) => _authored = value),
                    _menu<int>(null, 'Size', _size, {
                      for (var n = 4; n <= 10; n++) n: '$n × $n',
                    }, (value) => _size = value),
                    _menu<int>(null, 'Difficulty', _difficulty, {
                      0: 'Unknown',
                      for (var n = 1; n <= 5; n++) n: '$n / 5',
                    }, (value) => _difficulty = value),
                    _menu<LibraryProgress>(null, 'Progress', _progress, {
                      for (final entry in LibraryProgress.values)
                        entry: _progressLabel(entry),
                    }, (value) => _progress = value),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Classic only'),
                      selected: _classic,
                      onSelected: (value) => setState(() => _classic = value),
                    ),
                    FilterChip(
                      label: const Text('Featured on CtC'),
                      selected: _featured,
                      onSelected: (value) => setState(() => _featured = value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Include rules',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: !_all,
                      onSelected: (_) => setState(() => _all = false),
                    ),
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _all,
                      onSelected: (_) => setState(() => _all = true),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final rule in libraryRules)
                      FilterChip(
                        label: Text(rule.label),
                        selected: _rules.contains(rule.id),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _rules.add(rule.id);
                            _excluded.remove(rule.id);
                          } else {
                            _rules.remove(rule.id);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Exclude rules',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text('Requires a complete rule list.'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final rule in libraryRules)
                      FilterChip(
                        label: Text(rule.label),
                        selected: _excluded.contains(rule.id),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _excluded.add(rule.id);
                            _rules.remove(rule.id);
                          } else {
                            _excluded.remove(rule.id);
                          }
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _LibraryFilters(
                rules: _rules,
                excluded: _excluded,
                classic: _classic,
                all: _all,
                featured: _featured,
                authored: _authored,
                size: _size,
                difficulty: _difficulty,
                progress: _progress,
              ),
            ),
            child: const Text('Show puzzles'),
          ),
        ],
      ),
    ),
  );

  Widget _menu<T>(
    T? reset,
    String title,
    T? selected,
    Map<T, String> values,
    ValueChanged<T?> change,
  ) => PopupMenuButton<({T? value})>(
    initialValue: (value: selected),
    onSelected: (option) => setState(() => change(option.value)),
    itemBuilder: (_) => [
      PopupMenuItem(value: (value: reset), child: Text('Any $title')),
      for (final item in values.entries)
        PopupMenuItem(value: (value: item.key), child: Text(item.value)),
    ],
    child: Chip(
      label: Text(values[selected] ?? title),
      avatar: const Icon(Icons.expand_more),
    ),
  );
}

class _RuleChips extends StatelessWidget {
  const _RuleChips({
    required this.entry,
    this.featured = false,
    this.tappable = false,
  });
  final LibraryEntry entry;
  final bool featured;
  final bool tappable;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 2,
    children: [
      if (featured)
        const Chip(
          label: Text('Featured on CtC'),
          avatar: Icon(Icons.play_circle_outline, size: 17),
          visualDensity: VisualDensity.compact,
        ),
      for (final rule in libraryRules.where(
        (rule) => entry.ruleIds.contains(rule.id),
      ))
        if (tappable)
          ActionChip(
            label: Text(rule.label),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(rule.label),
                content: Text(rule.explanation),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          )
        else
          Chip(label: Text(rule.label), visualDensity: VisualDensity.compact),
      if (!entry.completeRules)
        const Chip(
          label: Text('More rules may apply'),
          visualDensity: VisualDensity.compact,
        ),
    ],
  );
}

class _LibraryDetails extends StatefulWidget {
  const _LibraryDetails({
    required this.id,
    required this.store,
    this.canColonyPlay,
    this.onColonyPlay,
    this.torchbearer,
    this.reduceMotion = false,
  });
  final String id;
  final LibraryStore store;
  final bool Function(BoardSpec)? canColonyPlay;
  final void Function(BoardSpec)? onColonyPlay;
  final ValueListenable<Creature?>? torchbearer;
  final bool reduceMotion;

  @override
  State<_LibraryDetails> createState() => _LibraryDetailsState();
}

class _LibraryDetailsState extends State<_LibraryDetails> {
  String? _message;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (widget.store.saved(widget.id)) return;
    try {
      await widget.store.details(widget.id, language: _language(context));
    } on Exception catch (error) {
      if (mounted) setState(() => _message = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final fresh = widget.store.entry(widget.id)!;
      final saved = widget.store.download(widget.id);
      final entry = saved?.entry ?? fresh;
      final board = saved?.board;
      final native = saved?.nativeDefinition;
      final job = widget.store.jobs
          .where((job) => job.id == entry.id)
          .firstOrNull;
      final videos = [...fresh.videos]
        ..sort((a, b) {
          if (a.available != b.available) return a.available ? -1 : 1;
          final comparison = (b.date?.millisecondsSinceEpoch ?? 0).compareTo(
            a.date?.millisecondsSinceEpoch ?? 0,
          );
          return comparison == 0 ? a.id.compareTo(b.id) : comparison;
        });
      return Scaffold(
        appBar: AppBar(title: const Text('Puzzle details')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                entry.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text('By ${entry.author}'),
              Text(
                [
                  _difficultyLabel(entry),
                  _ratingLabel(entry),
                  if (entry.size != null) '${entry.size} × ${entry.size}',
                  widget.store.availability(entry.id).label,
                  if (saved?.manual == true) 'Manual check',
                ].join(' · '),
              ),
              const SizedBox(height: 12),
              _RuleChips(
                entry: entry,
                featured: fresh.videos.isNotEmpty,
                tappable: true,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (native != null && saved!.supportReasons.isEmpty)
                    FilledButton.icon(
                      icon: const Icon(Icons.grid_on),
                      label: Text(
                        widget.store.getSave(entry.id, entry.revision) == null
                            ? 'Play puzzle'
                            : 'Resume puzzle',
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LibraryPlayer(
                            store: widget.store,
                            puzzle: saved,
                            torchbearer: widget.torchbearer,
                            reduceMotion: widget.reduceMotion,
                          ),
                        ),
                      ),
                    ),
                  if (board != null &&
                      widget.store.challenges.any(
                        (item) => item.id == board.id,
                      ) &&
                      widget.canColonyPlay?.call(board) == true)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.hub_outlined),
                      label: const Text('Play with Colony'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onColonyPlay?.call(board);
                      },
                    ),
                  if (!entry.authored && saved == null)
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.download),
                      label: Text(
                        job == null ? 'Save offline' : _jobLabel(job),
                      ),
                      onPressed: job == null
                          ? () => unawaited(
                              widget.store.requestDownload(entry.id),
                            )
                          : job.state == LibraryJobState.failed ||
                                job.state == LibraryJobState.paused
                          ? () =>
                                unawaited(widget.store.retryDownload(entry.id))
                          : null,
                    ),
                  if (!entry.authored && saved != null)
                    TextButton(
                      onPressed: () =>
                          unawaited(widget.store.removeDownload(entry.id)),
                      child: const Text('Remove download'),
                    ),
                  if (saved != null &&
                      !entry.authored &&
                      entry.revision != fresh.revision &&
                      job == null)
                    TextButton(
                      onPressed: () => unawaited(
                        widget.store.requestDownload(entry.id, replace: true),
                      ),
                      child: const Text('Download newer revision'),
                    ),
                  if (!entry.authored)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Read setter’s page'),
                      onPressed: () => _external(context, entry.portal),
                    ),
                ],
              ),
              if (_message != null && entry.rules.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_message!),
                ),
              if (saved?.diagram case final diagram?)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: InteractiveViewer(
                    child: Image.memory(
                      base64Decode(diagram),
                      semanticLabel: 'Saved puzzle diagram by ${entry.author}',
                    ),
                  ),
                )
              else if (board != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: _BoardPreview(puzzle: saved!),
                  ),
                ),
              for (final (index, video) in videos.indexed) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.ondemand_video),
                    label: Text(
                      video.available
                          ? (index == 0
                                ? 'Watch CtC solve'
                                : 'Watch another CtC solve')
                          : 'CtC solve unavailable',
                    ),
                    onPressed: video.available
                        ? () => _external(context, video.watch)
                        : null,
                  ),
                ),
                if (video.note case final note?) Text(note),
              ],
              const SizedBox(height: 14),
              Text(
                'Puzzle rules',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                entry.rules.isEmpty
                    ? 'Open the original puzzle for the author’s instructions.'
                    : entry.rules,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _BoardPreview extends StatelessWidget {
  const _BoardPreview({required this.puzzle});
  final LibraryDownload puzzle;
  @override
  Widget build(BuildContext context) {
    final board = puzzle.board!;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: SudokuBoardView(
          size: board.size,
          regions: board.regions,
          cells: board.givens,
          fixed: board.indices
              .where((index) => board.givens[index] != 0)
              .toSet(),
          visible: board.fog == FogKind.none
              ? null
              : board.starterPatch.toSet(),
          marks: _marks(puzzle),
          clueArtwork: puzzle.refs.isEmpty ? null : LibraryArtwork(puzzle),
          onCell: (_) {},
        ),
      ),
    );
  }
}

class LibrarySettingsTile extends StatelessWidget {
  const LibrarySettingsTile({super.key, required this.store});
  final LibraryStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => SwitchListTile(
      value: store.automatic,
      title: const Text('Automatically download Logic Masters puzzles'),
      subtitle: const Text(
        'Start with the newest puzzles and save compatible boards or references.',
      ),
      onChanged: (value) {
        unawaited(store.setAutomatic(value));
        if (value) unawaited(store.synchronize(language: _language(context)));
      },
    ),
  );
}

class _DownloadQueue extends StatelessWidget {
  const _DownloadQueue(this.store);
  final LibraryStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final jobs = store.jobs.toList();
      return Scaffold(
        appBar: AppBar(
          title: const Text('Download queue'),
          actions: [
            IconButton(
              tooltip: 'Resume downloads',
              icon: const Icon(Icons.refresh),
              onPressed: () => unawaited(store.resumeDownloads()),
            ),
          ],
        ),
        body: SafeArea(
          child: jobs.isEmpty
              ? const Center(child: Text('No puzzles in the queue.'))
              : ListView.builder(
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return ListTile(
                      title: Text(store.entry(job.id)?.title ?? job.id),
                      subtitle: Text(
                        [
                          _jobLabel(job),
                          if (job.reason case final reason?) reason,
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (job.state == LibraryJobState.downloading)
                            const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          if (job.state == LibraryJobState.paused ||
                              job.state == LibraryJobState.failed)
                            IconButton(
                              tooltip: 'Retry download',
                              icon: const Icon(Icons.refresh),
                              onPressed: () =>
                                  unawaited(store.retryDownload(job.id)),
                            ),
                          IconButton(
                            tooltip: 'Cancel download',
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                unawaited(store.cancelDownload(job.id)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      );
    },
  );
}

List<BoardMark> _marks(LibraryDownload puzzle) => puzzle.refs.isNotEmpty
    ? []
    : [
        for (final rule in puzzle.board!.rules)
          BoardMark(rule.kind.name, rule.cells, rule.target),
      ];

String _language(BuildContext context) {
  final appLanguage = Localizations.localeOf(context).languageCode;
  final deviceLanguage = View.of(
    context,
  ).platformDispatcher.locale.languageCode;
  return appLanguage == 'de' || deviceLanguage == 'de' ? 'de' : 'en';
}

Future<void> _external(BuildContext context, Uri link) async {
  var opened = false;
  try {
    opened = await launchUrl(link, mode: LaunchMode.externalApplication);
  } on Exception {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The link could not be opened.')),
    );
  }
}

String _difficultyLabel(LibraryEntry entry) => entry.difficulty == null
    ? 'Difficulty unknown'
    : 'Difficulty ${entry.difficulty}/5${entry.estimated ? ' (author estimate)' : ''}';

String _ratingLabel(LibraryEntry entry) =>
    entry.rating == null ? 'Rating unknown' : '${entry.rating}% rating';

String _jobLabel(LibraryJob job) => switch (job.state) {
  LibraryJobState.queued => 'Queued',
  LibraryJobState.downloading => 'Downloading',
  LibraryJobState.paused => 'Paused',
  LibraryJobState.failed => 'Failed',
};

String _progressLabel(LibraryProgress progress) => switch (progress) {
  LibraryProgress.unplayed => 'Unplayed',
  LibraryProgress.started => 'In progress',
  LibraryProgress.solved => 'Solved',
  LibraryProgress.manual => 'Solved · manual check',
};
