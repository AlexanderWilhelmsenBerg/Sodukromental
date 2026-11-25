import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/board_view.dart';

void main() {
  testWidgets(
    'board touch, drag, semantics and keyboard share cell positions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      const regions = [0, 0, 1, 1, 0, 0, 1, 1, 2, 2, 3, 3, 2, 2, 3, 3];
      final entries = List<int>.filled(16, 0)..[0] = 1;
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => Column(
                  children: [
                    SudokuBoardView(
                      size: 4,
                      cells: entries,
                      regions: regions,
                      fixed: const {0},
                      anchors: const {0},
                      selected: selected,
                      onCell: (index) => setState(() => selected = index),
                      onDigit: (index, digit) {
                        setState(() => entries[index] = digit);
                      },
                      onErase: (index) => setState(() => entries[index] = 0),
                      onDrop: (index, digit) {
                        setState(() => entries[index] = digit.value!);
                      },
                    ),
                    const Draggable<BoardDrag>(
                      data: BoardDrag.digit(4),
                      feedback: BoardDigitFace(value: 4),
                      child: KeyedSubtree(
                        key: ValueKey('test-digit-4'),
                        child: BoardDigitFace(value: 4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      Finder cell(int index) => find.byKey(ValueKey('cell-$index'));
      expect(
        find.bySemanticsLabel('Row 1 column 1, 1, locked'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Row 1 column 3, empty'), findsOneWidget);

      await tester.tap(cell(1));
      await tester.pump();
      expect(selected, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pump();
      expect(selected, 1);
      expect(entries[2], 3);
      expect(find.bySemanticsLabel('Row 1 column 3, 3'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(entries[2], 0);

      final source = tester.getCenter(
        find.byKey(const ValueKey('test-digit-4')),
      );
      final destination = tester.getCenter(cell(3));
      await tester.dragFrom(source, destination - source);
      await tester.pump();
      expect(entries[3], 4);
      expect(find.bySemanticsLabel('Row 1 column 4, 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
