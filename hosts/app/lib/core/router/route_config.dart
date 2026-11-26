/// Route configuration constants and helpers for The Strong Rope app.
///
/// This module defines all route paths, names, and provides utilities
/// for deep linking and navigation stack management.
library;

/// All route paths in the application.
abstract class AppRoutes {
  // === PUBLIC ROUTES (No auth required) ===
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';

  // Public content routes (shareable deep links)
  static const articles = '/articles';
  static const search = '/search';
  static const articleDetail = '/articles/:slug';
  static const videos = '/videos';
  static const videoDetail = '/videos/:videoId';
  static String videoDetailPath(String videoId) => '/videos/$videoId';
  static const publications = '/publications';

  // Release notes, opened from the version in the Me tab (guests included)
  static const releaseNotes = '/release-notes';

  // About, accreditation and contact (Me tab entries). Public pages, like
  // release notes.
  static const about = '/about';
  static const accreditation = '/accreditation';
  static const contact = '/contact';
  static const sendFeedback = '/send-feedback';

  // Tab starting screens. Library is public; Classes and Me invite a guest to
  // sign in in place of a member's content.
  static const library = '/library';
  static const me = '/me';

  // === PROTECTED ROUTES (Auth required) ===
  static const profileCompletion = '/profile-completion';
  static const notificationPermission = '/notification-permission';

  // Home and content
  static const home = '/home';
  static const homeArticles = '/home/articles';
  static const homeArticleDetail = '/home/articles/detail/:slug';

  // Profile
  static const profile = '/profile';
  static const editProfile = '/profile/edit';

  // Notifications
  static const notifications = '/notifications';

  // Classes
  static const classes = '/classes';
  static const classQuizzes = '/classes/:classId/quizzes';
  static const classPerformance = '/classes/:classId/performance';
  static const classSyllabus = '/classes/:classId/syllabus';
  static const classGuide = '/classes/:classId/guide';
  static const classRegistration = '/class-registration';
  static const classDashboardDetail = '/classes/:classId/dashboard';

  // Quizzes (standalone for deep linking)
  static const quizTaking = '/quizzes/:quizId';
  static const quizResult = '/quizzes/:quizId/result';

  // A quiz announcement's link (#868): lands on Home, where the quiz card is
  static const homeQuiz = '/home/quiz';

  // An MCQ link, by the MCQ's random code (not its id)
  static const mcqLink = '/mcq/:code';

  // A class join link, by the class's random code. Public: it shows the class
  // before sign-in.
  static const joinLink = '/join/:code';

  // A parent-invite link, by the invite's random code. Protected: accepting
  // needs an account, so a signed-out person signs in and returns to it.
  static const parentInviteLink = '/link/:code';

  // A guide link: the web's guide page, `/guide.php?guide=<slug>` (#1138).
  // Protected: only students and teachers read it, so a signed-out person
  // signs in and returns to it.
  static const guideLink = '/guide.php';

  // Class Conduction (teacher/admin)
  static const classConduction = '/classes/:classId/conduction';
  static const classConductionAdd = '/classes/:classId/conduction/add';
  static const classConductionEdit =
      '/classes/:classId/conduction/:sessionId/edit';

  // MCQ Management (teacher/admin)
  static const classMcqManage = '/classes/:classId/mcq/manage';
  static const classMcqManageAdd = '/classes/:classId/mcq/manage/add';
  static const classMcqManageStandard = '/classes/:classId/mcq/manage/standard';
  static const classMcqManageEdit = '/classes/:classId/mcq/manage/:quizId/edit';
  static const classMcqManageScores =
      '/classes/:classId/mcq/manage/:quizId/scores';
  static const classMcqManageOffline =
      '/classes/:classId/mcq/manage/:quizId/offline';
  static const classMcqManageCopy = '/classes/:classId/mcq/manage/:quizId/copy';

  // Class Notification (teacher/admin)
  static const myClassAlerts = '/my-class-alerts';
  static const classEvents = '/classes/:classId/scheduled-events';
  static const classNotification = '/classes/:classId/notifications/send';
  static const classScheduledNotifications =
      '/classes/:classId/notifications/scheduled';

