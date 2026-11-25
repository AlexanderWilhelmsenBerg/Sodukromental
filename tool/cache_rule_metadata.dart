import 'dart:convert';
import 'dart:io';
import 'package:sodukromental/library_models.dart';
import 'package:sodukromental/library_source.dart';

/// Enrich the listing with rule labels from already-fetched portal detail
/// files. Input is a JSON map of portal IDs to local HTML paths on stdin.
Future<void> main() async {
  final sources = jsonDecode(await utf8.decodeStream(stdin)) as Map;
  final target = File('assets/library/catalog.json');
  final rows = (jsonDecode(await target.readAsString()) as List)
      .cast<Map<String, dynamic>>();
  var tagged = 0;
  for (final raw in rows) {
    final path = sources[raw['id']];
    if (path is! String) continue;
    final entry = LibraryEntry.fromJson(raw);
    try {
      final detail = parseLibraryDetail(
        await File(path).readAsString(),
        entry,
        entry.portal,
        DateTime.now().toUtc(),
      ).entry;
      raw['ruleIds'] = detail.ruleIds.toList()..sort();
      raw['tags'] = detail.tags;
      if (detail.size != null) raw['size'] = detail.size;
      tagged++;
    } on FormatException {
      // An unavailable source page keeps its existing listing metadata.
    }
  }
  await target.writeAsString('${jsonEncode(rows)}\n');
  stdout.writeln('Enriched $tagged listing records from cached detail pages.');
}
