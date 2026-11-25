import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/board_view.dart';
import 'package:sodukromental/campaign.dart';
import 'package:sodukromental/colony_screen.dart';
import 'package:sodukromental/creatures.dart';
import 'package:sodukromental/tilt_input.dart';

void main() {
  for (final width in [320.0, 375.0, 414.0, 768.0]) {
    testWidgets('campaign fits $width dp with enlarged text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1150);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final run = Campaign();
      await tester.pumpWidget(_app(run, scale: 1.6));
      expect(find.byType(SudokuBoardView), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        final token = find.byKey(ValueKey('tutorial-token-$i'));
        expect(token, findsOneWidget);
        expect(tester.getSize(token), const Size.square(48));
      }
      expect(
        find.bySemanticsLabel('Row 1 column 1, 1, locked'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets(
    'opening uses selected and dragged sentence tokens and resumes a delivery',
    (tester) async {
      final start = DateTime.utc(2026);
      var run = Campaign(now: start);
      await tester.pumpWidget(_app(run));
      Future<void> cell(int index) async {
        await tester.tap(find.byKey(ValueKey('cell-$index')));
        await tester.pumpAndSettle();
      }

      for (final (from, to) in [(5, 1), (9, 5), (10, 9), (5, 4)]) {
        await cell(from);
        await cell(to);
      }
      expect(run.tutorialReady, isTrue);
      final token = find.byKey(const ValueKey('tutorial-token-0'));
      final gap = find.byKey(const ValueKey('cell-3'));
      await tester.dragFrom(
        tester.getCenter(token),
        tester.getCenter(gap) - tester.getCenter(token),
      );
      await tester.pumpAndSettle();
      expect(run.usedTutorialTokens, {0});
      for (final (id, to) in [(2, 5), (1, 10)]) {
        await tester.tap(find.byKey(ValueKey('tutorial-token-$id')));
        await tester.pumpAndSettle();
        await cell(to);
      }
      expect(run.dna, 3);
      await tester.tap(find.text('Create amoeba'));
      await tester.pump();
      expect(run.dna, 0);
      run = Campaign.fromJson(run.toJson());
      run.tick(start.add(const Duration(seconds: 3)));
      await tester.pumpWidget(_app(run));
      await tester.pump();
      expect(run.creatures, hasLength(1));
      final offer = run.offers.single;
      final offerTile = find.byKey(ValueKey('offer-${offer.id}'));
      await tester.ensureVisible(offerTile);
      await tester.tap(offerTile);
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('cell-12')));
      await cell(12);
      expect(run.cleared, isTrue);
      expect(run.rna, 6);
      await tester.tap(find.text('Grow to 5×5'));
      await tester.pumpAndSettle();
      expect(run.board.id, 'growth-5');
      expect(find.text('Request digits'), findsOneWidget);
    },
  );

  testWidgets('two matching, idle helpers flock at the tray', (tester) async {
    final start = DateTime.utc(2026);
    final amoeba = Creature.amoeba(1).toJson();
    final second = Creature.amoeba(2).toJson()
      ..['id'] = 'next-helper'
      ..['isAmoeba'] = false;
    final saved = Campaign(now: start).toJson()
      ..['clears'] = ['opening', 'growth-5']
      ..['creatures'] = [amoeba, second];
    final run = Campaign.fromJson(saved);
    expect(run.openBoard('growth-6'), isTrue);
    run.tick(start.add(const Duration(milliseconds: 100)));
    expect(run.reaction?.kind, ReactionKind.flock);
    expect(run.reaction?.index, -1);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(run));
    expect(find.byKey(ValueKey('reacting-${amoeba['id']}')), findsOneWidget);
    expect(find.byKey(const ValueKey('reacting-next-helper')), findsOneWidget);
    expect(find.bySemanticsLabel('2 helpers gathered for 4'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('dense grid offers linear placement at 320 dp', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1150);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final saved = Campaign().toJson()
      ..['clears'] = campaignBoards.take(6).map((board) => board.id).toList();
    final run = Campaign.fromJson(saved);
    expect(run.openBoard('renban'), isTrue);
    await tester.pumpWidget(_app(run, scale: 1.6));
    final empty = run.cells.indexOf(0);
    expect(empty, lessThan(run.board.size));
    final digit = run.tray.keys.first;
    final tile = find.byKey(ValueKey('tray-$digit'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    final selector = find.text('Select square');
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    final target = find.widgetWithText(ListTile, 'Column ${empty + 1}');
    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(run.cells[empty], digit);
    expect(tester.takeException(), isNull);
  });

  test('tilt requires stable dominant readings and covers all directions', () {
    final start = DateTime.utc(2026);
    final input = TiltInput();
    for (final (x, y, direction) in [
      (-9.0, 0.0, GravityDirection.right),
      (0.0, -9.0, GravityDirection.up),
      (9.0, 0.0, GravityDirection.left),
      (0.0, 9.0, GravityDirection.down),
    ]) {
      input.reset(
        direction == GravityDirection.down
            ? GravityDirection.up
            : GravityDirection.down,
      );
      expect(input.add(0, 0, start), isNull);
      GravityDirection? settled;
      for (var i = 1; i < 20; i++) {
        final emitted = input.add(
          x,
          y,
          start.add(Duration(milliseconds: i * 20)),
        );
        if (emitted != null) settled = emitted;
      }
      expect(settled, direction);
      expect(input.add(x, y, start.add(const Duration(seconds: 1))), isNull);
    }
  });
}

Widget _app(Campaign run, {double scale = 1}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(scale),
        disableAnimations: true,
      ),
      child: ColonyScreen(campaign: run, onChanged: () {}, tiltEnabled: false),
    ),
  ),
);
