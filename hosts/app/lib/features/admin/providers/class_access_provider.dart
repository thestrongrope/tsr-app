import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/class_access.dart';
import '../models/permission_grants.dart';
import '../repositories/class_access_repository.dart';

/// Each action is a provider so a test can stand in for the network.
typedef SearchClassAccessMembers =
    Future<List<MemberRef>> Function(String query);

final classAccessSearchProvider = Provider<SearchClassAccessMembers>(
  (ref) => ClassAccessRepository().searchMembers,
);

/// The classes one member manages and the rule each comes from.
final memberAccessProvider = FutureProvider.autoDispose
    .family<MemberAccess, int>(
      (ref, token) => ClassAccessRepository().getMember(token),
      retry: (retryCount, error) => null,
    );

/// The genders this admin may use, the levels and the cities.
final accessOptionsProvider = FutureProvider.autoDispose<AccessOptions>(
  (ref) => ClassAccessRepository().getOptions(),
  retry: (retryCount, error) => null,
);

typedef PreviewAccess =
    Future<ClassPreview> Function({
      required int gender,
      required List<AccessFilter> filters,
    });

final previewAccessProvider = Provider<PreviewAccess>(
  (ref) => ClassAccessRepository().preview,
);

typedef GrantAccess =
    Future<void> Function({
      required int token,
      required int gender,
      required List<AccessFilter> filters,
      required String reason,
      required String version,
      required String previewHash,
    });

final grantAccessProvider = Provider<GrantAccess>(
  (ref) => ClassAccessRepository().grant,
);

typedef RevokeAccess =
    Future<void> Function({
      required int id,
      required String reason,
      required String version,
    });

final revokeAccessProvider = Provider<RevokeAccess>(
  (ref) => ClassAccessRepository().revoke,
);
