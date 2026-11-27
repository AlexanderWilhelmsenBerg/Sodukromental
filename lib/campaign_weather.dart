part of 'campaign.dart';

/// Water has one owner at a time: a printed counter, a carrier, or the cistern.
/// Only the mounted colony scene registers counters it has actually shaped.
class ColonyWeather {
  static const int capacity = 8;
  static const _cycle = 45000;
  static const _rainDuration = 11000;
  int elapsed = 0, stored = 0, watered = 0;
  String? carrierId;
  int _due = 0, _lastPlanter = 0, _filledEpoch = -1;
  bool get showering => elapsed % _cycle < _rainDuration;
  final _sources = <String, int>{};
  final _pools = <String, int>{};
  final _caughtThisShower = <String>{};

  int pool(String id) => _pools[id] ?? 0;
  void observe(String id, int counters) {
    if (counters > 0) _sources[id] = counters;
  }

  void leave(String id) => _sources.remove(id);
  void drain(String id) {
    _pools.remove(id);
    _sources.remove(id);
  }

  Set<String> _busyWorkers(Campaign campaign) => {
    ...campaign.jobs.map((j) => j.workerId),
    ...campaign.offers.map((o) => o.workerId),
    ...campaign.fogStaffing.assignedWorkerIds.where(
      (_) => campaign.board.fog != FogKind.none,
    ),
  };

  bool _scoop(String id, Campaign campaign) {
    if (carrierId != null ||
        stored >= capacity ||
        pool(id) <= 0 ||
        !_sources.containsKey(id))
      return false;
    final busy = _busyWorkers(campaign);
    final worker = campaign.creatures
        .where((c) => !busy.contains(c.id))
        .firstOrNull;
    if (worker == null) return false;
    _pools[id] = pool(id) - 1;
    carrierId = worker.id;
    _due = elapsed + 2300;
    return true;
  }

  bool _advance(int delta, Campaign campaign) {
    if (delta <= 0 ||
        campaign.population.communalCapacity == 0 ||
        campaign.libraryChallenge)
      return false;
    final previous = elapsed;
    elapsed += delta;
    var changed = previous % _cycle < _rainDuration != showering;
    if (elapsed ~/ _cycle != _filledEpoch) {
      _filledEpoch = elapsed ~/ _cycle;
      _caughtThisShower.clear();
      _pools.removeWhere((id, n) => !_sources.containsKey(id));
    }
    if (showering) {
      for (final e in _sources.entries) {
        if (!campaign.claimedGlyphs.contains(e.key) &&
            _caughtThisShower.add(e.key)) {
          _pools[e.key] = e.value;
          changed = true;
        }
      }
    }
    if (carrierId != null && _busyWorkers(campaign).contains(carrierId)) {
      // The resident keeps the bucket while a digit, lamp or building job takes priority.
      _due += delta;
    } else if (carrierId != null && elapsed >= _due) {
      stored = math.min(stored + 1, capacity);
      carrierId = null;
      changed = true;
    } else if (carrierId == null && elapsed ~/ 4000 != previous ~/ 4000) {
      for (final id in _sources.keys) {
        if (_scoop(id, campaign)) {
          changed = true;
          break;
        }
      }
    }
    if (stored >= 2 && elapsed - _lastPlanter >= 30000) {
      stored--;
      watered++;
      _lastPlanter = elapsed;
      changed = true;
    }
    return changed;
  }

  Map<String, dynamic> _save() => {
    'elapsed': elapsed,
    'stored': stored,
    'watered': watered,
    'carrier': carrierId,
    'due': _due,
    'planter': _lastPlanter,
    'epoch': _filledEpoch,
    'pools': Map.of(_pools),
    'caught': _caughtThisShower.toList(),
  };
  void _restore(Map<String, dynamic> v) {
    elapsed = math.max(0, v['elapsed'] as int? ?? 0);
    stored = (v['stored'] as int? ?? 0).clamp(0, capacity);
    watered = math.max(0, v['watered'] as int? ?? 0);
    carrierId = v['carrier'] as String?;
    _due = v['due'] as int? ?? 0;
    _lastPlanter = v['planter'] as int? ?? 0;
    _filledEpoch = v['epoch'] as int? ?? -1;
    _sources.clear();
    _pools
      ..clear()
      ..addAll(
        _map(v['pools']).map((k, n) => MapEntry(k, (n as int).clamp(0, 4))),
      );
    _caughtThisShower
      ..clear()
      ..addAll(_list<String>(v['caught']));
  }
}

extension RainCollection on Campaign {
  bool scoopWater(String id) {
    if (!weather._scoop(id, this)) return false;
    _changed();
    return true;
  }
}
