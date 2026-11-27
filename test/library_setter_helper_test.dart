import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/library_import.dart';
import 'package:sodukromental/library_models.dart';
import 'package:sodukromental/library_source.dart';

LibraryResponse response(String value) =>
    LibraryResponse(200, Uint8List.fromList(utf8.encode(value)));

String article(String title, String content) =>
    '<div class="rp_titel"><h2>$title</h2></div><div class="rp_html">$content</div>';

void main() {
  test(
    '000VLD takes its CTC-App link and its puzzle diagram, past the teaching example',
    () async {
      const roundabout = LibraryEntry(
        id: '000VLD',
        title: 'Roundabout',
        author: 'Phistomefel',
      );
      final events = <String>[];
      void trace(String stage, String message, Uri? uri) =>
          events.add('$stage $message');
      final entry = parseLibraryDetail(
        File('test/fixtures/000VLD-setter.html').readAsStringSync(),
        roundabout,
        roundabout.portal,
        DateTime.utc(2026, 11, 27),
        trace: trace,
      ).entry;
      expect(entry.content, 'https://sudokupad.app/0tov5o4wuj');
      expect(entry.diagram, endsWith('3576d90c-53803-34303934352d32'));
      final saved = await LibraryImport.read(entry, (uri) async {
        expect(uri.toString(), 'https://sudokupad.app/api/puzzle/0tov5o4wuj');
        return response(File('test/fixtures/000VLD.scl').readAsStringSync());
      }, trace: trace);
      expect(saved?.availability, LibraryAvailability.play);
      expect(saved?.nativeDefinition?.layers.length, 21);
      expect(events.any((e) => e.contains('Skipped an illustration')), isTrue);
      expect(events.any((e) => e.startsWith('Verification Accepted')), isTrue);
      expect(events.any((e) => e.startsWith('Decode Decoded a 9 × 9')), isTrue);
    },
  );

  test(
    'the playable linked picture and full-size diagram win over shop or example thumbnails',
    () {
      const entry = LibraryEntry(
        id: '000W7Q',
        title: 'Technology',
        author: 'setter',
      );
      LibraryEntry parse(String content) => parseLibraryDetail(
        article(entry.title, content),
        entry,
        entry.portal,
        DateTime.utc(2026),
      ).entry;
      final images = parse(
        '''
      <a href="https://example.com/shop"><img src="/Dateien/shop.jpg"></a>
      <p>Previous puzzle <a href="https://sudokupad.app/wrong"><img src="/Dateien/old.jpg" alt="Play"></a></p>
      <a href="https://sudokupad.app/qjqyw1jb8b"><span><img src="/Dateien/actual.jpg"></span></a>
      <a href="https://sudokupad.app/rep79njsaw">White background version</a>''',
      );
      expect(images.content, 'https://sudokupad.app/qjqyw1jb8b');
      expect(images.alternativeContent, ['https://sudokupad.app/rep79njsaw']);
      expect(images.diagram, endsWith('/actual.jpg'));
      final full = parse(
        '''
      <img src="/Dateien/icon.png"><br>Example:
      <a href="/Dateien/example.png"><img src="/Dateien/example-thumb.png"></a>
      <br>The puzzle:
      <a href="/Dateien/bild.php?data=full"><img src="/Dateien/thumb.png"></a>''',
      );
      expect(full.diagram, endsWith('/Dateien/bild.php?data=full'));
      expect(full.content, isNull);
    },
  );

  test(
    'a setter article can identify a board by its portal backlink; catalogs, other editions and multiple boards cannot',
    () async {
      const entry = LibraryEntry(
        id: '000W5I',
        title: 'Bent Arrow',
        author: 'GiAnMMV',
      );
      const landing = 'https://gianmmv.github.io/puzzles/bent-arrow/';
      const share = 'https://sudokupad.app/3mtz7tzdc3';
      final detail = parseLibraryDetail(
        article(entry.title, '''
      <a href="https://gianmmv.github.io/puzzles/">More puzzles</a>
      <a href="$landing">Play the puzzle</a>
      <a href="https://gianmmv.github.io/puzzles/random/?from=bent-arrow">Lucky</a>
      <a href="https://logic-masters.de/Benutzer/profil.php?name=GiAnMMV">Profile</a>
      '''),
        entry,
        entry.portal,
        DateTime.utc(2026),
      ).entry;
      expect(detail.content, landing);
      expect(detail.alternativeContent, isEmpty);
      String setter(String id, [String extra = '']) =>
          '''
      <main><article><h1>Bent Arrow</h1><a href="$share">Play in SudokuPad</a>
      <a href="https://logic-masters.de/Raetselportal/Raetsel/zeigen.php?id=$id">Logic Masters Germany</a>$extra</article></main>''';
      final seen = <Uri>[];
      final package = File(
        'test/fixtures/000W5I.scl',
      ).readAsStringSync().trim();
      LibraryFetch fetch(String body) => (uri) async {
        seen.add(uri);
        if (uri.toString() == landing) return response(body);
        expect(uri.toString(), 'https://sudokupad.app/api/puzzle/3mtz7tzdc3');
        return response(package);
      };
      final resolution = await LibraryImport.resolve(
        detail,
        fetch(setter('000W5I')),
      );
      expect(resolution?.redirects, 1);
      expect(seen, hasLength(2));
      expect(resolution?.payload, package);
      final decoded = LibraryImport.decode(detail, resolution!.payload);
      expect(decoded?.availability, LibraryAvailability.play);
      expect(decoded?.nativeDefinition?.width, 4);
      for (final body in [
        setter('000XXX'),
        setter('000W5I', '<a href="https://sudokupad.app/another">Play</a>'),
      ]) {
        seen.clear();
        expect(await LibraryImport.resolve(detail, fetch(body)), isNull);
        expect(seen.map((u) => u.toString()), [landing]);
      }
    },
  );

  test(
    'traces distinguish a player shell and wrong edition from a missing source',
    () async {
      const entry = LibraryEntry(
        id: '000VJJ',
        title: 'The Greatest Fog',
        author: 'Prof.Dori',
        content: 'https://sudokupad.app/wrong',
        alternativeContent: ['https://sudokupad.app/shell'],
      );
      final messages = <String>[];
      final found = await LibraryImport.resolve(
        entry,
        (uri) async => response(
          uri.path.endsWith('/shell')
              ? '<html>player</html>'
              : jsonEncode({
                  'cells': [
                    [{}],
                  ],
                  'title': 'Another Board',
                }),
        ),
        trace: (stage, message, uri) => messages.add(message),
      );
      expect(found, isNull);
      expect(
        messages.any(
          (message) => message.contains('embedded title does not match'),
        ),
        isTrue,
      );
      expect(
        messages.any(
          (message) => message.contains('web page instead of puzzle data'),
        ),
        isTrue,
      );
      expect(messages.last, contains('No authored player destination'));
    },
  );
}
