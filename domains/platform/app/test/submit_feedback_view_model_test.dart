import 'package:flutter_test/flutter_test.dart';
import 'package:tsr_platform_app/tsr_platform_app.dart';

class FakeRepository implements FeedbackRepository {
  FakeRepository(this.results);

  final List<SendResult> results;
  final List<String> sentClientIds = [];

  @override
  Future<SendResult> send({required String clientId, required String text}) async {
    sentClientIds.add(clientId);
    return results.removeAt(0);
  }
}

void main() {
  var counter = 0;
  String ids() => 'id-${counter++}';

  test('empty text cannot be sent and never reaches the API', () async {
    final repo = FakeRepository([]);
    final vm = SubmitFeedbackViewModel(repo, clientIds: ids)..updateText('   ');

    await vm.send();

    expect(vm.canSend, isFalse);
    expect(repo.sentClientIds, isEmpty);
  });

  test('text over the limit cannot be sent', () {
    final vm = SubmitFeedbackViewModel(FakeRepository([]), clientIds: ids)
      ..updateText('a' * (SubmitFeedbackViewModel.maxLength + 1));

    expect(vm.canSend, isFalse);
  });

  test('a sent message clears the text and thanks the member', () async {
    final vm = SubmitFeedbackViewModel(FakeRepository([const Sent(7)]), clientIds: ids)
      ..updateText('JazakAllah');

    await vm.send();

    expect(vm.status, SendStatus.sent);
    expect(vm.text, isEmpty);
  });

  test('a retry after no answer reuses the same client id, so it is a safe replay', () async {
    final repo = FakeRepository([const Unreachable(), const Sent(9)]);
    final vm = SubmitFeedbackViewModel(repo, clientIds: ids)..updateText('sent twice');

    await vm.send();
    expect(vm.status, SendStatus.unreachable);
    await vm.send();

    expect(vm.status, SendStatus.sent);
    expect(repo.sentClientIds.toSet(), hasLength(1));
  });

  test('the next message after a sent one gets a new client id', () async {
    final repo = FakeRepository([const Sent(1), const Sent(2)]);
    final vm = SubmitFeedbackViewModel(repo, clientIds: ids)..updateText('first');

    await vm.send();
    vm.updateText('second');
    await vm.send();

    expect(repo.sentClientIds.toSet(), hasLength(2));
  });

  test('a refusal shows the API detail', () async {
    final vm = SubmitFeedbackViewModel(FakeRepository([const Rejected('Sign in required')]), clientIds: ids)
      ..updateText('hello');

    await vm.send();

    expect(vm.status, SendStatus.rejected);
    expect(vm.message, 'Sign in required');
  });
}
