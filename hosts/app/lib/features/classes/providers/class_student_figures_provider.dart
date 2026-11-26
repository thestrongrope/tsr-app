import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/class_student_figures.dart';
import 'class_manage_provider.dart';

/// Which class and which range; null dates are the server's default (the last
/// year). A record, so the same request is the same provider.
typedef StudentFiguresRequest = ({int classId, String? from, String? to});

final classStudentFiguresProvider = FutureProvider.autoDispose
    .family<ClassStudentFigures, StudentFiguresRequest>((ref, request) {
      return ref
          .watch(classManageRepositoryProvider)
          .getStudentFigures(
            request.classId,
            from: request.from,
            to: request.to,
          );
    }, retry: (_, _) => null);
