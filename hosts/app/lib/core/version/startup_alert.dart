/// Which alerts a member is owed at startup, and what they have already
/// dismissed (#519).
///
/// The decision is pure — status, policy and the dismissals go in, an ordered
/// list comes out — for the same reason the update gate is: the interesting
/// behaviour is what happens when information is missing, and that is only
/// testable if deciding is separate from fetching and showing.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import '../constants/app_constants.dart';
import 'version_gate.dart';

/// One thing to show the member, once.
sealed class StartupAlert {
  const StartupAlert();
}

/// A newer build is available, with what changed in it.
class ReleaseAlert extends StartupAlert {
  /// The recommended build this alert is about. Dismissing records it, so the
  /// next recommended build alerts again.
  final int build;
  final String version;
  final List<String> notes;
  final String storeUrl;

  const ReleaseAlert({
    required this.build,
    required this.version,
    required this.notes,
    required this.storeUrl,
  });
}

/// A message from the team, such as a new initiative.
class AnnouncementAlert extends StartupAlert {
  final Announcement announcement;

  const AnnouncementAlert(this.announcement);
}

/// The alerts due now, in the order to show them: the release, then the
/// announcement.
///
/// A required update returns nothing: the blocking screen owns that case and an
/// alert must never appear under it. A release is only offered when the server
/// has a record for the recommended build, because the alert's job is to say
/// what changed.
List<StartupAlert> dueStartupAlerts({
  required VersionStatus status,
  required VersionPolicy policy,
  required Announcement? announcement,
  required int? dismissedReleaseBuild,
  required String? dismissedAnnouncementId,
}) {
  if (status == VersionStatus.updateRequired) return const [];

  final latest = policy.latest;
  return [
    if (status == VersionStatus.updateRecommended &&
        latest != null &&
        policy.recommendedBuild > (dismissedReleaseBuild ?? 0))
      ReleaseAlert(
        build: policy.recommendedBuild,
        version: latest.version,
        notes: latest.notes,
        storeUrl: policy.storeUrl,
      ),
    if (announcement != null && announcement.id != dismissedAnnouncementId)
      AnnouncementAlert(announcement),
  ];
}

/// What the member has dismissed, kept on the device.
///
/// On the device rather than the server because the alert is public and
/// pre-login: there may be no account to remember against.
class StartupAlertStore {
  static const _releaseKey = 'dismissedReleaseBuild';
  static const _announcementKey = 'dismissedAnnouncementId';

  Box get _box => Hive.box(AppConstants.settingsBoxKey);

  int? get dismissedReleaseBuild {
    final value = _box.get(_releaseKey);
    return value is int ? value : null;
  }

  String? get dismissedAnnouncementId {
    final value = _box.get(_announcementKey);
    return value is String ? value : null;
  }

  Future<void> dismissRelease(int build) => _box.put(_releaseKey, build);

  Future<void> dismissAnnouncement(String id) => _box.put(_announcementKey, id);
}

final startupAlertStoreProvider = Provider<StartupAlertStore>(
  (ref) => StartupAlertStore(),
);
