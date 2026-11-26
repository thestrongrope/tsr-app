import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/route_config.dart';
import '../../../core/services/action_link.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../classes/providers/classes_provider.dart';
import '../../grand_quiz/providers/grand_quiz_provider.dart';
import '../../wordpress/providers/tsr_providers.dart';
import '../models/user_notification.dart';

/// Whether the class or quiz a notification was about can be opened (#800).
enum NotificationTarget { open, gone, noAccess }

final _classLink = RegExp(r'^/classes/(\d+)(/|$)');
final _quizLink = RegExp(r'^/quizzes/(\d+)$');
final _articleLink = RegExp(r'^/articles/([A-Za-z0-9_-]+)$');
final _conductionLink = RegExp(r'^/classes/(\d+)/conduction(/add)?$');

/// Asks the server the same question the target screen would, so the access
/// rules (gender, enrolment, role) stay in one place: the API. A 403 is a
/// refusal; a 404 is a class or quiz that is gone or no longer the member's.
/// Any other failure (offline, a fault) is not a verdict, so the link is opened
/// and the target screen reports it as it always does.
///
/// Links that are not a class, a quiz or an article are not checked.
typedef NotificationTargetChecker =
    Future<NotificationTarget> Function(String link);

final notificationTargetCheckerProvider = Provider<NotificationTargetChecker>((
  ref,
) {
  return (link) async {
    if (link == AppRoutes.homeQuiz) return _checkQuizCard(ref);

    final repository = ref.read(classesRepositoryProvider);
    try {
      final classId = _classLink.firstMatch(link)?.group(1);
      final quizId = _quizLink.firstMatch(link)?.group(1);
      final articleSlug = _articleLink.firstMatch(link)?.group(1);
      final conductionClassId = _conductionLink.firstMatch(link)?.group(1);
      if (conductionClassId != null) {
        // The list screen's own call, behind the same sessions:create guard
        // as adding a record. Class dashboard access answers a different
        // question (#865).
        await repository.getConductionSessions(
          int.parse(conductionClassId),
          pageSize: 1,
        );
      } else if (classId != null) {
        await repository.getClassDetail(int.parse(classId));
      } else if (quizId != null) {
        await repository.getQuizDetail(int.parse(quizId));
      } else if (articleSlug != null) {
        // Public content: only a missing article is a verdict (gone).
        await ref.read(tsrWebServiceProvider).getArticle(articleSlug);
      }
    } on ApiException catch (e) {
      if (e.statusCode == 403) return NotificationTarget.noAccess;
      if (e.statusCode == 404) return NotificationTarget.gone;
    } catch (e) {
      // Offline or any other fault is not a verdict either.
      debugPrint('Notification target check failed: $e');
    }
    return NotificationTarget.open;
  };
});

/// A quiz announcement (#868) leads to the quiz card on Home. The quiz is
/// asked afresh: one that is offline or over is [NotificationTarget.gone], one
/// the member is left out of is [NotificationTarget.noAccess], and a quiz that
/// cannot be loaded is not a verdict, so the link is opened.
Future<NotificationTarget> _checkQuizCard(Ref ref) async {
  await ref.read(grandQuizProvider.notifier).loadQuizInfo(forceRefresh: true);
  final quiz = ref.read(grandQuizProvider).quizInfo;
  if (quiz == null) return NotificationTarget.open;
  if (quiz.status == 'offline' || quiz.status == 'ended') {
    return NotificationTarget.gone;
  }
  if (!quiz.canTakePart) return NotificationTarget.noAccess;
  return NotificationTarget.open;
}

// ───────────────────────── Where a notification leads ─────────────────────────

/// Where a notification leads (#925). One of three shapes: a [link] to open,
/// several [classIds] to choose between (each opens that class's conduction
/// records), or nothing, so the text is shown.
class NotificationDestination {
  const NotificationDestination.link(String this.link) : classIds = const [];
  const NotificationDestination.chooseClass(this.classIds) : link = null;
  const NotificationDestination.none() : link = null, classIds = const [];

  final String? link;
  final List<int> classIds;

  @override
  bool operator ==(Object other) =>
      other is NotificationDestination &&
      other.link == link &&
      listEquals(other.classIds, classIds);

  @override
  int get hashCode => Object.hash(link, Object.hashAll(classIds));

  @override
  String toString() =>
      'NotificationDestination(link: $link, classIds: $classIds)';
}

