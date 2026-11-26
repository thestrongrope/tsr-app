import 'dart:math' as math;

import '../../../core/router/route_config.dart';

/// The screens Home's "Jump back in" card remembers. This list is the
/// whitelist: a screen that is not here is never recorded (person details,
/// reports, search and the rest).
enum RecentActionKind {
  classDashboard(forClass: true),
  classQuizzes(forClass: true),
  classConduction(forClass: true),
  classNotification(forClass: true),
  thisWeek(forClass: false),
  adminQuiz(forClass: false),
  adminStandardMcqs(forClass: false),
  adminTransfers(forClass: false),
  adminWhatsappReminders(forClass: false);

  const RecentActionKind({required this.forClass});

  /// Does the screen belong to one class?
  final bool forClass;
}

/// One remembered visit: ids and a time only. Names are resolved when shown.
class RecentAction {
  const RecentAction({required this.kind, this.classId, required this.at});

  final RecentActionKind kind;
  final int? classId;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'k': kind.name,
    'c': classId,
    't': at.millisecondsSinceEpoch,
  };

  /// Null for anything unreadable, so one bad entry never loses the rest.
  static RecentAction? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = RecentActionKind.values
        .where((k) => k.name == json['k'])
        .firstOrNull;
    final millis = json['t'];
    final classId = json['c'];
    if (kind == null || millis is! int) return null;
    if (kind.forClass != (classId is int)) return null;
    return RecentAction(
      kind: kind,
      classId: classId as int?,
      at: DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }
}

/// A (kind, class) pair and how much it has been used lately.
class RecentActionGroup {
  const RecentActionGroup({
    required this.kind,
    this.classId,
    required this.score,
    required this.lastAt,
  });

  final RecentActionKind kind;
  final int? classId;
  final double score;
  final DateTime lastAt;
}

/// How far back a visit still counts.
const recentActionWindow = Duration(days: 30);

/// A visit's weight halves every this many days.
const recentActionHalfLifeDays = 7;

/// Groups [events] by (kind, classId) and ranks them, best first. A visit
/// scores 0.5^(ageInDays / 7), so a group's score is its visits weighted by how
/// recent they are; visits older than 30 days are ignored. Equal scores go to
/// the group visited most recently.
List<RecentActionGroup> rankRecentActions(
  List<RecentAction> events,
  DateTime now,
) {
  final scores = <(RecentActionKind, int?), double>{};
  final lastVisit = <(RecentActionKind, int?), DateTime>{};
  for (final event in events) {
    final age = now.difference(event.at);
    if (age > recentActionWindow) continue;
    final ageInDays =
        math.max(0, age.inMicroseconds) / Duration.microsecondsPerDay;
    final key = (event.kind, event.classId);
    scores[key] =
        (scores[key] ?? 0) +
        math.pow(0.5, ageInDays / recentActionHalfLifeDays);
    final last = lastVisit[key];
    if (last == null || event.at.isAfter(last)) lastVisit[key] = event.at;
  }
  final groups = [
    for (final entry in scores.entries)
      RecentActionGroup(
        kind: entry.key.$1,
        classId: entry.key.$2,
        score: entry.value,
        lastAt: lastVisit[entry.key]!,
      ),
  ];
  groups.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : b.lastAt.compareTo(a.lastAt);
  });
  return groups;
}

/// The whitelisted action a route name stands for, with its class id when the
/// route has one. [arguments] is the route's path parameters, which go_router
/// puts on every page. Null for every route that is not remembered.
({RecentActionKind kind, int? classId})? recentActionForRoute(
  String? name,
  Object? arguments,
) {
  final kind = switch (name) {
    RouteNames.classDashboardDetail => RecentActionKind.classDashboard,
    RouteNames.classQuizzes => RecentActionKind.classQuizzes,
    RouteNames.classConduction => RecentActionKind.classConduction,
    RouteNames.classNotification => RecentActionKind.classNotification,
    RouteNames.adminThisWeek => RecentActionKind.thisWeek,
    RouteNames.adminQuiz => RecentActionKind.adminQuiz,
    RouteNames.adminStandardMcqs => RecentActionKind.adminStandardMcqs,
    RouteNames.adminTransfers => RecentActionKind.adminTransfers,
    RouteNames.adminWhatsappReminders =>
      RecentActionKind.adminWhatsappReminders,
    _ => null,
  };
  if (kind == null) return null;
  if (!kind.forClass) return (kind: kind, classId: null);
  final rawId = arguments is Map ? arguments['classId'] : null;
  final classId = rawId == null ? null : int.tryParse('$rawId');
  if (classId == null) return null;
  return (kind: kind, classId: classId);
}
