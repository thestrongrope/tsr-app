import 'package:flutter_test/flutter_test.dart';
import 'package:tsr_shared_app/tsr_shared_app.dart';

void main() {
  test('client ids are version 4 UUIDs the API accepts', () {
    final id = newClientId();

    expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(id.length, lessThanOrEqualTo(36));
  });

  test('client ids do not repeat', () {
    final ids = {for (var i = 0; i < 1000; i++) newClientId()};

    expect(ids.length, 1000);
  });
}
