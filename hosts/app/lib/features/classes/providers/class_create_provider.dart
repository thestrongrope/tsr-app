import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/class_create.dart';
import '../models/class_manage.dart';
import '../repositories/class_create_repository.dart';

/// What the create form offers: genders, tags, timezones.
final createClassOptionsProvider =
    FutureProvider.autoDispose<CreateClassOptions>(
      (ref) => ClassCreateRepository().getOptions(),
      retry: (retryCount, error) => null,
    );

/// The levels a class can be at.
final classLevelsProvider = FutureProvider.autoDispose<List<ManageOption>>(
  (ref) => ClassCreateRepository().getLevels(),
  retry: (retryCount, error) => null,
);

/// Teacher candidates for a new class: (gender, query).
typedef SearchNewClassTeachers =
    Future<List<ManageOption>> Function(int gender, String query);

final searchNewClassTeachersProvider = Provider<SearchNewClassTeachers>(
  (ref) =>
      (gender, query) => ClassCreateRepository().searchTeachers(gender, query),
);

/// Creates a class and answers with its id.
typedef CreateClass =
    Future<int> Function({
      required int gender,
      required int levelId,
      required String location,
      required String city,
      required String country,
      required int teacher,
      required List<int> tags,
      required List<ManageSchedule> schedules,
    });

final createClassProvider = Provider<CreateClass>(
  (ref) =>
      ({
        required int gender,
        required int levelId,
        required String location,
        required String city,
        required String country,
        required int teacher,
        required List<int> tags,
        required List<ManageSchedule> schedules,
      }) => ClassCreateRepository().createClass(
        gender: gender,
        levelId: levelId,
        location: location,
        city: city,
        country: country,
        teacher: teacher,
        tags: tags,
        schedules: schedules,
      ),
);
