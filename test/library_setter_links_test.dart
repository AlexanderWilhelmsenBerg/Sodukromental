import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/library_diagram_sheet.dart';
import 'package:sodukromental/library_digest.dart';
import 'package:sodukromental/library_import.dart';
import 'package:sodukromental/library_models.dart';
import 'package:sodukromental/library_player_controller.dart';
import 'package:sodukromental/library_source.dart';
import 'package:sodukromental/library_store.dart';

const _entry = LibraryEntry(
  id: '000TZ5',
  title: 'Classic 21.07',
  author: 'IntelENC',
);
const _classic =
    'classic530070000600195000098000060800060003400803001700020006060000280000419005000080079';
LibraryResponse _text(String body, {int status = 200, String? location}) =>
    LibraryResponse(
      status,
      Uint8List.fromList(utf8.encode(body)),
      headers: {if (location != null) 'location': location},
    );

String _page(
  String links, {
  bool translated = false,
  LibraryEntry entry = _entry,
}) =>
    '''
<div class="rp_titel"><h2>${entry.title}</h2><span class="rp_eingestellt"><a>${entry.author}</a></span></div>
<div class="rp_html"><p>Normal Sudoku rules apply.</p>$links</div>
${translated ? '<img class="langwahl" alt="de"><img class="langwahl" alt="Print version">' : ''}
''';

