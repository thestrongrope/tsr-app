import 'package:flutter/foundation.dart';
import 'package:tsr_shared_app/tsr_shared_app.dart';

import 'feedback_repository.dart';

enum SendStatus { idle, sending, sent, rejected, unreachable }

/// Screen logic only: what to show and when sending is allowed. The rules (who may send, the
/// real length limit) are the API's; the quick length check here only saves a round trip, and
/// the API always checks again.
class SubmitFeedbackViewModel extends ChangeNotifier {
  SubmitFeedbackViewModel(this._repository, {String Function() clientIds = newClientId})
      : _clientIds = clientIds;

  /// Same limit as the API (domains/platform/spec/api.yaml), counted the same way (code points).
  static const int maxLength = 2000;

  final FeedbackRepository _repository;
  final String Function() _clientIds;

  String _text = '';
  String? _clientId;
  SendStatus _status = SendStatus.idle;
  String? _message;

  String get text => _text;
  SendStatus get status => _status;
  String? get message => _message;

  bool get canSend {
    final length = _text.trim().runes.length;
    return _status != SendStatus.sending && length > 0 && length <= maxLength;
  }

  void updateText(String value) {
    _text = value;
    if (_status != SendStatus.sending) {
      _status = SendStatus.idle;
      _message = null;
    }
    notifyListeners();
  }

  Future<void> send() async {
    if (!canSend) {
      return;
    }
    // One id per message, kept until it is stored, so a retry after a lost reply is a replay.
    _clientId ??= _clientIds();
    _status = SendStatus.sending;
    notifyListeners();

    final result = await _repository.send(clientId: _clientId!, text: _text.trim());
    switch (result) {
      case Sent():
        _status = SendStatus.sent;
        _message = 'Thank you. Your feedback was sent.';
        _text = '';
        _clientId = null;
      case Rejected(:final detail):
        _status = SendStatus.rejected;
        _message = detail;
      case Unreachable():
        _status = SendStatus.unreachable;
        _message = 'Could not reach the server. Try again.';
    }
    notifyListeners();
  }
}
