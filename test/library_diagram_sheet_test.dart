import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/library.dart';
import 'package:sodukromental/library_diagram_sheet.dart';
import 'package:sodukromental/library_source.dart';

void main() {
  testWidgets(
    '00036W image-only puzzle opens and resumes its manual worksheet offline',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 850);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dir = Directory.systemTemp.createTempSync('sodu-diagram-sheet');
      final db = File('${dir.path}/library.sqlite');
      const entry = LibraryEntry(
        id: '00036W',
        title: 'Classic Sudoku',
        author: 'Shinya',
      );
      const detail = '''
      <div class="rp_titel"><h2>Classic Sudoku</h2><span class="rp_eingestellt">Published on 25. January 2020, 16:18 by <a>Shinya</a></span></div>
      <div class="rp_html">A classic sudoku without any additional rules.
        <div style="clear:both;text-align:center"><img src="/Dateien/bild.php?data=99446e8e-5915-343133362d31"></div>
      </div>
    ''';
      final diagram = File('test/fixtures/00036W.png').readAsBytesSync();
      var online = true;
      var offlineFetches = 0;
      Future<LibraryStore> open() => LibraryStore.open(
        executor: NativeDatabase(db),
        records: [entry],
        includeAuthored: false,
        decodeImage: (bytes) async => bytes.length == diagram.length,
        fetch: (uri) async {
          if (!online) {
            offlineFetches++;
            throw StateError('unexpected network access');
          }
          if (uri.path == '/Dateien/bild.php')
            return LibraryResponse(200, diagram);
          expect(uri.path, endsWith('zeigen.php'));
          return LibraryResponse(200, Uint8List.fromList(utf8.encode(detail)));
        },
      );
      var store = await open();
      addTearDown(() async {
        await store.close();
        dir.deleteSync(recursive: true);
      });
      await tester.runAsync(() async {
        await store.requestDownload(entry.id);
        final limit = Stopwatch()..start();
        while (store.download(entry.id) == null &&
            limit.elapsedMilliseconds < 8000) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(store.availability(entry.id), LibraryAvailability.view);
        await store.rememberShelf(true);
      });
      final revision = store.download(entry.id)!.entry.revision;
      online = false;

      Future<void> tap(Finder target) async {
        await tester.ensureVisible(target.first);
        await tester.pump();
        await tester.tap(target.first);
        await tester.pumpAndSettle();
      }

      Future<void> showSheet(String label) async {
        await tester.pumpWidget(MaterialApp(home: LibraryScreen(store: store)));
        await tester.pumpAndSettle();
        await tap(find.widgetWithText(ListTile, 'Classic Sudoku'));
        await tap(find.text(label));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pumpAndSettle();
      }

      Finder cell(int i) => find.byKey(ValueKey('worksheet-cell-$i'));
      Finder digit(int i) => find.byKey(ValueKey('worksheet-digit-$i'));

      await showSheet('Solve on diagram');
      final image = find.byKey(const ValueKey('worksheet-align-tap'));
      final r = tester.getRect(image);
      expect(r.width / r.height, closeTo(483 / 465, .0001));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Use aligned grid'),
            )
            .onPressed,
        isNull,
      );
      Future<void> corner(double x, double y) async {
        await tester.tapAt(
          r.topLeft + Offset(r.width * x / 483, r.height * y / 465),
        );
        await tester.pump();
      }

      await corner(6, 6);
      await corner(4, 4);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Use aligned grid'),
            )
            .onPressed,
        isNull,
      );
      await corner(474, 457);
      await tap(find.text('Use aligned grid'));
      expect(cell(80), findsOneWidget);
      final aligned = tester.getRect(cell(0));
      expect(aligned.left, closeTo(r.left + r.width * 6 / 483, 1));
      expect(aligned.width, closeTo(r.width * 468 / 483 / 9, 1));
      await tap(cell(0));
      await tap(find.text('Lock printed cell'));
      expect(tester.widget<FilledButton>(digit(2)).onPressed, isNull);
      await tap(cell(1));
      await tap(digit(7));
      await tap(find.text('Erase entry'));
      await tap(digit(4));
      await tap(find.text('Finish manually'));
      await tap(find.text('Mark complete'));
      expect(find.text('Manually completed'), findsOneWidget);
      expect(store.getSave(entry.id, revision), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await store.close();
      store = await open();
      await showSheet('Resume diagram worksheet');
      expect(find.text('Manually completed'), findsOneWidget);
      expect(
        find.descendant(of: cell(1), matching: find.text('4')),
        findsOneWidget,
      );
      await tap(find.text('Continue editing'));
      await tap(cell(0));
      expect(find.text('Unlock printed cell'), findsOneWidget);
      expect(tester.widget<FilledButton>(digit(2)).onPressed, isNull);
      final saved = store.download(entry.id)!;
      expect(LibraryDiagramSheet.hasDraft(store, saved), isTrue);
      expect(
        LibraryDiagramSheet.hasDraft(
          store,
          LibraryDownload(saved.entry, diagram: 'different'),
        ),
        isFalse,
      );
      expect(store.getDiagramSheet(entry.id, 'another-revision'), isNull);
      expect(offlineFetches, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
