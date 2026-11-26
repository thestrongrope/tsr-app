import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/parent/models/models.dart';
import 'package:the_strong_rope/features/parent/providers/parent_provider.dart';
import 'package:the_strong_rope/features/parent/repositories/parent_repository.dart';
import 'package:the_strong_rope/features/parent/screens/child_class_performance_screen.dart';
import 'package:the_strong_rope/features/parent/screens/child_classes_screen.dart';
import 'package:the_strong_rope/features/parent/screens/my_children_screen.dart';
import 'package:the_strong_rope/features/parent/screens/parent_links_screen.dart';

class _FakeParentRepository extends ParentRepository {
  List<ChildModel> children = [];
  List<ChildClassModel> classes = [];
  ChildPerformanceModel? performance;
  List<ChildAttendanceHistory> attendance = [];
  List<ChildScoreModel> scores = [];
  List<ParentLinkModel> links = [];

  final List<int> revokedTokens = [];

  @override
  Future<List<ChildModel>> getChildren() async => children;

  @override
  Future<List<ChildClassModel>> getChildClasses(int childToken) async => classes;

  @override
  Future<ChildPerformanceModel> getChildPerformance(
    int childToken,
    int classId, {
    String? from,
    String? to,
  }) async =>
      performance ??
      const ChildPerformanceModel(
        attendance: ChildAttendanceSummary(
          totalSessions: 10,
          attendedSessions: 8,
          attendancePercentage: 80.0,
          totalRecitation: 30,
        ),
        quizzes: ChildQuizSummary(
          quizzesAttempted: 2,
          quizAverageScore: 85.0,
        ),
      );

  @override
  Future<List<ChildAttendanceHistory>> getChildAttendance(
    int childToken,
    int classId, {
    String? from,
    String? to,
  }) async =>
      attendance;

  @override
  Future<List<ChildScoreModel>> getChildScores(
    int childToken,
    int classId, {
    String? from,
    String? to,
  }) async =>
      scores;

  @override
  Future<List<ParentLinkModel>> getParentLinks() async => links;

  @override
  Future<void> revokeLink(int childToken) async {
    revokedTokens.add(childToken);
    links = links.map((l) {
      if (l.childToken == childToken) {
        return ParentLinkModel(
          id: l.id,
          parentToken: l.parentToken,
          childToken: l.childToken,
          childName: l.childName,
          relationship: l.relationship,
          status: 'revoked',
          source: l.source,
          createdAt: l.createdAt,
          createdByName: l.createdByName,
          revokedAt: '2026-11-04',
        );
      }
      return l;
    }).toList();
  }
}

