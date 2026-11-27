class LibraryEvent {
  const LibraryEvent({
    required this.time,
    required this.puzzleId,
    required this.stage,
    required this.message,
    this.location,
  });

  final DateTime time;
  final String puzzleId;
  final String stage;
  final String message;
  final String? location;

  String get reportLine => [
    time.toUtc().toIso8601String(),
    if (puzzleId.isNotEmpty) puzzleId,
    stage,
    message,
    ?location,
  ].join(' · ');

  // URLs may embed an entire puzzle, a signed query or credentials. Keep the
  // public host and route, and only short identifiers used by puzzle sources.
  static String? describeUri(Uri? uri) {
    if (uri == null || uri.host.isEmpty) return null;
    try {
      return _publicRoute(uri);
    } on FormatException {
      // An invalid percent-encoded path can still be useful as a host-only clue.
      return Uri(scheme: uri.scheme, host: uri.host).toString();
    }
  }

  static String _publicRoute(Uri uri) {
    final segments = uri.pathSegments.map((part) {
      if (part.length > 80 ||
          RegExp(
            r'^(scl|fpuz|ctc|classic).{20}',
            caseSensitive: false,
          ).hasMatch(part)) {
        return '[encoded]';
      }
      return part;
    });
    final query = <String, String>{};
    for (final key in [
      'id',
      'chlang',
      'listname',
      'start',
      'data',
      'puzzleid',
    ]) {
      final value = uri.queryParameters[key];
      if (value != null && RegExp(r'^[a-zA-Z0-9_-]{1,60}$').hasMatch(value)) {
        query[key] = value;
      }
    }
    final address = Uri(
      scheme: uri.scheme,
      host: uri.host,
      pathSegments: segments,
      queryParameters: query.isEmpty ? null : query,
    ).toString();
    return address.length > 260 ? '${address.substring(0, 259)}…' : address;
  }
}
