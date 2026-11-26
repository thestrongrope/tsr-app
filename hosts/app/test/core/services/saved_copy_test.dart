import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/services/saved_copy.dart';

void main() {
  late Directory dir;
  late Box box;
  var now = DateTime.utc(2026, 10, 1, 12);
  late SavedCopies copies;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('saved_copy_test');
    Hive.init(dir.path);
    box = await Hive.openBox('saved');
    now = DateTime.utc(2026, 10, 1, 12);
    copies = SavedCopies(box, owner: () => 7, clock: () => now);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('a copy just under 7 days old is read', () async {
    await copies.save('k', 'v');
    now = now.add(savedCopyMaxAge - const Duration(seconds: 1));
    expect(copies.read('k'), 'v');
  });

  test('a copy 7 days old or older is not read', () async {
    await copies.save('k', 'v');
    now = now.add(savedCopyMaxAge);
    expect(copies.read('k'), isNull);
  });

  test('saving again replaces the copy and restarts its age', () async {
    await copies.save('k', 'old');
    now = now.add(const Duration(days: 6));
    await copies.save('k', 'new');
    now = now.add(const Duration(days: 6));
    expect(copies.read('k'), 'new');
  });

  test('nothing saved, or a value with no save time, is not read', () async {
    expect(copies.read('missing'), isNull);
    await box.put('plain', 'v');
    expect(copies.read('plain'), isNull);
  });

  group('owner (#761)', () {
    test('a copy is read only by the member who saved it', () async {
      await copies.save('k', 'v');
      expect(
        SavedCopies(box, owner: () => 8, clock: () => now).read('k'),
        isNull,
      );
      expect(copies.read('k'), 'v');
    });

    test('a copy saved with no owner is not read', () async {
      await box.put('k', {'savedAt': now.toIso8601String(), 'data': 'v'});
      expect(copies.read('k'), isNull);
    });

    test('nobody signed in: nothing is saved and nothing is read', () async {
      final guest = SavedCopies(box, owner: () => null, clock: () => now);
      await guest.save('g', 'v');
      expect(box.get('g'), isNull);
      await copies.save('k', 'v');
      expect(guest.read('k'), isNull);
    });
  });

  group('isUnreachable', () {
    test('no connection, timeout and 5xx are', () {
      expect(isUnreachable(const ApiException('x', 0)), isTrue);
      expect(isUnreachable(const ApiException('x', 408)), isTrue);
      expect(isUnreachable(const ApiException('x', 503)), isTrue);
    });

    test('a refusal is not', () {
      expect(isUnreachable(const ApiException('x', 401)), isFalse);
      expect(isUnreachable(const ApiException('x', 403)), isFalse);
      expect(isUnreachable(const ApiException('x', 404)), isFalse);
    });

    test('a raw Dio failure is judged the same way', () {
      final request = RequestOptions(path: '/x');
      expect(
        isUnreachable(
          DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          ),
        ),
        isTrue,
      );
      expect(
        isUnreachable(
          DioException(
            requestOptions: request,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: request, statusCode: 403),
          ),
        ),
        isFalse,
      );
    });

    test('anything else is not', () {
      expect(isUnreachable(Exception('parse failure')), isFalse);
    });
  });
}
