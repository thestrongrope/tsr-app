import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsr_app/main.dart';
import 'package:tsr_platform_app/tsr_platform_app.dart';

class _AlwaysSent implements FeedbackRepository {
  @override
  Future<SendResult> send({required String clientId, required String text}) async => const Sent(1);
}

void main() {
  testWidgets('the shell shows send feedback and a member can send', (tester) async {
    await tester.pumpWidget(TsrApp(feedback: _AlwaysSent()));

    expect(find.text('Send feedback'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('feedback-text')), 'JazakAllah');
    await tester.pump();
    await tester.tap(find.byKey(const Key('feedback-send')));
    await tester.pumpAndSettle();

    expect(find.text('Thank you. Your feedback was sent.'), findsOneWidget);
  });
}
