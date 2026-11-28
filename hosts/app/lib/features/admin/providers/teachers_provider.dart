import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/teachers.dart';
import '../repositories/teachers_repository.dart';

/// The teachers of a gender (1 gents, 2 ladies).
final teachersProvider = FutureProvider.autoDispose.family<TeachersList, int>(
  (ref, gender) => TeachersRepository().getTeachers(gender: gender),
  retry: (retryCount, error) => null,
);

/// One teacher, by token.
final teacherDetailProvider = FutureProvider.autoDispose
    .family<TeacherDetail, int>(
      (ref, token) => TeachersRepository().getTeacher(token),
      retry: (retryCount, error) => null,
    );

/// Saves training changes under one comment; returns how many teachers changed.
typedef ChangeTraining =
    Future<int> Function({
      required List<TrainingChange> changes,
      required String comments,
    });

final changeTrainingProvider = Provider<ChangeTraining>(
  (ref) =>
      ({required List<TrainingChange> changes, required String comments}) =>
          TeachersRepository().changeTraining(
            changes: changes,
            comments: comments,
          ),
);

/// Imports the teachers of active classes for a gender; returns how many were added.
typedef ImportTeachers = Future<int> Function({required int gender});

final importTeachersProvider = Provider<ImportTeachers>(
  (ref) =>
      ({required int gender}) =>
          TeachersRepository().importTeachers(gender: gender),
);
