import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodukromental/boards.dart';

void main() {
  test('stored boards validate and read the previous unversioned shape', () {
    final board = boardsById['night-market']!;
    final encoded =
        jsonDecode(jsonEncode(board.toJson())) as Map<String, dynamic>;
    expect(encoded['version'], 1);
    expect(BoardSpec.fromJson(encoded).toJson(), board.toJson());
    encoded.remove('version');
    expect(BoardSpec.fromJson(encoded).toJson(), board.toJson());
    expect(
      () => BoardSpec.fromJson({...encoded, 'version': 99}),
      throwsFormatException,
    );
    expect(
      () => BoardSpec.fromJson({
        ...encoded,
        'rules': [
          {
            'kind': 'renban',
            'cells': [0, 1, 99],
          },
        ],
      }),
      throwsArgumentError,
    );
    expect(
      () => BoardSpec.fromJson({
        ...encoded,
        'starterPatch': [0, 1, 99],
      }),
      throwsArgumentError,
    );
  });

  test('the 28 authored assets are unique puzzles with connected regions', () {
    expect(campaignBoards, hasLength(28));
    expect(campaignBoards.map((board) => board.id).toSet(), hasLength(28));
    for (final board in campaignBoards) {
      for (var region = 0; region < board.size; region++) {
        final members = board.indices
            .where((index) => board.regions[index] == region)
            .toSet();
        expect(members, hasLength(board.size), reason: board.id);
        final reached = {members.first};
        final pending = [members.first];
        while (pending.isNotEmpty) {
          for (final neighbor in board.adjacent(pending.removeLast())) {
            if (members.contains(neighbor) && reached.add(neighbor)) {
              pending.add(neighbor);
            }
          }
        }
        expect(reached, members, reason: '${board.id} region $region');
      }
      expect(board.accepts(board.solution), isTrue, reason: board.id);
      expect(board.countSolutions(), 1, reason: board.id);
      if (board.id.startsWith('growth-')) {
        expect(board.givens, isNot(contains(board.size)), reason: board.id);
      }
    }
  });

  test('both rules in each finale are necessary for a unique solution', () {
    final finales = campaignBoards.where((board) => board.finale);
    expect(finales, hasLength(3));
    for (final board in finales) {
      final kinds = board.rules.map((rule) => rule.kind).toSet();
      expect(kinds, hasLength(2), reason: board.id);
      for (final removed in kinds) {
        final constraints = board.rules.where((rule) => rule.kind != removed);
        expect(
          board.countSolutions(constraints: constraints.toList()),
          2,
          reason: '${board.id} without ${removed.label}',
        );
      }
    }
  });

  test('every fog asset can be solved from visible clues and its triggers', () {
    final fogBoards = campaignBoards.where(
      (board) => board.fog != FogKind.none,
    );
    expect(fogBoards, hasLength(4));
    for (final board in fogBoards) {
      final visible = board.starterPatch.toSet();
      final entries = [
        for (final index in board.indices)
          visible.contains(index) ? board.givens[index] : 0,
      ];
      final fired = <String>{};

      while (entries.contains(0)) {
        MapEntry<int, int>? placement;
        final activeRules = board.visibleRules(visible);
        for (final cell in visible.where((index) => entries[index] == 0)) {
          final candidates = board.candidates(
            entries,
            cell,
            constraints: activeRules,
          );
          expect(candidates, isNotEmpty, reason: '${board.id} cell $cell');
          if (candidates.length == 1) {
            placement = MapEntry(cell, candidates.single);
            break;
          }
        }
        expect(placement, isNotNull, reason: '${board.id} stalled in fog');
        entries[placement!.key] = placement.value;
        for (final reveal in board.reveals) {
          final ready = reveal.requires.every(
            (index) => entries[index] == board.solution[index],
          );
          if (ready && fired.add(reveal.id)) {
            for (final index in reveal.patch.where(visible.add)) {
              entries[index] = board.givens[index];
            }
          }
        }
      }

      expect(fired, hasLength(board.reveals.length), reason: board.id);
      expect(visible, hasLength(board.size * board.size), reason: board.id);
      expect(board.accepts(entries), isTrue, reason: board.id);
    }
  });
}
