import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sodukromental/updates.dart';

void main() {
  test(
    'a malformed latest response preserves the last validated update',
    () async {
      var response = http.Response('broken body', 200);
      final service = UpdateService(
        version: '1.9.0',
        code: 10,
        packageId: stablePackage,
        client: MockClient((_) async => response),
        save: (_) async {},
        cached: {
          'latest': {
            'version': '1.10.0',
            'code': 11,
            'page':
                'https://github.com/$releaseRepository/releases/tag/v1.10.0',
          },
        },
      );

      expect(service.showBanner, isTrue);
      expect(
        await service.check(manual: true),
        contains('could not be verified'),
      );
      expect(service.available?.version, '1.10.0');

      response = http.Response('', 404);
      expect(
        await service.check(manual: true),
        contains('no public stable release'),
      );
      expect(service.available, isNull);
    },
  );

  test(
    'HTTP-date Retry-After defers another update request until that time',
    () async {
      var time = DateTime.utc(2026, 11, 25, 10);
      final retryAt = time.add(const Duration(hours: 1));
      var requests = 0;
      final service = UpdateService(
        version: '1.9.0',
        code: 10,
        packageId: stablePackage,
        client: MockClient((_) async {
          requests++;
          return http.Response(
            '',
            429,
            headers: {'retry-after': HttpDate.format(retryAt)},
          );
        }),
        save: (_) async {},
        now: () => time,
      );

      expect(await service.check(manual: true), contains('try again later'));
      time = time.add(const Duration(minutes: 20));
      expect(await service.check(manual: true), contains('try again later'));
      expect(requests, 1);
      time = retryAt;
      await service.check(manual: true);
      expect(requests, 2);
    },
  );
}
