// `GET /classes/create-options` (#636): what the create-a-class form offers.
//
// Strict about the envelope, as for the reports: a body that is not this answer
// throws, so the screen offers a retry.

import 'class_manage.dart';

class CreateClassOptions {
  const CreateClassOptions({
    required this.genders,
    required this.tags,
    required this.timezones,
  });

  /// The genders (1 gents, 2 ladies) the caller may create a class for; never
  /// empty, the server refuses a caller who may create for none.
  final List<int> genders;
  final List<ManageOption> tags;
  final List<ManageTimezone> timezones;

  factory CreateClassOptions.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('create options is not an object');
    }
    return CreateClassOptions(
      genders: [for (final g in json['genders'] as List<dynamic>) g as int],
      tags: [
        for (final t in json['tags'] as List<dynamic>)
          ManageOption.fromJson(t as Map<String, dynamic>),
      ],
      timezones: [
        for (final t in json['timezones'] as List<dynamic>)
          ManageTimezone.fromJson(t as Map<String, dynamic>),
      ],
    );
  }
}
