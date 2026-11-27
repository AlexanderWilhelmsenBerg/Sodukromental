import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/library.dart';
import 'package:sodukromental/library_source.dart';

void main() {
  testWidgets(
    'Library and puzzle logs display and copy their own live events',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      const first = LibraryEntry(
        id: '000ABC',
        title: 'First puzzle',
        author: 'Setter',
      );
      const second = LibraryEntry(
        id: '000ABD',
        title: 'Second puzzle',
        author: 'Setter',
      );
      var time = DateTime.utc(2026, 11, 27, 10);
      final store = (await tester.runAsync(
        () => LibraryStore.open(
          executor: NativeDatabase.memory(),
          records: const [first, second],
          includeAuthored: false,
          now: () => time,
          fetch: (uri) async {
            final entry = uri.queryParameters['id'] == first.id
                ? first
                : second;
            final body =
                '''
          <div class="rp_titel"><h2>${entry.title}</h2></div>
          <div class="rp_html"><p>Normal Sudoku rules apply.</p></div>
        ''';
            return LibraryResponse(200, Uint8List.fromList(utf8.encode(body)));
          },
        ),
      ))!;
      addTearDown(store.close);

      final copies = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copies.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: LibraryScreen(store: store, startSync: false),
        ),
      );
      await tester.tap(find.byTooltip('Library event log'));
      await tester.pumpAndSettle();
      expect(find.text('No Library events yet.'), findsOneWidget);
      final copy = find.text('Copy log for a report');
      final copyButton = find.ancestor(
        of: copy,
        matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
      );
      expect(tester.widget<OutlinedButton>(copyButton).onPressed, isNull);

      await tester.runAsync(() async {
        for (final entry in [first, second]) {
          await store.requestDownload(entry.id);
          await store.resumeDownloads();
          time = time.add(const Duration(minutes: 1));
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('No Library events yet.'), findsNothing);
      expect(
        store.events().map((event) => event.puzzleId),
        containsAll([first.id, second.id]),
      );
      expect(find.textContaining(second.id), findsWidgets);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(
        copies.single,
        store.events().map((event) => event.reportLine).join('\n'),
      );
      expect(find.text('Event log copied.'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Browse'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), first.id);
      await tester.pumpAndSettle();
      final result = find.widgetWithText(ListTile, first.title).hitTestable();
      expect(
        result,
        findsOneWidget,
        reason: store
            .browse(search: first.id)
            .map((entry) => entry.title)
            .join(', '),
      );
      await tester.tap(result);
      await tester.pumpAndSettle();
      final puzzleLog = find.text('Puzzle event log');
      await tester.ensureVisible(puzzleLog);
      await tester.tap(puzzleLog);
      await tester.pumpAndSettle();
      expect(find.text(first.title), findsOneWidget);
      expect(find.textContaining(first.id), findsWidgets);
      expect(find.textContaining(second.id), findsNothing);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(copies, hasLength(2));
      final scopedEvents = store.events(puzzleId: first.id);
      expect(scopedEvents, isNotEmpty);
      expect(
        copies.last,
        scopedEvents.map((event) => event.reportLine).join('\n'),
      );
      expect(copies.last, isNot(contains(second.id)));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
