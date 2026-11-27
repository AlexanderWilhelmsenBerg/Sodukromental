import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/board_view.dart';
import 'package:sodukromental/boards.dart';
import 'package:sodukromental/rule_lessons.dart';

void main() {
  testWidgets('a loose tile follows a single legal track and commits once', (
    t,
  ) async {
    final moves = <(int, int)>[];
    int? selected;
    final cells = List.filled(16, 1)..[6] = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: StatefulBuilder(
                builder: (context, rebuild) => SudokuBoardView(
                  size: 4,
                  cells: cells,
                  regions: boxRegions(4, 2, 2),
                  sliding: true,
                  anchors: const {7},
                  selected: selected,
                  onCell: (i) => rebuild(() => selected = i),
                  onDrop: (to, data) {
                    moves.add((data.source!, to));
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final source = t.getCenter(find.byKey(const ValueKey('cell-5')));
    Future<void> gesture(Offset end) async {
      final p = await t.startGesture(source);
      for (var i = 1; i <= 4; i++) {
        await p.moveTo(source + end * (i / 4));
        await t.pump();
      }
      await p.up();
      await t.pump();
    }

    await gesture(const Offset(65, 65));
    await gesture(const Offset(0, 75));
    await gesture(const Offset(32, 0));
    expect(moves, isEmpty);
    final p = await t.startGesture(source);
    await p.moveBy(const Offset(61, 0));
    await t.pump();
    final extra = await t.startGesture(source + const Offset(0, 31));
    await extra.up();
    await p.up();
    await t.pump();
    expect(moves, isEmpty);
    await gesture(const Offset(155, 7));
    expect(moves, [(5, 6)]);
    await t.tapAt(source);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(moves, [(5, 6), (5, 6)]);
    await t.drag(find.byKey(const ValueKey('cell-7')), const Offset(-80, 0));
    expect(moves.length, 2);
  });

  test(
    'all authored variants and rule combinations have an independent example',
    () {
      final lessons = {for (final l in ruleLessons) l.id: l};
      for (final kind in RuleKind.values) {
        expect(lessons, contains(kind.name));
      }
      for (final board in campaignBoards) {
        final ids = RuleLesson.forBoard(board).map((l) => l.id).toSet();
        expect(ids, containsAll(board.rules.map((r) => r.kind.name).toSet()));
        if (board.fog != FogKind.none) expect(ids, contains(board.fog.name));
        if (board.gravity) expect(ids, contains('gravity'));
      }
      for (final lesson in lessons.values) {
        expect(lesson.answers.toSet().length, lesson.answers.length);
        expect(lesson.correct, inInclusiveRange(0, lesson.answers.length - 1));
      }
    },
  );

  testWidgets('worm practice can be retried and replayed independently', (
    t,
  ) async {
    var played = false;
    final credits = <String>{};
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RuleWorkbook(
              lessons: [ruleLessons.first],
              onPlay: () => played = true,
              onPractice: credits.add,
              reducedMotion: true,
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Try an example'));
    await t.pump();
    await t.tap(find.text('1'));
    await t.pump();
    expect(credits, isEmpty);
    expect(find.textContaining('Try again.'), findsOneWidget);
    await t.tap(find.text('4'));
    await t.pump();
    expect(credits, {'renban'});
    await t.tap(find.text('Play'));
    expect(played, isTrue);
  });
}
