import 'package:flutter/services.dart';

/// Blocks screenshots, screen recording and the recent-apps thumbnail for the
/// screen that calls [enable], until [disable] (Android FLAG_SECURE, #693).
/// iOS cannot block screenshots, so there it does nothing; so does any platform
/// with no handler (tests, web, desktop).
class SecureScreen {
  const SecureScreen._();

  static const _channel = MethodChannel('com.thestrongrope/secure_screen');

  static Future<void> enable() => _call('enable');

  static Future<void> disable() => _call('disable');

  static Future<void> _call(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // No handler on this platform.
    } on PlatformException {
      // The flag could not be changed; nothing more to do.
    }
  }
}
