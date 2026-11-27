enum SocialMomentKind {
  greeting,
  handoff,
  argument,
  tussle,
  standOff,
  returnGlyph,
}

/// A visual opportunity backed by two owned resident IDs. It never substitutes
/// a scenic actor for a worker and never transfers job ownership.
class SocialMoment {
  const SocialMoment({
    required this.id,
    required this.firstId,
    required this.secondId,
    required this.kind,
    required this.startedActiveMs,
    required this.dueActiveMs,
    this.jobId,
    this.glyphId,
  });

  final String id;
  final String firstId;
  final String secondId;
  final SocialMomentKind kind;
  final int startedActiveMs;
  final int dueActiveMs;
  final String? jobId;
  final String? glyphId;

  bool involves(String residentId) =>
      firstId == residentId || secondId == residentId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstId': firstId,
    'secondId': secondId,
    'kind': kind.name,
    'startedActiveMs': startedActiveMs,
    'dueActiveMs': dueActiveMs,
    if (jobId != null) 'jobId': jobId,
    if (glyphId != null) 'glyphId': glyphId,
  };

  factory SocialMoment.fromJson(Map<String, dynamic> json) => SocialMoment(
    id: json['id'] as String,
    firstId: json['firstId'] as String,
    secondId: json['secondId'] as String,
    kind: SocialMomentKind.values.byName(json['kind'] as String),
    startedActiveMs: json['startedActiveMs'] as int,
    dueActiveMs: json['dueActiveMs'] as int,
    jobId: json['jobId'] as String?,
    glyphId: json['glyphId'] as String?,
  );
}