  // Manage a class (classes:update) and a teacher's roster (class-students:read)
  static const classManage = '/classes/:classId/manage';
  static const classRoster = '/classes/:classId/students';
  static const classStudentFigures = '/classes/:classId/students/performance';

  // A class's day and time, for its teacher and MCQ admin (classes:schedule)
  static const classSchedule = '/classes/:classId/schedule';

  // === PARENT & CHILDREN ROUTES (#633) ===
  static const myChildren = '/parent/children';
  static const childClasses = '/parent/children/:childToken/classes';
  static String childClassesPath(int childToken) =>
      '/parent/children/$childToken/classes';
  static const childClassPerformance =
      '/parent/children/:childToken/classes/:classId';
  static String childClassPerformancePath(int childToken, int classId) =>
      '/parent/children/$childToken/classes/$classId';
  static const parentLinks = '/parent/links';
  static const myParents = '/me/parents';

  // === ADMIN ROUTES (Admin permission required) ===
  static const admin = '/admin';
  static const adminNotifications = '/admin/notifications';
  static const adminClassEvents = '/admin/class-events';
  static const adminSyllabus = '/admin/syllabus';
  static const adminReports = '/admin/reports';
  static const adminDeactivatedClasses = '/admin/deactivated-classes';
  static const adminTransfers = '/admin/transfers';
  static const adminPermissions = '/admin/permissions';
  static const adminPermissionMember = '/admin/permissions/:token';
  static String adminPermissionMemberPath(int token) =>
      '/admin/permissions/$token';
  static const adminClassAccess = '/admin/class-access';
  static const adminClassAccessMember = '/admin/class-access/:token';
  static String adminClassAccessMemberPath(int token) =>
      '/admin/class-access/$token';
  static const adminEnrolByToken = '/admin/enrol-by-token';
  static const adminWhatsappReminders = '/admin/whatsapp-reminders';
  static const adminDonors = '/admin/donors';
  static const adminGuides = '/admin/guides';
  static const adminAccessLog = '/admin/access-log';
  static const adminDeletionRequests = '/admin/deletion-requests';
  static const adminFeedback = '/admin/feedback';
  static const adminStandardMcqs = '/admin/standard-mcqs';
  static const adminQuiz = '/admin/quiz';
  static const adminMcqCopy = '/admin/mcq-copy';
  static const adminTeachers = '/admin/teachers';
  static const adminTeacher = '/admin/teachers/:token';
  static String adminTeacherPath(int token) => '/admin/teachers/$token';

  // The cards global search opens for a person (#557).
  static const studentCard = '/students/:token';
  static String studentCardPath(int token) => '/students/$token';
  static const subscriberCard = '/subscribers/:token';
  static String subscriberCardPath(int token) => '/subscribers/$token';
  static const adminConductionReport = '/admin/reports/conduction';
  static const adminWeeklyReport = '/admin/reports/weekly';
  static const adminSummaryReport = '/admin/reports/summary';
  static const adminStudentPerformance = '/admin/reports/students';
  static const adminTsrReport = '/admin/reports/tsr';
  static const adminPendingReport = '/admin/reports/pending';
  static const adminSubjectConduction = '/admin/reports/subject-conduction';
  static const adminClassSessions = '/admin/reports/class-sessions';
  static const adminMcqSummary = '/admin/reports/mcq-summary';
  static const adminMcqAdherence = '/admin/reports/mcq-adherence';
  static const adminActiveTeachers = '/admin/reports/active-teachers';
  static const adminQuranLeaderboard = '/admin/reports/quran-leaderboard';
  static const adminRegistrations = '/admin/reports/registrations';
  static const adminThisWeek = '/admin/this-week';
  static const sendNotification = '/admin/send-notification';
  static const notificationHistory = '/admin/notification-history';

  // Account deletion
  static const deleteAccount = '/profile/delete';
  static const deletionPending = '/account/deletion-pending';
  static const accountDeleted = '/account/deleted';

  // Legacy route (to be removed)
  static const classDashboard = '/class-dashboard';

