import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/permissions/capabilities.dart';
import 'package:the_strong_rope/core/router/route_config.dart';
import 'package:the_strong_rope/features/search/destinations.dart';
import 'package:the_strong_rope/features/search/models/search_result.dart';

// The Screens and Reports a person can search for (#557): a built-in list,
// each entry gated by the permission that opens it, as the Manage tab is.

Capabilities _holds(List<String> permissions) => Capabilities.of(
  payload: PermissionsPayload(
    version: 4,
    permissions: permissions,
    scopes: const PermissionScopes(gender: 1),
    issuedAt: '',
  ),
  classes: null,
);

/// What a signed-in member finds.
List<SearchResult> _find(String query, Capabilities capabilities) =>
    matchDestinations(query, capabilities, signedIn: true);

List<String> _titles(List<SearchResult> results) =>
    results.map((r) => r.title).toList();

void main() {
  test('registrations are found only by whoever may read them', () {
    final may = _find('regis', _holds(['registrations:read:gender']));
    final mayNot = _find('regis', _holds(['reports:read:gender']));

    expect(_titles(may), ['Registrations']);
    expect(may.single.kind, SearchKind.destination);
    expect(may.single.target, AppRoutes.adminRegistrations);
    expect(mayNot, isEmpty);
  });

  test('a reports holder finds the reports but not the Manage-only tools', () {
    final payload = _holds(['reports:read:gender']);

    expect(
      _titles(_find('conduction', payload)),
      contains('Conduction Report'),
    );
    expect(_find('donors', payload), isEmpty);
    expect(_find('transfers', payload), isEmpty);
  });

  test(
    'nothing is found without a payload or for a query under two letters',
    () {
      expect(_find('regis', const Capabilities.none()), isEmpty);
      expect(_find('r', _holds(['reports:read:all'])), isEmpty);
      expect(_find('', _holds(['reports:read:all'])), isEmpty);
    },
  );

  test('keywords match as well as titles, in any case', () {
    final payload = _holds(['donors:read:all']);

    expect(_titles(_find('DONORS', payload)), ['Donors']);
  });

  test('the Quran leaderboard has a permission of its own', () {
    final reportsOnly = _holds(['reports:read:gender']);
    final leaderboard = _holds([
      'reports:read:gender',
      'quran-leaderboard:read:gender',
    ]);

    expect(_find('quran', reportsOnly), isEmpty);
    expect(_titles(_find('quran', leaderboard)), ['Quran Leaderboard']);
  });

  test('every entry opens a route the app really has', () {
    final real = <String>{
      AppRoutes.adminNotifications,
      AppRoutes.adminSyllabus,
      AppRoutes.adminReports,
      AppRoutes.adminDeactivatedClasses,
      AppRoutes.adminTransfers,
      AppRoutes.adminTeachers,
      AppRoutes.adminWhatsappReminders,
      AppRoutes.adminDonors,
      AppRoutes.adminDeletionRequests,
      AppRoutes.adminGuides,
      AppRoutes.adminAccessLog,
      AppRoutes.adminPermissions,
      AppRoutes.adminConductionReport,
      AppRoutes.adminWeeklyReport,
      AppRoutes.adminSummaryReport,
      AppRoutes.adminStudentPerformance,
      AppRoutes.adminTsrReport,
      AppRoutes.adminPendingReport,
      AppRoutes.adminSubjectConduction,
      AppRoutes.adminClassSessions,
      AppRoutes.adminMcqSummary,
      AppRoutes.adminMcqAdherence,
      AppRoutes.adminActiveTeachers,
      AppRoutes.adminQuranLeaderboard,
      AppRoutes.adminRegistrations,
      AppRoutes.profile,
      AppRoutes.myChildren,
      AppRoutes.myParents,
      AppRoutes.notifications,
      AppRoutes.about,
      AppRoutes.accreditation,
      AppRoutes.contact,
      AppRoutes.sendFeedback,
      AppConstants.donateUrl,
    };

    for (final destination in searchDestinations) {
      expect(real, contains(destination.route), reason: destination.title);
    }
    // Two screens may share a name (Notifications); the subtitle tells them apart.
    expect(
      searchDestinations.map((d) => '${d.subtitle} ${d.title}').toSet().length,
      searchDestinations.length,
    );
  });

  test('a member with no admin permission finds the Me screens', () {
    final member = _holds(const []);

    final feedback = _find('feedback', member);
    expect(_titles(feedback), ['Send feedback']);
    expect(feedback.single.subtitle, 'Me');
    expect(feedback.single.target, AppRoutes.sendFeedback);

    expect(_titles(_find('profile', member)), ['Profile']);
    expect(_titles(_find('children', member)), ['My Children']);
    expect(_titles(_find('contact', member)), ['Contact']);
    expect(_titles(_find('accredit', member)), ['Accreditation']);
    expect(_titles(_find('about', member)), ['About']);
    expect(_titles(_find('notif', member)), ['Notifications']);
  });

  test('Donate is found as a contribution and opens the donation page', () {
    final member = _holds(const []);

    for (final word in ['donate', 'contribution', 'donation']) {
      final found = _find(word, member);
      expect(_titles(found), ['Donate'], reason: word);
      expect(found.single.target, AppConstants.donateUrl, reason: word);
    }
    expect(AppConstants.donateUrl, startsWith('https://'));
  });

  test('a guest finds the public pages but not a member\'s own screens', () {
    List<SearchResult> guest(String query) =>
        matchDestinations(query, _holds(const []), signedIn: false);

    expect(_titles(guest('about')), ['About']);
    expect(_titles(guest('contact')), ['Contact']);
    expect(_titles(guest('accredit')), ['Accreditation']);
    expect(_titles(guest('donate')), ['Donate']);
    expect(guest('feedback'), isEmpty);
    expect(guest('profile'), isEmpty);
    expect(guest('children'), isEmpty);
    expect(guest('notif'), isEmpty);
  });

  test('My Parents is found only by a member who may manage their parents', () {
    final may = _holds(['parents:manage:self']);
    final mayNot = _holds(const []);

    expect(_titles(_find('parents', may)), ['My Parents']);
    expect(_find('parents', mayNot), isEmpty);
  });

  test('a broadcaster finds both Notifications screens, told apart', () {
    final found = _find(
      'notifications',
      _holds(['notifications:broadcast:all']),
    );

    expect(found.map((r) => '${r.subtitle} ${r.title}').toSet(), {
      'Manage Notifications',
      'Me Notifications',
    });
  });

  test('a superuser finds a report and a tool by a part of the name', () {
    final payload = _holds([
      'reports:read:all',
      'registrations:read:all',
      'quran-leaderboard:read:all',
      'teachers:read:all',
      'guides:manage:all',
    ]);

    expect(
      _titles(_find('teach', payload)),
      containsAll(['Teachers', 'Active Teachers']),
    );
    expect(_titles(_find('guide', payload)), ['Guides']);
  });
}
