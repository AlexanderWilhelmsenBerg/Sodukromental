import 'dart:convert';
import 'dart:io';
import 'package:sodukromental/campaign.dart';
import 'package:sodukromental/library_models.dart';

/// Seed and verify two ordinary saved games on a disposable Android emulator.
void main(List<String> args) {
  if (args.length == 2 && args.first == 'verify') {
    final data = jsonDecode(File(args[1]).readAsStringSync());
    final run = Campaign.fromJson(data['campaign']);
    final library = LibrarySave.fromJson(data['library']);
    if (run.seed != 61312 ||
        run.dna != 2 ||
        run.usedTutorialTokens.length != 2 ||
        run.board.id != 'opening' ||
        run.cells[3] != 4 ||
        run.cells[5] != 4 ||
        library.progress != LibraryProgress.started ||
        library.history[library.index].notes[4]?.contains(5) != true) {
      throw StateError(
        'Saved campaign progress or library notes changed after installation.',
      );
    }
    stdout.writeln(
      'Restored the two claimed 4s, 2 DNA, the same seed and the 5×5 Library note.',
    );
    return;
  }
  final run = Campaign(seed: 61312);
  for (final (from, to) in [(5, 1), (9, 5), (10, 9), (5, 4)]) {
    if (!run.slide(from, to)) throw StateError('Opening slide failed');
  }
  if (!run.placeTutorialToken(3) || !run.placeTutorialToken(5)) {
    throw StateError('Opening token placement failed');
  }
  final board = boardsById['growth-5']!;
  final save = LibrarySave(
    [
      LibraryPosition(board.givens, {}),
      LibraryPosition(board.givens, {
        4: {5},
      }),
    ],
    1,
    DateTime.now().toUtc(),
    LibraryProgress.started,
  );
  stdout.write(
    jsonEncode({'campaign': run.toJson(), 'library': save.toJson()}),
  );
}
