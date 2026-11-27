// Hallmark · component: campaign work panels · genre: playful · theme: Hum
// states: default · focus · active · disabled · loading · error · success
// contrast: project palette
// Hallmark · pre-emit critique: P4 H4 E4 S5 R5 V4
import 'package:flutter/material.dart';

import 'hum.dart';

/// The one expandable row kept beside the active board objective.
///
/// It intentionally accepts display data and callbacks rather than a Campaign;
/// the domain remains authoritative and this view can also describe a restored
/// or reduced-motion job without inventing an actor.
class CampaignWorkRow extends StatelessWidget {
  const CampaignWorkRow({
    super.key,
    required this.title,
    required this.detail,
    this.workerNames = const [],
    this.shortfall = 0,
    this.actions = const [],
  });

  final String title;
  final String detail;
  final List<String> workerNames;
  final int shortfall;
  final List<CampaignWorkAction> actions;

  @override
  Widget build(BuildContext context) => Material(
    color: Hum.board,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(
        color: shortfall > 0 ? Hum.error : Hum.grid.withValues(alpha: .44),
      ),
    ),
    child: ExpansionTile(
      key: const ValueKey('campaign-work-row'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      leading: Icon(
        shortfall > 0 ? Icons.warning_amber_rounded : Icons.light_mode_outlined,
        color: shortfall > 0 ? Hum.error : Hum.focus,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(detail),
      children: [
        if (workerNames.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Crew · ${workerNames.join(', ')}'),
          ),
        if (shortfall > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '$shortfall more ${shortfall == 1 ? 'worker is' : 'workers are'} needed.',
                style: const TextStyle(
                  color: Hum.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (actions.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final action in actions)
                  TextButton.icon(
                    key: action.key,
                    onPressed: action.onPressed,
                    icon: Icon(action.icon),
                    label: Text(action.label),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

class CampaignWorkAction {
  const CampaignWorkAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Key? key;
}

/// Compact reminder shown on the board and repeated in Colony jobs.
class ProjectPinBanner extends StatelessWidget {
  const ProjectPinBanner({
    super.key,
    required this.label,
    required this.detail,
    required this.onClear,
  });

  final String label;
  final String detail;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Pinned goal. $label. $detail',
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Hum.cyan,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Hum.focus),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            const Icon(Icons.push_pin_outlined, color: Hum.focus),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(detail),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Clear pinned goal',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Read-only history row. Mutating archive controls remain in the prestige
/// preview so an accidental history tap can never reset the current run.
class ColonyArchiveRow extends StatelessWidget {
  const ColonyArchiveRow({
    super.key,
    required this.title,
    required this.summary,
    this.contributor,
  });

  final String title;
  final String summary;
  final String? contributor;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.inventory_2_outlined, color: Hum.focus),
    title: Text(title),
    subtitle: Text(
      [
        summary,
        if (contributor != null && contributor!.isNotEmpty)
          'Remembered companion · $contributor',
      ].join('\n'),
    ),
  );
}
