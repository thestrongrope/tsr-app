/// Deciding whether this build is still allowed to run.
///
/// The server publishes a minimum build number per platform at
/// `GET /app-version`; anything below it is asked to update before going
/// further. See `docs/specs/force-update/design.md`.
///
/// Everything here is pure — integers in, an enum out, no IO and no Flutter.
/// That is deliberate: the interesting behaviour is what happens when the
/// answer is unavailable or malformed, and that is only testable if deciding
/// is separated from fetching.
library;

/// What the app should do about its own version.
enum VersionStatus {
  /// Carry on. Also the answer whenever the requirement cannot be determined.
  ok,

  /// A newer build is available. The startup alert offers it, dismissibly.
  updateRecommended,

  /// Below the minimum. The app should stop here and send the user to the
  /// store.
  updateRequired,
}

/// The notes of one release, for the startup alert.
class ReleaseNotes {
  final String version;

  /// Short strings, shown as a list. Empty is allowed: the update is still
  /// offered, without a notes section.
  final List<String> notes;

  const ReleaseNotes({required this.version, required this.notes});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReleaseNotes &&
          other.version == version &&
          _sameNotes(other.notes, notes);

  @override
  int get hashCode => Object.hash(version, Object.hashAll(notes));

  static bool _sameNotes(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A message the team wants members to see once, such as a new initiative.
/// A new [id] is what makes it show again.
class Announcement {
  final String id;
  final String title;
  final String body;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
  });
}

/// One platform's build requirements, as published by the server.
class VersionPolicy {
  /// Builds below this are refused.
  final int minimumBuild;

  /// The newest build the server knows about.
  final int recommendedBuild;

  /// Where to send someone who needs to update.
  final String storeUrl;

  /// What changed in [recommendedBuild], when the server has notes for it.
  /// Null is normal: it only means the startup alert has nothing to say.
  final ReleaseNotes? latest;

  const VersionPolicy({
    required this.minimumBuild,
    required this.recommendedBuild,
    required this.storeUrl,
    this.latest,
  });

  /// The policy that permits everything.
  ///
  /// Build 1 is below every build that has ever shipped, so this blocks
  /// nobody. It is what every failure resolves to — see [policyFromJson] and
  /// the note on failing open in [decideVersionStatus].
  static const VersionPolicy permissive = VersionPolicy(
    minimumBuild: 1,
    recommendedBuild: 1,
    storeUrl: '',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VersionPolicy &&
          other.minimumBuild == minimumBuild &&
          other.recommendedBuild == recommendedBuild &&
          other.storeUrl == storeUrl &&
          other.latest == latest;

  @override
  int get hashCode =>
      Object.hash(minimumBuild, recommendedBuild, storeUrl, latest);

  @override
  String toString() =>
      'VersionPolicy(min: $minimumBuild, recommended: $recommendedBuild)';
}

/// Whether [build] may still run under [policy].
///
/// Comparison is on the integer build number, never the version name: as
/// strings, '1.0.10' sorts below '1.0.9', and every hand-rolled version
/// comparison meets that eventually.
///
/// A build number that could not be read is [VersionStatus.ok]. This is the
/// fail-open rule, and it is the point rather than a convenience: a gate that
/// refused when it could not tell would turn any outage — a request that timed
/// out, a file lost on the server, a version string the app could not parse —
/// into every client locking simultaneously. Version fragmentation degrades
/// slowly and the user can escape it; a global lockout is immediate and needs a
/// server fix before anyone can open the app at all.
VersionStatus decideVersionStatus({
  required int? build,
  required VersionPolicy policy,
}) {
  if (build == null) return VersionStatus.ok;

  if (build < policy.minimumBuild) return VersionStatus.updateRequired;
  if (build < policy.recommendedBuild) return VersionStatus.updateRecommended;
  return VersionStatus.ok;
}

/// The integer build from a Flutter version string such as `1.0.1+9`.
///
/// Returns null when there is no `+build` part, or it is not a number — which
/// [decideVersionStatus] treats as [VersionStatus.ok].
int? buildNumberFrom(String version) {
  final plus = version.lastIndexOf('+');
  if (plus < 0 || plus == version.length - 1) return null;
  return int.tryParse(version.substring(plus + 1).trim());
}

/// Reads one platform's policy out of a `/app-version` body.
///
/// Every way of failing — a body that is not a map, a missing or non-map
/// platform key, a `minimumBuild` that is absent or not an integer — yields
/// [VersionPolicy.permissive] rather than throwing. The endpoint is
/// deliberately lenient for the same reason, so this is belt and braces: the
/// client must not lock itself out over a response it could not read.
VersionPolicy policyFromJson(dynamic body, String platform) {
  if (body is! Map) return VersionPolicy.permissive;

  final entry = body[platform];
  if (entry is! Map) return VersionPolicy.permissive;

  final minimum = entry['minimumBuild'];
  if (minimum is! int) return VersionPolicy.permissive;

  final recommended = entry['recommendedBuild'];
  final storeUrl = entry['storeUrl'];

  return VersionPolicy(
    minimumBuild: minimum,
    recommendedBuild: recommended is int ? recommended : minimum,
    storeUrl: storeUrl is String ? storeUrl : '',
    latest: _releaseNotesFrom(entry['latest']),
  );
}

/// This platform's `latest` entry, or null for every way of being unreadable.
/// Only the notes part is lost: the policy around it is never affected.
ReleaseNotes? _releaseNotesFrom(dynamic latest) {
  if (latest is! Map) return null;

  final version = latest['version'];
  if (version is! String || version.isEmpty) return null;

  final notes = latest['notes'];
  return ReleaseNotes(
    version: version,
    notes: notes is List
        ? [
            for (final note in notes)
              if (note is String && note.isNotEmpty) note,
          ]
        : const [],
  );
}

/// The active announcement in a `/app-version` body, or null when there is none
/// or it cannot be read. Never throws: a bad announcement must not cost anyone
/// their update prompt, let alone their app.
Announcement? announcementFromJson(dynamic body) {
  if (body is! Map) return null;

  final entry = body['announcement'];
  if (entry is! Map) return null;

  final id = entry['id'];
  final title = entry['title'];
  if (id is! String || id.isEmpty || title is! String || title.isEmpty) {
    return null;
  }

  final text = entry['body'];
  return Announcement(id: id, title: title, body: text is String ? text : '');
}
