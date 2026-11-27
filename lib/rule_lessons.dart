import 'package:flutter/material.dart';

import 'boards.dart';
import 'creature_view.dart';
import 'creatures.dart';
import 'hum.dart';

/// Each exercise is self-contained. It has no reference to a live board or inventory.
class RuleLesson {
  const RuleLesson(
    this.id,
    this.title,
    this.line,
    this.valid,
    this.invalid,
    this.reason,
    this.prompt,
    this.answers,
    this.correct,
    this.success,
  );
  final String id, title, line, valid, invalid, reason, prompt, success;
  final List<String> answers;
  final int correct;

  static List<RuleLesson> forBoard(BoardSpec board) {
    final ids = {
      if (board.fog != FogKind.none) board.fog.name,
      ...board.rules.map((r) => r.kind.name),
      if (board.gravity) 'gravity',
    };
    return [for (final id in ids) ruleLessons.singleWhere((l) => l.id == id)];
  }
}

const ruleLessons = [
  RuleLesson(
    'renban',
    'Renban worm',
    'My whole line uses consecutive digits, once each. They can be in any order.',
    '6  4  7  5',
    '4  6  7  8',
    'The worm is missing 5 between 4 and 8.',
    'Finish my four-cell line: 2, 5, 3, __.',
    ['1', '4', '6'],
    1,
    '2, 3, 4 and 5 form an unbroken run.',
  ),
  RuleLesson(
    'thermometer',
    'Thermometer',
    'Start at the round bulb. Each digit must be larger than the one before it.',
    '●2  5  8',
    '●2  5  4',
    'The temperature falls from 5 to 4.',
    'Which tip fits after bulb 3 and middle 6?',
    ['4', '6', '8'],
    2,
    '3, 6, 8 increases all the way.',
  ),
  RuleLesson(
    'kropkiWhite',
    'White Kropki dot',
    'Two cells touching a white dot differ by one.',
    '3 ○ 4',
    '2 ○ 4',
    '2 and 4 are two apart.',
    'Which neighbor can touch 7 across a white dot?',
    ['5', '8', '3'],
    1,
    '7 and 8 differ by one.',
  ),
  RuleLesson(
    'kropkiBlack',
    'Black Kropki dot',
    'Across a black dot, one digit is double its neighbor.',
    '3 ● 6',
    '3 ● 5',
    'Double 3 is 6.',
    'Which neighbor can touch 4 across a black dot?',
    ['1', '6', '8'],
    2,
    'Double 4 is 8.',
  ),
  RuleLesson(
    'germanWhispers',
    'German Whispers',
    'Each step along this line changes by at least five on a 9×9 board.',
    '2 ━ 8',
    '2 ━ 6',
    'The difference is only four.',
    'From 3, which step is big enough?',
    ['7', '9', '5'],
    1,
    '3 to 9 changes by six.',
  ),
  RuleLesson(
    'killer',
    'Killer cage',
    'Fill the cage with different digits that add to its little total.',
    '₇[2  5]',
    '₇[3  5]',
    '3 + 5 is 8, but the label says 7.',
    'A two-cell cage totals 9. One cell holds 2. Fill the other.',
    ['7', '5', '9'],
    0,
    '2 + 7 totals 9.',
  ),
  RuleLesson(
    'arrow',
    'Arrow',
    'Add the digits along the shaft to find the digit inside the circle.',
    '⑥ ← 2  4',
    '⑤ ← 2  4',
    '2 + 4 does not equal 5.',
    'The shaft holds 3 and 4. What goes in its circle?',
    ['1', '7', '8'],
    1,
    'The circle holds their sum, 7.',
  ),
  RuleLesson(
    'palindrome',
    'Palindrome',
    'Walk this line in either direction. You must read the same sequence.',
    '2  5  2',
    '2  5  3',
    'The two ends disagree.',
    'Complete the mirror: 7, 1, 1, __.',
    ['1', '6', '7'],
    2,
    'Both walks read 7, 1, 1, 7.',
  ),
  RuleLesson(
    'regionSum',
    'Region Sum Line',
    'Each stretch of line between region boundaries has the same sum.',
    '1 + 4 │ 5',
    '1 + 4 │ 6',
    'The two stretches total 5 and 6.',
    'One stretch is 2 + 4. Which lone digit fits the next region?',
    ['5', '6', '7'],
    1,
    'Both stretches add to 6.',
  ),
  RuleLesson(
    'sandwich',
    'Sandwich',
    'The outside clue counts only the digits between the 1 and the 9.',
    '₅[1 2 3 9]',
    '₆[1 2 3 9]',
    'The filling adds to 5.',
    'For 1, 2, 6, 9, what is the sandwich clue?',
    ['8', '9', '7'],
    0,
    'Between the crusts, 2 + 6 gives 8.',
  ),
  RuleLesson(
    'xSums',
    'X-Sums',
    'Read from the clue. The first digit tells how many cells to add, including itself.',
    '₉[3  1  5]',
    '₆[3  1  5]',
    'Three cells add to 9.',
    'From the edge you see 2, 4, 7. What clue belongs there?',
    ['13', '4', '6'],
    2,
    'The leading 2 selects the first two cells, so 2 + 4 = 6.',
  ),
  RuleLesson(
    'diagonal',
    'Diagonal',
    'Each marked diagonal holds each digit from 1 to 9 once.',
    '1↘2↘3↘4↘5↘6↘7↘8↘9',
    '1↘2↘3↘4↘4↘6↘7↘8↘9',
    'The second 4 repeats on this diagonal.',
    'The diagonal holds 1 through 8. Which digit finishes it?',
    ['4', '9', '8'],
    1,
    '9 is the only missing digit.',
  ),
  RuleLesson(
    'antiKnight',
    'Anti-Knight',
    'Hop two squares across and one up or down, or turn that shape. The two ends must differ.',
    '4  ♞→  7',
    '4  ♞→  4',
    'A knight hop cannot land on the same digit.',
    'You hop from a 5. Which landing digit is forbidden?',
    ['5', '2', '4'],
    0,
    'A second 5 would match the start of the hop.',
  ),
  RuleLesson(
    'halo',
    'Halo fog',
    'A correct torch placement lights its authored patch around the cell.',
    'Correct → lit patch',
    'Wrong → dark patch',
    'A wrong entry earns no new light.',
    'What happens when the torch digit is correct?',
    ['Reveal the board', 'Light its patch'],
    1,
    'Only this trigger’s patch lights.',
  ),
  RuleLesson(
    'trail',
    'Trail fog',
    'Follow the torch trail. A correct trigger lights the next authored patch along it.',
    'Trigger → next patch',
    'Guess → no light',
    'Guessing does not extend the trail.',
    'Which patch lights after the trigger?',
    ['Next trail patch', 'Every neighbor'],
    0,
    'The setter chose this next patch.',
  ),
  RuleLesson(
    'linked',
    'Linked torches',
    'Some patches wait for a pair of correct placements. Both posts must be ready.',
    '✓ + ✓ → light',
    '✓ + ? → dark',
    'One lit post leaves its partner waiting.',
    'The first post is ready. What earns the shared patch?',
    ['Move the flame', 'Fill its partner'],
    1,
    'With both triggers correct, the linked patch lights.',
  ),
  RuleLesson(
    'gravity',
    'Gravity',
    'Loose pieces fall toward the low edge. A placed clue stays anchored.',
    '↓ loose tile falls',
    '↓ given stays put',
    'Tilting cannot dislodge a given.',
    'You press the left arrow. Which pieces travel left?',
    ['Givens', 'Loose pieces', 'Every digit'],
    1,
    'Only loose pieces follow gravity.',
  ),
];

