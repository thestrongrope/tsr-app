import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every decision about what a member may see goes through `Capabilities`.
/// This fails when a screen, route or provider reads the saved permissions
/// itself, which is how the Classes tab and the class list came to disagree.
///
/// Files that may read the permissions answer: the provider that holds it, the
/// model that parses it, and the `capabilities*.dart` files that decide from it.
/// `classes_provider.dart` may build a `Capabilities` from it, because reading
/// `capabilitiesProvider` from inside that provider would be circular.
const _mayReadPermissions = [
  'lib/core/permissions/',
  'lib/core/providers/permissions_provider.dart',
  'lib/core/models/permissions_payload.dart',
];
const _mayImportPayload = [
  ..._mayReadPermissions,
  'lib/features/classes/providers/classes_provider.dart',
];

final _memberRead = RegExp(
  r'payload\s*[?!]?\s*\.\s*(can[A-Z]\w*|has[A-Z]\w*|shows[A-Z]\w*|scopes|navigation|can\()',
);

/// The lines of [source] that read a member of a permissions payload.
List<String> directReads(String source) => [
  for (final line in source.split('\n'))
    if (_memberRead.hasMatch(line) && !line.contains('response.payload'))
      line.trim(),
];

bool _under(String path, List<String> prefixes) =>
    prefixes.any((prefix) => path == prefix || path.startsWith(prefix));

Iterable<File> _libFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('the detector finds a direct read and ignores the allowed shapes', () {
    expect(
      directReads('final ok = state.payload?.canReadReports == true;'),
      isNotEmpty,
    );
    expect(
      directReads('final g = permissions.payload!.scopes.gender;'),
      isNotEmpty,
    );
    expect(directReads('if (ref.read(p).payload.hasClasses) {}'), isNotEmpty);
    expect(
      directReads(
        'final c = Capabilities.of(payload: state.payload, classes: l);',
      ),
      isEmpty,
    );
    expect(directReads('final p = response.payload;'), isEmpty);
    expect(directReads('if (state.payload == null) return;'), isEmpty);
  });

  test('no screen, route or provider reads the permissions payload itself', () {
    final offences = <String>[];
    for (final file in _libFiles()) {
      final path = file.path.replaceAll('\\', '/');
      if (_under(path, _mayReadPermissions)) continue;
      for (final line in directReads(file.readAsStringSync())) {
        offences.add('$path: $line');
      }
    }
    expect(
      offences,
      isEmpty,
      reason:
          'Ask Capabilities (an extension in lib/core/permissions/) instead:\n${offences.join('\n')}',
    );
  });

  test('only the allowed files import the payload type', () {
    final offences = [
      for (final file in _libFiles())
        if (!_under(file.path.replaceAll('\\', '/'), _mayImportPayload) &&
            file.readAsStringSync().contains('permissions_payload.dart'))
          file.path,
    ];
    expect(offences, isEmpty);
  });
}
