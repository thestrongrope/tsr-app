// `/admin/whatsapp/link*` (#693): the state of the WhatsApp link and its QR code.
//
// Strict about the envelope: a body that is not this answer throws, so the
// screen offers a retry.

import '../../../core/utils/api_datetime.dart';

enum WhatsappLinkState { connected, waiting, offline }

/// Connected, waiting for a scan, or offline.
class WhatsappLinkStatus {
  const WhatsappLinkStatus({required this.state, this.lastSeen});

  final WhatsappLinkState state;

  /// When the link was last connected, if the service knows.
  final DateTime? lastSeen;

  bool get isConnected => state == WhatsappLinkState.connected;

  factory WhatsappLinkStatus.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('whatsapp link: unexpected response');
    }
    final state = switch (json['state']) {
      'connected' => WhatsappLinkState.connected,
      'waiting' => WhatsappLinkState.waiting,
      'offline' => WhatsappLinkState.offline,
      _ => throw const FormatException('whatsapp link: unknown state'),
    };
    final seen = json['lastSeen'];
    return WhatsappLinkStatus(
      state: state,
      lastSeen: seen is String ? parseApiLocalDateTime(seen) : null,
    );
  }
}

/// The current QR code. A live credential: whoever scans it controls the linked
/// WhatsApp account. It is held in memory by the screen showing it and nowhere
/// else; [toString] hides the code so a log line cannot leak it.
class WhatsappLinkQr {
  const WhatsappLinkQr({
    required this.code,
    required this.ageSeconds,
    required this.validSeconds,
  });

  /// The code to draw; null when there is none yet or the server withheld a stale one.
  final String? code;

  /// How old the code was when the server answered.
  final int? ageSeconds;

  /// How long a code stays scannable.
  final int validSeconds;

  factory WhatsappLinkQr.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('whatsapp qr: unexpected response');
    }
    final code = json['qr'];
    final valid = json['validSeconds'];
    if (valid is! num) {
      throw const FormatException('whatsapp qr: unexpected response');
    }
    return WhatsappLinkQr(
      code: code is String && code.isNotEmpty ? code : null,
      ageSeconds: (json['ageSeconds'] as num?)?.toInt(),
      validSeconds: valid.toInt(),
    );
  }

  @override
  String toString() => 'WhatsappLinkQr(hidden)';
}
