import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/utils/share_bytes.dart';

void main() {
  test(
    'in a browser the file is saved under its name; no temporary folder and no share sheet is asked for',
    () async {
      // Outside a browser the save writes to the path it is given, so the test
      // can read the file back. No plugin is registered here: asking for the
      // temporary folder or the share sheet would throw.
      final folder = await Directory.systemTemp.createTemp('share_bytes_test');
      addTearDown(() => folder.delete(recursive: true));
      final name = '${folder.path}/Donors.xlsx';

      await shareBytes([1, 2, 3], name, isWeb: true);

      expect(await File(name).readAsBytes(), [1, 2, 3]);
    },
  );

  test('a file name says what kind of file it is', () {
    expect(mimeTypeOf('Donors.xlsx'), contains('spreadsheetml'));
    expect(mimeTypeOf('MCQ_7.pdf'), 'application/pdf');
    expect(mimeTypeOf('Conduction-all-weeks-3-2026.csv'), 'text/csv');
    expect(mimeTypeOf('unknown.bin'), 'application/octet-stream');
  });
}