  /// Routes that don't require authentication.
  static const publicRoutes = <String>[
    splash,
    login,
    register,
    articles,
    videos,
    publications,
    releaseNotes,
    about,
    accreditation,
    contact,
    library,
    search,
  ];

  /// Routes that require admin permissions.
  static const adminRoutes = <String>[
    admin,
    adminNotifications,
    adminClassEvents,
    adminSyllabus,
    adminReports,
    adminDeactivatedClasses,
    adminTransfers,
    adminPermissions,
    adminClassAccess,
    adminEnrolByToken,
    adminWhatsappReminders,
    adminDonors,
    adminGuides,
    adminAccessLog,
    adminDeletionRequests,
    adminFeedback,
    adminStandardMcqs,
    adminQuiz,
    adminMcqCopy,
    adminTeachers,
    adminConductionReport,
    adminWeeklyReport,
    adminSummaryReport,
    adminStudentPerformance,
    adminTsrReport,
    adminPendingReport,
    adminSubjectConduction,
    adminClassSessions,
    adminMcqSummary,
    adminMcqAdherence,
    adminActiveTeachers,
    adminQuranLeaderboard,
    adminRegistrations,
    adminThisWeek,
    sendNotification,
    notificationHistory,
  ];

  /// The screens the Me tab lists. Each is a sibling of [me] in the Me branch,
  /// not nested under it, so opening one with `go` leaves nothing to go back to.
  static const meScreens = <String>{
    profile,
    myChildren,
    myParents,
    notifications,
    about,
    accreditation,
    contact,
    sendFeedback,
  };

  /// A person card (#557) sits outside the tab shell; every other screen search
  /// can open is inside it. A route in the shell cannot be pushed from one
  /// outside it: go_router adds a second copy of the shell to the root
  /// navigator and Flutter asserts on the duplicate key. Open those with `go`.
  static bool isPersonCard(String path) =>
      path.startsWith('/students/') || path.startsWith('/subscribers/');

  /// Check if a route path is public (no auth required).
  static bool isPublicRoute(String path) {
    // Exact matches
    if (publicRoutes.contains(path)) return true;

    // Pattern matches for public routes with parameters
    if (path.startsWith('/articles/') && path != '/articles') return true;
    if (path.startsWith('/videos/') && path != '/videos') return true;
    if (isJoinLink(path)) return true;

    return false;
  }

  /// Whether a path is an MCQ link, `/mcq/<code>`.
  static bool isMcqLink(String path) => path.startsWith('/mcq/');

  /// Whether a path is a class join link, `/join/<code>`.
  static bool isJoinLink(String path) => path.startsWith('/join/');

  /// Whether a path is an article link, `/articles/<slug>` (#1121). The bare
  /// list path `/articles` is not one: it names no article.
  static bool isArticleLink(String path) =>
      path.startsWith('/articles/') && path.length > '/articles/'.length;

  /// Whether a path is a parent-invite link, `/link/<code>` (#1122).
  static bool isParentInviteLink(String path) =>
      path.startsWith('/link/') && path.length > '/link/'.length;

  /// Whether a path is a guide link, `/guide.php` (#1138), with or without its
  /// query: the guide is named by `?guide=`, and a saved link keeps it.
  static bool isGuideLink(String path) =>
      path == guideLink || path.startsWith('$guideLink?');

  /// Whether a path is one of the links the app claims on the TSR hosts.
  static bool isAppLink(String path) =>
      isMcqLink(path) ||
      isJoinLink(path) ||
      isArticleLink(path) ||
      isParentInviteLink(path) ||
      isGuideLink(path);

  /// Check if a route path requires admin permissions.
  static bool isAdminRoute(String path) {
    return path.startsWith('/admin');
  }

