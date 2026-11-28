import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/whatsapp_link.dart';

/// API calls behind the WhatsApp link (#693). The server checks `whatsapp:manage`
/// and rate-limits; hiding the controls is a courtesy. The QR code is returned to
/// the caller and kept nowhere: not here, not in a provider, not on disk.
class WhatsappLinkRepository {
  final ApiClient _apiClient;

  WhatsappLinkRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<WhatsappLinkStatus> getStatus() async => WhatsappLinkStatus.fromJson(
    await _apiClient.get<dynamic>(AppConstants.adminWhatsappLinkEndpoint),
  );

  Future<WhatsappLinkQr> getQr() async => WhatsappLinkQr.fromJson(
    await _apiClient.get<dynamic>(AppConstants.adminWhatsappLinkQrEndpoint),
  );

  /// Clears the current session; a new code follows.
  Future<void> relink() async {
    await _apiClient.post<dynamic>(AppConstants.adminWhatsappRelinkEndpoint);
  }

  /// Ends the session on WhatsApp's side as well.
  Future<void> logout() async {
    await _apiClient.post<dynamic>(AppConstants.adminWhatsappLogoutEndpoint);
  }
}

/// What to tell the admin when a link call fails: the server's own words (the
/// retry message, the rate limit, a failed change), a generic line otherwise.
String whatsappLinkErrorWords(Object error) => error is ApiException
    ? error.message
    : 'Something went wrong. Please try again.';