/// The one mapping from a notification to its destination, for a tapped push
/// and for a row in the notification list alike.
///
/// An allowlisted [actionLink] wins (#428); a refused or empty one is ignored
/// and the [type] decides. [classId] and [quizId] are the push's own strings;
/// [classIds] are the classes a pending-forms reminder covers (#831).
NotificationDestination notificationDestination({
  String? type,
  String? actionLink,
  String? classId,
  String? quizId,
  List<int> classIds = const [],
}) {
  if (actionLink != null &&
      actionLink.isNotEmpty &&
      isAllowedActionLink(actionLink)) {
    return NotificationDestination.link(actionLink);
  }

  final validClassId = _positiveId(classId);
  final validQuizId = _positiveId(quizId);

  switch (type) {
    case 'admin_announcement':
      return const NotificationDestination.link(AppRoutes.notifications);
    case 'quiz_announcement':
      return const NotificationDestination.link(AppRoutes.homeQuiz);
    case 'quiz_released':
      return NotificationDestination.link(
        validQuizId != null ? '/quizzes/$validQuizId' : AppRoutes.notifications,
      );
    case 'class_reminder':
      return NotificationDestination.link(
        validClassId != null
            ? '/classes/$validClassId/dashboard'
            : AppRoutes.classes,
      );
    case 'conduction_reminder':
      // After the class: start a new record for it (owner decision, #865).
      return NotificationDestination.link(
        validClassId != null
            ? '/classes/$validClassId/conduction/add'
            : AppRoutes.classes,
      );
    case 'class_announcement':
      return NotificationDestination.link(
        validClassId != null
            ? '/classes/$validClassId/dashboard'
            : AppRoutes.notifications,
      );
    case 'cc_reminder':
      // Pending class forms: the class's list of records, with a chooser when
      // the reminder covers several classes (#919).
      final ids = [
        for (final id in classIds)
          if (id > 0) id,
      ];
      if (ids.isEmpty) return const NotificationDestination.none();
      if (ids.length == 1) {
        return NotificationDestination.link('/classes/${ids.first}/conduction');
      }
      return NotificationDestination.chooseClass(ids);
    default:
      return const NotificationDestination.none();
  }
}

/// A record id written as plain digits, as the server sends it. `int.tryParse`
/// alone also takes `-5`, `+5`, `0x10` and padded text, and a link built from
/// those would not match the access check's pattern, so it would skip it.
int? _positiveId(String? value) {
  if (value == null || !_digits.hasMatch(value)) return null;
  final id = int.tryParse(value);
  return id != null && id > 0 ? id : null;
}

final _digits = RegExp(r'^\d+$');

/// A payload value as text. FCM data values are strings; a local payload is
/// JSON the app wrote, so anything else is malformed and treated as absent.
String? _text(Object? value) => value is String ? value : null;

/// A tapped push or local notification. FCM data values are strings, so the
/// pending-forms reminder's `class_ids` is comma separated.
NotificationDestination pushDestination(Map<String, dynamic> data) {
  final classIds = <int>[];
  for (final part in (_text(data['class_ids']) ?? '').split(',')) {
    final id = _positiveId(part.trim());
    if (id != null && !classIds.contains(id)) classIds.add(id);
  }
  return notificationDestination(
    type: _text(data['type']),
    actionLink: _text(data['action_link']),
    classId: _text(data['class_id']),
    quizId: _text(data['quiz_id']),
    classIds: classIds,
  );
}

/// A row in the notification list. A row has no type: the classes it covers
/// (#831) are what mark it as a pending-forms reminder, and only when it
/// carries no link of its own.
NotificationDestination historyDestination(UserNotification notification) {
  final link = notification.actionLink;
  final noLink = link == null || link.isEmpty;
  return notificationDestination(
    type: noLink && notification.classes.isNotEmpty ? 'cc_reminder' : null,
    actionLink: link,
    classIds: [for (final c in notification.classes) c.id],
  );
}

// ───────────────────────── Opening a destination ─────────────────────────

