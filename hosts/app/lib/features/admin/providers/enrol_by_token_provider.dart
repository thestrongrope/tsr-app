import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enrol_by_token.dart';
import '../repositories/enrol_by_token_repository.dart';

/// Each action is a provider so a test can stand in for the network.
typedef LookupMember = Future<MemberDetails> Function(int token);

final lookupMemberProvider = Provider<LookupMember>(
  (ref) => EnrolByTokenRepository().lookup,
);

typedef EnrolMember =
    Future<void> Function({required int token, required int classId});

final enrolMemberProvider = Provider<EnrolMember>(
  (ref) => EnrolByTokenRepository().enrol,
);

/// The member being looked up. The details include contact data, so they live
/// only here: dropped when the screen closes, never saved or logged.
class MemberLookup extends AsyncNotifier<MemberDetails?> {
  /// The newest lookup; an older reply that lands after [clear] is ignored.
  int _latest = 0;

  @override
  MemberDetails? build() => null;

  /// One lookup at a time: a second tap while one runs sends nothing.
  Future<void> lookup(int token) async {
    if (state.isLoading) return;
    final mine = ++_latest;
    state = const AsyncLoading<MemberDetails?>();
    final result = await AsyncValue.guard<MemberDetails?>(
      () => ref.read(lookupMemberProvider)(token),
    );
    if (!ref.mounted || mine != _latest) return;
    state = result;
  }

  void clear() {
    _latest++;
    state = const AsyncData<MemberDetails?>(null);
  }
}

final memberLookupProvider =
    AsyncNotifierProvider.autoDispose<MemberLookup, MemberDetails?>(
      MemberLookup.new,
    );
