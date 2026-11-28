import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/classes/models/models.dart';
import 'package:the_strong_rope/features/classes/providers/providers.dart';

/// The two getters `_SyllabusScreenState._buildBody` branches on.
///
/// The screen has exactly three branches — loading, error, and empty — and then
/// dereferences `state.syllabus!`. So these getters are not a convenience: any
/// state that `isEmpty` and `hasItems` both call false is a crash, because
/// nothing is left to catch it.
///
/// That is what happened. `isEmpty` read `syllabus != null && items.isEmpty`,
/// which is false when there is no syllabus at all, so a state of no syllabus /
/// no error / not loading fell through to `syllabus!.items.length` at
/// syllabus_screen.dart:133. Crashlytics recorded 16 events across 13 users on
/// 1.0.0 (7), with crash-free users at 66.67%.
SyllabusLevel _level({required int itemCount}) {
  return SyllabusLevel(
    levelId: 3,
    levelName: 'MIQDAD',
    levelCode: 'MK',
    items: List.generate(
      itemCount,
      (i) => SyllabusItem(
        id: i + 1,
        levelId: 3,
        subjectName: 'Ahkam',
        linkType: SyllabusLinkType.pdf,
        url: 'https://example.invalid/$i.pdf',
      ),
    ),
  );
}

void main() {
  group('SyllabusState.isEmpty', () {
    test('a state with no syllabus loaded is empty', () {
      // The regression. Before the fix this returned false, and the screen
      // dereferenced null on the very next line.
      const state = SyllabusState();

      expect(state.syllabus, isNull);
      expect(state.isEmpty, isTrue);
    });

    test('a syllabus with no items is empty', () {
      final state = SyllabusState(syllabus: _level(itemCount: 0));
      expect(state.isEmpty, isTrue);
    });

    test('a syllabus with items is not empty', () {
      final state = SyllabusState(syllabus: _level(itemCount: 2));
      expect(state.isEmpty, isFalse);
    });
  });

  group('SyllabusState.hasItems', () {
    test('only a loaded syllabus with items has items', () {
      expect(const SyllabusState().hasItems, isFalse);
      expect(SyllabusState(syllabus: _level(itemCount: 0)).hasItems, isFalse);
      expect(SyllabusState(syllabus: _level(itemCount: 2)).hasItems, isTrue);
    });
  });

  test('isEmpty and hasItems are exact complements', () {
    // The property that makes the crash impossible rather than merely fixed.
    // The screen renders the list whenever neither guard fires, so if these two
    // can ever both be false, a null dereference is reachable again.
    final states = <SyllabusState>[
      const SyllabusState(),
      const SyllabusState(isLoading: true),
      const SyllabusState(error: 'network down'),
      SyllabusState(syllabus: _level(itemCount: 0)),
      SyllabusState(syllabus: _level(itemCount: 1)),
      SyllabusState(syllabus: _level(itemCount: 9)),
    ];

    for (final state in states) {
      expect(
        state.isEmpty,
        isNot(state.hasItems),
        reason:
            'isEmpty and hasItems disagree for syllabus='
            '${state.syllabus?.items.length}, which leaves the screen with no '
            'branch and a null dereference',
      );
    }
  });
}
