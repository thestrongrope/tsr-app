import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/version/release_notes.dart';

/// `GET /release-notes` -> `{releases: [{version, date, notes, builds}]}`.
///
/// Unlike the startup alert, which swallows every failure, this screen has to
/// tell "the server has no notes" from "we could not read the answer": the
/// first is an empty list, the second throws.
void main() {
  group('releasesFromJson', () {
    test('reads releases in the order the server sent them', () {
      final releases = releasesFromJson({
        'releases': [
          {
            'version': '1.1.0',
            'date': '2026-10-11',
            'notes': ['Manage a class from the app'],
            'builds': {'android': 16},
          },
          {'version': '1.0.6', 'date': '2026-09-20', 'notes': [], 'builds': {}},
        ],
      });

      expect(releases.map((r) => r.version), ['1.1.0', '1.0.6']);
      expect(releases.first.date, '2026-10-11');
      expect(releases.first.notes, ['Manage a class from the app']);
      expect(releases.last.notes, isEmpty);
    });

    test('an empty list is "no notes", not an error', () {
      expect(releasesFromJson({'releases': []}), isEmpty);
    });

    test('drops an entry without a version, and non-string notes', () {
      final releases = releasesFromJson({
        'releases': [
          {
            'date': '2026-10-11',
            'notes': ['no version'],
          },
          {
            'version': '1.1.0',
            'date': '2026-10-11',
            'notes': ['kept', 3, ''],
          },
        ],
      });

      expect(releases, hasLength(1));
      expect(releases.single.notes, ['kept']);
    });

    test('throws when the body is not what the server promises', () {
      expect(() => releasesFromJson(null), throwsFormatException);
      expect(() => releasesFromJson('<html>'), throwsFormatException);
      expect(() => releasesFromJson({'releases': 'x'}), throwsFormatException);
      expect(() => releasesFromJson({}), throwsFormatException);
    });
  });

  group('isInstalled', () {
    const release = Release(version: '1.1.0', date: '2026-10-11', notes: []);

    test('matches on the version name, ignoring the build number', () {
      expect(release.isInstalled('1.1.0'), isTrue);
      expect(release.isInstalled('1.0.6'), isFalse);
    });
  });
}
