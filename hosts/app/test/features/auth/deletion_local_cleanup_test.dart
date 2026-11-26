import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/models/user.dart' as app_user;
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/account_deletion/models/deletion_request.dart';
import 'package:the_strong_rope/features/auth/providers/auth_provider.dart';

class _FakeApiClient extends Fake implements ApiClient {
  bool tokensCleared = false;

  @override
  Future<void> clearTokens() async => tokensCleared = true;
}

/// After account deletion the member's profile and tokens must leave the
/// device even when signing out of Google/Firebase fails (for example offline),
/// and the failure must reach the member.
void main() {
  late Directory dir;
  late _FakeApiClient api;
  late ProviderContainer container;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('deletion_cleanup_test');
    Hive.init(dir.path);
    Hive.registerAdapter(app_user.UserAdapter());
    await Hive.openBox<app_user.User>(AppConstants.userBoxKey);
    await Hive.box<app_user.User>(AppConstants.userBoxKey).put(
      'current_user',
      const app_user.User(
        id: 1,
        token: 7,
        email: 'member@example.com',
        name: 'Member',
        roleId: 1,
      ),
    );
    api = _FakeApiClient();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
  });

  tearDown(() async {
    container.dispose();
    await Hive.close();
    Hive.resetAdapters();
    await dir.delete(recursive: true);
  });

  AuthService serviceWith(Future<void> Function() signOut) => AuthService(
    container.read(Provider((ref) => ref)),
    signOutOfIdentityProviders: signOut,
  );

  test('clears tokens and profile when the identity sign-out throws', () async {
    final service = serviceWith(() async => throw Exception('offline'));

    final failed = await service.clearSession();

    expect(failed, ['identity provider sign-out']);
    expect(api.tokensCleared, isTrue);
    expect(Hive.box<app_user.User>(AppConstants.userBoxKey).get('current_user'), isNull);
  });

  test('reports nothing when every step succeeds', () async {
    final service = serviceWith(() async {});

    expect(await service.clearSession(), isEmpty);
    expect(api.tokensCleared, isTrue);
  });

  test('signOutWithoutDeviceUnregister still clears, then throws', () async {
    final service = serviceWith(() async => throw Exception('offline'));

    await expectLater(
      service.signOutWithoutDeviceUnregister(),
      throwsException,
    );
    expect(api.tokensCleared, isTrue);
    expect(Hive.box<app_user.User>(AppConstants.userBoxKey).get('current_user'), isNull);
  });

  test('deletion wipe flags residual data when the sign-out fails', () async {
    final service = serviceWith(() async => throw Exception('offline'));
    final notifier = AuthNotifier(service);
    addTearDown(notifier.dispose);

    await notifier.applyDeletionStatus(DeletionStatus.completed);

    expect(notifier.state.deletionLeftDataOnDevice, isTrue);
    expect(api.tokensCleared, isTrue);
    expect(Hive.box<app_user.User>(AppConstants.userBoxKey).get('current_user'), isNull);
  });
}
