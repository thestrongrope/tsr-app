import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #736: a server time must go through `lib/core/utils/api_datetime.dart`.
/// `DateTime.parse` / `tryParse` read a zone-less string as device-local time,
/// so using them on a server value shows it hours out. This fails when a new
/// file in lib/ calls them directly. If the new call is for something that is
/// not a server time of day (a calendar date, a local cache stamp, a value the
/// server sends with a zone), add the file below with the reason.
const _allowed = <String, String>{
  'core/utils/api_datetime.dart': 'the shared helper itself',
  'core/services/saved_copy.dart': 'local cache stamp',
  'features/wordpress/repositories/wordpress_repository.dart':
      'local cache stamp',
  'features/grand_quiz/repositories/grand_quiz_repository.dart':
      'local cache stamp',
  'features/wordpress/models/article.dart': 'WordPress post date',
  'features/wordpress/models/article.g.dart': 'generated',
  'features/wordpress/screens/tsr_article_detail_screen.dart': 'WordPress date',
  'features/home/presentation/widgets/latest_articles.dart': 'WordPress date',
  'features/wordpress/widgets/library_latest_articles.dart': 'WordPress date',
  'features/classes/models/class_model.dart': 'calendar date',
  'features/classes/models/conduction.dart': 'calendar dates',
  'features/classes/models/class_session.dart': 'calendar date',
  'features/classes/screens/conduction_list_screen.dart': 'calendar date',
  'features/reports/screens/class_sessions_screen.dart': 'calendar date',
  'features/classes/widgets/manage_details_tab.dart': 'calendar date picker',
  'features/classes/screens/class_student_figures_screen.dart': 'calendar date',
  'features/reports/models/unplaced_registrations.dart': 'calendar date',
  'features/grand_quiz/models/quiz_info.dart': 'sent with a zone',
  'features/admin/models/deactivated_classes.dart': 'sent with a Z',
  'features/admin/models/whatsapp_reminders.dart': 'sent with a Z',
  'features/notifications/models/user_notification.dart':
      'fallback after the helper',
  'features/calendar/calendar_repository.dart':
      'the Undo hold stamp this phone wrote itself, in UTC with a Z',
  'features/classes/screens/scheduled_notifications_screen.dart':
      'send_at is a wall clock in the notification\'s own zone, shown as written; '
      'next_run is sent with an offset',
};

void main() {
  test('no screen or model parses a server time without the shared helper', () {
    final pattern = RegExp(r'DateTime\.(parse|tryParse)\(');
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.substring('lib/'.length);
      if (_allowed.containsKey(path)) continue;
      for (final line in entity.readAsLinesSync()) {
        if (line.trimLeft().startsWith('//')) continue;
        if (pattern.hasMatch(line)) {
          offenders.add(path);
          break;
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use parseApiLocalDateTime / formatApiLocalDateTime from '
          'core/utils/api_datetime.dart for server times: $offenders',
    );
  });
}
