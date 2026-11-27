import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/library_diagram_sheet.dart';
import 'package:sodukromental/library_digest.dart';
import 'package:sodukromental/library_import.dart';
import 'package:sodukromental/library_models.dart';
import 'package:sodukromental/library_player_controller.dart';
import 'package:sodukromental/library_source.dart';
import 'package:sodukromental/library_store.dart';

void main() {
  test(
    '0.2.1+5 saved Greatest Fog and diagram notes upgrade offline',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'greatest-fog-upgrade',
      );
      addTearDown(() => temp.delete(recursive: true));
      final db = File('${temp.path}/library.sqlite');
      const catalog = LibraryEntry(
        id: '000VJJ',
        title: 'The Greatest Fog',
        author: 'Prof.Dori',
      );
      final entry = parseLibraryDetail(
        File('test/fixtures/000VJJ-detail.html').readAsStringSync(),
        catalog,
        catalog.portal,
        DateTime.utc(2026, 11, 27),
      ).entry;
      final payload = File(
        'test/fixtures/000VJJ.scl',
      ).readAsStringSync().trim();
      final image = base64Encode(
        File('test/fixtures/000VJJ.png').readAsBytesSync(),
      );
      final notes = {
        'version': 1,
        'images': {
          librarySha256(image): {
            'size': 9,
            'bounds': [0.0, 0.0, 1.0, 1.0],
            'marks': {'24': 4},
            'locked': [24],
          },
        },
      };
      final legacy = LibraryDownload(
        entry,
        diagram: image,
        supportReasons: const [
          'This edition uses fog reveal rules that are not yet reproducible.',
        ],
        provenance: {
          'originalUrl': entry.content,
          'resolvedUrl': 'https://sudokupad.app/api/puzzle/jni23ia3hh',
          'fingerprint': librarySha256(payload),
          'sourcePayload': payload,
          'resolverVersion': 3,
        },
      );
      expect(legacy.availability, LibraryAvailability.view);
      final offlineAttempts = <Uri>[];
      Future<LibraryStore> open({bool installLegacy = false}) =>
          LibraryStore.open(
            executor: NativeDatabase(
              db,
              setup: installLegacy
                  ? (sqlite) => sqlite.execute(
                      'INSERT INTO downloads (id, body) VALUES (?, ?)',
                      [entry.id, jsonEncode(legacy.toJson())],
                    )
                  : null,
            ),
            records: [entry],
            includeAuthored: false,
            fetch: (uri) async {
              offlineAttempts.add(uri);
              throw const LibraryRequestFailure('Offline', retry: false);
            },
          );
      final original = await open();
      await original.saveDiagramSheet(entry.id, entry.revision, notes);
      await original.close();

      final upgraded = await open(installLegacy: true);
      final puzzle = upgraded.download(entry.id)!;
      expect(puzzle.availability, LibraryAvailability.play);
      expect(
        puzzle.provenance['resolverVersion'],
        LibraryImport.resolverVersion,
      );
      expect(puzzle.provenance['reEvaluatedOffline'], true);
      expect(puzzle.provenance['sourcePayload'], payload);
      expect(puzzle.diagram, image);
      expect(LibraryDiagramSheet.hasDraft(upgraded, puzzle), true);
      expect(upgraded.getDiagramSheet(entry.id, entry.revision), notes);
      final player = LibraryPlayerController(puzzle: puzzle);
      expect(player.visible.length, 26);
      player.select(24);
      player.apply('4');
      expect(player.visible.length, 31);
      await upgraded.save(entry.id, entry.revision, player.snapshot());
      player.dispose();
      await upgraded.close();

      final reopened = await open();
      addTearDown(reopened.close);
      final restored = LibraryPlayerController(
        puzzle: reopened.download(entry.id)!,
        save: reopened.getSave(entry.id, entry.revision),
      );
      addTearDown(restored.dispose);
      expect(restored.displayedValue(24), '4');
      expect(restored.visible.length, 31);
      restored.undo();
      expect(restored.visible.length, 26);
      expect(reopened.getDiagramSheet(entry.id, entry.revision), notes);
      expect(offlineAttempts, isEmpty);
    },
  );
}
