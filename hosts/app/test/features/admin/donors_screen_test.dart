import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/admin/models/donors.dart';
import 'package:the_strong_rope/features/admin/providers/donors_provider.dart';
import 'package:the_strong_rope/features/admin/screens/donors_screen.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart'
    show ReportFormat;

const _ali = Donor(
  name: 'Ali Raza',
  email: 'ali@example.test',
  mobile: '+971500000000',
  city: 'Dubai',
  state: '',
  country: 'AE',
  zip: '',
);

const _zayd = Donor(
  name: 'Zayd Khan',
  email: 'zayd@example.test',
  mobile: '+919800000000',
  city: 'Mumbai',
  state: 'MH',
  country: 'IN',
  zip: '400001',
);

Widget _wrap(Future<List<Donor>> Function() load, {ShareDonors? share}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      donorsProvider.overrideWith((ref) => load()),
      if (share != null) shareDonorsProvider.overrideWithValue(share),
    ],
    child: const MaterialApp(home: DonorsScreen()),
  );
}

void main() {
  testWidgets('lists the donors with their details and a count', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(() async => [_ali, _zayd]));
    await tester.pumpAndSettle();

    expect(find.text('2 donors'), findsOneWidget);
    expect(find.text('Ali Raza'), findsOneWidget);
    expect(find.textContaining('ali@example.test'), findsOneWidget);
    expect(find.textContaining('Mumbai, MH, IN 400001'), findsOneWidget);
  });

  testWidgets('search narrows by any column, and says when none match', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(() async => [_ali, _zayd]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '400001');
    await tester.pumpAndSettle();
    expect(find.text('Zayd Khan'), findsOneWidget);
    expect(find.text('Ali Raza'), findsNothing);
    expect(find.text('1 of 2 donors'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ali@example');
    await tester.pumpAndSettle();
    expect(find.text('Ali Raza'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No donor matches your search.'), findsOneWidget);
  });

  testWidgets('no donors says so and offers no file', (tester) async {
    await tester.pumpWidget(_wrap(() async => []));
    await tester.pumpAndSettle();

    expect(find.text('There are no donors.'), findsOneWidget);
    expect(find.byTooltip('Share'), findsNothing);
  });

  testWidgets('Share hands the chosen format to the file download', (
    tester,
  ) async {
    final shared = <ReportFormat>[];
    await tester.pumpWidget(
      _wrap(() async => [_ali], share: (format) async => shared.add(format)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share as PDF'));
    await tester.pumpAndSettle();

    expect(shared, [ReportFormat.pdf]);
  });

  testWidgets('a file that cannot be prepared says so', (tester) async {
    await tester.pumpWidget(
      _wrap(() async => [_ali], share: (_) async => throw Exception('offline')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share as Excel'));
    await tester.pumpAndSettle();

    expect(
      find.text('The file could not be prepared. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Ali Raza'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry that loads again', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap(() async {
        calls++;
        if (calls == 1) throw Exception('offline');
        return [_ali];
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('The donors could not be loaded.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Ali Raza'), findsOneWidget);
  });
}
