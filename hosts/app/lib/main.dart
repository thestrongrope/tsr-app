import 'package:flutter/material.dart';
import 'package:tsr_platform_app/tsr_platform_app.dart';
import 'package:tsr_shared_app/tsr_shared_app.dart';

// The shell: wiring only. It builds the shared API client and hands each domain package what it
// needs. No screen and no rule lives here.
//
// Local run against the dev stack (docker-compose.dev.yml):
//   flutter run --dart-define=TSR_API_BASE_URL=http://10.0.2.2:8088   (Android emulator)
//   flutter run --dart-define=TSR_API_BASE_URL=http://localhost:8088   (iOS simulator)
// TSR_DEV_TOKEN is a synthetic member from db/synthetic/seed.sql; the dev header is accepted only
// by an API running in Development. Production sign-in (Firebase) is not in this sample yet.

const _baseUrl = String.fromEnvironment('TSR_API_BASE_URL', defaultValue: 'http://localhost:8088');
const _devToken = String.fromEnvironment('TSR_DEV_TOKEN', defaultValue: '900001');

void main() {
  final api = ApiClient(
    baseUrl: Uri.parse(_baseUrl),
    authHeaders: () => {'X-Dev-Token': _devToken},
  );
  runApp(TsrApp(feedback: ApiFeedbackRepository(api)));
}

class TsrApp extends StatelessWidget {
  const TsrApp({super.key, required this.feedback});

  final FeedbackRepository feedback;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Strong Rope',
      theme: tsrTheme(),
      home: SubmitFeedbackView(viewModel: SubmitFeedbackViewModel(feedback)),
    );
  }
}
