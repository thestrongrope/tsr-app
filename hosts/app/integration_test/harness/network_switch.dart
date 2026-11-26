import 'package:dio/dio.dart';
import 'package:patrol/patrol.dart';
import 'package:the_strong_rope/core/network/api_client.dart';

/// Takes the app offline for a journey, in the two ways the app can tell.
///
/// Both halves are needed because the runner reaches the local API through
/// `adb reverse` (scripts/patrol-android.sh), and that tunnel rides on adb, not
/// on the device's network: airplane mode alone leaves every request working.
///
/// - **Requests fail.** An interceptor, put first on the app's own Dio, answers
///   every call with a connection error while [offline] is true. That is the
///   same `DioExceptionType.connectionError` a real dead network produces, so
///   the app takes the path it takes in the field (`isUnreachable`).
/// - **The device says so.** Airplane mode changes what connectivity_plus
///   reports. The conduction queue sends on that change back to online, so a
///   journey that never changed it would never see the send.
///
/// Nothing here is in `lib/`: the app ships no test hook.
class NetworkSwitch {
  NetworkSwitch(this.$);

  final PatrolIntegrationTester $;

  bool _offline = false;
  bool _installed = false;

  void _install() {
    if (_installed) return;
    _installed = true;
    ApiClient().dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (!_offline) return handler.next(options);
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              message: 'Patrol: network switched off',
            ),
          );
        },
      ),
    );
  }

  Future<void> goOffline() async {
    _install();
    _offline = true;
    await $.platformAutomator.mobile.enableAirplaneMode();
  }

  Future<void> goOnline() async {
    // Requests work again before the device reports a network: the app sends
    // on that report, and a send that met a still-failing request would stop
    // and wait for a change that never comes.
    _offline = false;
    await $.platformAutomator.mobile.disableAirplaneMode();
  }
}
