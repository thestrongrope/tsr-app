import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/permission_grants.dart';
import '../repositories/permission_grants_repository.dart';

/// Searches members. A provider so a test can stand in for the network.
typedef SearchMembers = Future<List<MemberRef>> Function(String query);

final memberSearchProvider = Provider<SearchMembers>(
  (ref) => PermissionGrantsRepository().searchMembers,
);

/// What one member holds and what may still be granted.
final memberPermissionsProvider = FutureProvider.autoDispose
    .family<MemberPermissions, int>(
      (ref, token) => PermissionGrantsRepository().getMember(token),
      retry: (retryCount, error) => null,
    );

typedef GrantPermission =
    Future<void> Function({
      required int token,
      required String permission,
      required String reason,
    });

final grantPermissionProvider = Provider<GrantPermission>(
  (ref) => PermissionGrantsRepository().grant,
);

typedef RevokePermission =
    Future<void> Function({required int id, required String reason});

final revokePermissionProvider = Provider<RevokePermission>(
  (ref) => PermissionGrantsRepository().revoke,
);
