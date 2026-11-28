import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/version/version_gate.dart';

/// The force-update decision.
///
/// Most of these tests are about failing open, and that is the right balance:
/// the happy path is one comparison, while the ways of not knowing the answer
/// are many. A gate that refused when it could not tell would convert any
/// outage into every client locking at once — worse than the fragmentation it
/// exists to prevent, because a lockout needs a server fix before anyone can
/// open the app.
///
/// See docs/specs/force-update/design.md.
void main() {
  const policy = VersionPolicy(
    minimumBuild: 5,
    recommendedBuild: 9,
    storeUrl: 'https://example.invalid/app',
  );

  group('decideVersionStatus', () {
    test('a build below the minimum must update', () {
      expect(
        decideVersionStatus(build: 4, policy: policy),
        VersionStatus.updateRequired,
      );
    });

    test('a build exactly at the minimum is allowed', () {
      // The boundary is the bug people write: `<=` here would refuse the very
      // build the server just declared acceptable.
      expect(
        decideVersionStatus(build: 5, policy: policy),
        VersionStatus.updateRecommended,
      );
    });

    test('a build between minimum and recommended is merely behind', () {
      expect(
        decideVersionStatus(build: 7, policy: policy),
        VersionStatus.updateRecommended,
      );
    });

    test('a build at the recommended version is ok', () {
      expect(decideVersionStatus(build: 9, policy: policy), VersionStatus.ok);
    });

    test('a build newer than the server knows about is ok, not suspicious', () {
      // A developer or a tester running ahead of the store must not be walled.
      expect(decideVersionStatus(build: 99, policy: policy), VersionStatus.ok);
    });

    test('an unknown build is ok', () {
      // The fail-open rule at its sharpest: if we cannot tell, we allow.
      expect(
        decideVersionStatus(build: null, policy: policy),
        VersionStatus.ok,
      );
    });

    test('the permissive policy never requires an update', () {
      for (final build in [1, 5, 9, 1000]) {
        expect(
          decideVersionStatus(build: build, policy: VersionPolicy.permissive),
          VersionStatus.ok,
          reason: 'build $build was refused by the permissive policy',
        );
      }
    });
  });

  group('buildNumberFrom', () {
    test('reads the build out of a Flutter version string', () {
      expect(buildNumberFrom('1.0.1+9'), 9);
      expect(buildNumberFrom('1.0.0+7'), 7);
      expect(buildNumberFrom('10.20.30+12345'), 12345);
    });

    test('a string comparison would get this pair backwards', () {
      // '1.0.10' sorts below '1.0.9' lexicographically. The integers do not,
      // which is the whole reason the contract is a build number.
      expect('1.0.10'.compareTo('1.0.9'), lessThan(0));
      expect(
        buildNumberFrom('1.0.10+10')!,
        greaterThan(buildNumberFrom('1.0.9+9')!),
      );
    });

    test('anything unparseable is null, and therefore ok', () {
      for (final version in [
        '1.0.1',
        '',
        '+',
        '1.0.1+',
        '1.0.1+abc',
        'nonsense',
      ]) {
        expect(buildNumberFrom(version), isNull, reason: version);
        expect(
          decideVersionStatus(build: buildNumberFrom(version), policy: policy),
          VersionStatus.ok,
          reason: 'version "$version" should not lock anyone out',
        );
      }
    });
  });

  group('policyFromJson', () {
    test('reads a well-formed platform entry', () {
      final parsed = policyFromJson(const {
        'android': {
          'minimumBuild': 5,
          'recommendedBuild': 9,
          'storeUrl': 'https://example.invalid/app',
        },
        'ios': {'minimumBuild': 2, 'recommendedBuild': 5, 'storeUrl': 'x'},
      }, 'android');

      expect(parsed.minimumBuild, 5);
      expect(parsed.recommendedBuild, 9);
      expect(parsed.storeUrl, 'https://example.invalid/app');
    });

    test('platforms are read independently', () {
      const body = {
        'android': {'minimumBuild': 5},
        'ios': {'minimumBuild': 2},
      };

      expect(policyFromJson(body, 'android').minimumBuild, 5);
      expect(policyFromJson(body, 'ios').minimumBuild, 2);
    });

    test('a missing recommendedBuild falls back to the minimum', () {
      final parsed = policyFromJson(const {
        'android': {'minimumBuild': 6},
      }, 'android');

      expect(parsed.recommendedBuild, 6);
    });

    test('every malformed body yields the permissive policy', () {
      // Named so a failure says which shape broke it.
      final malformed = <String, dynamic>{
        'null': null,
        'a string': 'nope',
        'a number': 42,
        'a list': <dynamic>[],
        'empty map': <String, dynamic>{},
        'platform missing': {
          'ios': {'minimumBuild': 3},
        },
        'platform is a list': {'android': <dynamic>[]},
        'platform is a string': {'android': 'nope'},
        'minimumBuild missing': {'android': <String, dynamic>{}},
        'minimumBuild a string': {
          'android': {'minimumBuild': '5'},
        },
        'minimumBuild null': {
          'android': {'minimumBuild': null},
        },
        'minimumBuild a double': {
          'android': {'minimumBuild': 5.0},
        },
      };

      malformed.forEach((name, body) {
        expect(
          policyFromJson(body, 'android'),
          VersionPolicy.permissive,
          reason: '$name should have yielded the permissive policy',
        );
      });
    });

    test('a malformed body cannot lock anyone out end to end', () {
      // The property that matters, asserted through both steps rather than
      // trusting that a permissive policy is used correctly downstream.
      final status = decideVersionStatus(
        build: buildNumberFrom('1.0.1+9'),
        policy: policyFromJson('garbage', 'android'),
      );

      expect(status, VersionStatus.ok);
    });
  });
}

