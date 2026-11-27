import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/library_artwork.dart';
import 'package:sodukromental/library_import.dart';
import 'package:sodukromental/library_models.dart';
import 'package:sodukromental/library_player_controller.dart';
import 'package:sodukromental/library_source.dart';
import 'package:sodukromental/library_store.dart';

LibraryResponse _text(String value, {int status = 200, String? location}) =>
    LibraryResponse(
      status,
      Uint8List.fromList(utf8.encode(value)),
      headers: {if (location != null) 'location': location},
    );

Future<void> _until(bool Function() ready) async {
  final limit = DateTime.now().add(const Duration(seconds: 10));
  while (!ready() && DateTime.now().isBefore(limit)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(ready(), isTrue);
}

String _detail(String id, String title, String content, {String links = ''}) =>
    '''
    <div class="rp_titel"><h2>$title</h2>
      <span class="rp_eingestellt">Published on 1. November 2026 by <a>Setter</a></span>
    </div>
    <div class="rp_html">
      <p>Normal Sudoku rules apply. Follow every authored visual clue.</p>
      $links
      <p><a href="$content">Solve $title on SudokuPad</a></p>
    </div>
    <div class="rp_aenderdatum">Last changed on 2. November 2026</div>
    ''';

void main() {
  for (final fixture in [
    (
      id: '000S4K',
      title: 'Ringing the Changes',
      author: 'Fool on Hill',
      file: 'test/fixtures/000S4K.scl',
      link: 'https://sudokupad.app/zhsltyic9o',
      refs: 17,
      alias: false,
    ),
    (
      id: '000VSG',
      title: 'The Graveyard Of Totality',
      author: 'fjam',
      file: 'test/fixtures/000VSG.scl',
      link: 'https://tinyurl.com/graveyardoftotality',
      refs: 23,
      alias: true,
    ),
  ]) {
    test(
      '${fixture.id} downloads, edits and cold-restores through the native player offline',
      () async {
        final folder = await Directory.systemTemp.createTemp('phase2-native');
        addTearDown(() => folder.delete(recursive: true));
        final database = File('${folder.path}/library.db');
        final payload = (await File(fixture.file).readAsString()).trim();
        var offline = false;
        var requests = 0;
        Future<LibraryResponse> fetch(Uri uri) async {
          requests++;
          if (offline) throw StateError('offline player attempted a request');
          if (uri.path.endsWith('zeigen.php')) {
            final distractor = fixture.id == '000S4K'
                ? '<p>Previous puzzle <a href="https://sudokupad.app/5tqg4ino2g">Whisper, who dares?</a></p>'
                : '';
            return _text(
              _detail(
                fixture.id,
                fixture.title,
                fixture.link,
                links: distractor,
              ),
            );
          }
          if (fixture.alias && uri.host == 'tinyurl.com') {
            return _text(
              '',
              status: 301,
              location: 'https://sudokupad.app/$payload',
            );
          }
          if (uri.host == 'sudokupad.app' &&
              uri.path.startsWith('/api/puzzle/')) {
            return _text(payload);
          }
          throw StateError('unexpected acquisition request: $uri');
        }

        final record = LibraryEntry(
          id: fixture.id,
          title: fixture.title,
          author: fixture.author,
        );
        var store = await LibraryStore.open(
          executor: NativeDatabase(database),
          fetch: fetch,
          records: [record],
          includeAuthored: false,
        );
        await store.requestDownload(fixture.id);
        await _until(() => store.download(fixture.id) != null);
        final installed = store.download(fixture.id)!;
        expect(installed.availability, LibraryAvailability.play);
        expect(installed.refs, hasLength(fixture.refs));
        expect(installed.provenance['sourcePayload'], payload);
        expect(installed.provenance['fingerprint'], hasLength(64));
        if (fixture.id == '000VSG') {
          expect(
            installed.provenance['fingerprint'],
            '4e6091781ee3e97706476d7265c638e2bbfdd243b0af9d6bc47c7f9ec4b6dc16',
          );
        }
        final definition = installed.nativeDefinition!;
        expect(definition.layers, hasLength(fixture.refs));

        final editable = definition.playable.firstWhere(
          (cell) => definition.givens[cell] == null,
        );
        final answer = definition.solution[editable]!;
        final controller = LibraryPlayerController(puzzle: installed);
        controller.select(editable);
        controller.apply(answer);
        controller.setMode(LibraryInputMode.corner);
        controller.apply('1');
        controller.setMode(LibraryInputMode.center);
        controller.apply('2');
        controller.setMode(LibraryInputMode.color);
        controller.apply('amber');
        expect(controller.position.values[editable], answer);
        expect(controller.position.cornerMarks[editable], {'1'});
        expect(controller.position.centerMarks[editable], {'2'});
        expect(controller.position.colors[editable], {'amber'});
        await store.save(
          fixture.id,
          installed.entry.revision,
          controller.snapshot(),
        );
        final onlineRequests = requests;
        await store.close();

        offline = true;
        store = await LibraryStore.open(
          executor: NativeDatabase(database),
          fetch: fetch,
          records: [record],
          includeAuthored: false,
        );
        final restoredDownload = store.download(fixture.id)!;
        final restored = LibraryPlayerController(
          puzzle: restoredDownload,
          save: store.getSave(fixture.id, installed.entry.revision),
        );
        expect(restored.position.values[editable], answer);
        expect(restored.position.cornerMarks[editable], {'1'});
        expect(restored.position.centerMarks[editable], {'2'});
        expect(restored.position.colors[editable], {'amber'});
        expect(requests, onlineRequests);
        await store.close();
      },
    );
  }

  test(
    'real DQ2 and W3T definitions retain geometry and honest check scopes',
    () async {
      Future<LibraryDownload> fixture(
        String id,
        String title,
        String author,
      ) async => LibraryImport.decode(
        LibraryEntry(id: id, title: title, author: author),
        (await File('test/fixtures/$id.scl').readAsString()).trim(),
      )!;

      final magic = await fixture('000DQ2', 'The Magic Column', 'marty_sears');
      final magicDefinition = magic.nativeDefinition!;
      expect(magic.availability, LibraryAvailability.play);
      expect(magicDefinition.width, 10);
      expect(magicDefinition.symbols, [
        for (var value = 1; value <= 9; value++) '$value',
      ]);
      expect(magicDefinition.allowRowRepeats, isTrue);
      expect(magicDefinition.deliberateBlanks, hasLength(10));
      expect(
        magicDefinition.layers.map((layer) => layer['order']),
        orderedEquals(List.generate(63, (i) => i)),
      );
      expect(magic.manual, isTrue);
      expect(magic.finalCheck, isTrue);
      final magicController = LibraryPlayerController(puzzle: magic);
      for (final cell in magicDefinition.playable) {
        if (magicDefinition.deliberateBlanks.contains(cell)) continue;
        magicController.select(cell);
        magicController.apply(magicDefinition.solution[cell]!);
      }
      final magicCheck = magicController.check();
      expect(magicCheck.solved, isTrue);
      expect(magicCheck.message, contains('authorized solution'));

      final balanced = await fixture('000W3T', 'Balanced X-Sums', 'Ambrose');
      final balancedDefinition = balanced.nativeDefinition!;
      expect(balanced.availability, LibraryAvailability.play);
      expect(balancedDefinition.symbols, [
        '-3',
        '-2',
        '-1',
        '0',
        '1',
        '2',
        '3',
      ]);
      expect(balancedDefinition.regions.whereType<int>(), isEmpty);
      expect(balancedDefinition.solution, isEmpty);
      expect(balanced.finalCheck, isFalse);
      expect(balanced.manual, isTrue);
      final balancedController = LibraryPlayerController(puzzle: balanced);
      balancedController.select(0);
      balancedController.apply('-3');
      balancedController.select(1);
      balancedController.apply('0');
      final balancedCheck = balancedController.check();
      expect(balancedController.position.values.take(2), ['-3', '0']);
      expect(balancedCheck.solved, isFalse);
      expect(balancedCheck.message, contains('unfinished'));
      expect(libraryArtworkMargin(balanced, balancedDefinition), .8);

      expect(libraryArtworkMargin(magic, magicDefinition), .8);
    },
  );

  testWidgets('real DQ2 and W3T artwork paints with exterior margins', (
    tester,
  ) async {
    for (final fixture in [
      (id: '000DQ2', title: 'The Magic Column', author: 'marty_sears'),
      (id: '000W3T', title: 'Balanced X-Sums', author: 'Ambrose'),
    ]) {
      final payload = await tester.runAsync(
        () => File('test/fixtures/${fixture.id}.scl').readAsString(),
      );
      final download = LibraryImport.decode(
        LibraryEntry(
          id: fixture.id,
          title: fixture.title,
          author: fixture.author,
        ),
        payload!.trim(),
      )!;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 420,
              child: LibraryArtwork(download),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(libraryArtworkMargin(download, download.nativeDefinition!), .8);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });
}
