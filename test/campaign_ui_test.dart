import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/campaign_ui.dart';

void main() {
  testWidgets('work row names real crew and exposes recovery', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignWorkRow(
            title: 'Torches 1/3',
            detail: 'Crew short. Earned light stays safe.',
            workerNames: const ['Reed'],
            shortfall: 2,
            actions: [
              CampaignWorkAction(
                label: 'Open village',
                icon: Icons.cottage_outlined,
                onPressed: () => opened = true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Torches 1/3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('campaign-work-row')));
    await tester.pumpAndSettle();
    expect(find.text('Crew · Reed'), findsOneWidget);
    expect(find.text('2 more workers are needed.'), findsOneWidget);
    await tester.tap(find.text('Open village'));
    expect(opened, isTrue);
  });

  testWidgets('pin is explicit and clearable', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectPinBanner(
            label: 'Finish the Workshop',
            detail: '1 beam remaining',
            onClear: () => cleared = true,
          ),
        ),
      ),
    );
    expect(find.text('1 beam remaining'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear pinned goal'));
    expect(cleared, isTrue);
  });
}
