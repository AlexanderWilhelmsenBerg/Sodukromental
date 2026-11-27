import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/library_events.dart';
import 'package:sodukromental/library_models.dart';
import 'package:sodukromental/library_source.dart';
import 'package:sodukromental/library_store.dart';

const entry = LibraryEntry(
  id: '000VJJ',
  title: 'The Greatest Fog',
  author: 'Prof.Dori',
);

void main() {
  test('exported URLs keep the puzzle route and omit private or encoded data', () {
    expect(
      LibraryEvent.describeUri(
        Uri.parse(
          'https://user:password@logic-masters.de/Raetselportal/Raetsel/zeigen.php?chlang=en&id=000VJJ&secret=token#private',
        ),
      ),
      'https://logic-masters.de/Raetselportal/Raetsel/zeigen.php?id=000VJJ&chlang=en',
    );
    final inline = List.filled(1000, 'x').join();
    final location = LibraryEvent.describeUri(
      Uri.parse('https://sudokupad.app/scl$inline?load=$inline'),
    );
    expect(location, contains('sudokupad.app'));
    expect(location, isNot(contains('xxxx')));
    expect(location!.length, lessThan(100));
  });

  test(
    'migrates a v1 Library and keeps bounded, ordered diagnostics across restart',
    () async {
      final folder = await Directory.systemTemp.createTemp('sodu-log');
      addTearDown(() => folder.delete(recursive: true));
      final file = File('${folder.path}/library.sqlite');
      var online = true;
      Future<LibraryResponse> fetch(Uri uri) async {
        if (!online) fail('Unexpected offline request to $uri');
        if (uri.host == 'logic-masters.de') {
          return LibraryResponse(
            200,
            Uint8List.fromList(
              utf8.encode(
                '<div class="rp_titel"><h2>The Greatest Fog</h2></div>'
                '<div class="rp_html"><p>Normal Sudoku rules apply.</p>'
                '<a href="https://sudokupad.app/removed">Play the puzzle</a></div>',
              ),
            ),
          );
        }
        return LibraryResponse(404, Uint8List(0));
      }

      final store = await LibraryStore.open(
        executor: NativeDatabase(
          file,
          setup: (db) {
            for (final name in [
              'catalog',
              'downloads',
              'progress',
              'jobs',
              'preferences',
            ]) {
              db.execute(
                'CREATE TABLE $name (id TEXT PRIMARY KEY, body TEXT NOT NULL)',
              );
            }
            db.execute('INSERT INTO preferences VALUES (?, ?)', [
              'source',
              '{"savedShelf":true}',
            ]);
            db.execute('PRAGMA user_version=1');
          },
        ),
        records: [entry],
        includeAuthored: false,
        fetch: fetch,
        now: () => DateTime.utc(2026, 11, 27),
      );
      expect(store.opensSavedShelf, isTrue);
      for (var attempt = 0; attempt <= LibraryStore.eventLimit; attempt++) {
        await store.requestDownload(entry.id);
        await store.resumeDownloads();
        if (store.events().length == LibraryStore.eventLimit) break;
      }
      // Another attempt forces eviction on disk and in memory.
      await store.retryDownload(entry.id);
      await store.resumeDownloads();
      final events = store.events(puzzleId: entry.id);
      expect(events, hasLength(LibraryStore.eventLimit));
      expect(events.first.stage, 'Failed');
      expect(
        events.any(
          (e) =>
              e.message.contains('HTTP 404') &&
              e.location!.endsWith('/api/puzzle/removed'),
        ),
        isTrue,
      );
      expect(store.events(puzzleId: 'other'), isEmpty);
      final report = events.map((e) => e.reportLine).toList();
      await store.close();
      online = false;
      final reopened = await LibraryStore.open(
        executor: NativeDatabase(
          file,
          setup: (db) {
            expect(
              db
                  .select('SELECT COUNT(*) AS count FROM library_events')
                  .single['count'],
              LibraryStore.eventLimit,
            );
          },
        ),
        records: [entry],
        includeAuthored: false,
        fetch: fetch,
      );
      addTearDown(reopened.close);
      expect(reopened.opensSavedShelf, isTrue);
      expect(reopened.events().map((e) => e.reportLine), report);
    },
  );
}
