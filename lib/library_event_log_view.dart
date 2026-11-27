import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'library_events.dart';
import 'library_store.dart';

class LibraryEventLogView extends StatelessWidget {
  const LibraryEventLogView({
    super.key,
    required this.store,
    this.puzzleId,
    this.puzzleTitle,
  });

  final LibraryStore store;
  final String? puzzleId;
  final String? puzzleTitle;

  static Future<void> show(
    BuildContext context,
    LibraryStore store, {
    String? puzzleId,
    String? puzzleTitle,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => LibraryEventLogView(
        store: store,
        puzzleId: puzzleId,
        puzzleTitle: puzzleTitle,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final events = store.events(puzzleId: puzzleId);
      return Scaffold(
        appBar: AppBar(
          title: Text(
            puzzleId == null ? 'Library event log' : 'Puzzle event log',
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (puzzleTitle case final title?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              Expanded(
                child: events.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            puzzleId == null
                                ? 'No Library events yet.'
                                : 'No events for this puzzle yet.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : SelectionArea(
                        child: ListView.separated(
                          itemCount: events.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) =>
                              _EventRow(events[index]),
                        ),
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy log for a report'),
            onPressed: events.isEmpty ? null : () => _copy(context, events),
          ),
        ),
      );
    },
  );

  Future<void> _copy(BuildContext context, List<LibraryEvent> events) async {
    final lines = events.map((event) => event.reportLine).join('\n');
    var message = 'Event log copied.';
    try {
      await Clipboard.setData(ClipboardData(text: lines));
    } on PlatformException {
      message = 'Could not copy the event log.';
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow(this.event);

  final LibraryEvent event;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    final time = event.time.toLocal();
    final when = [
      localizations.formatShortDate(time),
      localizations.formatTimeOfDay(
        TimeOfDay.fromDateTime(time),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      ),
    ].join(' ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.stage, style: theme.textTheme.titleSmall),
          Text(event.message),
          if (event.location case final location?)
            Text(location, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            [when, if (event.puzzleId.isNotEmpty) event.puzzleId].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
