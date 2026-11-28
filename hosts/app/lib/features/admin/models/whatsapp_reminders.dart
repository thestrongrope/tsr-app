// `/admin/whatsapp/*` (#418): the WhatsApp reminders, their runs, and what each
// run sent. The server shows these to those who may manage the reminders.
//
// Strict about the envelope, tolerant about the rows, as for the reports: a body
// that is not this answer throws, so the screen offers a retry.

/// Text as sent, or empty for anything that is not text.
String _text(Object? value) => value is String ? value : '';

/// Text as sent, or null for a missing value.
String? _textOrNull(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int _int(Object? value) => (value as num?)?.toInt() ?? 0;

/// The server's times are UTC with a Z; null when there is none or it cannot be read.
DateTime? _utc(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

const whatsappLanguages = ['hinglish', 'english', 'gujarati', 'swahili'];
const whatsappGenders = ['gents', 'ladies'];

/// ISO weekday 1..7 as a name; '' for anything else.
String weekdayName(int? weekday) => switch (weekday) {
  1 => 'Monday',
  2 => 'Tuesday',
  3 => 'Wednesday',
  4 => 'Thursday',
  5 => 'Friday',
  6 => 'Saturday',
  7 => 'Sunday',
  _ => '',
};

/// One reminder: which classes it covers, in what language, and when it is sent.
class WhatsappReminder {
  const WhatsappReminder({
    required this.id,
    required this.name,
    required this.gender,
    required this.city,
    required this.country,
    required this.levels,
    required this.lang,
    required this.leewayDays,
    required this.timezone,
    required this.weekday,
    required this.sendTime,
    required this.scheduleOn,
    required this.enabled,
  });

  final int id;
  final String name;

  /// `gents` or `ladies`.
  final String gender;
  final String? city;
  final String? country;

  /// Comma-separated level names.
  final String levels;
  final String lang;
  final int leewayDays;
  final String timezone;

  /// ISO weekday, 1 Monday to 7 Sunday; null for none.
  final int? weekday;

  /// `HH:MM:SS` in [timezone]; null for none.
  final String? sendTime;

  /// Sent on a timer at [weekday] and [sendTime]; off means by hand only.
  final bool scheduleOn;
  final bool enabled;

  /// "Mumbai, India", whichever of the two are set.
  String get place => [city, country].whereType<String>().join(', ');

  /// `HH:MM`, or null.
  String? get sendTimeShort => sendTime != null && sendTime!.length >= 5
      ? sendTime!.substring(0, 5)
      : sendTime;

  /// "Monday 18:00 (Asia/Kolkata)", or '' when no day and time are set.
  String get when {
    if (weekday == null || sendTimeShort == null) return '';
    return '${weekdayName(weekday)} $sendTimeShort ($timezone)';
  }

  factory WhatsappReminder.fromJson(Map<String, dynamic> json) =>
      WhatsappReminder(
        id: _int(json['id']),
        name: _text(json['name']),
        gender: _text(json['gender']),
        city: _textOrNull(json['city']),
        country: _textOrNull(json['country']),
        levels: _text(json['levels']),
        lang: _text(json['lang']),
        leewayDays: _int(json['leewayDays']),
        timezone: _text(json['timezone']),
        weekday: (json['weekday'] as num?)?.toInt(),
        sendTime: _textOrNull(json['sendTime']),
        scheduleOn: json['scheduleOn'] == true,
        enabled: json['enabled'] == true,
      );

  /// Throws [FormatException] when [body] is not `{"reminders": [...]}`.
  static List<WhatsappReminder> listFromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['reminders'] is! List) {
      throw const FormatException('whatsapp reminders: unexpected response');
    }
    return [
      for (final r in body['reminders'] as List)
        if (r is Map<String, dynamic>) WhatsappReminder.fromJson(r),
    ];
  }

  /// Throws [FormatException] when [body] is not `{"reminder": {...}}`.
  static WhatsappReminder oneFromJson(dynamic body) {
    if (body is! Map<String, dynamic> ||
        body['reminder'] is! Map<String, dynamic>) {
      throw const FormatException('whatsapp reminder: unexpected response');
    }
    return WhatsappReminder.fromJson(body['reminder'] as Map<String, dynamic>);
  }
}

