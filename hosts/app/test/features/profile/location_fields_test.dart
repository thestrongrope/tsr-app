import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/profile/models/geo.dart';
import 'package:the_strong_rope/features/profile/providers/geo_provider.dart';
import 'package:the_strong_rope/features/profile/repositories/geo_repository.dart';
import 'package:the_strong_rope/features/profile/widgets/location_fields.dart';

class _FakeGeo extends GeoRepository {
  bool failLookups = false;
  bool failCountries = false;
  final lookups = <String>[];

  @override
  Future<List<GeoCountry>> countries() async {
    if (failCountries) throw Exception('offline');
    return const [
      GeoCountry(code: 'IN', name: 'India', hasPostalCodes: true),
      GeoCountry(code: 'TZ', name: 'Tanzania', hasPostalCodes: false),
    ];
  }

  @override
  Future<GeoPostalResult?> postal(String countryCode, String code) async {
    lookups.add('$countryCode $code');
    if (failLookups) throw Exception('offline');
    return switch (code) {
      '400001' => const GeoPostalResult(city: 'Mumbai', state: 'Maharashtra'),
      '110001' => const GeoPostalResult(city: 'New Delhi', state: 'Delhi'),
      // Like the UAE's: a city but no state, so State must stay editable.
      '28119' => const GeoPostalResult(city: 'Al Ras'),
      _ => null,
    };
  }

  @override
  Future<List<GeoCity>> cities(String countryCode, String query) async {
    if (failLookups) throw Exception('offline');
    return const [
      GeoCity(name: 'Dar es Salaam', state: 'Dar es Salaam Region'),
    ];
  }
}