void main() {
  late _FakeParentRepository fakeRepo;

  setUp(() {
    fakeRepo = _FakeParentRepository();
  });

  Widget createTestWidget({
    required Widget child,
    _FakeParentRepository? repo,
  }) {
    return ProviderScope(
      overrides: [
        parentRepositoryProvider.overrideWithValue(repo ?? fakeRepo),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('MyChildrenScreen', () {
    testWidgets('shows empty state with instructions when no children linked', (
      tester,
    ) async {
      fakeRepo.children = [];

      await tester.pumpWidget(
        createTestWidget(child: const MyChildrenScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Children Linked'), findsOneWidget);
      expect(
        find.textContaining('ask their teacher or school administrator for a parent invite link'),
        findsOneWidget,
      );
      expect(find.text('View My Links'), findsOneWidget);
    });

    testWidgets('shows linked children cards when present', (tester) async {
      fakeRepo.children = [
        const ChildModel(
          token: 2001,
          name: 'Zainab Ali',
          gender: 2,
          relationship: 'mother',
          classes: [
            ChildClassSummary(
              classId: 10,
              className: 'Quran Recitation',
              classCode: 'QR1',
              status: 'A',
            ),
            ChildClassSummary(
              classId: 11,
              className: 'Islamic History',
              classCode: 'IH1',
              status: 'A',
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(child: const MyChildrenScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Zainab Ali'), findsOneWidget);
      expect(find.text('Mother'), findsOneWidget);
      expect(find.text('2 classes'), findsOneWidget);
    });
  });

  group('ChildClassesScreen', () {
    testWidgets('shows empty state when child has no classes', (tester) async {
      fakeRepo.classes = [];

      await tester.pumpWidget(
        createTestWidget(
          child: const ChildClassesScreen(childToken: 2001),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Classes Found'), findsOneWidget);
      expect(
        find.text('This student is not currently enrolled in any classes.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows active and inactive classes with badges and NEVER displays meeting links',
      (tester) async {
        fakeRepo.classes = [
          const ChildClassModel(
            classId: 101,
            className: 'Fiqh Level 1',
            classCode: 'F101',
            gender: 1,
            teacherName: 'Sheikh Ahmad',
            startedOn: '2026-01-10',
            enrolmentStatus: 'A',
          ),
          const ChildClassModel(
            classId: 102,
            className: 'Arabic Grammar',
            classCode: 'AG102',
            gender: 1,
            teacherName: 'Ustadh Omar',
            startedOn: '2025-09-01',
            enrolmentStatus: 'I',
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: const ChildClassesScreen(childToken: 2001),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Fiqh Level 1'), findsOneWidget);
        expect(find.text('Teacher: Sheikh Ahmad'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);

        expect(find.text('Arabic Grammar'), findsOneWidget);
        expect(find.text('Teacher: Ustadh Omar'), findsOneWidget);
        expect(find.text('Inactive'), findsOneWidget);

        // Critical privacy verification: meeting links must NOT be present anywhere
        expect(find.textContaining('meet.google.com'), findsNothing);
        expect(find.textContaining('zoom.us'), findsNothing);
        expect(find.textContaining('http'), findsNothing);
      },
    );
  });

  group('ChildClassPerformanceScreen', () {
    testWidgets('shows attendance figures and session history', (
      tester,
    ) async {
      fakeRepo.performance = const ChildPerformanceModel(
        attendance: ChildAttendanceSummary(
          totalSessions: 20,
          attendedSessions: 17,
          attendancePercentage: 85.0,
          totalRecitation: 45,
        ),
        quizzes: ChildQuizSummary(
          quizzesAttempted: 4,
          quizAverageScore: 90.0,
        ),
      );

      fakeRepo.attendance = const [
        ChildAttendanceHistory(
          date: '2026-10-15',
          duration: 60,
          present: true,
          recitation: 10,
        ),
        ChildAttendanceHistory(
          date: '2026-10-08',
          duration: 60,
          present: false,
          recitation: 0,
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(
          child: const ChildClassPerformanceScreen(
            childToken: 2001,
            classId: 101,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Attendance Overview'), findsOneWidget);
      expect(find.text('85.0%'), findsOneWidget);
      expect(find.text('17 / 20'), findsOneWidget);
      expect(find.text('45 min'), findsOneWidget);

      expect(find.text('2026-10-15'), findsOneWidget);
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Recitation: 10 min'), findsOneWidget);

      expect(find.text('2026-10-08'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);
    });

    testWidgets('shows quiz summary and quiz score breakdown on quiz tab', (
      tester,
    ) async {
      fakeRepo.performance = const ChildPerformanceModel(
        attendance: ChildAttendanceSummary(
          totalSessions: 10,
          attendedSessions: 8,
          attendancePercentage: 80.0,
          totalRecitation: 20,
        ),
        quizzes: ChildQuizSummary(
          quizzesAttempted: 3,
          quizAverageScore: 92.5,
        ),
      );

      fakeRepo.scores = const [
        ChildScoreModel(
          quizId: 501,
          quizName: 'Surah Al-Mulk Quiz',
          score: 9,
          totalQuestions: 10,
          percentage: 90.0,
          attemptedOn: '2026-10-12',
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(
          child: const ChildClassPerformanceScreen(
            childToken: 2001,
            classId: 101,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Quiz Scores tab
      await tester.tap(find.text('Quiz Scores'));
      await tester.pumpAndSettle();

      expect(find.text('Quiz Overview'), findsOneWidget);
      expect(find.text('92.5%'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      expect(find.text('Surah Al-Mulk Quiz'), findsOneWidget);
      expect(find.text('9 / 10'), findsOneWidget);
      expect(find.text('90.0%'), findsOneWidget);
    });
  });

  group('ParentLinksScreen', () {
    testWidgets('shows empty state when no links found', (tester) async {
      fakeRepo.links = [];

      await tester.pumpWidget(
        createTestWidget(child: const ParentLinksScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Links Found'), findsOneWidget);
      expect(
        find.text('You do not have any active or previous parent-child links.'),
        findsOneWidget,
      );
    });

    testWidgets('shows active and revoked links and handles revoke flow', (
      tester,
    ) async {
      fakeRepo.links = [
        const ParentLinkModel(
          id: 1,
          parentToken: 1001,
          childToken: 2001,
          childName: 'Zainab Ali',
          relationship: 'mother',
          status: 'active',
          source: 'link',
          createdAt: '2026-10-01',
          createdByName: 'Invite link',
        ),
        const ParentLinkModel(
          id: 2,
          parentToken: 1001,
          childToken: 2002,
          childName: 'Hassan Ali',
          relationship: 'mother',
          status: 'revoked',
          source: 'token_entry',
          createdAt: '2026-09-01',
          createdByName: 'Ustadh Karim',
          revokedAt: '2026-09-15',
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(child: const ParentLinksScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Zainab Ali'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Revoke Link'), findsOneWidget);

      expect(find.text('Hassan Ali'), findsOneWidget);
      expect(find.text('Revoked'), findsOneWidget);

      // Who created each link, by display name
      expect(find.text('Created by: Invite link'), findsOneWidget);
      expect(find.text('Created by: Ustadh Karim'), findsOneWidget);

      // Tap Revoke Link
      await tester.tap(find.text('Revoke Link'));
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Revoke Parent Link'), findsOneWidget);
      expect(
        find.textContaining('Are you sure you want to revoke your parent link to Zainab Ali?'),
        findsOneWidget,
      );

      // Tap Confirm 'Revoke' button inside dialog
      await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
      await tester.pumpAndSettle();

      expect(fakeRepo.revokedTokens, [2001]);
    });
  });
}
