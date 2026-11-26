import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/whatsapp_reminders.dart';

/// API calls behind the WhatsApp reminders admin (#418). The server checks
/// `whatsapp:manage`; hiding the screen is a courtesy. A refusal arrives as an
/// `ApiException` carrying the notifier's own words: 400 for a setting that is
/// not valid (nothing saved), 409 for a run already going, a reminder switched
/// off or WhatsApp not linked, 502 when the reminder service cannot be reached.
class WhatsappRemindersRepository {
  final ApiClient _apiClient;

  WhatsappRemindersRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<WhatsappReminder>> getReminders() async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.adminWhatsappRemindersEndpoint,
    );
    return WhatsappReminder.listFromJson(body);
  }

  /// Saves [fields] (the server's camelCase names: `lang`, `leewayDays`,
  /// `sendTime`, `scheduleOn`...) and returns the reminder as it now is.
  Future<WhatsappReminder> updateReminder(
    int id,
    Map<String, dynamic> fields,
  ) async {
    final body = await _apiClient.put<dynamic>(
      AppConstants.adminWhatsappReminderEndpoint(id),
      data: fields,
    );
    return WhatsappReminder.oneFromJson(body);
  }

  /// Recent runs, newest first; [reminderId] narrows them to one reminder.
  Future<List<WhatsappRun>> getRuns({int? reminderId, int limit = 20}) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.adminWhatsappRunsEndpoint,
      queryParameters: {'limit': limit, 'reminderId': ?reminderId},
    );
    return WhatsappRun.listFromJson(body);
  }

  Future<WhatsappRunDetail> getRun(int id) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.adminWhatsappRunEndpoint(id),
    );
    return WhatsappRunDetail.fromJson(body);
  }

  /// Starts a run and returns its id. A dry run unless [dryRun] is false: it
  /// previews who would be messaged and sends nothing.
  Future<int> startRun(int reminderId, {bool dryRun = true}) async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.adminWhatsappReminderRunEndpoint(reminderId),
      data: {'dryRun': dryRun},
    );
    final runId = body is Map<String, dynamic> ? body['runId'] : null;
    if (runId is! num) {
      throw const FormatException('whatsapp run: unexpected response');
    }
    return runId.toInt();
  }

  /// Sends one real message to one number; recorded as a run.
  Future<void> sendTest({
    required String mobile,
    required String message,
  }) async {
    await _apiClient.post<dynamic>(
      AppConstants.adminWhatsappTestEndpoint,
      data: {'mobile': mobile, 'message': message},
    );
  }
}

/// What to tell the admin when a reminder call fails: the server's own words for
/// a refusal (the setting that was not valid, the run already going, WhatsApp not
/// linked), a generic line for anything else.
String whatsappErrorWords(Object error) => error is ApiException
    ? error.message
    : 'Something went wrong. Please try again.';
