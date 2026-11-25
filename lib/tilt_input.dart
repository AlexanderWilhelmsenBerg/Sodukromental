import 'dart:math' as math;

import 'campaign.dart';

/// Maps steady in-plane accelerometer readings to the fixed portrait frame.
class TiltInput {
  TiltInput({
    this.deadZone = 3.2,
    this.stability = const Duration(milliseconds: 180),
  });

  final double deadZone;
  final Duration stability;
  GravityDirection _direction = GravityDirection.down;
  GravityDirection? _candidate;
  DateTime? _since;
  double? _x;
  double? _y;

  void reset(GravityDirection direction) {
    _direction = direction;
    _candidate = null;
    _since = null;
    _x = _y = null;
  }

  GravityDirection? add(double x, double y, DateTime timestamp) {
    final horizontal = _x = _x == null ? x : .72 * _x! + .28 * x;
    final vertical = _y = _y == null ? y : .72 * _y! + .28 * y;
    final major = math.max(horizontal.abs(), vertical.abs());
    final minor = math.min(horizontal.abs(), vertical.abs());
    if (major < deadZone || major - minor < 1.2) {
      _candidate = null;
      _since = null;
      return null;
    }
    final next = horizontal.abs() > vertical.abs()
        ? horizontal < 0
              ? GravityDirection.right
              : GravityDirection.left
        : vertical < 0
        ? GravityDirection.up
        : GravityDirection.down;
    if (next != _candidate) {
      _candidate = next;
      _since = timestamp;
      return null;
    }
    if (next == _direction || timestamp.difference(_since!) < stability)
      return null;
    _direction = next;
    return next;
  }
}