/// One run of a reminder: its window, how it ended, and the counts.
class WhatsappRun {
  const WhatsappRun({
    required this.id,
    required this.reminderId,
    required this.startedAt,
    required this.finishedAt,
    required this.fromDate,
    required this.toDate,
    required this.status,
    required this.sent,
    required this.skipped,
    required this.failed,
    required this.dryRun,
    required this.error,
  });

  final int id;
  final int? reminderId;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  /// `YYYY-MM-DD`, null when the run has no window.
  final String? fromDate;
  final String? toDate;

  /// `running`, `success`, `partial`, `failed`, `test`... as the notifier says.
  final String status;
  final int sent;
  final int skipped;
  final int failed;
  final bool dryRun;
  final String? error;

  bool get isRunning => status == 'running';

  /// "12 Oct → 18 Oct" source text, or null with no window.
  String? get window =>
      fromDate != null && toDate != null ? '$fromDate → $toDate' : null;

  factory WhatsappRun.fromJson(Map<String, dynamic> json) => WhatsappRun(
    id: _int(json['id']),
    reminderId: (json['reminderId'] as num?)?.toInt(),
    startedAt: _utc(json['startedAt']),
    finishedAt: _utc(json['finishedAt']),
    fromDate: _textOrNull(json['fromDate']),
    toDate: _textOrNull(json['toDate']),
    status: _text(json['status']),
    sent: _int(json['sent']),
    skipped: _int(json['skipped']),
    failed: _int(json['failed']),
    dryRun: json['dryRun'] == true,
    error: _textOrNull(json['error']),
  );

  /// Throws [FormatException] when [body] is not `{"runs": [...]}`.
  static List<WhatsappRun> listFromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['runs'] is! List) {
      throw const FormatException('whatsapp runs: unexpected response');
    }
    return [
      for (final r in body['runs'] as List)
        if (r is Map<String, dynamic>) WhatsappRun.fromJson(r),
    ];
  }
}

/// One teacher a run handled.
class WhatsappMessage {
  const WhatsappMessage({
    required this.mobile,
    required this.name,
    required this.missing,
    required this.excerpt,
    required this.status,
    required this.error,
    required this.sentAt,
  });

  final String mobile;
  final String? name;

  /// How many items the teacher is missing; null for a test message.
  final int? missing;
  final String? excerpt;
  final String status;
  final String? error;
  final DateTime? sentAt;

  factory WhatsappMessage.fromJson(Map<String, dynamic> json) =>
      WhatsappMessage(
        mobile: _text(json['mobile']),
        name: _textOrNull(json['name']),
        missing: (json['missing'] as num?)?.toInt(),
        excerpt: _textOrNull(json['excerpt']),
        status: _text(json['status']),
        error: _textOrNull(json['error']),
        sentAt: _utc(json['sentAt']),
      );
}

/// A run with each teacher it handled.
class WhatsappRunDetail {
  const WhatsappRunDetail({required this.run, required this.messages});

  final WhatsappRun run;
  final List<WhatsappMessage> messages;

  /// Throws [FormatException] when [body] is not this answer.
  factory WhatsappRunDetail.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> ||
        body['run'] is! Map<String, dynamic> ||
        body['messages'] is! List) {
      throw const FormatException('whatsapp run: unexpected response');
    }
    return WhatsappRunDetail(
      run: WhatsappRun.fromJson(body['run'] as Map<String, dynamic>),
      messages: [
        for (final m in body['messages'] as List)
          if (m is Map<String, dynamic>) WhatsappMessage.fromJson(m),
      ],
    );
  }
}
