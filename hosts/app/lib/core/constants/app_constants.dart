import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'The Strong Rope';

  /// The donation page on the website, opened from Me and from search.
  static const String donateUrl = 'https://thestrongrope.com/donate';
  static const String appTagline = 'Connecting hearts to Islamic knowledge';
  static const String appDescription =
      'The Strong Rope app: Islamic duas, lectures & Ahlul Bayt (a.s.) content.';

  // API Configuration
  /// Base URL for the PHP API layer.
  ///
  /// Debug builds default to the local Dockerized PHP mobile API container
  /// (tsr_mobileapi, port 4005). Release builds default to the production
  /// endpoint. Override either with:
  /// `--dart-define=TSR_API_BASE_URL=https://mobile-api.thestrongrope.com`
  static final String baseUrl = _resolveBaseUrl();

  /// Pick the API base URL: an explicit `--dart-define` wins, otherwise
  /// debug builds use the local container and release builds use prod.
  static String _resolveBaseUrl() {
    const fromEnv = String.fromEnvironment('TSR_API_BASE_URL');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return kDebugMode
        ? 'https://127.0.0.1:4005'
        : 'https://mobile-api.thestrongrope.com';
  }

  static const String apiVersion = '/api/v1';

  // API Endpoints
  /// Minimum and recommended build per platform, for the update gate.
  /// Public — a client old enough to need updating may also hold a stale token.
  static const String appVersionEndpoint = '/app-version';

  /// Every release's notes, newest first. Public, like [appVersionEndpoint].
  static const String releaseNotesEndpoint = '/release-notes';
  static const String authEndpoint = '/auth/link';
  static const String usersEndpoint = '/users';
  static const String classesEndpoint = '/classes';
  static const String devicesEndpoint = '/devices';
  static const String classLevelsEndpoint = '/class-levels';
  static const String classCreateOptionsEndpoint = '/classes/create-options';
  static const String classCreateTeachersEndpoint = '/classes/teachers';
  static const String adminDonorsEndpoint = '/admin/donors';
  static const String adminDeletionRequestsEndpoint =
      '/admin/deletion-requests';
  static String adminDeletionRequestHoldEndpoint(int id) =>
      '/admin/deletion-requests/$id/hold';
  static String adminDeletionRequestConfirmationSentEndpoint(int id) =>
      '/admin/deletion-requests/$id/confirmation-sent';
  static String adminDeletionRequestCompleteEndpoint(int id) =>
      '/admin/deletion-requests/$id/complete';
  // Feedback review queue (#891)
  static const String adminFeedbackEndpoint = '/admin/feedback';
  static String adminFeedbackHandleEndpoint(int id) =>
      '/admin/feedback/$id/handle';
  static String adminFeedbackUnhandleEndpoint(int id) =>
      '/admin/feedback/$id/unhandle';
  static const String standardMcqSourcesEndpoint = '/standard-mcqs/sources';
  static const String standardMcqUpdateEndpoint = '/standard-mcqs/update';
  // Quiz admin (#673): Grand and Mega.
  static const String quizAdminEndpoint = '/admin/quiz';
  static const String quizAdminRefreshEndpoint = '/admin/quiz/settings/refresh';
  static const String quizAdminDownloadEndpoint = '/admin/quiz/download';
  static const String quizAdminGenerateEndpoint =
      '/admin/quiz/winners/generate';
  static const String quizAdminRegenerateEndpoint =
      '/admin/quiz/winners/regenerate';
  static const String quizAdminPublishEndpoint = '/admin/quiz/publish';
  static const String quizAdminResetEndpoint = '/admin/quiz/reset';
  static const String adminDonorsDownloadEndpoint = '/admin/donors/download';
  static const String mcqEndpoint = '/mcq';
  static const String reportsConductionEndpoint = '/reports/conduction';
  static const String reportsConductionDownloadEndpoint =
      '/reports/conduction/download';
  static const String reportsConductionDownloadAllEndpoint =
      '/reports/conduction/download-all';
  static const String reportsWeeklyEndpoint = '/reports/weekly';
  static const String reportsWeeklyDownloadEndpoint =
      '/reports/weekly/download';
  static const String reportsSummaryEndpoint = '/reports/summary';
  static const String reportsStudentsEndpoint = '/reports/students';
  static const String reportsStudentsDownloadEndpoint =
      '/reports/students/download';
  static const String reportsTsrEndpoint = '/reports/tsr';
  static const String reportsTsrDownloadEndpoint = '/reports/tsr/download';
  static const String reportsPendingEndpoint = '/reports/pending';
  static const String reportsPendingDownloadEndpoint =
      '/reports/pending/download';
  static const String reportsPendingNudgeEndpoint = '/reports/pending/nudge';
  static const String reportsClassSessionsEndpoint = '/reports/class-sessions';
  static const String reportsClassSessionsDownloadAllEndpoint =
      '/reports/class-sessions/download-all';
  static const String reportsMcqSummaryEndpoint = '/reports/mcq-summary';
  static const String reportsMcqSummaryDownloadAllEndpoint =
      '/reports/mcq-summary/download-all';
  static const String reportsMcqAdherenceEndpoint = '/reports/mcq-adherence';
  static const String reportsMcqAdherenceDownloadAllEndpoint =
      '/reports/mcq-adherence/download-all';
  static const String reportsActiveTeachersEndpoint =
      '/reports/active-teachers';
  static const String reportsActiveTeachersDownloadEndpoint =
      '/reports/active-teachers/download';
  static const String reportsThisWeekEndpoint = '/reports/this-week';
  static const String searchEndpoint = '/search';
  static const String reportsRegistrationsEndpoint = '/reports/registrations';
  static const String reportsRegistrationsDownloadEndpoint =
      '/reports/registrations/download';
  static const String reportsAllocatedRegistrationsDownloadEndpoint =
      '/reports/registrations/allocated/download';
  static const String registrationsEndpoint = '/registrations';
  static const String reportsQuranLeaderboardEndpoint =
      '/reports/quran-leaderboard';
  static const String reportsQuranLeaderboardDownloadEndpoint =
      '/reports/quran-leaderboard/download';
  static const String reportsSubjectConductionEndpoint =
      '/reports/subject-conduction';
  static const String reportsSubjectConductionDownloadEndpoint =
      '/reports/subject-conduction/download';
  static const String reportsSummaryDownloadEndpoint =
      '/reports/summary/download';

  // Class-specific endpoints (append class_id)
  static String classDetailEndpoint(int classId) => '/classes/$classId';
  static String classManageEndpoint(int classId) => '/classes/$classId/manage';
  static String classScheduleEndpoint(int classId) =>
      '/classes/$classId/schedule';
  static String classGuideEndpoint(int classId) => '/classes/$classId/guide';
  static const String guidesEndpoint = '/guides';
  // Reading a level's guide by the slug in a guide link (#1138).
  static const String readerGuidesEndpoint = '/me/guides';
  static String readerGuideEndpoint(String slug) =>
      '/me/guides/${Uri.encodeComponent(slug)}';
  static const String adminAccessLogEndpoint = '/admin/access-log';
  static const String adminAccessLogDownloadEndpoint =
      '/admin/access-log/download';
  static String guideEndpoint(int levelId) => '/guides/$levelId';
  static String classStudentsEndpoint(int classId) =>
      '/classes/$classId/students';
  static String classStudentFiguresEndpoint(int classId) =>
      '/classes/$classId/students/performance';
  static String classStudentsBulkEndpoint(int classId) =>
      '/classes/$classId/students/bulk';
  static String classTeachersEndpoint(int classId) =>
      '/classes/$classId/teachers';
  static String classStudentEndpoint(int classId, int token) =>
      '/classes/$classId/students/$token';
  static String classSessionsEndpoint(int classId) =>
      '/classes/$classId/sessions';
  static String classAttendanceEndpoint(int classId) =>
      '/classes/$classId/my-attendance';
  static String classPerformanceEndpoint(int classId) =>
      '/classes/$classId/my-performance';

  /// Scheduled and reminder class notifications. The literal
  /// `scheduled` segment is what the server router matches.
  static String classScheduledNotificationsEndpoint(int classId) =>
      '/classes/$classId/notifications/scheduled';

  static String classScheduledNotificationEndpoint(int classId, int id) =>
      '/classes/$classId/notifications/scheduled/$id';
  static String classQuizzesEndpoint(int classId) =>
      '/classes/$classId/mcq/quizzes';
  static String classScoresEndpoint(int classId) =>
      '/classes/$classId/my-scores';
  // The syllabus topics for the class's own level. Only levels with a syllabus
  // return anything — see ClassesRepository.getSyllabusTopics.
  static String classSyllabusTopicsEndpoint(int classId) =>
      '/classes/$classId/syllabus-topics';
  // Class conduction (teacher/admin)
  static String classConductionEndpoint(int classId) =>
      '/classes/$classId/conduction';
  static String classConductionNewEndpoint(int classId) =>
      '/classes/$classId/conduction/new';
  static String classConductionCheckEndpoint(int classId) =>
      '/classes/$classId/conduction/check';
  static String classConductionSessionEndpoint(int classId, int sessionId) =>
      '/classes/$classId/conduction/$sessionId';

  /// The Holy Quran surah list backing the conduction form's dropdown.
  static const String holyQuranEndpoint = '/holy-quran';

  // Class request form (mobile version of tsr_class.php)
  static const String classRegistrationEndpoint = '/registration';

  // Quiz endpoints
  static String quizDetailEndpoint(int quizId) => '/mcq/quizzes/$quizId';
  static String quizQuestionsEndpoint(int quizId) =>
      '/mcq/quizzes/$quizId/questions';
  static String quizSubmitEndpoint(int quizId) =>
      '/mcq/quizzes/$quizId/responses';
  static String quizScoreEndpoint(int quizId) =>
      '/mcq/quizzes/$quizId/my-score';

  // MCQ management (teacher/admin)
  static String mcqManageEndpoint(int classId) =>
      '/classes/$classId/mcq/manage';
  static String mcqCreateEndpoint(int classId) => '/classes/$classId/mcq';
  static String mcqTopicsEndpoint(int classId) =>
      '/classes/$classId/mcq/topics';
  static String mcqStandardEndpoint(int classId) =>
      '/classes/$classId/mcq/standard';
  static String mcqStandardCopyEndpoint(int classId, int mcqId) =>
      '/classes/$classId/mcq/standard/$mcqId/copy';
  // Copy picker (mcqs:copy): classes, then topics, then quizzes.
  static const String mcqCopyClassesEndpoint = '/mcq/copy/classes';
  static String mcqCopyTopicsEndpoint(int classId) =>
      '/mcq/copy/classes/$classId/topics';
  static String mcqCopyQuizzesEndpoint(int classId) =>
      '/mcq/copy/classes/$classId/quizzes';
  static String mcqManageDetailEndpoint(int quizId) => '/mcq/manage/$quizId';
  static String mcqManageScoresEndpoint(int quizId) =>
      '/mcq/manage/$quizId/scores';
  static String mcqManageOfflineEndpoint(int quizId) =>
      '/mcq/manage/$quizId/offline';
  static String mcqManageSheetEndpoint(int quizId) =>
      '/mcq/manage/$quizId/sheet';
  static String mcqManagePublishEndpoint(int quizId) =>
      '/mcq/manage/$quizId/publish';
  static String mcqManageDeactivateEndpoint(int quizId) =>
      '/mcq/manage/$quizId/deactivate';
  static String mcqManageCopyEndpoint(int quizId) => '/mcq/manage/$quizId/copy';

  // A super admin's permission grants (#567)
  static const String adminPermissionMembersEndpoint =
      '/admin/permissions/members';
  static String adminPermissionMemberEndpoint(int token) =>
      '/admin/permissions/members/$token';
  static String adminPermissionGrantEndpoint(int token) =>
      '/admin/permissions/members/$token/grants';
  static String adminPermissionRevokeEndpoint(int grantId) =>
      '/admin/permissions/grants/$grantId/revoke';

  // A coordination admin's class access (#1034)
  static const String classAccessMembersEndpoint =
      '/admin/class-access/members';
  static String classAccessMemberEndpoint(int token) =>
      '/admin/class-access/members/$token';
  static const String classAccessOptionsEndpoint =
      '/admin/class-access/options';
  static const String classAccessPreviewEndpoint =
      '/admin/class-access/preview';
  static String classAccessGrantEndpoint(int token) =>
      '/admin/class-access/members/$token/rules';
  static String classAccessRevokeEndpoint(int ruleId) =>
      '/admin/class-access/rules/$ruleId/revoke';

  // A super admin looks a member up by token and enrols them (#1050)
  /// Responses under it carry a member's contact details, so they are never
  /// written to the debug log.
  static const String adminMembersPrefix = '/admin/members/';
  static String adminMemberEndpoint(int token) => '/admin/members/$token';
  static String adminMemberEnrolEndpoint(int token) =>
      '/admin/members/$token/enrolments';

  // A super admin links an extra student to the member they are (#1135).
  /// Responses under it carry a member's contact details, so they are never
  /// written to the debug log.
  static const String adminExtraStudentsPrefix = '/admin/extra-students/';
  static String adminExtraStudentLinkEndpoint(int token, int memberToken) =>
      '/admin/extra-students/$token/link/$memberToken';

  // Bulk student transfers (#420)
  static const String adminTransfersEndpoint = '/admin/transfers';
  static const String adminTransferClassesEndpoint = '/admin/transfers/classes';
  static const String adminTransferHistoryEndpoint = '/admin/transfers/history';
  static String adminTransferStudentsEndpoint(int classId) =>
      '/admin/transfers/classes/$classId/students';

  // Deactivated classes (#618)
  static const String adminDeactivatedClassesEndpoint =
      '/admin/deactivated-classes';
  static const String adminDeactivatedClassesCandidatesEndpoint =
      '/admin/deactivated-classes/candidates';
  static String classDeactivateEndpoint(int classId) =>
      '/classes/$classId/deactivate';

  // WhatsApp reminders (#418)
  static const String adminWhatsappRemindersEndpoint =
      '/admin/whatsapp/reminders';
  static String adminWhatsappReminderEndpoint(int id) =>
      '/admin/whatsapp/reminders/$id';
  static String adminWhatsappReminderRunEndpoint(int id) =>
      '/admin/whatsapp/reminders/$id/run';
  static const String adminWhatsappRunsEndpoint = '/admin/whatsapp/runs';
  static String adminWhatsappRunEndpoint(int id) => '/admin/whatsapp/runs/$id';
  static const String adminWhatsappTestEndpoint = '/admin/whatsapp/test';
  static const String adminWhatsappLinkEndpoint = '/admin/whatsapp/link';
  static const String adminWhatsappLinkQrEndpoint = '/admin/whatsapp/link/qr';
  static const String adminWhatsappRelinkEndpoint =
      '/admin/whatsapp/link/relink';
  static const String adminWhatsappLogoutEndpoint =
      '/admin/whatsapp/link/logout';

  // Teachers (#622)
  static const String adminTeachersEndpoint = '/admin/teachers';
  static const String adminTeachersTrainingEndpoint =
      '/admin/teachers/training';
  static const String adminTeachersImportEndpoint = '/admin/teachers/import';
  static String teacherEndpoint(int token) => '/teachers/$token';
  static String studentEndpoint(int token) => '/students/$token';
  static String subscriberEndpoint(int token) => '/subscribers/$token';

  // Syllabus endpoints
  static const String syllabusLevelsEndpoint = '/syllabus/levels';
  static String syllabusLevelEndpoint(int levelId) =>
      '/syllabus/level/$levelId';
  static const String adminSyllabusEndpoint = '/admin/syllabus';
  static String adminSyllabusItemEndpoint(int id) => '/admin/syllabus/$id';

  // Parent & Children endpoints (#633)
  static const String childrenEndpoint = '/me/children';
  static const String childrenLinksEndpoint = '/me/children/links';
  static String childrenLinkAcceptEndpoint(String code) =>
      '/me/children/link/$code';
  static String childrenLinkRevokeEndpoint(int childToken) =>
      '/me/children/$childToken/link';
  static String childClassesEndpoint(int childToken) =>
      '/me/children/$childToken/classes';
  static String childClassAttendanceEndpoint(int childToken, int classId) =>
      '/me/children/$childToken/classes/$classId/attendance';
  static String childClassPerformanceEndpoint(int childToken, int classId) =>
      '/me/children/$childToken/classes/$classId/performance';
  static String childClassScoresEndpoint(int childToken, int classId) =>
      '/me/children/$childToken/classes/$classId/scores';
  static String memberParentLinksEndpoint(int childToken) =>
      '/members/$childToken/parent-links';
  static String memberParentCandidateEndpoint(
    int childToken,
    int parentToken,
  ) => '/members/$childToken/parents/candidate/$parentToken';
  static String memberParentsEndpoint(int childToken) =>
      '/members/$childToken/parents';
  static const String myParentsEndpoint = '/me/parents';
  static String myParentRevokeEndpoint(int parentToken) =>
      '/me/parents/$parentToken';

  // Storage Keys
  static const String userBoxKey = 'user_box';
  static const String settingsBoxKey = 'settings_box';
  static const String cacheBoxKey = 'cache_box';
  static const String offlineBoxKey = 'offline_box';

  // Secure Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String firebaseTokenKey = 'firebase_token';

  // User Preferences Keys
  static const String isFirstLaunchKey = 'is_first_launch';
  static const String selectedLanguageKey = 'selected_language';
  static const String notificationsEnabledKey = 'notifications_enabled';
  static const String themeKey = 'theme_mode';

  // Scheduled Notification Settings Keys
  static const String classReminderEnabledKey = 'class_reminder_enabled';
  static const String conductionReminderEnabledKey =
      'conduction_reminder_enabled';
  static const String classReminderLeadMinutesKey =
      'class_reminder_lead_minutes';
  static const String conductionReminderDelayMinutesKey =
      'conduction_reminder_delay_minutes';

  // Animation Durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 400);
  static const Duration longAnimationDuration = Duration(milliseconds: 600);

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double defaultBorderRadius = 8.0;
  static const double cardBorderRadius = 12.0;
  static const double buttonHeight = 48.0;

  // Image Paths
  static const String logoPath = 'assets/images/logo/tsr_logo.webp';

  // Default Icons (using Material Icons instead of assets)
  // Use Icons.account_circle or Icons.person for user avatar

  // Error Messages
  static const String networkErrorMessage =
      'Please check your internet connection and try again.';
  static const String genericErrorMessage =
      'Something went wrong. Please try again.';
  static const String authErrorMessage =
      'Authentication failed. Please try again.';
  static const String timeoutErrorMessage =
      'Request timed out. Please try again.';

  // Success Messages
  static const String loginSuccessMessage = 'Welcome back!';
  static const String logoutSuccessMessage =
      'You have been signed out successfully.';
  static const String profileUpdatedMessage = 'Profile updated successfully.';

  // Login Page
  static const String loginTitle = 'Get Started';
  static const String loginSubTitle =
      'Sign in to continue your Islamic learning journey.';
  static const String orDividerText = 'or';

  // Registration Page
  static const String registerTitle = 'Join TSR Academy';
  static const String registerSubTitle =
      'Create your account and begin your Islamic learning journey with our community';
  static const String registerButtonText = 'Create Account';
  static const String loginInstead = 'Already have an account? ';
  static const String loginLinkText = 'Sign In';
  static const String registerSuccessMessage = 'Welcome to TSR Academy!';
  static const String registerWelcomeTitle = 'Welcome to Our Community';
  static const String registerWelcomeDesc =
      'Start your journey of Islamic knowledge and spiritual growth';

  // Registration Benefits Section
  static const String benefitsHeading = "What you'll get:";
  static const String benefitsQualityEducationTitle = 'Quality Education';
  static const String benefitsQualityEducationDesc =
      'Learn from qualified Islamic scholars';
  static const String benefitsCommunityTitle = 'Community';
  static const String benefitsCommunityDesc =
      'Join a supportive learning community';
  static const String benefitsComprehensiveTitle = 'Comprehensive';
  static const String benefitsComprehensiveDesc =
      'Access to diverse Islamic knowledge';

  // Registration Benefits: full list moved here for single source of truth
  static const List<BenefitItem> registerBenefits = <BenefitItem>[
    BenefitItem(
      icon: Icons.school_rounded,
      title: benefitsQualityEducationTitle,
      description: benefitsQualityEducationDesc,
    ),
    BenefitItem(
      icon: Icons.people_rounded,
      title: benefitsCommunityTitle,
      description: benefitsCommunityDesc,
    ),
    BenefitItem(
      icon: Icons.book_rounded,
      title: benefitsComprehensiveTitle,
      description: benefitsComprehensiveDesc,
    ),
  ];
  // Validation Messages
  static const String emailRequiredMessage = 'Email is required';
  static const String emailInvalidMessage =
      'Please enter a valid email address';
  static const String nameRequiredMessage = 'Name is required';
  static const String nameMinLengthMessage =
      'Name must be at least 2 characters';

  // Network Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
  // The quiz admin's download and publish call Google Sheets from inside the
  // request (#673), which is slow on a real sheet.
  static const Duration quizAdminSlowTimeout = Duration(seconds: 120);

  // Cache Duration
  static const Duration cacheExpiration = Duration(hours: 24);
  static const Duration shortCacheExpiration = Duration(hours: 1);
  static const Duration categoryCacheDuration = Duration(days: 30);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Firebase Configuration
  static const String fcmVapidKey =
      ''; // Add your VAPID key for web notifications

  // WordPress Article Categories - matches your WordPress setup
  static final Map<String, CategoryInfo> articleCategories = {
    'Snippets': CategoryInfo(
      icon: Icons.snippet_folder,
      color: Color(0xFF2E7D32), // Dark green
    ),
    'Raafezi': CategoryInfo(
      icon: Icons.security,
      color: Color(0xFF7B1FA2), // Purple
    ),
    'Ahle Tasannun': CategoryInfo(
      icon: Icons.groups,
      color: Color(0xFF1976D2), // Blue
    ),
    'Mahdaviyyat': CategoryInfo(
      icon: Icons.star,
      color: Color(0xFFFF8F00), // Gold
    ),
    'Wilayat': CategoryInfo(
      icon: Icons.favorite,
      color: Color(0xFFE91E63), // Pink
    ),
    'Q&A': CategoryInfo(
      icon: Icons.quiz,
      color: Color(0xFF388E3C), // Green
    ),
    'Traditions': CategoryInfo(
      icon: Icons.history_edu,
      color: Color(0xFF5D4037), // Brown
    ),
    'Imam Ali (as) in Quran': CategoryInfo(
      icon: Icons.menu_book,
      color: Color(0xFF6A1B9A), // Deep purple
    ),
  };

  // Bookmark storage keys
  static const String bookmarksBoxKey = 'bookmarks_box';

  // ============ Grand/Mega Quiz Constants ============

  /// Grand/Mega Quiz info: public, a bearer is optional (the API answers a signed-out caller too).
  static const String quizInfoEndpoint = '/quiz/info';

  /// How long quiz info is kept: the API's own settings copy is 60 seconds old at most.
  static const Duration quizInfoCacheDuration = Duration(seconds: 60);

  /// Quiz status values
  static const String quizStatusOffline = 'offline';
  static const String quizStatusUpcoming = 'upcoming';
  static const String quizStatusRegistered = 'registered';
  static const String quizStatusLive = 'live';
  static const String quizStatusEnded = 'ended';

  /// Episode status values
  static const String episodeStatusUpcoming = 'upcoming';
  static const String episodeStatusLive = 'live';
  static const String episodeStatusEnded = 'ended';

  /// Quiz type values
  static const String quizTypeMega = 'mega';
  static const String quizTypeGrand = 'grand';

  /// Quiz cache key
  static const String grandQuizCacheKey = 'grand_quiz_info';

  // Quiz UI Messages
  static const String quizRegisterNow = 'Register Now';
  static const String quizRegistered = 'You are registered!';
  static const String quizWatchLive = 'Watch Live';
  static const String quizViewDetails = 'View Details';
  static const String quizEnded = 'Quiz Ended';
  static const String quizUpcoming = 'Coming Soon';
  static const String quizNoActive = 'No active quiz at the moment';
}

class BenefitItem {
  final IconData icon;
  final String title;
  final String description;

  const BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class CategoryInfo {
  final IconData icon;
  final Color color;

  const CategoryInfo({required this.icon, required this.color});
}

class AppStrings {
  static const String youtubeChannelUrl =
      'https://www.youtube.com/@TheStrongRope';
  static const String viewChannelText = 'View channel';
  static const String subscribeText = 'Subscribe';
  static const String videosAppBarSubtitle = 'Subscribe for latest lectures';
}
