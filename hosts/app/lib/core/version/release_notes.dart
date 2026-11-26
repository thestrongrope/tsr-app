import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/app_constants.dart';
import '../network/api_client.dart';

/// The release history shown from the version row in the Me tab.
///
/// The server owns the wording (`web/data/app_versions.json`, served by the
/// public `GET /release-notes`). Unlike the startup alert, which swallows every
/// failure, this screen must tell "no notes yet" (an empty list) from "could
/// not read the answer" (an exception), so [releasesFromJson] throws.

/// One release: its version name, date (YYYY-MM-DD) and what it changed.
class Release {
  const Release({
    required this.version,
    required this.date,
    required this.notes,
  });

  final String version;
  final String date;
  final List<String> notes;

  /// Whether this is the release the member has installed. Matched on the
  /// version name: build numbers differ per platform and are not shown.
  bool isInstalled(String installedVersion) => version == installedVersion;
}

/// Releases from a `/release-notes` body, newest first as the server sent them.
///
/// Throws [FormatException] when the body is not `{releases: [...]}`. An entry
/// without a version is dropped, and only non-empty string notes are kept, as
/// the server does.
List<Release> releasesFromJson(dynamic body) {
  if (body is! Map || body['releases'] is! List) {
    throw const FormatException('release notes: unexpected response');
  }

  return [
    for (final entry in body['releases'] as List)
      if (entry is Map && entry['version'] is String && entry['version'] != '')
        Release(
          version: entry['version'] as String,
          date: entry['date'] is String ? entry['date'] as String : '',
          notes: [
            if (entry['notes'] is List)
              for (final note in entry['notes'] as List)
                if (note is String && note.isNotEmpty) note,
          ],
        ),
  ];
}

/// The release history. Errors are left for the screen to show.
///
/// No automatic retry: Riverpod's default keeps the screen loading through
/// ten backed-off attempts, so an offline member would see a spinner and not
/// the "try again" the screen offers.
final releaseNotesProvider = FutureProvider.autoDispose<List<Release>>((
  ref,
) async {
  final body = await ApiClient().get<dynamic>(
    AppConstants.releaseNotesEndpoint,
  );
  return releasesFromJson(body);
}, retry: (retryCount, error) => null);

/// The installed version and build number, e.g. `1.1.0` and `16`.
typedef InstalledVersion = ({String version, String build});

final installedVersionProvider = FutureProvider<InstalledVersion>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return (version: info.version, build: info.buildNumber);
});
