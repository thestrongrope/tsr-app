import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/reports/models/unplaced_registrations.dart';
import 'package:the_strong_rope/features/reports/providers/reports_provider.dart';
import 'package:the_strong_rope/features/reports/screens/registrations_screen.dart';

class _FixedPermissions extends PermissionsNotifier {
  _FixedPermissions(List<String> permissions) {
    state = PermissionsState(
      payload: PermissionsPayload(
        version: 4,
        permissions: permissions,
        scopes: const PermissionScopes(gender: 1),
        issuedAt: '',
      ),
    );
  }
}

const _ali = Registrant(
  id: 9,
  token: 1002,
  email: 'ali@example.test',
  mobile: '+971500000000',
  profession: 'Engineer',
  birthYear: 1990,
  interests: '["Research","Teaching"]',
  name: 'Ali Raza',
  city: 'Dubai',
  country: 'AE',
  preferredLocation: 'Online',
  requestedClass: 'A1',
  status: 'Accepted',
  registeredOn: '2026-10-02',
);

const _zayd = Registrant(
  id: 8,
  name: 'Zayd Khan',
  city: 'Mumbai',
  country: 'IN',
  preferredLocation: '',
  requestedClass: '',
  status: 'Pending',
  registeredOn: '2026-09-20',
);

UnplacedRegistrations _data({
  List<Registrant> registrants = const [_ali, _zayd],
}) => UnplacedRegistrations(gender: 1, registrants: registrants);

const _a1 = PlacementClass(
  id: 10,
  code: 'A1',
  level: 'Primary',
  teacher: 'Fatima',
  location: 'Dubai',
  students: 12,
);

Widget _wrap(
  Future<UnplacedRegistrations> Function(int?) load, {
  List<String> permissions = const ['registrations:read:gender'],
  Future<List<PlacementClass>> Function(int)? classes,
  PlaceRegistrant? place,
  RejectRegistrant? reject,
  ShareRegistrations? share,
  ShareRegistrations? shareAllocated,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      permissionsProvider.overrideWith((ref) => _FixedPermissions(permissions)),
      registrationsProvider.overrideWith((ref, gender) => load(gender)),
      if (classes != null)
        registrationClassesProvider.overrideWith((ref, id) => classes(id)),
      if (place != null) placeRegistrantProvider.overrideWithValue(place),
      if (reject != null) rejectRegistrantProvider.overrideWithValue(reject),
      if (share != null) shareRegistrationsProvider.overrideWithValue(share),
      if (shareAllocated != null)
        shareAllocatedRegistrationsProvider.overrideWithValue(shareAllocated),
    ],
    child: const MaterialApp(home: Scaffold(body: RegistrationsScreen())),
  );
}

String _daysAgo(int days) => DateTime.now()
    .subtract(Duration(days: days))
    .toIso8601String()
    .substring(0, 10);