/// What the startup alert reads from the same `/app-version` body (#519).
///
/// Everything here fails to *nothing*: a body the client cannot read must never
/// produce an alert, an error or a lockout.
void startupAlertParsingTests() {
  group('latest release notes', () {
    Map<String, dynamic> body(dynamic latest) => {
      'android': {
        'minimumBuild': 1,
        'recommendedBuild': 16,
        'storeUrl': 'https://example.invalid/app',
        'latest': ?latest,
      },
    };

    test('are read when well formed', () {
      final policy = policyFromJson(
        body({
          'version': '1.0.7',
          'notes': ['One', 'Two'],
        }),
        'android',
      );

      expect(policy.latest?.version, '1.0.7');
      expect(policy.latest?.notes, ['One', 'Two']);
    });

    test('are absent when the server sends none', () {
      expect(policyFromJson(body(null), 'android').latest, isNull);
    });

    test('are ignored when wrongly typed, without touching the policy', () {
      for (final bad in [
        'text',
        42,
        <dynamic>[],
        {'version': 7, 'notes': []},
        {'version': '', 'notes': []},
      ]) {
        final policy = policyFromJson(body(bad), 'android');

        expect(policy.latest, isNull, reason: '$bad');
        expect(policy.recommendedBuild, 16, reason: 'the policy is unaffected');
      }
    });

    test('keep only non-empty string notes; missing notes mean none', () {
      expect(
        policyFromJson(
          body({
            'version': '1.0.7',
            'notes': ['ok', 3, '', null],
          }),
          'android',
        ).latest?.notes,
        ['ok'],
      );
      expect(
        policyFromJson(body({'version': '1.0.7'}), 'android').latest?.notes,
        isEmpty,
      );
    });
  });

  group('announcement', () {
    test('is read when well formed', () {
      final a = announcementFromJson({
        'announcement': {'id': 'a1', 'title': 'T', 'body': 'B'},
      });

      expect(a?.id, 'a1');
      expect(a?.title, 'T');
      expect(a?.body, 'B');
    });

    test('is null for every way of being unreadable', () {
      for (final bad in <dynamic>[
        null,
        'x',
        {'announcement': null},
        {'announcement': 'text'},
        {
          'announcement': {'title': 'T'},
        },
        {
          'announcement': {'id': '', 'title': 'T'},
        },
        {
          'announcement': {'id': 5, 'title': 'T'},
        },
        {
          'announcement': {'id': 'a'},
        },
      ]) {
        expect(announcementFromJson(bad), isNull, reason: '$bad');
      }
    });

    test('a missing body reads as empty', () {
      expect(
        announcementFromJson({
          'announcement': {'id': 'a', 'title': 'T'},
        })?.body,
        '',
      );
    });
  });
}
