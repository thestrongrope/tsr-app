import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/content_width_cap.dart';
import '../providers/providers.dart';
import 'class_dashboard_screen.dart';
import '../widgets/class_loading_skeleton.dart';

/// Full dashboard for a single class, opened from the class list.
///
/// Fetches the class detail (including schedules) so the dashboard content has
/// everything it needs, then renders [ClassDashboardContent].
class ClassDetailScreen extends ConsumerWidget {
  final int classId;

  const ClassDetailScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(classDetailProvider(classId));

    return Scaffold(
      appBar: AppBar(title: const Text('Class Dashboard')),
      body: ContentWidthCap(
        child: detailAsync.when(
          data: (classModel) => ClassDashboardContent(classModel: classModel),
          loading: () => const ClassLoadingSkeleton(),
          error: (error, _) => AppErrorView(
            error: error,
            onRetry: () => ref.invalidate(classDetailProvider(classId)),
          ),
        ),
      ),
    );
  }
}
