import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/local_store.dart';

void main() {
  test(
    'migrates a version one campaign and keeps settings independent',
    () async {
      final store = LocalStore(
        NativeDatabase.memory(
          setup: (db) {
            db.execute(
              'CREATE TABLE snapshots(name TEXT PRIMARY KEY, body TEXT NOT NULL)',
            );
            db.execute('INSERT INTO snapshots VALUES(?,?)', [
              'campaign',
              '{"dna":3}',
            ]);
            db.execute('PRAGMA user_version = 1');
          },
        ),
      );
      addTearDown(store.close);
      expect(await store.read('campaign'), {'dna': 3});
      await store.put('settings', {'motion': false});
      await store.put('campaign', {'dna': 4});
      expect(await store.read('settings'), {'motion': false});
      expect(await store.read('campaign'), {'dna': 4});
    },
  );
}
