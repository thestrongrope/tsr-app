import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Which push `action_link` paths the app will follow (#428).
///
/// A push may carry a path that is pushed onto the router. Left open, a link
/// such as `/login?error=<text>` or any screen that was never meant to be a
/// push target could be reached from a notification. The server refuses these
/// when a push is sent (`api_action_link_allowed`, web/api/mobile/lib/response.php);
/// this is the same list on the device, so an old, forged or replayed push
/// cannot do what the server would have refused.
///
/// Content screens only, no query string, no `.`: `/classes/../login` and
/// `//host` do not match.
final _allowedActionLink = RegExp(
  r'^/(classes|quizzes|home|articles|videos|notifications)(/[A-Za-z0-9_-]+)*$',
);

bool isAllowedActionLink(String link) => _allowedActionLink.hasMatch(link);

/// Whether a notification's [location] opens over the tabs rather than in one.
///
/// Taking a quiz sits outside the tabs, so it is pushed on top. Everything else
/// lives in a tab and is opened with `go`, which shows its tab (#561); a push
/// would open it under whichever tab happened to be selected.
bool opensOverTabs(String location) => location.startsWith('/quizzes/');

final _videoLink = RegExp(r'^/videos/([A-Za-z0-9_-]+)$');

/// The YouTube watch page for a `/videos/<id>` link, or null for any other
/// link (`/videos`, the list, is a screen in the app) (#867).
Uri? videoWatchUri(String location) {
  final id = _videoLink.firstMatch(location)?.group(1);
  if (id == null) return null;
  return Uri.https('www.youtube.com', '/watch', {'v': id});
}

Future<bool> launchVideo(Uri uri) async {
  try {
    // Hand the video to YouTube; fall back to the platform default.
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
    return await launchUrl(uri);
  } catch (e) {
    debugPrint('Error launching video: $e');
    return false;
  }
}

/// Opens an allowlisted [location] from a notification: in its tab, or over
/// the tabs for a quiz ([opensOverTabs]). A `/videos/<id>` link plays the
/// video in YouTube instead ([videoWatchUri]). Used by a tapped push and by
/// the notification inbox, so both go to the same place.
///
/// Returns false only when a video could not be launched, so the caller can
/// say so. [launch] is a seam for tests.
Future<bool> openActionLink(
  BuildContext context,
  String location, {
  Future<bool> Function(Uri uri) launch = launchVideo,
}) async {
  final video = videoWatchUri(location);
  if (video != null) return launch(video);
  if (opensOverTabs(location)) {
    context.push(location);
  } else {
    context.go(location);
  }
  return true;
}