  /// Get the logical parent route for back-stack hydration.
  ///
  /// Returns the parent route path, or null if this is a root-level route.
  static String? getParentRoute(String path) {
    final parentMap = <String, String>{
      // Home sub-routes
      '/home/articles': home,

      // Profile routes
      profile: home,
      '/profile/edit': profile,

      // Class sub-routes - pattern matching handled below
      '/class-registration': classes,

      // Admin sub-routes
      admin: home,
      '/admin/notifications': admin,
      '/admin/send-notification': admin,
      '/admin/notification-history': admin,
      '/admin/reports/conduction': admin,
    };

    // Exact match
    if (parentMap.containsKey(path)) {
      return parentMap[path];
    }

    // Pattern matches
    if (path.startsWith('/home/articles/detail/')) return '/home/articles';
    if (path.startsWith('/videos/')) return videos;
    if (path.startsWith('/classes/') && path.contains('/quizzes')) {
      return classes;
    }
    if (path.startsWith('/classes/') && path.contains('/performance')) {
      return classes;
    }
    if (path.startsWith('/classes/') && path.contains('/syllabus')) {
      return classes;
    }
    if (path.startsWith('/classes/') && path.contains('/guide')) {
      return classes;
    }
    if (path.startsWith('/classes/') && path.contains('/conduction')) {
      return classes;
    }
    if (path.startsWith('/classes/') && path.contains('/mcq/manage')) {
      return classes;
    }
    if (path.startsWith('/classes/') && path.contains('/notifications/')) {
      return classes;
    }
    if (RegExp(
      r'^/classes/\d+/(manage|students|students/performance|schedule)$',
    ).hasMatch(path)) {
      return classes;
    }
    if (path.startsWith('/classes/') && path.contains('/dashboard')) {
      return classes;
    }
    if (path.startsWith('/quizzes/') && path.endsWith('/result')) {
      // Extract quiz path without /result
      return path.replaceAll('/result', '');
    }
    if (path.startsWith('/quizzes/')) {
      // Quiz taking -> needs class context, fallback to classes
      return classes;
    }

    // Parent routes (#633)
    if (RegExp(r'^/parent/children/\d+/classes/\d+$').hasMatch(path)) {
      final childToken = path.split('/')[3];
      return '/parent/children/$childToken/classes';
    }
    if (RegExp(r'^/parent/children/\d+/classes$').hasMatch(path)) {
      return myChildren;
    }
    if (path == myChildren || path == parentLinks || path == myParents) {
      return me;
    }

    return null;
  }

  /// Build a complete navigation stack for a given deep link path.
  ///
  /// Returns a list of routes from root to the target, enabling proper
  /// back button behavior when entering via deep link.
  static List<String> buildNavigationStack(String targetPath) {
    final stack = <String>[];
    String? current = targetPath;

    while (current != null) {
      stack.insert(0, current);
      current = getParentRoute(current);
    }

    // Always ensure home is at the base for protected routes
    if (stack.isNotEmpty && !isPublicRoute(targetPath) && stack.first != home) {
      stack.insert(0, home);
    }

    return stack;
  }
}

