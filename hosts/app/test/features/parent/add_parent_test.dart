import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/models/user.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/auth/providers/auth_provider.dart';
import 'package:the_strong_rope/features/notifications/providers/user_notifications_provider.dart';
import 'package:the_strong_rope/features/members/models/entity_cards.dart';
import 'package:the_strong_rope/features/members/providers/members_provider.dart';
import 'package:the_strong_rope/features/members/screens/student_card_screen.dart';
import 'package:the_strong_rope/features/parent/models/models.dart';
import 'package:the_strong_rope/features/parent/providers/parent_provider.dart';
import 'package:the_strong_rope/features/parent/repositories/parent_repository.dart';
import 'package:the_strong_rope/features/parent/screens/my_parents_screen.dart';
import 'package:the_strong_rope/features/parent/widgets/add_parent_dialog.dart';
import 'package:the_strong_rope/features/profile/presentation/me_screen.dart';

class _FixedPermissions extends PermissionsNotifier {
  _FixedPermissions(List<String> permissions) {
    state = PermissionsState(
      payload: PermissionsPayload(
        version: 4,
        permissions: permissions,
        scopes: const PermissionScopes(gender: 1),
        issuedAt: '',
      ),
    );
  }
}

class _FakeParentRepository extends ParentRepository {
  ParentInviteLink inviteLink = const ParentInviteLink(
    code: 'abc123xyz',
    url: 'https://example.com/link/abc123xyz',
    expiresAt: '2026-11-05 12:00:00',
  );
  String? lookupNameResult = 'Ibrahim Khan';
  ApiException? lookupError;
  ApiException? addError;
  final List<({int childToken, int parentToken, String relationship})> directAdds = [];
  List<MyParentModel> myParents = [];
  final List<int> revokedParents = [];

  @override
  Future<ParentInviteLink> createInviteLink(int childToken) async => inviteLink;

  @override
  Future<String?> lookupParentName(int childToken, int parentToken) async {
    if (lookupError != null) throw lookupError!;
    return lookupNameResult;
  }

  @override
  Future<void> addParentDirect(
    int childToken,
    int parentToken,
    String relationship,
  ) async {
    if (addError != null) throw addError!;
    directAdds.add((
      childToken: childToken,
      parentToken: parentToken,
      relationship: relationship,
    ));
  }

  @override
  Future<List<MyParentModel>> getMyParents() async => myParents;

  @override
  Future<void> revokeMyParent(int parentToken) async {
    revokedParents.add(parentToken);
    myParents = myParents.where((p) => p.parentToken != parentToken).toList();
  }
}

const _sampleCard = StudentCard(
  token: 2001,
  name: 'Zainab Ali',
  gender: 2,
  classes: [],
);