void main() {
  late _FakeGeo geo;
  late TextEditingController country, zip, state, city;
  late List<String> changes;
  late List<String?> problems;

  setUp(() {
    geo = _FakeGeo();
    country = TextEditingController();
    zip = TextEditingController();
    state = TextEditingController();
    city = TextEditingController();
    changes = [];
    problems = [];
  });

  /// What blocks saving right now (null: nothing).
  String? blocking() => problems.isEmpty ? null : problems.last;

  /// Whether the field with this label accepts typing.
  bool enabled(WidgetTester tester, String label) => tester
      .widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, label),
          matching: find.byType(TextField),
        ),
      )
      .enabled!;

  Future<void> enterPostalCode(WidgetTester tester, String code) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Postal code'),
      code,
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  /// Type [typed] in the country field, then tap [name] in the list under it.
  Future<void> pickCountry(
    WidgetTester tester,
    String typed,
    String name,
  ) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Country'),
      typed,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  Future<void> pumpFields(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [geoRepositoryProvider.overrideWithValue(geo)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LocationFields(
                country: country,
                zip: zip,
                state: state,
                city: city,
                onChanged: (f, v) => changes.add('${f.name}=$v'),
                onProblemChanged: problems.add,
                decoration: (label, icon, {hint}) =>
                    InputDecoration(labelText: label),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty country is preselected from the device locale', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('en', 'IN');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    await pumpFields(tester);

    expect(country.text, 'India');
    expect(changes, contains('country=India'));
  });

  testWidgets('a country the member already has is left alone', (tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('en', 'IN');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    country.text = 'Indai';

    await pumpFields(tester);

    expect(country.text, 'Indai');
  });

  testWidgets(
    'a postal code that matches fills State and City and locks them',
    (tester) async {
      country.text = 'India';
      await pumpFields(tester);
      expect(enabled(tester, 'State/Province'), isTrue, reason: 'no code yet');

      await enterPostalCode(tester, '400001');

      expect(geo.lookups, ['IN 400001']);
      expect(state.text, 'Maharashtra');
      expect(city.text, 'Mumbai');
      expect(changes, containsAll(['state=Maharashtra', 'city=Mumbai']));
      expect(enabled(tester, 'State/Province'), isFalse);
      expect(enabled(tester, 'City'), isFalse);
      expect(blocking(), isNull);
      expect(
        find.textContaining('Filled in from your postal code'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'editing the code locks State and City at once, before it is checked',
    (tester) async {
      country.text = 'India';
      state.text = 'Maharashtra';
      city.text = 'Pune';
      await pumpFields(tester);
      expect(enabled(tester, 'City'), isTrue);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Postal code'),
        '4000',
      );
      await tester.pump(); // before the lookup runs

      expect(enabled(tester, 'State/Province'), isFalse);
      expect(enabled(tester, 'City'), isFalse);
      expect(find.textContaining('Checking the postal code'), findsOneWidget);
    },
  );

  testWidgets(
    'a new postal code that matches replaces what was typed or stored',
    (tester) async {
      country.text = 'India';
      state.text = 'Maharashtra';
      city.text = 'Bombay'; // people spell things differently: the data wins
      await pumpFields(tester);

      await enterPostalCode(tester, '400001');

      expect(city.text, 'Mumbai');
      expect(enabled(tester, 'City'), isFalse);
    },
  );

  testWidgets(
    'a code that does not match frees State and City, keeps what was there and says so',
    (tester) async {
      country.text = 'India';
      state.text = 'Gujarat';
      city.text = 'Surat';
      await pumpFields(tester);

      await enterPostalCode(tester, '999999');

      expect(state.text, 'Gujarat', reason: 'nothing to replace it with');
      expect(city.text, 'Surat');
      expect(enabled(tester, 'State/Province'), isTrue);
      expect(enabled(tester, 'City'), isTrue);
      expect(
        blocking(),
        isNull,
        reason: 'the postal code is a helper, not a rule',
      );
      expect(
        find.textContaining('We do not have that postal code'),
        findsOneWidget,
      );
    },
  );

  testWidgets('clearing the code frees State and City and keeps their values', (
    tester,
  ) async {
    country.text = 'India';
    await pumpFields(tester);
    await enterPostalCode(tester, '400001');

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Postal code'),
      '',
    );
    await tester.pumpAndSettle();

    expect(enabled(tester, 'State/Province'), isTrue);
    expect(enabled(tester, 'City'), isTrue);
    expect(state.text, 'Maharashtra');
    expect(city.text, 'Mumbai');
    expect(blocking(), isNull);
  });

  testWidgets(
    'a failed lookup frees State and City, keeps their values and says so',
    (tester) async {
      country.text = 'India';
      state.text = 'Gujarat';
      city.text = 'Surat';
      geo.failLookups = true;
      await pumpFields(tester);

      await enterPostalCode(tester, '400001');

      expect(state.text, 'Gujarat');
      expect(city.text, 'Surat');
      expect(enabled(tester, 'State/Province'), isTrue);
      expect(enabled(tester, 'City'), isTrue);
      expect(blocking(), isNull);
      expect(
        find.textContaining('Could not check the postal code'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a code whose data has no state leaves State editable, so it can be filled',
    (tester) async {
      country.text = 'India';
      await pumpFields(tester);

      await enterPostalCode(tester, '28119');

      expect(city.text, 'Al Ras');
      expect(enabled(tester, 'City'), isFalse);
      expect(
        enabled(tester, 'State/Province'),
        isTrue,
        reason: 'State is required: an empty locked field would block saving',
      );
    },
  );

  testWidgets(
    'a stored code that matches locks the fields without changing them',
    (tester) async {
      country.text = 'India';
      zip.text = '400001';
      state.text = 'Gujarat';
      city.text = 'Surat';

      await pumpFields(tester);

      expect(geo.lookups, ['IN 400001']);
      expect(
        state.text,
        'Gujarat',
        reason: 'opening a profile changes nothing',
      );
      expect(city.text, 'Surat');
      expect(enabled(tester, 'State/Province'), isFalse);
      expect(enabled(tester, 'City'), isFalse);
    },
  );

  testWidgets(
    'a stored code that does not match leaves the stored place editable',
    (tester) async {
      country.text = 'India';
      zip.text = '999999';
      state.text = 'Gujarat';
      city.text = 'Surat';

      await pumpFields(tester);

      expect(state.text, 'Gujarat');
      expect(city.text, 'Surat');
      expect(enabled(tester, 'State/Province'), isTrue);
      expect(enabled(tester, 'City'), isTrue);
      expect(blocking(), isNull);
    },
  );

  testWidgets('a stored code with an empty field fills just that field', (
    tester,
  ) async {
    country.text = 'India';
    zip.text = '400001';
    city.text = 'Thane';

    await pumpFields(tester);

    expect(
      state.text,
      'Maharashtra',
      reason: 'an empty locked field would block saving',
    );
    expect(city.text, 'Thane');
  });

  testWidgets('typed text that is not a country never becomes the value', (
    tester,
  ) async {
    await pumpFields(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Country'),
      'My House',
    );
    await tester.pumpAndSettle();

    expect(country.text, isEmpty);
    expect(changes.where((c) => c.startsWith('country=')), isEmpty);
    expect(blocking(), isNull);
    expect(find.text('No country matches "My House"'), findsOneWidget);
  });

  testWidgets('the empty country field shows the whole list when tapped', (
    tester,
  ) async {
    await pumpFields(tester);

    await tester.tap(find.widgetWithText(TextFormField, 'Country'));
    await tester.pumpAndSettle();

    expect(find.text('India'), findsOneWidget);
    expect(find.text('Tanzania'), findsOneWidget);
  });

  testWidgets('picking a country from the list makes it the value', (
    tester,
  ) async {
    await pumpFields(tester);

    await pickCountry(tester, 'Tan', 'Tanzania');

    expect(country.text, 'Tanzania');
    expect(changes, contains('country=Tanzania'));
  });

  testWidgets(
    'leaving the field without picking puts the picked country back',
    (tester) async {
      country.text = 'India';
      await pumpFields(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Country'),
        'Tanz',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextFormField, 'State/Province'));
      await tester.pumpAndSettle();

      expect(country.text, 'India');
      expect(find.widgetWithText(TextFormField, 'India'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Tanz'), findsNothing);
    },
  );

  testWidgets('a stored country that is not on the list blocks saving', (
    tester,
  ) async {
    country.text = 'Atlantis';
    await pumpFields(tester);

    expect(blocking(), 'Choose your country from the list');
  });

  testWidgets(
    'without the list the country cannot be typed, and can be retried',
    (tester) async {
      geo.failCountries = true;
      await pumpFields(tester);

      expect(enabled(tester, 'Country'), isFalse);
      expect(
        find.text('Could not load the list of countries.'),
        findsOneWidget,
      );

      geo.failCountries = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(enabled(tester, 'Country'), isTrue);
    },
  );

  // #1178 finding 2: a required country when the list cannot load.
  Future<GlobalKey<FormState>> pumpRequiredForm(WidgetTester tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [geoRepositoryProvider.overrideWithValue(geo)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: LocationFields(
                  country: country,
                  zip: zip,
                  state: state,
                  city: city,
                  onChanged: (f, v) => changes.add('${f.name}=$v'),
                  onProblemChanged: problems.add,
                  countryValidator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Country is required' : null,
                  decoration: (label, icon, {hint}) =>
                      InputDecoration(labelText: label),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return formKey;
  }

  testWidgets(
    'list failed and country empty: field is disabled and the form is stuck',
    (tester) async {
      geo.failCountries = true;
      final formKey = await pumpRequiredForm(tester);

      expect(enabled(tester, 'Country'), isFalse, reason: 'field disabled');
      expect(find.text('Try again'), findsOneWidget);
      expect(
        formKey.currentState!.validate(),
        isFalse,
        reason: 'required country is empty',
      );
      await tester.pumpAndSettle();
      expect(find.text('Country is required'), findsOneWidget);

      // The member cannot type a country while the list is down.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Country'),
        'India',
      );
      await tester.pumpAndSettle();
      expect(country.text, isEmpty, reason: 'no free-text fallback');

      geo.failCountries = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(enabled(tester, 'Country'), isTrue);
    },
  );

  testWidgets('list failed but country already stored: the form validates', (
    tester,
  ) async {
    geo.failCountries = true;
    country.text = 'India';
    final formKey = await pumpRequiredForm(tester);

    expect(enabled(tester, 'Country'), isFalse);
    expect(formKey.currentState!.validate(), isTrue);
  });

  testWidgets(
    'changing the country frees the fields when the new one has no postal data',
    (tester) async {
      country.text = 'India';
      await pumpFields(tester);
      await enterPostalCode(tester, '400001');
      expect(enabled(tester, 'City'), isFalse);

      await pickCountry(tester, 'Tan', 'Tanzania');

      expect(enabled(tester, 'State/Province'), isTrue);
      expect(enabled(tester, 'City'), isTrue);
      expect(blocking(), isNull);
    },
  );

  testWidgets('a country with no postal codes has no postal field', (
    tester,
  ) async {
    country.text = 'Tanzania';
    await pumpFields(tester);

    expect(find.widgetWithText(TextFormField, 'Postal code'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'City'), findsOneWidget);
  });

  testWidgets('a country we do not list keeps the postal field', (
    tester,
  ) async {
    country.text = 'Atlantis';
    await pumpFields(tester);

    expect(find.widgetWithText(TextFormField, 'Postal code'), findsOneWidget);
  });

  testWidgets('the GeoNames credit is on screen where its data shows', (
    tester,
  ) async {
    await pumpFields(tester);

    expect(find.textContaining('GeoNames (CC BY 4.0)'), findsOneWidget);
  });

  testWidgets('picking a suggested city fills the state', (tester) async {
    country.text = 'Tanzania';
    await pumpFields(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'City'), 'Dar');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dar es Salaam, Dar es Salaam Region'));
    await tester.pumpAndSettle();

    expect(city.text, 'Dar es Salaam');
    expect(state.text, 'Dar es Salaam Region');
  });
}