void main() {
  testWidgets('lists who is waiting, newest first, with what placing needs', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _data()));
    await tester.pumpAndSettle();

    expect(find.text('2 waiting to be placed'), findsOneWidget);
    expect(find.text('Ali Raza'), findsOneWidget);
    expect(find.text('Dubai, AE'), findsOneWidget);
    expect(find.text('Prefers Online · Asked for A1'), findsOneWidget);
    expect(find.text('Accepted · registered 2026-10-02'), findsOneWidget);
    // Zayd gave no preference and asked for no class: no such line.
    expect(find.text('Pending · registered 2026-09-20'), findsOneWidget);
    expect(find.textContaining('Prefers'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Ali Raza')).dy,
      lessThan(tester.getTopLeft(find.text('Zayd Khan')).dy),
    );
  });

  testWidgets('searching narrows by name or place, and says when none match', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _data()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'mumbai');
    await tester.pumpAndSettle();
    expect(find.text('Zayd Khan'), findsOneWidget);
    expect(find.text('Ali Raza'), findsNothing);
    expect(find.text('1 of 2 waiting to be placed'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No one matches your search.'), findsOneWidget);
  });

  testWidgets('New class is offered only with classes:create', (tester) async {
    await tester.pumpWidget(_wrap((_) async => _data()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('New class'), findsNothing);

    await tester.pumpWidget(
      _wrap(
        (_) async => _data(),
        permissions: const [
          'registrations:read:gender',
          'classes:create:gender',
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('New class'), findsOneWidget);
  });

  testWidgets('nobody waiting says so', (tester) async {
    await tester.pumpWidget(_wrap((_) async => _data(registrants: [])));
    await tester.pumpAndSettle();

    expect(find.text('Nobody is waiting to be placed.'), findsOneWidget);
  });

  testWidgets('only someone who reaches both genders chooses one', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _data()));
    await tester.pumpAndSettle();
    expect(find.text('Ladies'), findsNothing);

    final asked = <int?>[];
    await tester.pumpWidget(
      _wrap((gender) async {
        asked.add(gender);
        return _data();
      }, permissions: const ['registrations:read:all']),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ladies'));
    await tester.pumpAndSettle();

    expect(asked, [null, 2]);
  });

  testWidgets('a failed load offers a retry that loads again', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap((_) async {
        calls++;
        if (calls == 1) throw Exception('boom');
        return _data();
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('The registrations could not be loaded.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Ali Raza'), findsOneWidget);
  });

  testWidgets('Details shows what the web details panel shows', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap((_) async => _data()));
    await tester.pumpAndSettle();
    expect(find.text('ali@example.test'), findsNothing);

    await tester.tap(find.text('Details').first);
    await tester.pumpAndSettle();

    expect(find.text('ali@example.test'), findsOneWidget);
    expect(find.text('+971500000000'), findsOneWidget);
    expect(find.text('Engineer'), findsOneWidget);
    expect(find.text('1002'), findsOneWidget);
    expect(find.text('Research, Teaching'), findsOneWidget);
    expect(find.text('1990 / ${DateTime.now().year - 1990}'), findsOneWidget);
    await tester.tap(find.text('Hide details'));
    await tester.pumpAndSettle();
    expect(find.text('ali@example.test'), findsNothing);
  });

  testWidgets('the period narrows the list, and searching sets it aside', (
    tester,
  ) async {
    final recent = Registrant(
      id: 1,
      name: 'Recent Rana',
      city: '',
      country: '',
      preferredLocation: '',
      requestedClass: '',
      status: 'Pending',
      registeredOn: _daysAgo(10),
    );
    final old = Registrant(
      id: 2,
      name: 'Older Omar',
      city: '',
      country: '',
      preferredLocation: '',
      requestedClass: '',
      status: 'Pending',
      registeredOn: _daysAgo(400),
    );
    await tester.pumpWidget(
      _wrap((_) async => _data(registrants: [recent, old])),
    );
    await tester.pumpAndSettle();
    expect(find.text('Older Omar'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 3 months').last);
    await tester.pumpAndSettle();
    expect(find.text('Recent Rana'), findsOneWidget);
    expect(find.text('Older Omar'), findsNothing);

    await tester.enterText(find.byType(TextField), 'older');
    await tester.pumpAndSettle();
    expect(find.text('Older Omar'), findsOneWidget);
  });

  testWidgets('Place offers the classes, places, and reloads the list', (
    tester,
  ) async {
    var loads = 0;
    final placed = <(int, int)>[];
    await tester.pumpWidget(
      _wrap(
        (_) async {
          loads++;
          return _data();
        },
        classes: (_) async => const [_a1],
        place: (id, classId) async => placed.add((id, classId)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Place').first);
    await tester.pumpAndSettle();
    expect(find.text('Place Ali Raza'), findsOneWidget);
    expect(find.text('A1 · Primary'), findsOneWidget);
    expect(find.text('Fatima · Dubai · 12 students'), findsOneWidget);

    await tester.tap(find.text('A1 · Primary'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Place').last);
    await tester.pumpAndSettle();

    expect(placed, [(9, 10)]);
    expect(loads, 2);
    expect(find.text('Ali Raza placed in A1.'), findsOneWidget);
  });

  testWidgets('Place stays disabled until a class is chosen', (tester) async {
    await tester.pumpWidget(
      _wrap((_) async => _data(), classes: (_) async => const [_a1]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Place').first);
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Place').last,
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('with no class to place them in, it says so', (tester) async {
    await tester.pumpWidget(
      _wrap((_) async => _data(), classes: (_) async => const []),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Place').first);
    await tester.pumpAndSettle();

    expect(
      find.text('There is no class you can place them in.'),
      findsOneWidget,
    );
  });

  testWidgets('someone already placed elsewhere closes the sheet and reloads', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      _wrap(
        (_) async {
          loads++;
          return _data();
        },
        classes: (_) async => const [_a1],
        place: (_, _) async => throw const ApiException(
          'This registrant is no longer waiting: they have been placed or rejected.',
          409,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Place').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('A1 · Primary'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Place').last);
    await tester.pumpAndSettle();

    expect(find.text('Place Ali Raza'), findsNothing);
    expect(
      find.text(
        'This registrant is no longer waiting: they have been placed or rejected.',
      ),
      findsOneWidget,
    );
    expect(loads, 2);
  });

  testWidgets('a refusal to place keeps the sheet open with the reason', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      _wrap(
        (_) async {
          loads++;
          return _data();
        },
        classes: (_) async => const [_a1],
        place: (_, _) async => throw const ApiException(
          'Could not place them: their gender does not match this class.',
          422,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Place').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('A1 · Primary'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Place').last);
    await tester.pumpAndSettle();

    expect(find.text('Place Ali Raza'), findsOneWidget);
    expect(
      find.text(
        'Could not place them: their gender does not match this class.',
      ),
      findsOneWidget,
    );
    expect(loads, 1, reason: 'nothing changed, so no reload');
  });

  testWidgets('any other failure to place says to try again', (tester) async {
    await tester.pumpWidget(
      _wrap(
        (_) async => _data(),
        classes: (_) async => const [_a1],
        place: (_, _) async => throw Exception('boom'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Place').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('A1 · Primary'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Place').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Place Ali Raza'), findsOneWidget);
  });

  testWidgets('classes that fail to load offer a retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        (_) async => _data(),
        classes: (_) async {
          calls++;
          if (calls == 1) throw Exception('boom');
          return const [_a1];
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Place').first);
    await tester.pumpAndSettle();
    expect(find.text('The classes could not be loaded.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('A1 · Primary'), findsOneWidget);
  });

  testWidgets('Reject is for whoever may reject, and no one else', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap((_) async => _data()));
    await tester.pumpAndSettle();
    expect(find.text('Reject'), findsNothing);

    await tester.pumpWidget(
      _wrap(
        (_) async => _data(),
        permissions: const [
          'registrations:read:all',
          'registrations:reject:all',
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reject'), findsNWidgets(2));
  });

  testWidgets('Reject needs a reason, sends it trimmed, and reloads', (
    tester,
  ) async {
    var loads = 0;
    final rejected = <(int, String)>[];
    await tester.pumpWidget(
      _wrap(
        (_) async {
          loads++;
          return _data();
        },
        permissions: const [
          'registrations:read:all',
          'registrations:reject:all',
        ],
        reject: (id, reason) async => rejected.add((id, reason)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject').first);
    await tester.pumpAndSettle();
    expect(find.text('Reject Ali Raza'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Reject'))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField).last, '  Duplicate ');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();

    expect(rejected, [(9, 'Duplicate')]);
    expect(loads, 2);
    expect(find.text('Ali Raza rejected.'), findsOneWidget);
  });

  testWidgets('a failed reject keeps the dialog open with the reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        (_) async => _data(),
        permissions: const [
          'registrations:read:all',
          'registrations:reject:all',
        ],
        reject: (_, _) async => throw const ApiException(
          'You do not have permission to do that',
          403,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'x');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();

    expect(find.text('Reject Ali Raza'), findsOneWidget);
    expect(find.text('You do not have permission to do that'), findsOneWidget);
  });

  testWidgets('Share offers Excel and PDF for the list', (tester) async {
    final shared = <(int?, ReportFormat)>[];
    await tester.pumpWidget(
      _wrap(
        (_) async => _data(),
        share: (gender, format) async => shared.add((gender, format)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share as Excel'));
    await tester.pumpAndSettle();

    expect(shared, [(null, ReportFormat.xlsx)]);
  });

  testWidgets(
    'the placed registrations file is offered even when nobody waits',
    (tester) async {
      final shared = <(int?, ReportFormat)>[];
      await tester.pumpWidget(
        _wrap(
          (_) async => _data(registrants: const []),
          shareAllocated: (gender, format) async =>
              shared.add((gender, format)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Share'), findsNothing);
      await tester.tap(find.byTooltip('Placed in a class'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Placed, as PDF'));
      await tester.pumpAndSettle();

      expect(shared, [(null, ReportFormat.pdf)]);
    },
  );

  testWidgets('a file that cannot be prepared says so and changes nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        (_) async => _data(),
        share: (_, _) async => throw Exception('boom'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share as PDF'));
    await tester.pumpAndSettle();

    expect(
      find.text('The file could not be prepared. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Ali Raza'), findsOneWidget);
  });
}
