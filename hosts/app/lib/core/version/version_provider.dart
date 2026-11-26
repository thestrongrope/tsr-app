import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;

import '../constants/app_constants.dart';
import '../network/api_client.dart';
import 'version_gate.dart';

/// Fetching the update policy and turning it into a status.
///
/// The decision itself lives in `version_gate.dart` as pure functions; this
/// file is only the wiring. See `docs/specs/force-update/design.md`.

/// The platform key the server publishes policies under.
///
/// Anything that is not Android or iOS gets no policy — desktop and web builds
/// are developer tools here, and walling them would be noise rather than
/// safety.
String? currentVersionPlatform() {
  if (kIsWeb) return null;
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  return null;
}

/// What one `/app-version` fetch yields: this platform's policy, and the
/// announcement if there is a readable one.
typedef VersionInfo = ({VersionPolicy policy, Announcement? announcement});

const _permissiveInfo = (policy: VersionPolicy.permissive, announcement: null);

/// Reads the policy for this platform, and the announcement.
///
/// Returns the permissive policy and no announcement for every failure — an
/// unreachable endpoint, a timeout, a body it cannot read, a platform the
/// server does not publish. The gate must never lock a user out because it
/// could not ask, and the alert must never appear because it could not read.
Future<VersionInfo> fetchVersionInfo({ApiClient? client}) async {
  final platform = currentVersionPlatform();
  if (platform == null) return _permissiveInfo;

  try {
    // dynamic, not Map: `response.data as T` throws a TypeError rather than a
    // DioException if the body is not the shape asked for, and here that would
    // bypass the catch below in every version of this code that forgets.
    final response = await (client ?? ApiClient()).get<dynamic>(
      AppConstants.appVersionEndpoint,
    );
    return (
      policy: policyFromJson(response, platform),
      announcement: announcementFromJson(response),
    );
  } catch (e) {
    debugPrint('Version policy unavailable, allowing: $e');
    return _permissiveInfo;
  }
}

/// This build's number, or null when it cannot be read.
Future<int?> currentBuildNumber() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber.trim());
  } catch (e) {
    debugPrint('Build number unavailable, allowing: $e');
    return null;
  }
}

/// The status, the policy behind it and the announcement.
typedef VersionCheck = ({
  VersionStatus status,
  VersionPolicy policy,
  Announcement? announcement,
});

/// The app's update status, decided once.
///
/// Status, policy and announcement come from the same fetch on purpose: two
/// providers each calling [fetchVersionInfo] would make two requests to answer
/// one question.
///
/// Callers treat "not yet resolved" and "failed" as [VersionStatus.ok] and no
/// alert — see the wiring in `main.dart`. Nothing waits on this and nothing is
/// blocked by it failing; a gate may only stop someone when it is certain.
final versionCheckProvider = FutureProvider<VersionCheck>((ref) async {
  final info = await fetchVersionInfo();
  final build = await currentBuildNumber();

  return (
    status: decideVersionStatus(build: build, policy: info.policy),
    policy: info.policy,
    announcement: info.announcement,
  );
});
