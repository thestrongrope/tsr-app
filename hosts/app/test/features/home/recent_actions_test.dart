import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/router/route_config.dart';
import 'package:the_strong_rope/features/home/models/recent_action.dart';
import 'package:the_strong_rope/features/home/providers/recent_actions_provider.dart';
import 'package:the_strong_rope/features/home/services/recent_actions_observer.dart';
import 'package:the_strong_rope/features/home/services/recent_actions_store.dart';

final _now = DateTime(2026, 10, 23, 12);

RecentAction _visit(
  RecentActionKind kind, {
  int? classId,
  double daysAgo = 0,
}) => RecentAction(
  kind: kind,
  classId: classId,
  at: _now.subtract(Duration(minutes: (daysAgo * 24 * 60).round())),
);

void main() {
  group('rankRecentActions', () {
    test('groups visits by kind and class', () {
      final groups = rankRecentActions([
        _visit(RecentActionKind.classQuizzes, classId: 1),
        _visit(RecentActionKind.classQuizzes, classId: 2),
        _visit(RecentActionKind.classQuizzes, classId: 1),
      ], _now);

      expect(groups, hasLength(2));
      expect(groups.first.classId, 1);
      expect(groups.first.score, closeTo(2, 1e-9));
    });

    test('a visit loses half its weight every 7 days', () {
      final groups = rankRecentActions([
        _visit(RecentActionKind.thisWeek, daysAgo: 7),
        _visit(RecentActionKind.thisWeek, daysAgo: 14),
      ], _now);

      expect(groups.single.score, closeTo(0.5 + 0.25, 1e-9));
    });

    test('frequency beats a single newer visit', () {
      final groups = rankRecentActions([
        for (var i = 0; i < 4; i++)
          _visit(RecentActionKind.adminQuiz, daysAgo: 6),
        _visit(RecentActionKind.thisWeek),
      ], _now);

      expect(groups.first.kind, RecentActionKind.adminQuiz);
    });

    test('recency beats old frequency', () {
      final groups = rankRecentActions([
        for (var i = 0; i < 3; i++)
          _visit(RecentActionKind.adminQuiz, daysAgo: 28),
        _visit(RecentActionKind.thisWeek, daysAgo: 1),
      ], _now);

      expect(groups.first.kind, RecentActionKind.thisWeek);
    });

    test('visits older than 30 days are ignored', () {
      final groups = rankRecentActions([
        _visit(RecentActionKind.adminQuiz, daysAgo: 31),
        _visit(RecentActionKind.thisWeek, daysAgo: 29),
      ], _now);

      expect(groups.map((g) => g.kind), [RecentActionKind.thisWeek]);
    });

    test('equal scores go to the most recently visited', () {
      // Two visits a week ago and one visit now both score exactly 1.0.
      final events = [
        _visit(RecentActionKind.adminQuiz, daysAgo: 7),
        _visit(RecentActionKind.adminQuiz, daysAgo: 7),
        _visit(RecentActionKind.thisWeek),
      ];

      for (final order in [events, events.reversed.toList()]) {
        final groups = rankRecentActions(order, _now);
        expect(groups.first.score, groups.last.score);
        expect(groups.first.kind, RecentActionKind.thisWeek);
      }
    });

    test('nothing in, nothing out', () {
      expect(rankRecentActions(const [], _now), isEmpty);
    });
  });

  group('recentActionForRoute', () {
    test('maps each whitelisted route', () {
      expect(
        recentActionForRoute(RouteNames.classDashboardDetail, {'classId': '7'}),
        (kind: RecentActionKind.classDashboard, classId: 7),
      );
      expect(recentActionForRoute(RouteNames.classQuizzes, {'classId': '7'}), (
        kind: RecentActionKind.classQuizzes,
        classId: 7,
      ));
      expect(
        recentActionForRoute(RouteNames.classConduction, {'classId': '7'}),
        (kind: RecentActionKind.classConduction, classId: 7),
      );
      expect(
        recentActionForRoute(RouteNames.classNotification, {'classId': '7'}),
        (kind: RecentActionKind.classNotification, classId: 7),
      );
      expect(recentActionForRoute(RouteNames.adminThisWeek, const {}), (
        kind: RecentActionKind.thisWeek,
        classId: null,
      ));
      expect(recentActionForRoute(RouteNames.adminQuiz, null), (
        kind: RecentActionKind.adminQuiz,
        classId: null,
      ));
    });

    test('never maps person details, reports, search or anything else', () {
      for (final name in [
        RouteNames.adminTeacher,
        RouteNames.studentCard,
        RouteNames.subscriberCard,
        RouteNames.adminPermissionMember,
        RouteNames.adminReports,
        RouteNames.adminConductionReport,
        RouteNames.adminStudentPerformance,
        RouteNames.search,
        RouteNames.classConductionAdd,
        RouteNames.classConductionEdit,
        RouteNames.classRoster,
        RouteNames.home,
        'something-unnamed',
        null,
      ]) {
        expect(
          recentActionForRoute(name, {'classId': '7', 'token': '5'}),
          isNull,
          reason: '$name',
        );
      }
    });

    test('a class route without a usable class id is not recorded', () {
      expect(recentActionForRoute(RouteNames.classQuizzes, const {}), isNull);
      expect(
        recentActionForRoute(RouteNames.classQuizzes, {'classId': 'abc'}),
        isNull,
      );
    });
  });

  group('RecentActionsObserver', () {
    Route<void> route(String? name, [Object? arguments]) => MaterialPageRoute(
      settings: RouteSettings(name: name, arguments: arguments),
      builder: (_) => const SizedBox(),
    );

    test('reports whitelisted pushes and ignores the rest', () {
      final seen = <(RecentActionKind, int?)>[];
      final observer = RecentActionsObserver(
        (kind, classId) => seen.add((kind, classId)),
      );

      observer.didPush(route(RouteNames.adminTeacher, {'token': '5'}), null);
      observer.didPush(route(RouteNames.search), null);
      observer.didPush(route(RouteNames.classQuizzes, {'classId': '3'}), null);
      observer.didReplace(
        newRoute: route(RouteNames.adminThisWeek),
        oldRoute: route(RouteNames.home),
      );

      expect(seen, [
        (RecentActionKind.classQuizzes, 3),
        (RecentActionKind.thisWeek, null),
      ]);
    });
  });

  group('RecentActionsStore and notifier', () {
    late Directory dir;
    late Box box;
    late RecentActionsStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('hive_recent_actions_test');
      Hive.init(dir.path);
      box = await Hive.openBox(AppConstants.settingsBoxKey);
      store = RecentActionsStore(box);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('keeps only the last 30 visits, newest last', () async {
      for (var i = 0; i < 35; i++) {
        await store.add(
          7,
          RecentAction(
            kind: RecentActionKind.classQuizzes,
            classId: i,
            at: _now.add(Duration(minutes: i)),
          ),
        );
      }

      final stored = store.read(7);
      expect(stored, hasLength(RecentActionsStore.maxEvents));
      expect(stored.first.classId, 5);
      expect(stored.last.classId, 34);
    });

    test('stores ids, kinds and times, never names', () async {
      await store.add(7, _visit(RecentActionKind.classDashboard, classId: 3));

      final raw = box.get('recent_actions:7') as List;
      expect((raw.single as Map).keys.toSet(), {'k', 'c', 't'});
    });

    test('a second member never sees the first member\'s visits', () async {
      await store.add(7, _visit(RecentActionKind.thisWeek));

      expect(store.read(8), isEmpty);
      expect(store.read(7), hasLength(1));
    });

    test('an unreadable entry is skipped, not fatal', () async {
      await box.put('recent_actions:7', [
        'junk',
        {'k': 'nope', 't': 1},
        _visit(RecentActionKind.thisWeek).toJson(),
      ]);

      expect(store.read(7).map((a) => a.kind), [RecentActionKind.thisWeek]);
    });

    test('clearAll removes every member and nothing else', () async {
      await box.put('theme', 'dark');
      await store.add(7, _visit(RecentActionKind.thisWeek));
      await store.add(8, _visit(RecentActionKind.thisWeek));

      await store.clearAll();

      expect(store.read(7), isEmpty);
      expect(store.read(8), isEmpty);
      expect(box.get('theme'), 'dark');
    });

    test('the notifier records for a member and not for a guest', () async {
      final member = RecentActionsNotifier(store, 7, now: () => _now);
      await member.record(RecentActionKind.adminQuiz);
      expect(member.state.single.kind, RecentActionKind.adminQuiz);
      expect(store.read(7), hasLength(1));

      final guest = RecentActionsNotifier(store, null, now: () => _now);
      await guest.record(RecentActionKind.adminQuiz);
      expect(guest.state, isEmpty);
      expect(box.keys.where((k) => '$k'.startsWith('recent_actions:')), [
        'recent_actions:7',
      ]);
    });

    test('a new notifier for another member starts with their own', () async {
      await store.add(7, _visit(RecentActionKind.thisWeek));

      expect(RecentActionsNotifier(store, 8).state, isEmpty);
      expect(RecentActionsNotifier(store, 7).state, hasLength(1));
    });
  });
}