void main() {
  test(
    'Classic 21.07 upgrades its same-revision saved diagram via the real short link and cold-opens offline',
    () async {
      final tmp = await Directory.systemTemp.createTemp('sodu-setter-retry');
      addTearDown(() => tmp.delete(recursive: true));
      final db = File('${tmp.path}/library.sqlite');
      final payload = File(
        'test/fixtures/000TZ5.scl',
      ).readAsStringSync().trim();
      var includeGame = false;
      var offline = false;
      final seen = <String>[];
      Future<LibraryResponse> fetch(Uri uri) async {
        if (offline) fail('Offline player requested $uri');
        seen.add(uri.toString());
        return switch (uri.host) {
          'logic-masters.de' when uri.path.endsWith('zeigen.php') => _text(
            _page(
              '<img src="/Dateien/diagram.png">${includeGame ? '<a href="https://shorturl.at/xNwne">Open in SudokuPad</a>' : ''}',
            ),
          ),
          'logic-masters.de' when uri.path.endsWith('/diagram.png') => _text(
            'fixture diagram',
          ),
          'shorturl.at' when uri.path == '/xNwne' => _text(
            '',
            status: 301,
            location: 'https://www.shorturl.at/xNwne',
          ),
          'www.shorturl.at' when uri.path == '/xNwne' => _text(
            '',
            status: 302,
            location: 'https://sudokupad.app/$payload',
          ),
          _ => _text('', status: 404),
        };
      }

      Future<LibraryStore> open() => LibraryStore.open(
        executor: NativeDatabase(db),
        includeAuthored: false,
        records: [_entry],
        fetch: fetch,
        decodeImage: (_) async => true,
      );
      var store = await open();
      await store.requestDownload(_entry.id);
      await store.resumeDownloads();
      expect(store.availability(_entry.id), LibraryAvailability.view);
      final revision = store.download(_entry.id)!.entry.revision;
      final originalImage = store.download(_entry.id)!.diagram!;
      final worksheet = {
        'version': 1,
        'images': {
          librarySha256(originalImage): {
            'size': 9,
            'bounds': [0.0, 0.0, 1.0, 1.0],
            'marks': {'0': 3},
          },
        },
      };
      await store.saveDiagramSheet(_entry.id, revision, worksheet);
      await store.close();
      includeGame = true;
      store = await open();
      await store.requestDownload(_entry.id);
      await store.resumeDownloads();
      final found = store.download(_entry.id)!;
      expect(found.availability, LibraryAvailability.play);
      expect(found.entry.revision, revision);
      expect(found.diagram, originalImage);
      expect(LibraryDiagramSheet.hasDraft(store, found), isTrue);
      expect(
        LibraryDiagramSheet.hasDraft(
          store,
          found.withDiagram('different-image'),
        ),
        isFalse,
      );
      expect(found.provenance['sourcePayload'], payload);
      expect(found.provenance['originalUrl'], 'https://shorturl.at/xNwne');
      expect(found.nativeDefinition!.givens.take(9), [
        null,
        '8',
        '3',
        null,
        null,
        null,
        '4',
        '6',
        null,
      ]);
      expect(seen.where((url) => url.contains('zeigen.php')), hasLength(2));

      // A broken revision cannot replace a working local game with a diagram.
      includeGame = false;
      await store.requestDownload(_entry.id, replace: true);
      await store.resumeDownloads();
      expect(store.availability(_entry.id), LibraryAvailability.play);
      await store.close();
      offline = true;
      store = await open();
      expect(store.getDiagramSheet(_entry.id, revision), worksheet);
      expect(store.getDiagramSheet(_entry.id, 'other-revision'), isNull);
      final player = LibraryPlayerController(
        puzzle: store.download(_entry.id)!,
      );
      player.select(0);
      player.apply('1');
      expect(player.position.values[0], '1');
      player.dispose();
      await store.close();
    },
  );

  test(
    'after a removed player link, use a puzzle-specific landing and keep unrelated grids out',
    () async {
      const whispers = LibraryEntry(
        id: '000W8V',
        title: 'Whispers of the Heavens',
        author: 'starchacer',
      );
      final payload = File(
        'test/fixtures/000W8V.scl',
      ).readAsStringSync().trim();
      final entry = parseLibraryDetail(
        _page(
          '''
      <p>Previous puzzle <a href="https://sudokupad.app/wrong">Old edition</a></p>
      <p><a href="https://sudokupad.app/dead">Play Whispers of the Heavens</a></p>
      <p><a href="https://solvepaths.droste.ai/play/wxvv8gu4co">Alternative solver</a></p>
      <a href="/Raetselportal/Benutzer/allgemein.php?name=starchacer">My profile</a>''',
          entry: whispers,
        ),
        whispers,
        whispers.portal,
        DateTime.now(),
      ).entry;
      expect(entry.alternativeContent, [
        'https://solvepaths.droste.ai/play/wxvv8gu4co',
      ]);
      final seen = <String>[];
      final result = await LibraryImport.read(entry, (uri) async {
        seen.add(uri.toString());
        return switch (uri.toString()) {
          'https://sudokupad.app/api/puzzle/dead' => _text('', status: 404),
          'https://solvepaths.droste.ai/play/wxvv8gu4co' => _text(
            '<a href="https://sudokupad.app/another">Example</a><a href="https://sudokupad.app/wxvv8gu4co">Open puzzle</a>',
          ),
          'https://sudokupad.app/api/puzzle/wxvv8gu4co' => _text(payload),
          _ => fail('Unrelated URL fetched: $uri'),
        };
      });
      expect(seen, hasLength(3));
      expect(result?.availability, LibraryAvailability.play);
      expect(result?.provenance['sourcePayload'], payload);
    },
  );

  test(
    'a written-English edition can use a play link from its own German edition',
    () async {
      final store = await LibraryStore.open(
        executor: NativeDatabase.memory(),
        records: [_entry],
        includeAuthored: false,
        fetch: (uri) async {
          if (uri.host == 'logic-masters.de') {
            expect(uri.queryParameters['id'], _entry.id);
            return switch (uri.queryParameters['chlang']) {
              'en' => _text(_page('', translated: true)),
              'de' => _text(
                _page('<a href="https://sudokupad.app/edition">SudokuPad</a>'),
              ),
              _ => fail('Tried a non-language action'),
            };
          }
          return _text(_classic);
        },
      );
      addTearDown(store.close);
      await store.requestDownload(_entry.id);
      await store.resumeDownloads();
      expect(store.availability(_entry.id), LibraryAvailability.play);
      expect(store.download(_entry.id)!.entry.language, 'en');
    },
  );
}
