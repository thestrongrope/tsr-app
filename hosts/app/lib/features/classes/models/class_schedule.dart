import 'package:freezed_annotation/freezed_annotation.dart';

part 'class_schedule.freezed.dart';
part 'class_schedule.g.dart';

@freezed
sealed class ClassSchedule with _$ClassSchedule {
  const factory ClassSchedule({
    required int day,
    required int hour,
    required int minute,
    String? timezone,
  }) = _ClassSchedule;

  factory ClassSchedule.fromJson(Map<String, dynamic> json) =>
      _$ClassScheduleFromJson(json);
}

/// Helper extension for schedule display
extension ClassScheduleDisplay on ClassSchedule {
  String get dayName {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    return days[day % 7];
  }

  String get dayShort {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[day % 7];
  }

  String get timeFormatted {
    final h = hour > 12 ? hour - 12 : hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  String get fullSchedule => '$dayName at $timeFormatted';
}
