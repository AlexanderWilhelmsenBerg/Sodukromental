import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/board_moment.dart';
import 'package:sodukromental/creature_view.dart';
import 'package:sodukromental/creatures.dart';

void main() {
  testWidgets('torch route uses the named owned worker in reduced motion', (
    tester,
  ) async {
    final worker = Creature.amoeba(7);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 320,
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: TorchRouteMoment(
              dimension: 5,
              cells: const [0, 1, 6],
              worker: worker,
              reducedMotion: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CreatureSprite), findsOneWidget);
    final sprite = tester.widget<CreatureSprite>(find.byType(CreatureSprite));
    expect(sprite.creature.id, worker.id);
    expect(sprite.pose, CreaturePose.torch);
    expect(sprite.reducedMotion, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shatter overlay never invents more workers', (tester) async {
    final workers = List.generate(6, Creature.amoeba);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 320,
          child: GridShatterMoment(
            dimension: 9,
            openedSeams: 5,
            totalSeams: 12,
            workers: workers,
            reducedMotion: true,
          ),
        ),
      ),
    );

    expect(find.byType(CreatureSprite), findsNWidgets(4));
    final sprites = tester
        .widgetList<CreatureSprite>(find.byType(CreatureSprite))
        .toList();
    expect(
      sprites.map((sprite) => sprite.creature.id),
      workers.take(4).map((worker) => worker.id),
    );
    expect(sprites.every((sprite) => sprite.pose == CreaturePose.work), isTrue);
    expect(tester.takeException(), isNull);
  });
}
