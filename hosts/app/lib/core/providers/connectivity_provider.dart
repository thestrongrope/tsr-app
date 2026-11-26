import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long the device must report no network before the app says so, so
/// switching between wifi and mobile data does not flicker the banner.
const offlineBannerDelay = Duration(seconds: 2);

/// The device's network interfaces: the current state first, then each
/// change. Tests override this with a fake stream.
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) async* {
  final connectivity = Connectivity();
  yield await connectivity.checkConnectivity();
  yield* connectivity.onConnectivityChanged;
});

/// True once the device has had no network for [offlineBannerDelay]. It
/// only knows about network interfaces, not whether our server is reachable.
final isOfflineProvider = NotifierProvider<OfflineNotifier, bool>(
  OfflineNotifier.new,
);

class OfflineNotifier extends Notifier<bool> {
  Timer? _showTimer;

  @override
  bool build() {
    ref.onDispose(() => _showTimer?.cancel());
    ref.listen(connectivityStreamProvider, (_, next) {
      final results = next.value;
      if (results != null) _onResults(results);
    });
    return false;
  }

  void _onResults(List<ConnectivityResult> results) {
    // connectivity_plus reports a list; none means no interface at all.
    final offline =
        results.isEmpty ||
        (results.length == 1 && results.first == ConnectivityResult.none);
    if (!offline) {
      _showTimer?.cancel();
      _showTimer = null;
      state = false;
    } else if (!state) {
      _showTimer ??= Timer(offlineBannerDelay, () {
        _showTimer = null;
        state = true;
      });
    }
  }
}
