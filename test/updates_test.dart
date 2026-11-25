import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sodukromental/updates.dart';

void main() {
  test(
    'stable release, dismissal, cache, retry and offline all retain a valid update',
    () async {
      final root = 'https://github.com/$releaseRepository/releases';
      var mode = 200;
      var calls = 0;
      var time = DateTime.utc(2026);
      final service = UpdateService(
        version: '1.9.0',
        code: 10,
        packageId: stablePackage,
        save: (_) async {},
        now: () => time,
        client: MockClient((request) async {
          calls++;
          if (request.url.host == 'api.github.com') {
            if (mode == 429)
              return http.Response('', 429, headers: {'retry-after': '90'});
            if (mode == 304) {
              expect(request.headers['If-None-Match'], 'v1');
              return http.Response('', 304);
            }
            if (mode == 0) throw http.ClientException('offline');
            return http.Response(
              jsonEncode({
                'tag_name': 'v1.10.0',
                'draft': false,
                'prerelease': false,
                'html_url': '$root/tag/v1.10.0',
                'assets': [
                  for (final name in ['android-update.json', 'game.apk'])
                    {
                      'name': name,
                      'browser_download_url': '$root/download/v1.10.0/$name',
                    },
                ],
              }),
              200,
              headers: {'etag': 'v1'},
            );
          }
          return http.Response(
            jsonEncode({
              'applicationId': stablePackage,
              'version': '1.10.0',
              'versionCode': 11,
              'apk': 'game.apk',
            }),
            200,
          );
        }),
      );
      expect(await service.check(), 'An update is available.');
      expect(service.showBanner, isTrue);
      await service.dismiss();
      expect(service.showBanner, isFalse);
      expect(service.available!.version, '1.10.0');
      await service.check();
      expect(calls, 2);
      mode = 304;
      await service.check(manual: true);
      mode = 429;
      await service.check(manual: true);
      final previous = calls;
      await service.check(manual: true);
      expect(calls, previous);
      time = time.add(const Duration(minutes: 3));
      mode = 0;
      expect(await service.check(manual: true), contains('Could not reach'));
      expect(service.available!.code, 11);
    },
  );
  test('rejects missing asset, wrong package and mismatched version', () async {
    final root = 'https://github.com/$releaseRepository/releases';
    for (final fault in ['asset', 'package', 'tag', 'same', 'code']) {
      final service = UpdateService(
        version: '1.9.0',
        code: 3,
        packageId: stablePackage,
        save: (_) async {},
        client: MockClient(
          (req) async => http.Response(
            jsonEncode(
              req.url.host == 'api.github.com'
                  ? {
                      'tag_name': 'v1.9.1',
                      'draft': false,
                      'prerelease': false,
                      'html_url': '$root/tag/v1.9.1',
                      'assets': [
                        for (final n in [
                          'android-update.json',
                          if (fault != 'asset') 'game.apk',
                        ])
                          {
                            'name': n,
                            'browser_download_url': '$root/download/v1.9.1/$n',
                          },
                      ],
                    }
                  : {
                      'applicationId': fault == 'package'
                          ? 'other'
                          : stablePackage,
                      'version': fault == 'tag' ? '1.9.2' : '1.9.1',
                      'versionCode': fault == 'code' || fault == 'same' ? 3 : 4,
                      'apk': 'game.apk',
                    },
            ),
            200,
          ),
        ),
      );
      await service.check(manual: true);
      expect(service.available, isNull, reason: fault);
    }
    expect(newerVersion('1.9.0', '1.9.0'), isFalse);
    expect(newerVersion('1.10.0-beta', '1.9.0'), isFalse);
  });
}