class RuleWorkbook extends StatefulWidget {
  const RuleWorkbook({
    super.key,
    required this.lessons,
    required this.onPractice,
    required this.onPlay,
    this.onRead,
    this.teacher,
    this.onSpotlight,
    this.reducedMotion = false,
  });
  final List<RuleLesson> lessons;
  final ValueChanged<String> onPractice;
  final ValueChanged<String>? onRead;
  final VoidCallback onPlay;
  final ValueChanged<String>? onSpotlight;
  final Creature? teacher;
  final bool reducedMotion;
  @override
  State<RuleWorkbook> createState() => _RuleWorkbookState();
}

class _RuleWorkbookState extends State<RuleWorkbook> {
  int _page = 0;
  bool _trying = false;
  int? _answer;
  void _select(int index) => setState(() {
    _page = index;
    widget.onRead?.call(widget.lessons[index].id);
    _trying = false;
    _answer = null;
  });
  @override
  Widget build(BuildContext context) {
    final lesson = widget.lessons[_page];
    final worm = lesson.id == 'renban';
    final teacher = widget.teacher;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.lessons.length > 1)
          Wrap(
            spacing: 6,
            children: [
              for (var i = 0; i < widget.lessons.length; i++)
                ChoiceChip(
                  label: Text(widget.lessons[i].title),
                  selected: i == _page,
                  onSelected: (_) => _select(i),
                ),
            ],
          ),
        Row(
          children: [
            if (worm)
              const _LessonWorm()
            else if (teacher != null)
              CreatureSprite(
                creature: teacher,
                size: 48,
                pose: CreaturePose.carry,
                cargo: ['halo', 'trail', 'linked'].contains(lesson.id)
                    ? '✦'
                    : null,
                reducedMotion: widget.reducedMotion,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worm ? 'Renban worm' : teacher?.name ?? 'Field guide',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  if (!worm)
                    Text(
                      lesson.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(lesson.line),
        ),
        if (lesson.id == 'renban' ||
            ['halo', 'trail', 'linked'].contains(lesson.id))
          _PracticePatch(
            lesson: lesson,
            attempt: _trying && _answer != null
                ? lesson.answers[_answer!]
                : null,
            correct: _answer == lesson.correct,
            practicing: _trying,
            still: widget.reducedMotion,
          ),
        _ExampleStrip(valid: true, text: lesson.valid),
        _ExampleStrip(valid: false, text: lesson.invalid),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(lesson.reason),
        ),
        if (_trying) ...[
          const Divider(),
          Text(lesson.prompt, style: Theme.of(context).textTheme.titleMedium),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < lesson.answers.length; i++)
                ChoiceChip(
                  label: Text(lesson.answers[i]),
                  selected: i == _answer,
                  onSelected: (_) {
                    setState(() => _answer = i);
                    if (i == lesson.correct) widget.onPractice(lesson.id);
                  },
                ),
            ],
          ),
          if (_answer != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _answer == lesson.correct
                    ? lesson.success
                    : 'Try again. ${lesson.line}',
              ),
            ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (!_trying)
              OutlinedButton(
                onPressed: () => setState(() => _trying = true),
                child: const Text('Try an example'),
              ),
            if (widget.onSpotlight != null &&
                RuleKind.values.any((r) => r.name == lesson.id))
              TextButton(
                onPressed: () => widget.onSpotlight!(lesson.id),
                child: const Text('Show on board'),
              ),
            FilledButton(onPressed: widget.onPlay, child: const Text('Play')),
          ],
        ),
      ],
    );
  }
}

