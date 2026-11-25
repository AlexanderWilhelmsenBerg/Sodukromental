import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Snapshots are replaced atomically. Older installations stored one campaign
/// under the same key before per-screen settings were added in version two.
class LocalStore extends GeneratedDatabase {
  LocalStore(QueryExecutor executor) : super(executor);

  factory LocalStore.open() =>
      LocalStore(driftDatabase(name: 'sodukromental_player'));

  @override
  int get schemaVersion => 2;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE snapshots (name TEXT PRIMARY KEY, body TEXT NOT NULL, '
        'updated INTEGER NOT NULL DEFAULT 0)',
      );
    },
    onUpgrade: (_, from, to) async {
      if (from < 2) {
        await customStatement(
          'ALTER TABLE snapshots ADD COLUMN updated INTEGER NOT NULL DEFAULT 0',
        );
      }
    },
  );

  Future<Map<String, dynamic>?> read(String name) async {
    final row = await customSelect(
      'SELECT body FROM snapshots WHERE name = ?',
      variables: [Variable.withString(name)],
    ).getSingleOrNull();
    return row == null
        ? null
        : jsonDecode(row.read<String>('body')) as Map<String, dynamic>;
  }

  Future<void> put(String name, Map<String, dynamic> value) {
    final encoded = jsonEncode(value);
    return customStatement(
      'INSERT INTO snapshots (name, body, updated) VALUES (?, ?, ?) '
      'ON CONFLICT(name) DO UPDATE SET body=excluded.body, updated=excluded.updated',
      [name, encoded, DateTime.now().millisecondsSinceEpoch],
    );
  }
}
