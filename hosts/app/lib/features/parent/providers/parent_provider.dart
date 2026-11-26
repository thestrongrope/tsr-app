import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/utils/user_message.dart';
import '../models/models.dart';
import '../repositories/parent_repository.dart';

// ============ Repository Provider ============

final parentRepositoryProvider = Provider<ParentRepository>((ref) {
  return ParentRepository();
});

// ============ Filter Model ============

class ChildPerformanceFilter {
  final int childToken;
  final int classId;
  final String? from;
  final String? to;

  const ChildPerformanceFilter({
    required this.childToken,
    required this.classId,
    this.from,
    this.to,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChildPerformanceFilter &&
        other.childToken == childToken &&
        other.classId == classId &&
        other.from == from &&
        other.to == to;
  }

  @override
  int get hashCode => Object.hash(childToken, classId, from, to);
}

// ============ Children List State & Notifier ============

class ChildrenState {
  final bool isLoading;
  final List<ChildModel>? children;
  final String? error;

  const ChildrenState({
    this.isLoading = false,
    this.children,
    this.error,
  });

  ChildrenState copyWith({
    bool? isLoading,
    List<ChildModel>? children,
    String? error,
  }) {
    return ChildrenState(
      isLoading: isLoading ?? this.isLoading,
      children: children ?? this.children,
      error: error,
    );
  }

  bool get hasChildren => children != null && children!.isNotEmpty;
  int get childrenCount => children?.length ?? 0;
}

class ChildrenNotifier extends StateNotifier<ChildrenState> {
  final ParentRepository _repository;

  ChildrenNotifier(this._repository) : super(const ChildrenState()) {
    loadChildren();
  }

  Future<void> loadChildren() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final children = await _repository.getChildren();
      state = state.copyWith(isLoading: false, children: children);
    } catch (e) {
      debugPrint('Error loading children: $e');
      state = state.copyWith(isLoading: false, error: userMessage(e));
    }
  }

  Future<void> refresh() => loadChildren();
}

final childrenProvider =
    StateNotifierProvider.autoDispose<ChildrenNotifier, ChildrenState>((ref) {
  final repo = ref.watch(parentRepositoryProvider);
  return ChildrenNotifier(repo);
});

// ============ Child Classes Provider ============

final childClassesProvider = FutureProvider.autoDispose
    .family<List<ChildClassModel>, int>((ref, childToken) async {
  final repo = ref.watch(parentRepositoryProvider);
  return repo.getChildClasses(childToken);
}, retry: (_, _) => null);

// ============ Child Performance Provider ============

final childPerformanceProvider = FutureProvider.autoDispose
    .family<ChildPerformanceModel, ChildPerformanceFilter>((ref, filter) async {
  final repo = ref.watch(parentRepositoryProvider);
  return repo.getChildPerformance(
    filter.childToken,
    filter.classId,
    from: filter.from,
    to: filter.to,
  );
}, retry: (_, _) => null);

// ============ Child Attendance Sessions Provider ============

final childAttendanceHistoryProvider = FutureProvider.autoDispose
    .family<List<ChildAttendanceHistory>, ChildPerformanceFilter>((
      ref,
      filter,
    ) async {
      final repo = ref.watch(parentRepositoryProvider);
      return repo.getChildAttendance(
        filter.childToken,
        filter.classId,
        from: filter.from,
        to: filter.to,
      );
    }, retry: (_, _) => null);

// ============ Child Quiz Scores Provider ============

final childScoresProvider = FutureProvider.autoDispose
    .family<List<ChildScoreModel>, ChildPerformanceFilter>((ref, filter) async {
  final repo = ref.watch(parentRepositoryProvider);
  return repo.getChildScores(
    filter.childToken,
    filter.classId,
    from: filter.from,
    to: filter.to,
  );
}, retry: (_, _) => null);

// ============ Parent Links State & Notifier ============

class ParentLinksState {
  final bool isLoading;
  final List<ParentLinkModel>? links;
  final String? error;

  const ParentLinksState({
    this.isLoading = false,
    this.links,
    this.error,
  });

  ParentLinksState copyWith({
    bool? isLoading,
    List<ParentLinkModel>? links,
    String? error,
  }) {
    return ParentLinksState(
      isLoading: isLoading ?? this.isLoading,
      links: links ?? this.links,
      error: error,
    );
  }

  bool get hasLinks => links != null && links!.isNotEmpty;
  List<ParentLinkModel> get activeLinks =>
      links?.where((l) => l.isActive).toList() ?? [];
}

class ParentLinksNotifier extends StateNotifier<ParentLinksState> {
  final ParentRepository _repository;
  final Ref _ref;

  ParentLinksNotifier(this._repository, this._ref)
      : super(const ParentLinksState()) {
    loadLinks();
  }

  Future<void> loadLinks() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final links = await _repository.getParentLinks();
      state = state.copyWith(isLoading: false, links: links);
    } catch (e) {
      debugPrint('Error loading parent links: $e');
      state = state.copyWith(isLoading: false, error: userMessage(e));
    }
  }

  Future<void> refresh() => loadLinks();

  Future<bool> revokeLink(int childToken) async {
    try {
      await _repository.revokeLink(childToken);
      await loadLinks();
      _ref.read(childrenProvider.notifier).loadChildren();
      return true;
    } catch (e) {
      debugPrint('Error revoking link: $e');
      state = state.copyWith(error: userMessage(e));
      return false;
    }
  }
}

final parentLinksProvider =
    StateNotifierProvider<ParentLinksNotifier, ParentLinksState>((ref) {
  final repo = ref.watch(parentRepositoryProvider);
  return ParentLinksNotifier(repo, ref);
});

// ============ Child-side My Parents State & Notifier ============

class MyParentsState {
  final bool isLoading;
  final List<MyParentModel>? parents;
  final String? error;

  const MyParentsState({
    this.isLoading = false,
    this.parents,
    this.error,
  });

  MyParentsState copyWith({
    bool? isLoading,
    List<MyParentModel>? parents,
    String? error,
  }) {
    return MyParentsState(
      isLoading: isLoading ?? this.isLoading,
      parents: parents ?? this.parents,
      error: error,
    );
  }

  bool get hasParents => parents != null && parents!.isNotEmpty;
}

class MyParentsNotifier extends StateNotifier<MyParentsState> {
  final ParentRepository _repository;

  MyParentsNotifier(this._repository) : super(const MyParentsState()) {
    loadParents();
  }

  Future<void> loadParents() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final parents = await _repository.getMyParents();
      state = state.copyWith(isLoading: false, parents: parents);
    } catch (e) {
      debugPrint('Error loading my parents: $e');
      state = state.copyWith(isLoading: false, error: userMessage(e));
    }
  }

  Future<void> refresh() => loadParents();

  Future<bool> revokeParent(int parentToken) async {
    try {
      await _repository.revokeMyParent(parentToken);
      await loadParents();
      return true;
    } catch (e) {
      debugPrint('Error revoking parent: $e');
      state = state.copyWith(error: userMessage(e));
      return false;
    }
  }
}

final myParentsProvider =
    StateNotifierProvider<MyParentsNotifier, MyParentsState>((ref) {
  final repo = ref.watch(parentRepositoryProvider);
  return MyParentsNotifier(repo);
});
