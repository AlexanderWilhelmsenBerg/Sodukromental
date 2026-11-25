import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const releaseRepository = 'AlexanderWilhelmsenBerg/Sodukromental';
const stablePackage = 'org.sodukromental';

class UpdateInfo {
  const UpdateInfo(this.version, this.code, this.page);
  final String version;
  final int code;
  final Uri page;

  Map<String, dynamic> toJson() => {
    'version': version,
    'code': code,
    'page': page.toString(),
  };
  static UpdateInfo? fromJson(dynamic data) {
    if (data is! Map || data['version'] is! String || data['code'] is! int)
      return null;
    final version = data['version'] as String;
    final page = Uri.tryParse('${data['page']}');
    if (_versionParts(version) == null || page != _releasePage(version))
      return null;
    return UpdateInfo(version, data['code'] as int, page!);
  }
}

List<int>? _versionParts(String value) {
  if (!RegExp(
    r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$',
  ).hasMatch(value))
    return null;
  return value.split('.').map(int.parse).toList();
}

Uri _releasePage(String version) =>
    Uri.https('github.com', '/$releaseRepository/releases/tag/v$version');

bool newerVersion(String version, String installed) {
  final candidate = _versionParts(version);
  final current = _versionParts(installed);
  if (candidate == null || current == null) return false;
  for (var i = 0; i < current.length; i++) {
    if (candidate[i] != current[i]) return candidate[i] > current[i];
  }
  return false;
}

class UpdateService {
  UpdateService({
    required this.version,
    required this.code,
    required this.packageId,
    required this.client,
    required this.save,
    Map<String, dynamic>? cached,
    DateTime Function()? now,
  }) : cache = {...?cached},
       clock = now ?? DateTime.now;
  final String version, packageId;
  final int code;
  final http.Client client;
  final Map<String, dynamic> cache;
  final Future<void> Function(Map<String, dynamic>) save;
  final DateTime Function() clock;

  Future<String>? _running;
  UpdateInfo? get available {
    final found = UpdateInfo.fromJson(cache['latest']);
    return found != null &&
            found.code > code &&
            newerVersion(found.version, version)
        ? found
        : null;
  }

  bool get showBanner =>
      available != null && available!.version != cache['dismissed'];
  Future<void> dismiss() async {
    cache['dismissed'] = available?.version;
    await save(cache);
  }

  Future<String> check({bool manual = false}) =>
      _running ??= _check(manual).whenComplete(() => _running = null);

  Future<String> _check(bool manual) async {
    final now = clock().millisecondsSinceEpoch;
    if (now < (cache['retry'] as int? ?? 0))
      return 'The server asked us to try again later.';
    if (!manual &&
        now - (cache['checked'] as int? ?? 0) <
            const Duration(days: 1).inMilliseconds)
      return 'Checked recently.';
    Future<http.Response> get(Uri uri, [Map<String, String>? headers]) =>
        client.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    try {
      final response = await get(
        Uri.https(
          'api.github.com',
          '/repos/$releaseRepository/releases/latest',
        ),
        {
          'Accept': 'application/vnd.github+json',
          if (cache['etag'] is String) 'If-None-Match': cache['etag'] as String,
        },
      );
      if (response.statusCode == 304) {
        cache['checked'] = now;
        await save(cache);
        return available == null
            ? 'You have the latest version.'
            : 'An update is available.';
      }
      if (response.statusCode == 404) {
        cache.remove('latest');
        cache.remove('etag');
        cache['checked'] = now;
        await save(cache);
        return 'There is no public stable release yet.';
      }
      if (response.statusCode == 403 || response.statusCode == 429) {
        final seconds = int.tryParse(response.headers['retry-after'] ?? '');
        final reset = int.tryParse(response.headers['x-ratelimit-reset'] ?? '');
        int? retryDate;
        try {
          retryDate = HttpDate.parse(
            response.headers['retry-after'] ?? '',
          ).millisecondsSinceEpoch;
        } on HttpException {
          // An absent or non-date value can still be a seconds-based delay.
        }
        cache['retry'] = seconds != null
            ? now + seconds * 1000
            : retryDate != null && retryDate > now
            ? retryDate
            : reset != null && reset * 1000 > now
            ? reset * 1000
            : now + 900000;
        await save(cache);
        return 'The server asked us to try again later.';
      }
      if (response.statusCode != 200) throw const HttpException('release');
      final release = jsonDecode(response.body);
      if (release is! Map ||
          release['tag_name'] is! String ||
          release['assets'] is! List ||
          release['prerelease'] != false ||
          release['draft'] != false)
        throw const FormatException();
      final tag = release['tag_name'] as String;
      if (!tag.startsWith('v')) throw const FormatException();
      final releaseVersion = tag.substring(1);
      if (_versionParts(releaseVersion) == null ||
          release['html_url'] != _releasePage(releaseVersion).toString()) {
        throw const FormatException();
      }
      final assets = (release['assets'] as List).whereType<Map>();
      String? assetUrl(String name) {
        final expected =
            'https://github.com/$releaseRepository/releases/download/$tag/$name';
        return assets.any(
              (a) => a['name'] == name && a['browser_download_url'] == expected,
            )
            ? expected
            : null;
      }

      final manifest = assetUrl('android-update.json');
      if (manifest == null) throw const FormatException();
      final metaResponse = await get(Uri.parse(manifest));
      if (metaResponse.statusCode != 200) throw const HttpException('manifest');
      final meta = jsonDecode(metaResponse.body);
      if (meta is! Map ||
          meta['applicationId'] != packageId ||
          meta['version'] != releaseVersion ||
          meta['versionCode'] is! int ||
          meta['versionCode'] < 1 ||
          meta['apk'] is! String ||
          !RegExp(r'^[A-Za-z0-9._-]+\.apk$').hasMatch(meta['apk']) ||
          assetUrl(meta['apk']) == null) {
        throw const FormatException();
      }
      cache['latest'] = UpdateInfo(
        releaseVersion,
        meta['versionCode'],
        _releasePage(releaseVersion),
      ).toJson();
      cache['checked'] = now;
      cache['etag'] = response.headers['etag'];
      cache.remove('retry');
      await save(cache);
      return available == null
          ? 'You have the latest version.'
          : 'An update is available.';
    } on FormatException {
      return 'The release information could not be verified.';
    } on Exception {
      cache['retry'] = now + const Duration(minutes: 2).inMilliseconds;
      await save(cache);
      return 'Could not reach the releases service.';
    }
  }
}
