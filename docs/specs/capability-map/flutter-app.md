# Capability map: the Flutter app (tsr-account `mobile/`, version 1.6.0+23)

Read on 15 Nov 2026 from source. Nothing was built or run: every statement is from reading code and docs.

## Summary

- **Organisation.** `lib/core` (API client, router, permissions, services, version gate, shared widgets) and `lib/features/<feature>` (about, account_deletion, admin, auth, calendar, classes, feedback, grand_quiz, home, mcq_manage, members, notifications, parent, profile, reports, search, wordpress). State is Riverpod, routing is go_router, HTTP is Dio. Five bottom tabs: Home, Library, Classes, Manage, Me. Library, articles, videos, About, release notes and join links are open to a guest.
- **Sign-in.** Firebase Authentication (Google, Apple, email and password; the register screen offers Google and Apple only). The Firebase ID token is sent as a bearer token; `POST /auth/link` links the account, `GET /me` loads the profile. An incomplete profile holds the member on profile completion; a pending or finished deletion request locks the app to its own screen.
- **Roles and permissions.** The app no longer reads role names. `GET /me/permissions` returns permission strings of the form `thing:action:scope` (scope `all`, `gender`, `assigned`, `own`, `taught`, `enrolled`, `self`), class-id lists per scope, a `navigation` object (which of the Classes and Manage tabs show) and a `revision`. `core/permissions/capabilities*.dart` turns that plus the loaded class list into every show/hide answer; the router guards ask the same object. The copy is saved on the device, refetched when a response header announces a new revision, after 15 minutes on resume, and after a 403. The API remains the only real boundary.
- **Offline.** A banner shows when there is no network. Many reads keep a "saved copy" in Hive, tied to the member, shown only when the server cannot be reached (never after a refusal). New conduction records and feedback messages queue on the device and replay on reconnect. Paper MCQ answers are kept on the device until submitted. Syllabus PDFs download to app storage. Library content is cached. Class and event reminders are local scheduled notifications.
- **Older documents.** `docs/mobile/app/app-features-and-roles.md` is **stale throughout**: its role flags, `notificationScope`, the three `page.*` strings, the drawer, `/user/permissions` and its "known gaps" describe code that is gone, and it lists perhaps a fifth of today's features. `web-vs-mobile-parity.md` is **stale** in its counts ("58 routes") and in several verdicts (guides, Quran leaderboard and class events are now in the app); its point that the API is the authority still holds. `roadmap.md` is **stale**: it describes phases long finished and lists Apple sign-in as future.
- **Not read.** Screen bodies were read by search, not line by line; tests, Patrol journeys and native platform code (beyond the Android manifest's link filters and the entitlement key names) were not read; the lower two thirds of the parity document were not read; route names come from the app's own constants and were **not** cross-checked against `web/api/mobile/index.php`. Where a method or a gate is marked "unsure", it was not confirmed.

## Capabilities

Paths are relative to the API base. `{c}` is a class id, `{q}` a quiz id, `{t}` a member token.

| Area | Capability (verb phrase) | Who uses it (role or permission) | Screen(s) (feature folder) | API routes called (method path) | Reads or writes | Device features used | Notes (max 15 words) |
|---|---|---|---|---|---|---|---|
| Sign-in | Sign in with Google, Apple or email and password | Anyone | auth (login, register, splash) | POST /auth/link; GET /me | writes | secure storage, local storage | Firebase Auth; Apple button shown on iOS only (unsure elsewhere). |
| Sign-in | Sign out | Signed-in member | profile | DELETE /devices | writes | push, secure storage, local storage | Clears saved copies, reminders and permissions on the device. |
| Sign-in | Complete a mandatory profile before using the app | New member | profile (profile_completion) | PATCH /me; GET /geo/countries; POST /geo/postal; POST /geo/cities | writes | none | Router holds the member here until the profile is complete. |
| Sign-in | Be told to update, or forced to update, the app | Anyone | core/version | GET /app-version | reads | deep links (store link) | Platform is android or ios only; web gets no gate. |
| Sign-in | Read release notes and a startup announcement | Anyone | core/version | GET /release-notes; GET /app-version | reads | local storage | Dismissals remembered on the device. |
| Me | View own profile | Signed-in member | profile | GET /me | reads | local storage | Copy token to clipboard. |
| Me | Edit own profile and location | Signed-in member | profile (edit_profile) | PATCH /me; GET /geo/countries; POST /geo/postal; POST /geo/cities | writes | none | Profile picture upload is commented out. |
| Me | Request account deletion, see its status, cancel it | Signed-in member | account_deletion | POST, GET, DELETE /me/deletion-request | writes | local storage | Pending request locks the app to one screen. |
| Me | Read About, Accreditation and Contact pages | Anyone | about | none | reads | deep links (external apps) | Static content; images load from the public website. |
| Me | Send feedback to the team | Signed-in member (unsure for guests) | feedback | POST /feedback | writes | local storage | Queued offline with a client id, replayed on reconnect. |
| Me | Open the donation page | Anyone | profile (me_screen) | none | reads | deep links (browser) | Opens the website. |
| Me | Choose class and conduction reminder settings | Enrolled member or teacher | classes (notification settings sheet), profile | none | writes (device only) | push (local scheduled notifications), local storage | Rule exists on the phone only; no server twin. |
| Me | Allow or decline notification permission | Signed-in member | notifications (permission screen) | POST /devices | writes | push | Registers the FCM token; skipped entirely on web. |
| Home | See the home feed: banner, classes, shortcuts, latest articles and videos | Anyone (member parts need sign-in) | home | GET /classes?include=managed; website Library routes | reads | local storage | Cards are chosen from permissions and the class list. |
| Home | Jump back to a recently used screen | Signed-in member | home (recent actions) | none | reads | local storage | Visits remembered on the device, re-checked against permissions. |
| Home | See this week's teaching picture on Home | reports:read | home, reports (this_week) | GET /reports/this-week | reads | none | Card links to the full This week screen. |
| Home | Follow a Grand or Mega quiz: countdown, register, watch live | Anyone | grand_quiz (banner on Home) | none on the API (quiz info service) | reads | deep links (YouTube, form), secure storage, local storage | Calls the account site's quiz info endpoint directly. |
| Search | Search people, classes, screens and articles from one box | Signed-in member; results narrowed by permission | search | GET /search; website search route | reads | none | Screen destinations are filtered locally by the same capability facts. |
| Members | Open a student's card | Permission checked by the API (unsure which) | members | GET /students/{t} | reads | none | Reached from search. |
| Members | Open a subscriber's card | Permission checked by the API (unsure which) | members | GET /subscribers/{t} | reads | none | Reached from search. |
| Library | Browse and filter articles by category and tag | Anyone | wordpress (library, all_articles, content_hub) | website /api/v1/articles, /taxonomies/categories, /taxonomies/tags | reads | local storage | Cached on the device for offline reading. |
| Library | Read an article and share it | Anyone | wordpress (tsr_article_detail) | website /api/v1/articles/{slug} | reads | deep links, files (share sheet), local storage | Opens from an article link on the website hosts. |
| Library | Search articles and lectures | Anyone | wordpress, search | website /api/v1/search, /lectures/search | reads | none | |
| Library | Browse videos and play one | Anyone | wordpress (all_videos, video_detail) | website /api/v1/youtube | reads | deep links (YouTube app or browser) | Playback hands over to YouTube; no in-app player seen. |
| Library | Browse publications and open one | Anyone | wordpress (publications_list) | website /api/v1/publications | reads | deep links (browser) | Opens the file outside the app. |
| Library | Read a legacy article by numeric id and bookmark it | Anyone | wordpress (article_detail, articles_list) | WordPress REST: /posts, /posts/{id}, /categories | reads | local storage | Legacy path; unsure whether still reachable in normal use. |
| Classes | See my classes: attending, conducting, managing | Enrolled member, teacher, class admin, admins | classes (class_dashboard) | GET /classes?include=managed | reads | local storage | Tab shows from `navigation.classes` or a non-empty list. |
| Classes | Open a class: details, schedule, teacher, quick actions | Member of the class or its manager | classes (class_dashboard, class_detail) | GET /classes/{c}; GET /classes/{c}/sessions | reads | local storage | Actions follow per-class grants, badge follows the list. |
| Classes | See my attendance and quiz average in a class | Enrolled student | classes (class_performance) | GET /classes/{c}/my-performance, /my-attendance, /my-scores | reads | local storage | Hidden for a class the member conducts. |
| Classes | Request a class (registration form) | Signed-in member | classes (class_registration) | GET /registration; POST /registration | writes | none | Form prefilled from the server. |
| Classes | Preview a class from a join link and continue joining | Anyone (joining needs sign-in) | classes (join_link) | GET /join/{code} | reads | deep links (in and out) | Joining itself finishes in the browser on the account site. |
| Classes | Share a class's join link | Class teacher | classes (class_dashboard) | none | reads | files (share sheet) | |
| Classes | Read the class syllabus and download its PDFs | Member of the class | classes (syllabus) | GET /syllabus/levels; GET /syllabus/level/{id} | reads | files (download, open), local storage | PDFs come from Google Drive links and are stored on the device. |
| Classes | Read the level guide for a class | Student or teacher of the class | classes (guide) | GET /classes/{c}/guide | reads | files (share text) | |
| Classes | Open a guide from a guide link | Signed-in student or teacher | classes (guide_link) | GET /me/guides; GET /me/guides/{slug} | reads | deep links | Claims the web's `/guide.php?guide=` link. |
| Classes | Read a guide in another language | Student or teacher | classes (guide_translate) | none | reads | web view | Loads the public guide page with its translate widget. |
| Quiz | List a class's quizzes | Enrolled student | classes (quiz_list) | GET /classes/{c}/mcq/quizzes | reads | local storage | |
| Quiz | Take a quiz and submit answers | Enrolled student | classes (quiz_taking) | GET /mcq/quizzes/{q}; GET /mcq/quizzes/{q}/questions; POST /mcq/quizzes/{q}/responses | writes | none | |
| Quiz | See my result for a quiz | Enrolled student | classes (quiz_result) | GET /mcq/quizzes/{q}/my-score | reads | none | |
| Quiz | Open an MCQ from a link, or see why it cannot open | Signed-in member | classes (mcq_link) | GET /mcq/by-code/{code}; GET /mcq/open | reads | deep links | Lists the MCQs the member may attempt instead. |
| Teaching | Record a class session with attendance (conduction) | sessions:create on the class | classes (conduction_form, attendance sheet) | GET /classes/{c}/conduction/new; GET /conduction/check; GET /syllabus-topics; GET /holy-quran; POST /classes/{c}/conduction | writes | local storage | New records queue offline and replay; refusals are kept and shown. |
| Teaching | List and edit past session records | sessions:create on the class | classes (conduction_list, conduction_form) | GET /classes/{c}/conduction; GET, PUT /classes/{c}/conduction/{id} | writes | local storage | An edit needs the network. |
| Teaching | See the class roster | class-students:read on the class | classes (class_manage, students tab) | GET /classes/{c}/students | reads | none | |
| Teaching | See each student's attendance, MCQ results and recitation | mcqs:manage on the class | classes (class_student_figures) | GET /classes/{c}/students/performance | reads | none | Date range filter. |
| Teaching | Set a class's day, time and timezone | classes:schedule or classes:update | classes (class_schedule, manage schedule tab) | GET, PUT /classes/{c}/schedule | writes | none | |
| Teaching | Edit class details | classes:update | classes (class_manage, details tab) | GET /classes/{c}/manage; PUT /classes/{c}; GET /classes/{c}/teachers | writes | none | Teacher search by name. |
| Teaching | Add a student, or many at once | classes:update | classes (manage students tab, bulk add dialog) | POST /classes/{c}/students; POST /classes/{c}/students/bulk | writes | none | |
| Teaching | Edit, remove, restore or transfer a student | classes:update | classes (manage students tab) | PUT /classes/{c}/students/{t}; POST .../remove, .../restore, .../transfer | writes | none | |
| Teaching | Make a student a class admin, or undo it | classes:update | classes (manage students tab) | PUT /classes/{c}/students/{t}/class-admin | writes | none | |
| Teaching | Send a notification to one class | notifications:send on the class | classes (class_send_notification) | POST /classes/{c}/notifications | writes | none | |
| Teaching | Schedule, list and delete class notifications and reminders | notifications:send on the class | classes (scheduled_notifications) | GET, POST /classes/{c}/notifications/scheduled; DELETE .../scheduled/{id} | writes | none | Uses the device's timezone name. |
| Teaching | Create, edit and delete a class's scheduled events | notifications:send (any scope per class; `all` from Manage) | calendar (class_events), admin (class_events_picker) | GET, POST /classes/{c}/scheduled-events; PATCH, DELETE .../{id} | writes | none | Manage tile needs the `all` scope. |
| Teaching | Create a class | classes:create | classes (create_class) | GET /classes/create-options; GET /class-levels; GET /classes/teachers; POST /classes | writes | none | Entry point unsure (no route constant found). |
| MCQ | List a class's MCQs with their state | mcqs:manage on the class | mcq_manage (list) | GET /classes/{c}/mcq/manage | reads | none | Copy an MCQ's link to the clipboard. |
| MCQ | Write a new MCQ or edit one | mcqs:manage | mcq_manage (edit) | GET /classes/{c}/mcq/topics; POST /classes/{c}/mcq; GET, PUT /mcq/manage/{q} | writes | none | |
| MCQ | Publish or deactivate an MCQ | mcqs:manage | mcq_manage (list, edit) | POST /mcq/manage/{q}/publish; POST /mcq/manage/{q}/deactivate | writes | none | |
| MCQ | Add a standard MCQ to a class | mcqs:manage | mcq_manage (standard) | GET /classes/{c}/mcq/standard; POST /classes/{c}/mcq/standard/{id}/copy | writes | none | |
| MCQ | Copy an MCQ to or from another class | mcqs:copy | mcq_manage (copy, copy_picker) | GET /mcq/copy/classes; GET .../{c}/topics; GET .../{c}/quizzes; POST /mcq/manage/{q}/copy | writes | none | Also a Manage tile ("Copy MCQ"). |
| MCQ | See every student's score on an MCQ | mcqs:manage | mcq_manage (scores) | GET /mcq/manage/{q}/scores | reads | none | |
| MCQ | Record paper answers for students without a phone | mcqs:manage | mcq_manage (offline) | GET, POST /mcq/manage/{q}/offline | writes | local storage | Marks kept on the device until submitted. |
| MCQ | Download and share an MCQ's printable sheet | mcqs:manage | mcq_manage | GET /mcq/manage/{q}/sheet | reads | files (temp file, share sheet) | PDF bytes written to a temp file. |
| Parents | See my children and their classes | Linked parent | parent (my_children, child_classes) | GET /me/children; GET /me/children/{t}/classes | reads | none | |
| Parents | See a child's attendance, performance and scores in a class | Linked parent | parent (child_class_performance) | GET /me/children/{t}/classes/{c}/attendance, /performance, /scores | reads | none | |
| Parents | Accept a parent invite from a link | Signed-in member | parent (parent_invite) | GET, POST /me/children/link/{code} | writes | deep links | Signed-out person signs in and returns to the link. |
| Parents | List my child links and revoke one | Linked parent | parent (parent_links) | GET /me/children/links; DELETE /me/children/{t}/link | writes | none | |
| Parents | See my parents and revoke one | parents:manage:self | parent (my_parents) | GET /me/parents; DELETE /me/parents/{t} | writes | none | |
| Parents | Create a parent invite link for a student | parents:add | parent (add_parent_dialog) | POST /members/{t}/parent-links | writes | none | Link copied to the clipboard. |
| Parents | Add a parent to a student directly by token | parents:add-direct | parent (add_parent_dialog) | GET /members/{t}/parents/candidate/{parent}; POST /members/{t}/parents | writes | none | |
| Notifications | Receive push notifications and open what they point to | Signed-in member | core/services, notifications | POST /devices | reads | push, deep links | Target is checked with the API before opening. |
| Notifications | Read the inbox, see the unread count, mark read | Signed-in member | notifications (user_notifications) | GET /user/notifications; GET .../unread-count; POST .../{id}/read; POST .../read-all | writes | local storage | |
| Notifications | Get a local reminder before a class and after it to record it | Enrolled member; teacher with sessions:create:own | core/services (scheduled notifications) | none | reads | push (local scheduled), local storage | Scheduled weekly from the class list on the phone. |
| Notifications | See my class events and timetable alerts, mute or delete one for me | Enrolled member | calendar (calendar_screen) | GET /me/calendar; PUT /me/calendar/settings (method unsure) | writes | push (local scheduled) | Events become local notifications. |
| Admin | Send a broadcast notification | notifications:broadcast | admin (send_notification, notification_dashboard) | GET /class-levels; POST /notifications/send; GET /notifications/stats | writes | none | |
| Admin | Review notifications sent | notifications:broadcast | admin (notification_history) | GET /notifications/history | reads | none | |
| Admin | Manage WhatsApp reminders: edit, dry run, run, test message, see runs | whatsapp:manage | admin (whatsapp_reminders, reminder, run) | GET /admin/whatsapp/reminders; PUT .../{id}; POST .../{id}/run; GET /admin/whatsapp/runs, /runs/{id}; POST /admin/whatsapp/test | writes | none | |
| Admin | Link, relink or log out the WhatsApp sender by QR code | whatsapp:manage | admin (whatsapp_link) | GET /admin/whatsapp/link, /link/qr; POST /link/relink, /link/logout | writes | screenshot block (Android only) | QR is drawn in the app. |
| Admin | List teachers, open one, record training, import teachers | teachers:read (gender picker needs scope `all`) | admin (teachers, teacher_detail) | GET /admin/teachers; GET /teachers/{t}; POST /admin/teachers/training; POST /admin/teachers/import | writes | none | |
| Admin | Transfer or promote students in bulk and see the history | students:transfer | admin (student_transfers) | GET /admin/transfers/classes; GET .../classes/{c}/students; POST /admin/transfers; GET /admin/transfers/history | writes | none | |
| Admin | See eligible donors and download the list | donors:read | admin (donors) | GET /admin/donors; GET /admin/donors/download | reads | files (temp file, share sheet) | xlsx or PDF. |
| Admin | Maintain the syllabus: add, edit, delete items | syllabus:update | admin (syllabus_admin) | GET /syllabus/levels; GET, POST /admin/syllabus; PUT, DELETE /admin/syllabus/{id} | writes | deep links (preview a file link) | Items point at Google Drive files. |
| Admin | Write and publish a level's guide | guides:manage | admin (guides_admin, guide_editor) | GET /guides; GET, PUT /guides/{level} | writes | none | Rich text editor, saved as HTML. |
| Admin | Refresh standard MCQs from their sources | standard-mcqs:update | admin (standard_mcqs) | GET /standard-mcqs/sources; POST /standard-mcqs/update | writes | none | |
| Admin | Run the Grand or Mega quiz: refresh, download, generate winners, publish, reset | quiz:admin (reset needs quiz:reset) | admin (quiz_admin) | GET /admin/quiz; POST /admin/quiz/settings/refresh, /download, /winners/generate, /winners/regenerate, /publish, /reset | writes | none | Slow calls: the server talks to Google Sheets. |
| Admin | Reveal quiz winners on screen to an audience | quiz:admin | admin (quiz_winners_reveal) | none (uses winners already loaded) | reads | none | Full-screen presentation; suits a large display. |
| Admin | Grant or revoke a member's permissions | permissions:manage | admin (permission_grants) | GET /admin/permissions/members; GET .../{t}; POST .../{t}/grants; POST /admin/permissions/grants/{id}/revoke | writes | none | |
| Admin | Give a member class access by rule, preview it, revoke it | class-access:manage | admin (class_access) | GET /admin/class-access/members, /members/{t}, /options; POST /preview; POST /members/{t}/rules; POST /rules/{id}/revoke | writes | none | |
| Admin | Look a member up by token and enrol them in a class | members:enrol-by-token | admin (enrol_by_token) | GET /admin/members/{t}; POST /admin/members/{t}/enrolments | writes | none | Responses hold contact details; never logged. |
| Admin | Deactivate a class and list deactivated classes | deactivated-classes:manage | admin (deactivated_classes, deactivate_class) | GET /admin/deactivated-classes; GET .../candidates; POST /classes/{c}/deactivate | writes | none | |
| Admin | Work account deletion requests: open, hold, mark confirmation sent, complete | deletion-requests:manage | admin (deletion_requests) | GET, POST /admin/deletion-requests; POST .../{id}/hold, /confirmation-sent, /complete | writes | none | |
| Admin | Read the admin access log and download it | audit-log:read | admin (access_log) | GET /admin/access-log; GET /admin/access-log/download | reads | files (temp file, share sheet) | |
| Reports | See this week across classes, and one class's alignment | reports:read | reports (this_week) | GET /reports/this-week; GET /reports/this-week/class/{c} | reads | none | |
| Reports | Read the conduction report and share it | reports:read | reports (conduction_report) | GET /reports/conduction; GET .../download; GET .../download-all | reads | files (temp file, share sheet) | xlsx, PDF, or all weeks. |
| Reports | Read the weekly report and share it | reports:read | reports (weekly_report) | GET /reports/weekly; GET /reports/weekly/download | reads | files | |
| Reports | Read the class summary and share it | reports:read | reports (summary_report) | GET /reports/summary; GET /reports/summary/download | reads | files | |
| Reports | Read student performance and share it | reports:read | reports (student_performance) | GET /reports/students; GET /reports/students/download | reads | files | |
| Reports | Read "TSR at a glance" and share it | reports:read | reports (tsr_report) | GET /reports/tsr; GET /reports/tsr/download | reads | files | |
| Reports | See pending work per teacher and nudge a teacher | reports:read | reports (pending_report) | GET /reports/pending; GET .../download; POST /reports/pending/nudge | writes | files | Nudge can preview before sending. |
| Reports | Read subject conduction and share it | reports:read | reports (subject_conduction) | GET /reports/subject-conduction; GET .../download | reads | files | |
| Reports | See class sessions, one class's history, and share them | reports:read | reports (class_sessions) | GET /reports/class-sessions; GET .../{c}; GET .../{c}/download; GET .../download-all | reads | files | |
| Reports | Read the MCQ summary, per class, and share it | reports:read | reports (mcq_summary) | GET /reports/mcq-summary; GET .../{c}; GET .../{c}/download; GET .../download-all | reads | files | |
| Reports | Read MCQ adherence, per class, and share it | reports:read | reports (mcq_adherence) | GET /reports/mcq-adherence; GET .../{c}; GET .../{c}/download; GET .../download-all | reads | files | |
| Reports | List active teachers and share the list | reports:read | reports (active_teachers) | GET /reports/active-teachers; GET .../download | reads | files | |
| Reports | Read the Quran recitation leaderboard and share it | quran-leaderboard:read | reports (quran_leaderboard) | GET /reports/quran-leaderboard; GET .../download | reads | files | Gender picker only for scope `all`. |
| Reports | See class registrations, place one in a class, reject one, share lists | registrations:read (reject needs registrations:reject) | reports (registrations) | GET /reports/registrations; GET /registrations/{id}/classes; POST /registrations/{id}/place; POST .../reject; GET /reports/registrations/download; GET .../allocated/download | writes | files | |

Row count: 104.

Every report screen pins a gender admin to their own gender; only a member whose permission has scope `all` sees a gender picker. The server narrows as well.

## Web and desktop readiness

**This is an assessment from reading `pubspec.yaml` and the code, not a build result.** Plugin platform support below is from the plugins' general documentation as I know it, not from this project's lock file; treat each "yes" as "expected", and each "unsure" as needing a build.

### What the folders hold

- `web/`: the stock Flutter scaffold only: `index.html` (with a Google sign-in client id meta tag), `manifest.json` (portrait, default colours and names), `favicon.png`, four icons. **No Firebase messaging service worker, no web Firebase options.**
- `macos/`, `windows/`, `linux/`: runner folders exist. `docs/mobile/app/` has macOS setup notes, but see the next point.
- `lib/firebase_options.dart` configures **Android and iOS only**. For web, macOS, Windows and Linux it throws "not configured". `main.dart` calls `Firebase.initializeApp` first, so the app as written stops at start on every other platform (unless `core/config/firebase_override.dart` supplies options: it is a debug-only seam for Android, as far as I read).

### Plugins

| Plugin | Web | Desktop | What the code does |
|---|---|---|---|
| firebase_core, firebase_auth | yes | macOS yes; Windows partial; Linux no | Needs options for each platform (missing today). Web sign-in branches exist: `signInWithPopup` for Google and Apple. |
| google_sign_in | yes (different flow) | macOS yes; Windows, Linux no | Initialised and used only when `!kIsWeb`; desktop Windows/Linux would need another route. |
| firebase_messaging | yes, with a VAPID key and a service worker | macOS yes; Windows, Linux no | Every use is skipped on web; `fcmVapidKey` is an empty string; no service worker. Device registration sends `platform: 'mobile'` as a constant. |
| flutter_local_notifications | no | macOS, Linux, Windows partly (scheduled: unsure) | Class, conduction and event reminders depend on it; initialisation skipped on web, so no reminders there. |
| firebase_crashlytics | no | macOS yes; Windows, Linux no | Guarded by `kIsWeb` only, so Windows and Linux would call a missing plugin. |
| firebase_analytics | yes | macOS yes; Windows, Linux no | Called unguarded in `main.dart` and in reminder telemetry (which swallows failures). |
| flutter_secure_storage | yes, but weaker (browser storage, not a keychain) | yes (Linux needs libsecret) | Holds the Firebase ID token read on every request. |
| hive_ce, hive_ce_flutter | yes (IndexedDB) | yes | All saved copies, queues, permissions, bookmarks. Per browser, cleared with site data. |
| dio | yes (browser adapter) | yes | Debug builds install an IO-only adapter with a certificate override: unsure it compiles or runs on web. Browser calls need CORS on the API, the website routes and the quiz info endpoint. |
| path_provider + `dart:io` `File` | no | yes | Every download (reports, donors, access log, MCQ sheet, syllabus PDFs) writes a file then shares or opens it. Six files import `dart:io`. |
| share_plus | partial (Web Share API; files limited by browser) | yes | Used for every report export and for links. |
| open_filex | unsure | yes | Opens downloaded syllabus PDFs. |
| webview_flutter | no | macOS yes; Windows, Linux no | Guide translation screen. |
| url_launcher | yes | yes | Videos, publications, donate, contact, join in browser. |
| connectivity_plus | yes (browser's own signal) | yes | Offline banner and queue replay. |
| device_info_plus, package_info_plus | yes | yes | Request headers; all six platforms have a branch, web guarded by `kIsWeb`. |
| flutter_timezone | yes | unsure on Windows and Linux | Timezone for scheduled class notifications. |
| cached_network_image | yes (no disk cache; images need CORS) | yes | Thumbnails. |
| flutter_quill, flutter_html, qr_flutter, go_router, flutter_riverpod, intl, timezone | yes | yes | Pure Dart or broadly supported. |

### Platform checks in the code

`kIsWeb` or `Platform.is...` appear in only five files: `main.dart` (Crashlytics, Google sign-in init, background push handler, notification services), `core/network/api_client.dart` (Crashlytics reporting, device headers), `core/version/version_provider.dart` (the update gate knows `android` and `ios` only), `features/auth/providers/auth_provider.dart` (popup sign-in on web, no device registration on web), `firebase_options.dart`. `core/services/secure_screen.dart` is a method channel that does nothing where no handler exists. Nothing else is guarded.

### What plainly cannot work in a browser as written

- **Start-up:** no web Firebase options, so initialisation throws.
- **Push:** no token, no registration, no inbox badge updates from push; local reminders (class, conduction, calendar events) do not exist on web.
- **Files:** every export and download goes through `dart:io` files and a temp directory; syllabus PDFs are saved to the documents directory and fetched from Google Drive, which a browser request would not be allowed to read.
- **Deep links:** on the phone the OS hands `/join/`, `/mcq/`, `/link/`, `/articles/` and `/guide.php` on the organisation's hosts to the app. In a browser the app is its own URL, so those links only reach it if it is served on those hosts at those paths (and go_router's default hash URLs are replaced by path URLs). Join links also hand over to the account site to finish.
- **Secure storage:** works, but the token sits in browser storage.
- **Web view:** the guide translation screen has no web implementation.
- **Layout:** the manifest is portrait-only, a bottom tab bar and bouncing scroll are forced everywhere; `core/utils/responsive.dart` (11 lines) and `content_width_cap.dart` are the only wide-screen helpers found. Wide tables (student figures) scroll sideways.
- **Unsure:** whether the debug-only IO HTTP adapter and the `dart:io` imports compile for web; whether SystemChrome and the screenshot block are harmless on desktop.

## Calls outside the API

- Firebase Authentication (Google, Apple, email and password); the Auth emulator in debug builds
- Firebase Cloud Messaging
- Firebase Crashlytics
- Firebase Analytics
- Google Sign-In
- Apple sign-in (through Firebase)
- The public website's Library routes under `/api/v1/` (articles, article by slug, search, lecture search, categories, tags, YouTube list, publications)
- The public website's WordPress REST API (legacy article screens)
- The public website's static pages and images (About, Accreditation, donate, article share links)
- The account site's quiz info endpoint (Grand and Mega quiz banner), and its join and parent-invite pages opened in the browser
- The account site's guide page with Google Translate, in a web view
- Google Drive (syllabus PDFs: download or open)
- Google Forms (Grand quiz entry form link)
- YouTube (videos and live streams, opened outside the app)
- App Store and Play Store (update link)
- WhatsApp, Telegram, Instagram, Facebook, X (contact links, opened outside the app)
- GeoNames (attribution link only, as far as read; the lookups go through the API's `/geo/` routes)
