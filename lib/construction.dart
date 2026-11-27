import 'creatures.dart';

enum ConstructionLoadStage { reserved, cutting, cut, installing, installed }

class ConstructionLoad {
  ConstructionLoad({
    required this.id,
    required this.glyph,
    required this.stage,
    required this.fromFragment,
    this.workerId,
    this.dueAt,
  });

  final String id;
  final MaterialGlyph glyph;
  ConstructionLoadStage stage;
  final bool fromFragment;
  String? workerId;
  int? dueAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'glyph': {
      'id': glyph.id,
      'glyph': glyph.glyph,
      'role': glyph.role.name,
      'index': glyph.index,
    },
    'stage': stage.name,
    'fromFragment': fromFragment,
    if (workerId != null) 'workerId': workerId,
    if (dueAt != null) 'dueAt': dueAt,
  };

  factory ConstructionLoad.fromJson(Map<String, dynamic> json) {
    final glyph = Map<String, dynamic>.from(json['glyph'] as Map);
    return ConstructionLoad(
      id: json['id'] as String,
      glyph: MaterialGlyph(
        glyph['id'] as String,
        glyph['glyph'] as String,
        MaterialRole.values.byName(glyph['role'] as String),
        glyph['index'] as int?,
      ),
      stage:
          ConstructionLoadStage.values.asNameMap()[json['stage']] ??
          ConstructionLoadStage.reserved,
      fromFragment: json['fromFragment'] == true,
      workerId: json['workerId'] as String?,
      dueAt: json['dueAt'] as int?,
    );
  }
}

class ConstructionProjectWork {
  ConstructionProjectWork({
    required this.projectId,
    required List<ConstructionLoad> loads,
    this.paused = false,
    this.pausedAt,
    this.rewardApplied = false,
  }) : loads = List.unmodifiable(loads);

  final String projectId;
  final List<ConstructionLoad> loads;
  bool paused;
  int? pausedAt;
  bool rewardApplied;

  bool get complete =>
      loads.isNotEmpty &&
      loads.every((load) => load.stage == ConstructionLoadStage.installed);
  int get installedCount => loads
      .where((load) => load.stage == ConstructionLoadStage.installed)
      .length;

  Map<String, dynamic> toJson() => {
    'projectId': projectId,
    'loads': [for (final load in loads) load.toJson()],
    'paused': paused,
    if (pausedAt != null) 'pausedAt': pausedAt,
    'rewardApplied': rewardApplied,
  };

  factory ConstructionProjectWork.fromJson(Map<String, dynamic> json) =>
      ConstructionProjectWork(
        projectId: json['projectId'] as String,
        loads: [
          for (final item in (json['loads'] as List? ?? const []))
            ConstructionLoad.fromJson(Map<String, dynamic>.from(item as Map)),
        ],
        paused: json['paused'] == true,
        pausedAt: json['pausedAt'] as int?,
        rewardApplied: json['rewardApplied'] == true,
      );
}