void main() {
  late _FakeParentRepository fakeRepo;

  setUp(() {
    fakeRepo = _FakeParentRepository();
  });

  group('AddParentDialog', () {
    testWidgets('shows one-time link view by default and copies link', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            parentRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AddParentDialog(
                childToken: 2001,
                childName: 'Zainab',
                allowDirectTokenEntry: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Parent for Zainab'), findsOneWidget);
      expect(find.text('https://example.com/link/abc123xyz'), findsOneWidget);
      expect(find.text('Copy Link'), findsOneWidget);
      expect(find.text('By Token'), findsNothing);
    });

    testWidgets(
      'direct token entry requires lookup and Confirm is the only way to save',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              parentRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: AddParentDialog(
                  childToken: 2001,
                  childName: 'Zainab',
                  allowDirectTokenEntry: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Mode selector is visible
        expect(find.text('By Token'), findsOneWidget);

        // Switch to By Token mode
        await tester.tap(find.text('By Token'));
        await tester.pumpAndSettle();

        // Confirm button exists but is disabled before lookup
        final confirmFinder = find.byKey(const Key('confirm-add-parent-button'));
        expect(confirmFinder, findsOneWidget);
        FilledButton confirmButton = tester.widget(confirmFinder);
        expect(confirmButton.onPressed, isNull);

        // No direct adds yet
        expect(fakeRepo.directAdds, isEmpty);

        // Enter parent token
        await tester.enterText(
          find.byKey(const Key('parent-token-input')),
          '1005',
        );
        await tester.pumpAndSettle();

        // Confirm button is still disabled before lookup
        confirmButton = tester.widget(confirmFinder);
        expect(confirmButton.onPressed, isNull);

        // Tap Lookup button
        await tester.tap(find.byKey(const Key('lookup-parent-button')));
        await tester.pumpAndSettle();

        // Parent name is displayed to confirm identity
        expect(find.text('Confirm Person:'), findsOneWidget);
        expect(find.text('Ibrahim Khan'), findsOneWidget);

        // Confirm button is now enabled
        confirmButton = tester.widget(confirmFinder);
        expect(confirmButton.onPressed, isNotNull);

        // Tap Confirm button to save
        await tester.tap(confirmFinder);
        await tester.pumpAndSettle();

        // Verifies direct link was saved with correct parameters
        expect(fakeRepo.directAdds.length, 1);
        expect(fakeRepo.directAdds.first.childToken, 2001);
        expect(fakeRepo.directAdds.first.parentToken, 1005);
        expect(fakeRepo.directAdds.first.relationship, 'father');
      },
    );

    Future<void> openTokenEntry(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [parentRepositoryProvider.overrideWithValue(fakeRepo)],
          child: const MaterialApp(
            home: Scaffold(
              body: AddParentDialog(
                childToken: 2001,
                childName: 'Zainab',
                allowDirectTokenEntry: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('By Token'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('parent-token-input')), '3001');
    }

    const ambiguousBody = {
      'detail': 'More than one member has that token number. Please contact an admin.',
      'code': 'ambiguous_token',
    };

    testWidgets('an ambiguous token on lookup tells staff to contact an admin', (
      tester,
    ) async {
      fakeRepo.lookupError = const ApiException(
        'More than one member has that token number. Please contact an admin.',
        422,
        body: ambiguousBody,
      );
      await openTokenEntry(tester);

      await tester.tap(find.byKey(const Key('lookup-parent-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('contact an admin'), findsOneWidget);
      expect(find.text('Parent not found with token #3001'), findsNothing);
      expect(find.text('Confirm Person:'), findsNothing);
    });

    testWidgets('an ambiguous token on save tells staff to contact an admin', (
      tester,
    ) async {
      await openTokenEntry(tester);
      await tester.tap(find.byKey(const Key('lookup-parent-button')));
      await tester.pumpAndSettle();
      fakeRepo.addError = const ApiException(
        'Invalid relationship or self-link not allowed',
        422,
        body: ambiguousBody,
      );

      await tester.tap(find.byKey(const Key('confirm-add-parent-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('contact an admin'), findsOneWidget);
      expect(find.textContaining('Invalid relationship'), findsNothing);
    });

    testWidgets('another 422 on save keeps its own message', (tester) async {
      await openTokenEntry(tester);
      await tester.tap(find.byKey(const Key('lookup-parent-button')));
      await tester.pumpAndSettle();
      fakeRepo.addError = const ApiException(
        'Invalid relationship or self-link not allowed',
        422,
        body: {'detail': 'Invalid relationship or self-link not allowed'},
      );

      await tester.tap(find.byKey(const Key('confirm-add-parent-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Invalid relationship'), findsOneWidget);
      expect(find.textContaining('contact an admin'), findsNothing);
    });
  });

  group('StudentCardScreen permissions', () {
    testWidgets('Add parent action is absent when user lacks parents:add', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentCardProvider(2001).overrideWith((ref) => _sampleCard),
            permissionsProvider.overrideWith(
              (ref) => _FixedPermissions(['children:read:assigned']),
            ),
          ],
          child: const MaterialApp(
            home: StudentCardScreen(token: 2001),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Zainab Ali'), findsWidgets);
      expect(find.byKey(const Key('add-parent-button')), findsNothing);
    });

    testWidgets('Add parent action is present when user has parents:add:own', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentCardProvider(2001).overrideWith((ref) => _sampleCard),
            permissionsProvider.overrideWith(
              (ref) => _FixedPermissions(['parents:add:own']),
            ),
          ],
          child: const MaterialApp(
            home: StudentCardScreen(token: 2001),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Zainab Ali'), findsWidgets);
      expect(find.byKey(const Key('add-parent-button')), findsOneWidget);
    });
  });

  group('MyParentsScreen (child-side)', () {
    testWidgets('shows empty state and allows opening add parent', (
      tester,
    ) async {
      fakeRepo.myParents = [];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            parentRepositoryProvider.overrideWithValue(fakeRepo),
            currentUserProvider.overrideWithValue(
              const User(
                id: 5,
                token: 2001,
                name: 'Zainab',
                email: 'zainab@example.com',
                roleId: 1,
                gender: 2,
              ),
            ),
          ],
          child: const MaterialApp(
            home: MyParentsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Parents Linked'), findsOneWidget);
      expect(find.text('Add Parent'), findsWidgets);
    });

    testWidgets('shows linked parent and handles revoke action', (
      tester,
    ) async {
      fakeRepo.myParents = [
        const MyParentModel(
          id: 10,
          parentToken: 1005,
          parentName: 'Ibrahim Khan',
          relationship: 'father',
          status: 'active',
          source: 'invite_link',
          createdAt: '2026-10-10',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            parentRepositoryProvider.overrideWithValue(fakeRepo),
            currentUserProvider.overrideWithValue(
              const User(
                id: 5,
                token: 2001,
                name: 'Zainab',
                email: 'zainab@example.com',
                roleId: 1,
                gender: 2,
              ),
            ),
          ],
          child: const MaterialApp(
            home: MyParentsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ibrahim Khan'), findsOneWidget);
      expect(find.text('Father'), findsOneWidget);
      expect(find.text('Revoke Parent'), findsOneWidget);

      await tester.tap(find.text('Revoke Parent'));
      await tester.pumpAndSettle();

      expect(find.text('Revoke Parent Link'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
      await tester.pumpAndSettle();

      expect(fakeRepo.revokedParents, [1005]);
    });
  });

  group('MeScreen parent entry tile visibility', () {
    testWidgets('My Parents tile is absent when user lacks parents:manage:self', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationCountProvider.overrideWith((ref) => 0),
            permissionsProvider.overrideWith(
              (ref) => _FixedPermissions(['children:read:assigned']),
            ),
            currentUserProvider.overrideWithValue(
              const User(
                id: 1,
                token: 1001,
                name: 'Parent User',
                email: 'parent@example.com',
                roleId: 1,
                gender: 1,
              ),
            ),
          ],
          child: const MaterialApp(
            home: MeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Parents'), findsNothing);
    });

    testWidgets('My Parents tile is present when user has parents:manage:self', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationCountProvider.overrideWith((ref) => 0),
            permissionsProvider.overrideWith(
              (ref) => _FixedPermissions(['parents:manage:self']),
            ),
            currentUserProvider.overrideWithValue(
              const User(
                id: 2,
                token: 2001,
                name: 'Student User',
                email: 'student@example.com',
                roleId: 1,
                gender: 2,
              ),
            ),
          ],
          child: const MaterialApp(
            home: MeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Parents'), findsOneWidget);
    });
  });
}
