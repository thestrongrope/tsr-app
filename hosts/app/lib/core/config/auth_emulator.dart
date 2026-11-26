/// Where the Firebase Auth Emulator listens, from
/// `--dart-define=TSR_AUTH_EMULATOR_HOST=127.0.0.1:9099` (debug builds only).
///
/// Returns null when no value is given. Throws [StateError] for any value in a
/// release build, whatever it says, so a build that talks to an emulator can
/// never ship; and for a value that is not `host:port`.
({String host, int port})? authEmulatorTarget({
  required bool release,
  String value = const String.fromEnvironment('TSR_AUTH_EMULATOR_HOST'),
}) {
  if (value.isEmpty) return null;

  if (release) {
    throw StateError('TSR_AUTH_EMULATOR_HOST is set in a release build.');
  }

  final parts = value.split(':');
  final port = parts.length == 2 ? int.tryParse(parts[1]) : null;
  if (parts[0].isEmpty || port == null || port < 1 || port > 65535) {
    throw StateError(
      'TSR_AUTH_EMULATOR_HOST must be host:port, for example 127.0.0.1:9099.',
    );
  }
  return (host: parts[0], port: port);
}