class _PracticePatch extends StatelessWidget {
  const _PracticePatch({
    required this.lesson,
    required this.attempt,
    required this.correct,
    required this.practicing,
    required this.still,
  });
  final RuleLesson lesson;
  final String? attempt;
  final bool correct, practicing, still;
  @override
  Widget build(BuildContext context) {
    final worm = lesson.id == 'renban';
    final shown = worm
        ? (practicing ? ['2', '5', '3', attempt ?? '?'] : ['6', '4', '7', '5'])
        : lesson.id == 'linked'
        ? ['✦', correct ? '✦' : '?', correct ? '✦' : '']
        : ['✦', correct ? '✦' : '?', correct ? '✦' : ''];
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        label: worm
            ? 'Worked Renban line: ${shown.join(', ')}'
            : correct
            ? 'The authorized example patch is lit.'
            : 'The next patch is still covered.',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Wrap(
              children: [
                for (var i = 0; i < shown.length; i++)
                  AnimatedContainer(
                    duration: still
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: worm
                          ? Hum.board
                          : i == 0 || correct
                          ? Hum.torch
                          : const Color(0xffafafaf),
                      border: Border.all(color: Hum.grid, width: .7),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (worm) Container(height: 8, color: Hum.coral),
                        Text(
                          shown[i],
                          style: const TextStyle(
                            fontFamily: Hum.digitFont,
                            color: Hum.ink,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExampleStrip extends StatelessWidget {
  const _ExampleStrip({required this.valid, required this.text});
  final bool valid;
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${valid ? 'Works' : 'Counterexample'}: $text',
    child: ExcludeSemantics(
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: valid ? Hum.cyan : Hum.coral,
          border: Border(
            left: BorderSide(width: 3, color: valid ? Hum.focus : Hum.error),
          ),
        ),
        child: Row(
          children: [
            Icon(valid ? Icons.check : Icons.close, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontFamily: Hum.digitFont, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LessonWorm extends StatelessWidget {
  const _LessonWorm();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 54,
    height: 48,
    child: CustomPaint(painter: _WormPortrait()),
  );
}

class _WormPortrait extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 7; i++) {
      final x = 3 + i * 6.0;
      final y = [21, 24, 24, 21, 17, 15, 14][i].toDouble();
      canvas.drawRect(Rect.fromLTWH(x, y, 9, 10), paint..color = Hum.error);
      canvas.drawRect(
        Rect.fromLTWH(x + 1, y + 1, 7, 6),
        paint..color = Hum.coral,
      );
      if (i == 6)
        canvas.drawRect(
          Rect.fromLTWH(x + 5, y + 2, 2, 2),
          paint..color = Hum.ink,
        );
    }
  }

  @override
  bool shouldRepaint(_WormPortrait oldDelegate) => false;
}
