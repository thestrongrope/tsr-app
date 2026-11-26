import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/admin/models/whatsapp_reminders.dart';
import 'package:the_strong_rope/features/admin/providers/whatsapp_reminders_provider.dart';
import 'package:the_strong_rope/features/admin/screens/whatsapp_reminders_screen.dart';
import 'package:the_strong_rope/features/admin/screens/whatsapp_run_screen.dart';

const _mumbai = WhatsappReminder(
  id: 1,
  name: 'Mumbai gents',
  gender: 'gents',
  city: 'Mumbai',
  country: null,
  levels: 'BILAL,AMMAR',
  lang: 'hinglish',
  leewayDays: 10,
  timezone: 'Asia/Kolkata',
  weekday: null,
  sendTime: null,
  scheduleOn: false,
  enabled: true,
);

const _us = WhatsappReminder(
  id: 2,
  name: 'US gents',
  gender: 'gents',
  city: null,
  country: 'United States',
  levels: 'BILAL',
  lang: 'english',
  leewayDays: 7,
  timezone: 'America/Chicago',
  weekday: 7,
  sendTime: '13:00:00',
  scheduleOn: true,
  enabled: false,
);

WhatsappRun _run({
  String status = 'success',
  bool dryRun = false,
  int sent = 1,
  int failed = 0,
  String? error,
}) => WhatsappRun(
  id: 31,
  reminderId: 1,
  startedAt: DateTime.utc(2026, 10, 19, 12),
  finishedAt: DateTime.utc(2026, 10, 19, 12, 5),
  fromDate: '2026-10-12',
  toDate: '2026-10-18',
  status: status,
  sent: sent,
  skipped: 1,
  failed: failed,
  dryRun: dryRun,
  error: error,
);

const _teacher = WhatsappMessage(
  mobile: '919800000000',
  name: 'Ali',
  missing: 3,
  excerpt: 'Salaam',
  status: 'sent',
  error: null,
  sentAt: null,
);

Widget _wrap(
  Widget home, {
  List<WhatsappReminder> reminders = const [_mumbai, _us],
  List<WhatsappRun> runs = const [],
  UpdateWhatsappReminder? update,
  StartWhatsappRun? start,
  SendWhatsappTest? test,
  WhatsappRunDetail? detail,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      whatsappRemindersProvider.overrideWith((ref) async => reminders),
      whatsappRunsProvider.overrideWith((ref) async => runs),
      if (update != null)
        updateWhatsappReminderProvider.overrideWithValue(update),
      if (start != null) startWhatsappRunProvider.overrideWithValue(start),
      if (test != null) sendWhatsappTestProvider.overrideWithValue(test),
      whatsappRunProvider.overrideWith(
        (ref, id) async =>
            detail ??
            WhatsappRunDetail(run: _run(), messages: const [_teacher]),
      ),
    ],
    child: MaterialApp(home: home),
  );
}

