import 'package:tsr_shared_app/tsr_shared_app.dart';

/// What happened to one send.
sealed class SendResult {
  const SendResult();
}

/// Stored (or already stored: a replay returns the same id).
final class Sent extends SendResult {
  const Sent(this.id);
  final int id;
}

/// The API refused it (401, 403, 422); [detail] is the API's own words.
final class Rejected extends SendResult {
  const Rejected(this.detail);
  final String detail;
}

/// No answer: offline, timeout, server error. Safe to retry with the same client id.
final class Unreachable extends SendResult {
  const Unreachable();
}

/// Data layer for send feedback (Flutter's architecture guide). An interface because its real
/// implementation crosses an external boundary (HTTP); tests use a fake.
abstract interface class FeedbackRepository {
  Future<SendResult> send({required String clientId, required String text});
}

/// Calls POST /feedback (domains/platform/spec/api.yaml).
class ApiFeedbackRepository implements FeedbackRepository {
  ApiFeedbackRepository(this._api);

  final ApiClient _api;

  @override
  Future<SendResult> send({required String clientId, required String text}) async {
    try {
      final response = await _api.postJson('/feedback', {'clientId': clientId, 'text': text});
      if (response.isSuccess) {
        return Sent(response.json?['id'] as int? ?? 0);
      }
      if (response.statusCode >= 500) {
        return const Unreachable();
      }
      return Rejected(response.detail ?? 'Could not send');
    } on Exception {
      return const Unreachable();
    }
  }
}
