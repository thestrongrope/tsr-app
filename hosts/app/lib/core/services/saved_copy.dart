import 'package:dio/dio.dart';
import 'package:hive_ce/hive.dart';

import '../constants/app_constants.dart';
import '../models/user.dart';
import '../network/api_client.dart';

/// How long a saved copy may be shown when the network fails. Older than this
/// and the member sees the normal error with Retry instead.
const Duration savedCopyMaxAge = Duration(days: 7);

/// True when [e] means the server could not be reached (no connection, a
/// timeout, or a 5xx). A refusal (401, 403, any other 4xx) is not: an old copy
/// must never stand in for the server saying no.
///
/// Takes a raw [DioException] too, because some services call Dio directly
/// instead of through [ApiClient].
bool isUnreachable(Object e) {
  if (e is DioException) e = ApiException.fromDioException(e);
  if (e is! ApiException) return false;
  return e.isNetworkError || e.statusCode == 408 || e.isServerError;
}

/// The signed-in member's token, or null for a guest (token 0 is shared by
/// every guest) or when the user box cannot be read. Saved copies are tied to
/// this, so a copy is never shown to anyone else.
int? signedInToken() {
  try {
    final token = Hive.box<User>(
      AppConstants.userBoxKey,
    ).get('current_user')?.token;
    return token != null && token > 0 ? token : null;
  } catch (_) {
    return null;
  }
}

/// A value saved in a Hive box together with the time it was saved and the
/// member it belongs to. It can be shown as a fallback when the network fails,
/// and is refused once it is older than [maxAge] (null: never expires), when
/// it belongs to another member, or when it cannot be tied to the signed-in
/// member (an older save with no owner, or nobody signed in). The network
/// always comes first; this is never read while the server answers.
///
/// [owner] says who is signed in; [clock] lets tests move time.
class SavedCopies {
  SavedCopies(
    this._box, {
    required int? Function() owner,
    DateTime Function()? clock,
    this.maxAge = savedCopyMaxAge,
  }) : _owner = owner,
       _clock = clock ?? DateTime.now;

  final Box _box;
  final int? Function() _owner;
  final DateTime Function() _clock;
  final Duration? maxAge;

  /// Saves [data] for the signed-in member. Saves nothing when nobody is.
  Future<void> save(String key, Object data) async {
    final owner = _owner();
    if (owner == null) return;
    await _box.put(key, {
      'savedAt': _clock().toIso8601String(),
      'owner': owner,
      'data': data,
    });
  }

  /// The saved value, or null when there is none, it is unreadable, it is
  /// [maxAge] old or older, or it does not belong to the signed-in member.
  Object? read(String key) {
    final owner = _owner();
    final saved = _box.get(key);
    if (owner == null || saved is! Map) return null;
    if (saved['owner'] != owner) return null;
    final savedAt = DateTime.tryParse(saved['savedAt'] as String? ?? '');
    if (savedAt == null) return null;
    final limit = maxAge;
    if (limit != null && _clock().difference(savedAt) >= limit) return null;
    return saved['data'];
  }

  Future<void> delete(String key) => _box.delete(key);
}
