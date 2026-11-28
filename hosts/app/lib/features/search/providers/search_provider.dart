import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/router/route_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../destinations.dart';
import '../models/search_result.dart';
import '../repositories/search_repository.dart';

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(),
);

// One provider per source, keyed by the query. A new query is a new key, so an
// answer to an older query can never land on the newest one, and none retries
// on its own: a failure is shown as one.
final searchArticlesProvider = FutureProvider.autoDispose
    .family<SearchGroup, String>(
      (ref, query) => ref.watch(searchRepositoryProvider).articles(query),
      retry: (retryCount, error) => null,
    );

final searchVideosProvider = FutureProvider.autoDispose
    .family<SearchGroup, String>(
      (ref, query) => ref.watch(searchRepositoryProvider).videos(query),
      retry: (retryCount, error) => null,
    );

final searchPublicationsProvider = FutureProvider.autoDispose
    .family<SearchGroup, String>(
      (ref, query) => ref.watch(searchRepositoryProvider).publications(query),
      retry: (retryCount, error) => null,
    );

final searchPrivateProvider = FutureProvider.autoDispose
    .family<PrivateSearch, String>(
      (ref, query) => ref.watch(searchRepositoryProvider).privateSearch(query),
      retry: (retryCount, error) => null,
    );

const _privateKinds = {
  SearchKind.classRecord,
  SearchKind.teacher,
  SearchKind.guide,
  SearchKind.student,
  SearchKind.subscriber,
};

/// Everything one query finds, from every source at once. Fewer than two letters
/// asks nothing. The private kinds are asked only for a signed-in member with a
/// token above 0; Screens and Reports are matched here against the person's
/// permissions and need no server.
final globalSearchProvider = Provider.autoDispose
    .family<GlobalSearchView, String>((ref, query) {
      final q = query.trim();
      if (q.length < 2) return GlobalSearchView.idle;

      final groups = <SearchKind, SearchGroup>{};
      final failed = <SearchKind>{};
      var searching = false;

      void take(SearchKind kind, AsyncValue<SearchGroup> answer) {
        answer.when(
          data: (group) => groups[kind] = group,
          loading: () => searching = true,
          error: (_, _) => failed.add(kind),
        );
      }

      take(SearchKind.article, ref.watch(searchArticlesProvider(q)));
      take(SearchKind.video, ref.watch(searchVideosProvider(q)));
      take(SearchKind.publication, ref.watch(searchPublicationsProvider(q)));

      final user = ref.watch(currentUserProvider);
      final signedIn = user != null && user.token > 0;
      if (signedIn) {
        ref
            .watch(searchPrivateProvider(q))
            .when(
              data: (private) {
                groups.addAll(private.groups);
                failed.addAll(private.unavailable);
              },
              loading: () => searching = true,
              error: (_, _) => failed.addAll(_privateKinds),
            );
      }

      final destinations = matchDestinations(
        q,
        ref.watch(capabilitiesProvider),
        signedIn: signedIn,
      );
      if (destinations.isNotEmpty) {
        groups[SearchKind.destination] = SearchGroup(
          kind: SearchKind.destination,
          results: destinations,
          count: destinations.length,
        );
      }

      return GlobalSearchView(
        groups: groups,
        failed: failed,
        searching: searching,
      );
    });

/// Opens a result: a route inside the app, or an address outside it (a video or
/// a publication) handed to the phone.
typedef OpenTarget =
    Future<void> Function(BuildContext context, SearchResult result);

/// Opens an address outside the app; false when the phone cannot. A provider so
/// a test can make it fail.
final externalLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Opens a Me screen with Me behind it, as the Me tab does, so back returns to
/// Me. The screen is beside Me in the router, not under it, and it is inside
/// the tab shell, so it cannot be pushed while search is still on top: a `go`
/// only takes effect later, and pushing before then adds a second copy of the
/// shell. So the push waits for the router's next change, once.
///
/// Search is a root route, so the router is never on Me when a result is tapped.
/// Called from a widget already on Me, `go` changes nothing, the wait never ends
/// and the screen does not open: no caller does that today. A fix that pushed
/// without waiting would add the second shell this function exists to avoid.
void _openOverMe(GoRouter router, String target) {
  final delegate = router.routerDelegate;
  void pushWhenOnMe() {
    delegate.removeListener(pushWhenOnMe);
    if (delegate.currentConfiguration.uri.path == AppRoutes.me) {
      router.push(target);
    }
  }

  delegate.addListener(pushWhenOnMe);
  router.go(AppRoutes.me);
}

/// What a tap on a result does. A provider so a test can see where it would go.
final searchOpenProvider = Provider<OpenTarget>((ref) {
  final launch = ref.watch(externalLauncherProvider);
  return (context, result) async {
    if (result.target.startsWith('http')) {
      var opened = false;
      try {
        opened = await launch(Uri.parse(result.target));
      } on PlatformException {
        opened = false;
      }
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open that link')),
        );
      }
    } else if (result.target.isNotEmpty) {
      // A person card is outside the tab shell, so it opens over search. Anything
      // else is inside it and cannot be pushed from here; see isPersonCard.
      if (AppRoutes.isPersonCard(result.target)) {
        context.push(result.target);
      } else if (AppRoutes.meScreens.contains(result.target)) {
        _openOverMe(GoRouter.of(context), result.target);
      } else {
        context.go(result.target);
      }
    }
  };
});