Future<void> _tall(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Opens [name]'s editor from the list.
Future<void> _open(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists each reminder with its audience and schedule', (
    tester,
  ) async {
    await _tall(tester);
    await tester.pumpWidget(_wrap(const WhatsappRemindersScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Mumbai gents'), findsOneWidget);
    expect(find.textContaining('gents · Mumbai · BILAL,AMMAR'), findsOneWidget);
    expect(find.text('Schedule off — by hand only'), findsOneWidget);
    expect(find.text('US gents (off)'), findsOneWidget);
    expect(
      find.text('Schedule on · Sunday 13:00 (America/Chicago)'),
      findsOneWidget,
    );
  });

  testWidgets('recent runs show their counts and open to each teacher', (
    tester,
  ) async {
    await _tall(tester);
    await tester.pumpWidget(
      _wrap(const WhatsappRemindersScreen(), runs: [_run(failed: 2)]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recent runs'));
    await tester.pumpAndSettle();

    expect(find.text('Sent 1 · skipped 1 · failed 2'), findsOneWidget);

    await tester.tap(find.text('#31 · success'));
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('sent · 3 missing'), findsOneWidget);
  });

  testWidgets('a dry run starts without asking and sends nothing', (
    tester,
  ) async {
    await _tall(tester);
    bool? asked;
    await tester.pumpWidget(
      _wrap(
        const WhatsappRemindersScreen(),
        start: (id, {required dryRun}) async {
          asked = dryRun;
          return 31;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester, 'Mumbai gents');
    await tester.tap(find.text('Dry run (sends nothing)'));
    await tester.pumpAndSettle();

    expect(asked, isTrue);
    expect(find.text('Run #31'), findsOneWidget);
  });

  testWidgets('sending for real says so and starts only when confirmed', (
    tester,
  ) async {
    await _tall(tester);
    final asked = <bool>[];
    await tester.pumpWidget(
      _wrap(
        const WhatsappRemindersScreen(),
        start: (id, {required dryRun}) async {
          asked.add(dryRun);
          return 31;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester, 'Mumbai gents');

    await tester.tap(find.text('Send for real'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Real WhatsApp messages will go out'), findsOne);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(asked, isEmpty);

    await tester.tap(find.text('Send for real'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send messages'));
    await tester.pumpAndSettle();
    expect(asked, [false]);
  });

  testWidgets('a run the server refuses keeps the form and shows its words', (
    tester,
  ) async {
    await _tall(tester);
    await tester.pumpWidget(
      _wrap(
        const WhatsappRemindersScreen(),
        start: (id, {required dryRun}) async =>
            throw const ApiException('a run is already in progress', 409),
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester, 'Mumbai gents');
    await tester.tap(find.text('Dry run (sends nothing)'));
    await tester.pumpAndSettle();

    expect(find.text('a run is already in progress'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('turning the schedule on asks first, and saves only if agreed', (
    tester,
  ) async {
    await _tall(tester);
    final saved = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      _wrap(
        const WhatsappRemindersScreen(),
        update: (id, fields) async {
          saved.add(fields);
          return _mumbai;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester, 'Mumbai gents');
    await tester.tap(find.text('Schedule on'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('sends real WhatsApp messages'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();

    expect(saved.single['scheduleOn'], isTrue);
    expect(saved.single['leewayDays'], 10);
    expect(saved.single['city'], 'Mumbai');
    expect(saved.single['country'], isNull);
    expect(find.text('Mumbai gents saved.'), findsOneWidget);
  });

  testWidgets('an invalid setting shows the server words and leaves the form', (
    tester,
  ) async {
    await _tall(tester);
    await tester.pumpWidget(
      _wrap(
        const WhatsappRemindersScreen(),
        update: (id, fields) async => throw const ApiException(
          'send_time must be a time such as 13:00',
          400,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester, 'Mumbai gents');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('send_time must be a time such as 13:00'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets(
    'a test message goes to the number typed, after saying it is real',
    (tester) async {
      await _tall(tester);
      String? to;
      await tester.pumpWidget(
        _wrap(
          const WhatsappRemindersScreen(),
          test: ({required mobile, required message}) async => to = mobile,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Send a test message'));
      await tester.pumpAndSettle();
      expect(
        find.text('This sends one real WhatsApp message.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Mobile number'),
        ' 919800000000 ',
      );
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(to, '919800000000');
      expect(find.text('Test message sent.'), findsOneWidget);
    },
  );

  testWidgets('a run that failed part way shows how many and why', (
    tester,
  ) async {
    await _tall(tester);
    await tester.pumpWidget(
      _wrap(
        const WhatsappRunScreen(runId: 31),
        detail: WhatsappRunDetail(
          run: _run(
            status: 'failed',
            failed: 2,
            error: 'WhatsApp disconnected',
          ),
          messages: const [
            WhatsappMessage(
              mobile: '919811111111',
              name: null,
              missing: 2,
              excerpt: null,
              status: 'failed',
              error: 'not on WhatsApp',
              sentAt: null,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sent 1 · skipped 1 · failed 2'), findsOneWidget);
    expect(find.text('WhatsApp disconnected'), findsOneWidget);
    expect(find.text('919811111111'), findsOneWidget);
    expect(find.text('not on WhatsApp'), findsOneWidget);
  });

  testWidgets('a dry run says nothing was sent', (tester) async {
    await _tall(tester);
    await tester.pumpWidget(
      _wrap(
        const WhatsappRunScreen(runId: 31),
        detail: WhatsappRunDetail(
          run: _run(dryRun: true, sent: 0),
          messages: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('dry run, nothing was sent'), findsOneWidget);
  });
}