/// Opens [destination], the same way for a tapped push and for the list: the
/// class chooser when it covers several, then the access check, then the
/// screen, or else the notification's text with the reason (#800, #831).
///
/// [classNames] names the chooser's classes; an id without a name is shown as
/// "Class N".
Future<void> openNotificationTarget(
  BuildContext context, {
  required NotificationTargetChecker check,
  required NotificationDestination destination,
  required String title,
  required String body,
  DateTime? sentAt,
  Map<int, String> classNames = const {},
  Future<bool> Function(Uri uri)? launchVideo,
}) async {
  var link = destination.link;

  if (destination.classIds.isNotEmpty) {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                'Choose a class',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            for (final id in destination.classIds)
              ListTile(
                title: Text(classNames[id] ?? 'Class $id'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, id),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;
    link = '/classes/$chosen/conduction';
  }

  if (link == null) {
    showNotificationDetail(context, title: title, body: body, sentAt: sentAt);
    return;
  }

  final target = await check(link);
  if (!context.mounted) return;

  switch (target) {
    case NotificationTarget.open:
      final opened = launchVideo == null
          ? await openActionLink(context, link)
          : await openActionLink(context, link, launch: launchVideo);
      if (!opened && context.mounted) {
        showNotificationDetail(
          context,
          title: title,
          body: body,
          sentAt: sentAt,
          notice: 'This could not be opened.',
        );
      }
    case NotificationTarget.gone:
      showNotificationDetail(
        context,
        title: title,
        body: body,
        sentAt: sentAt,
        notice: 'This is no longer available.',
      );
    case NotificationTarget.noAccess:
      showNotificationDetail(
        context,
        title: title,
        body: body,
        sentAt: sentAt,
        notice: link == AppRoutes.homeQuiz
            ? 'You cannot take part in this quiz.'
            : 'You do not have access to this.',
      );
  }
}

/// The notification's full text, with the reason its target did not open when
/// there is one.
void showNotificationDetail(
  BuildContext context, {
  required String title,
  required String body,
  DateTime? sentAt,
  String? notice,
}) {
  if (MediaQuery.of(context).size.width > 600) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (sentAt != null)
                  Text(
                    DateFormat('MMM d, yyyy · H:mm a').format(sentAt),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
                  ),
                const SizedBox(height: 24),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: AppTheme.darkText,
                  ),
                ),
                if (notice != null) ...[
                  const SizedBox(height: 24),
                  _TargetNotice(notice),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ListView(
          controller: scrollController,
          children: [
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (sentAt != null)
              Text(
                DateFormat('MMM d, yyyy · H:mm a').format(sentAt),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
              ),
            const SizedBox(height: 24),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.6,
                color: AppTheme.darkText,
              ),
            ),
            if (notice != null) ...[
              const SizedBox(height: 24),
              _TargetNotice(notice),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
  );
}

// ───────────────────────── Taps from outside the app ─────────────────────────

/// Where a tapped push (app closed, in the background or open) and a tapped
/// local reminder arrive. [NotificationService] is the real source.
abstract class NotificationTapSource {
  Stream<NotificationTap> get taps;

  /// A tap that arrived before anyone listened; returned once.
  NotificationTap? takePendingTap();
}

final notificationTapSourceProvider = Provider<NotificationTapSource>(
  (ref) => NotificationService(),
);

/// Opens whatever a tapped notification is about, through the same check and
/// chooser as the notification list. Watched once in `TSRApp`.
final notificationTapProvider = Provider<void>((ref) {
  final source = ref.watch(notificationTapSourceProvider);

  Future<void> handle(NotificationTap tap) async {
    try {
      final context = await _navigatorContext();
      if (context == null || !context.mounted) {
        debugPrint('Notification tap dropped: the app did not finish starting');
        return;
      }
      final destination = pushDestination(tap.data);
      await openNotificationTarget(
        context,
        check: ref.read(notificationTargetCheckerProvider),
        destination: destination,
        title: tap.title,
        body: tap.body,
        classNames: _classNames(ref, destination.classIds),
      );
    } catch (e) {
      // A tap must never take the app down; at worst it opens nothing.
      debugPrint('Notification tap failed: $e');
    }
  }

  final subscription = source.taps.listen(handle);
  ref.onDispose(subscription.cancel);

  final pending = source.takePendingTap();
  if (pending != null) handle(pending);
});

/// Waits until the app can show a tapped notification's target. On a cold
/// start the router sits on the splash screen while sign-in and permissions
/// load, and sends any other location back there, so a target opened then
/// would be lost and the member would land on Home. The splash screen leaves
/// within seconds; the bound only stops a stuck start from holding the tap.
Future<BuildContext?> _navigatorContext() async {
  for (var attempt = 0; attempt < 200; attempt++) {
    final context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted && !_onSplash(context)) {
      return context;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return null;
}

bool _onSplash(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return false;
  return router.routerDelegate.currentConfiguration.uri.path ==
      AppRoutes.splash;
}

/// A push carries class ids but no names: use the member's cached classes.
Map<int, String> _classNames(Ref ref, List<int> ids) {
  final classes = ref.read(classesProvider).classes ?? const [];
  return {
    for (final c in classes)
      if (ids.contains(c.id)) c.id: c.code,
  };
}

/// Why a notification's target did not open, shown above its readable text.
class _TargetNotice extends StatelessWidget {
  const _TargetNotice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 18, color: AppTheme.errorRed),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.errorRed),
          ),
        ),
      ],
    );
  }
}
