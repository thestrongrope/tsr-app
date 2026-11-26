import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/entity_cards.dart';

/// API calls behind the Student and Subscriber cards (#557). The server decides
/// who may see whom; hiding a screen is a courtesy. A person that does not exist
/// and one the caller may not see are the same 404 (`ApiException`).
class MembersRepository {
  final ApiClient _apiClient;

  MembersRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<StudentCard> getStudent(int token) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.studentEndpoint(token),
    );
    return StudentCard.fromJson(body);
  }

  Future<SubscriberCard> getSubscriber(int token) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.subscriberEndpoint(token),
    );
    return SubscriberCard.fromJson(body);
  }
}
