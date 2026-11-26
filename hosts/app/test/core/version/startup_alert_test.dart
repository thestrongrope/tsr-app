import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/version/startup_alert.dart';
import 'package:the_strong_rope/core/version/version_gate.dart';

/// Which startup alerts are due, and in what order (#519).
///
/// Pure: policy, status and what the member already dismissed go in, a list of
/// alerts comes out. Showing them is the host widget's job.
void main() {
  const latest = ReleaseNotes(
    version: '1.0.7',
    notes: ['Hour and minute buttons'],
  );
  const policy = VersionPolicy(
    minimumBuild: 1,
    recommendedBuild: 16,
    storeUrl: 'https://example.invalid/app',
    latest: latest,
  );
  const news = Announcement(
    id: 'a1',
    title: 'New initiative',
    body: 'Join us.',
  );

  List<StartupAlert> due({
    VersionStatus status = VersionStatus.updateRecommended,
    VersionPolicy p = policy,
    Announcement? announcement,
    int? dismissedBuild,
    String? dismissedId,
  }) => dueStartupAlerts(
    status: status,
    policy: p,
    announcement: announcement,
    dismissedReleaseBuild: dismissedBuild,
    dismissedAnnouncementId: dismissedId,
  );

  test('a newer build with notes is a release alert carrying its notes', () {
    final alerts = due();

    expect(alerts, hasLength(1));
    final alert = alerts.single as ReleaseAlert;
    expect(alert.build, 16);
    expect(alert.version, '1.0.7');
    expect(alert.notes, ['Hour and minute buttons']);
    expect(alert.storeUrl, 'https://example.invalid/app');
  });

  test('a dismissed release is not shown again for that build', () {
    expect(due(dismissedBuild: 16), isEmpty);
  });

  test('a newer recommended build alerts again after an older dismissal', () {
    expect(due(dismissedBuild: 15), hasLength(1));
  });

  test('an up-to-date build gets no release alert', () {
    expect(due(status: VersionStatus.ok), isEmpty);
  });

  test(
    'no release record for the recommended build means no release alert',
    () {
      const bare = VersionPolicy(
        minimumBuild: 1,
        recommendedBuild: 16,
        storeUrl: 'https://example.invalid/app',
      );

      expect(due(p: bare), isEmpty);
    },
  );

  test('a release with no notes still offers the update', () {
    const noNotes = VersionPolicy(
      minimumBuild: 1,
      recommendedBuild: 16,
      storeUrl: 'https://example.invalid/app',
      latest: ReleaseNotes(version: '1.0.7', notes: []),
    );

    final alert = due(p: noNotes).single as ReleaseAlert;

    expect(alert.notes, isEmpty);
  });

  test('an announcement is due until its id is dismissed', () {
    final alerts = due(status: VersionStatus.ok, announcement: news);

    expect((alerts.single as AnnouncementAlert).announcement.id, 'a1');
    expect(
      due(status: VersionStatus.ok, announcement: news, dismissedId: 'a1'),
      isEmpty,
    );
  });

  test('a different announcement id shows again', () {
    expect(
      due(status: VersionStatus.ok, announcement: news, dismissedId: 'older'),
      hasLength(1),
    );
  });

  test('both due: the release comes first, then the announcement', () {
    final alerts = due(announcement: news);

    expect(alerts[0], isA<ReleaseAlert>());
    expect(alerts[1], isA<AnnouncementAlert>());
  });

  test('a required update shows no alert at all', () {
    expect(
      due(status: VersionStatus.updateRequired, announcement: news),
      isEmpty,
    );
  });
}
