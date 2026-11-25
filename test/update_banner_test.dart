import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sodukromental/campaign.dart';
import 'package:sodukromental/library.dart';
import 'package:sodukromental/local_store.dart';
import 'package:sodukromental/main.dart';
import 'package:sodukromental/updates.dart';

void main() {
  testWidgets(
    'a stable update stays in Settings after its library banner is dismissed',
    (tester) async {
      final store = LocalStore(NativeDatabase.memory());
      final library = await LibraryStore.open(
        executor: NativeDatabase.memory(),
        records: [],
        includeAuthored: false,
      );
      addTearDown(store.close);
      const release = 'https://github.com/$releaseRepository/releases';
      const names = ['game.apk', 'android-update.json'];
      final client = MockClient(
        (req) async => http.Response(
          jsonEncode(
            req.url.host == 'api.github.com'
                ? {
                    'tag_name': 'v1.10.0',
                    'prerelease': false,
                    'draft': false,
                    'html_url': '$release/tag/v1.10.0',
                    'assets': [
                      for (final name in names)
                        {
                          'name': name,
                          'browser_download_url':
                              '$release/download/v1.10.0/$name',
                        },
                    ],
                  }
                : {
                    'version': '1.10.0',
                    'versionCode': 11,
                    'applicationId': stablePackage,
                    'apk': 'game.apk',
                  },
          ),
          200,
        ),
      );
      final updates = UpdateService(
        version: '1.9.0',
        code: 10,
        packageId: stablePackage,
        client: client,
        save: (data) => store.put('update', data),
      );
      await updates.check(manual: true);
      final player = GameSession(
        Campaign(),
        {'reduceMotion': true},
        PackageInfo(
          appName: 'Sodukromental',
          packageName: stablePackage,
          version: '1.9.0',
          buildNumber: '10',
        ),
        client,
        updates,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: gameTheme(),
          home: GameHome(
            player: player,
            db: store,
            openLibrary: () async => library,
            syncLibrary: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Update available'), findsNothing);
      await tester.tap(find.text('Sudoku'));
      await tester.pumpAndSettle();
      expect(find.text('Update available · 1.10.0'), findsOneWidget);
      await tester.tap(find.byTooltip('Dismiss update'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Update available'), findsNothing);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      final link = find.text('View release 1.10.0');
      await tester.scrollUntilVisible(
        link,
        260,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(link, findsOneWidget);
      expect((await store.read('update'))?['dismissed'], '1.10.0');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