/// Route names for type-safe navigation.
abstract class RouteNames {
  static const splash = 'splash';
  static const login = 'login';
  static const register = 'register';
  static const profileCompletion = 'profileCompletion';
  static const notificationPermission = 'notificationPermission';
  static const home = 'home';
  static const articles = 'articles';
  static const search = 'search';
  static const articleDetail = 'articleDetail';
  static const articleBySlug = 'articleBySlug';
  static const allArticles = 'allArticles';
  static const allVideos = 'allVideos';
  static const videoDetail = 'videoDetail';
  static const publications = 'publications';
  static const releaseNotes = 'releaseNotes';
  static const about = 'about';
  static const accreditation = 'accreditation';
  static const contact = 'contact';
  static const sendFeedback = 'sendFeedback';
  static const library = 'library';
  static const me = 'me';
  static const profile = 'profile';
  static const editProfile = 'editProfile';
  static const deleteAccount = 'deleteAccount';
  static const deletionPending = 'deletionPending';
  static const accountDeleted = 'accountDeleted';
  static const userNotifications = 'userNotifications';
  static const classes = 'classes';
  static const classDashboard = 'classDashboard';
  static const homeQuiz = 'homeQuiz';
  static const classDashboardDetail = 'classDashboardDetail';
  static const classQuizzes = 'classQuizzes';
  static const classPerformance = 'classPerformance';
  static const classSyllabus = 'classSyllabus';
  static const classGuide = 'classGuide';
  static const classRegistration = 'classRegistration';
  static const quizTaking = 'quizTaking';
  static const quizResult = 'quizResult';
  static const mcqLink = 'mcqLink';
  static const joinLink = 'joinLink';
  static const parentInviteLink = 'parentInviteLink';
  static const guideLink = 'guideLink';
  static const classConduction = 'classConduction';
  static const classConductionAdd = 'classConductionAdd';
  static const classConductionEdit = 'classConductionEdit';
  static const classMcqManage = 'classMcqManage';
  static const classMcqManageAdd = 'classMcqManageAdd';
  static const classMcqManageStandard = 'classMcqManageStandard';
  static const classMcqManageEdit = 'classMcqManageEdit';
  static const classMcqManageScores = 'classMcqManageScores';
  static const classMcqManageOffline = 'classMcqManageOffline';
  static const classMcqManageCopy = 'classMcqManageCopy';
  static const classNotification = 'classNotification';
  static const classScheduledNotifications = 'classScheduledNotifications';
  static const classManage = 'classManage';
  static const classRoster = 'classRoster';
  static const classStudentFigures = 'classStudentFigures';
  static const classSchedule = 'classSchedule';
  static const admin = 'admin';
  static const adminClassEvents = 'adminClassEvents';
  static const notificationDashboard = 'notificationDashboard';
  static const adminSyllabus = 'adminSyllabus';
  static const adminReports = 'adminReports';
  static const adminDeactivatedClasses = 'adminDeactivatedClasses';
  static const adminTransfers = 'adminTransfers';
  static const adminPermissions = 'adminPermissions';
  static const adminPermissionMember = 'adminPermissionMember';
  static const adminClassAccess = 'adminClassAccess';
  static const adminClassAccessMember = 'adminClassAccessMember';
  static const adminEnrolByToken = 'adminEnrolByToken';
  static const adminWhatsappReminders = 'adminWhatsappReminders';
  static const adminDonors = 'adminDonors';
  static const adminGuides = 'adminGuides';
  static const adminAccessLog = 'adminAccessLog';
  static const adminGuideEditor = 'adminGuideEditor';
  static const adminDeletionRequests = 'adminDeletionRequests';
  static const adminFeedback = 'adminFeedback';
  static const adminStandardMcqs = 'adminStandardMcqs';
  static const adminQuiz = 'adminQuiz';
  static const adminMcqCopy = 'adminMcqCopy';
  static const adminTeachers = 'adminTeachers';
  static const adminTeacher = 'adminTeacher';
  static const adminConductionReport = 'adminConductionReport';
  static const adminWeeklyReport = 'adminWeeklyReport';
  static const adminSummaryReport = 'adminSummaryReport';
  static const adminStudentPerformance = 'adminStudentPerformance';
  static const adminTsrReport = 'adminTsrReport';
  static const adminPendingReport = 'adminPendingReport';
  static const adminSubjectConduction = 'adminSubjectConduction';
  static const adminClassSessions = 'adminClassSessions';
  static const adminClassSessionHistory = 'adminClassSessionHistory';
  static const adminMcqSummary = 'adminMcqSummary';
  static const adminMcqSummaryClass = 'adminMcqSummaryClass';
  static const adminMcqAdherence = 'adminMcqAdherence';
  static const adminMcqAdherenceClass = 'adminMcqAdherenceClass';
  static const adminActiveTeachers = 'adminActiveTeachers';
  static const adminQuranLeaderboard = 'adminQuranLeaderboard';
  static const adminRegistrations = 'adminRegistrations';
  static const adminThisWeek = 'adminThisWeek';
  static const studentCard = 'studentCard';
  static const subscriberCard = 'subscriberCard';
  static const sendNotification = 'sendNotification';
  static const notificationHistory = 'notificationHistory';
  static const myChildren = 'myChildren';
  static const childClasses = 'childClasses';
  static const childClassPerformance = 'childClassPerformance';
  static const parentLinks = 'parentLinks';
  static const myParents = 'myParents';
}
