import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../network/api_client.dart';

/// The words a member sees when something fails (#720).
///
/// Never an exception, a status line or markup. The server's own message is
/// used when it sent a short one for a refusal the member can act on ("You do
/// not have permission...", "That date already has a session"), but not for a
/// server fault: a 5xx body can be a gateway's HTML page.
String userMessage(Object error) {
  if (error is ApiException) {
    if (error.isNetworkError) return AppConstants.networkErrorMessage;
    if (error.statusCode == 408) return AppConstants.timeoutErrorMessage;
    if (error.isServerError) return _serverFault;
    return _readable(error.message) ?? AppConstants.genericErrorMessage;
  }
  if (error is TimeoutException) return AppConstants.timeoutErrorMessage;
  if (error is SocketException) return AppConstants.networkErrorMessage;
  if (error is DioException) {
    return userMessage(ApiException.fromDioException(error));
  }
  return AppConstants.genericErrorMessage;
}

const _serverFault =
    'Something went wrong on our side. Please try again in a moment.';

/// [message] if it reads like a sentence for a person: short, no markup.
String? _readable(String message) {
  final text = message.trim();
  if (text.isEmpty || text.length > 200) return null;
  if (text.contains('<') || text.contains('Exception')) return null;
  return text;
}
