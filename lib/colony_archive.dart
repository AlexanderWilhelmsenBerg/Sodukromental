import 'campaign.dart';

/// The next colony becomes current only after the atomic snapshot succeeds.
/// A failed write leaves the original wallet, companion and buildings in place.
Future<Campaign?> saveColonyTransition(
  Campaign current,
  bool Function(Campaign) command,
  Future<void> Function(Map<String, dynamic>) write,
) async {
  final next = Campaign.fromJson(current.toJson());
  if (!command(next)) return null;
  await write(next.toJson());
  return next;
}
