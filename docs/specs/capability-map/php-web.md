# Capability map: the PHP web application (tsr-account `web/`)

Read on 15 Nov 2026 from the tsr-account checkout, code only. One row is something a person can accomplish, not a file.

## Summary

- **Shape.** A flat folder of 110 top-level `web/*.php` pages (server-rendered Bootstrap, many with a Vue island that calls the same page with `?ajax=` or `?api=`), plus `web/score/` (the quiz competition admin, 6 files), `web/api/` (2 helper endpoints outside the mobile API), `web/cli/` (9 command-line scripts) and `web/models/` (shared with the mobile API). There is no menu file: the home page `index.php` shows a row of buttons, one per permission held, and the class list pages carry a "Generate Report" drop-down and a tab bar (`manage_classes_nav.php`).
- **Sign-in.** Google only, through a Firebase popup on `login.php`; the ID token is posted once, checked against Google's public keys, and a PHP session (cookie, about 30 days) carries the member from then on. The role is re-read from the database on every request.
- **Roles.** `users.roleid`: 1 super admin, 3 gents admin, 4 ladies admin, 5 class admin (coordinator of assigned classes), 6 class teacher (in the catalog only), 7 finance. Pages do not test the role; each calls `permissions->verify(user, 'resource:action', target)` and the scope (all, gender, assigned, own, taught, enrolled, self) narrows the data. Teachers and "MCQ admins" get their rights from the class relationship, and single permissions can be granted to a member by name. A refusal answers 404.
- **Coverage.** All 110 top-level pages were opened at least in excerpt (header comments, permission check, actions, headings, buttons, links). 92 are mapped to a row below, 6 are shared plumbing with no capability of their own, 12 look dead. Also covered: `score/`, `api/quiz_info.php`, `api/whatsapp_proxy.php`, `cli/`.
- **Not read.** `connect.php` (credentials), `vendor/`, the models in depth, most JavaScript, `score/log.txt`, `excel/`, `data/`, and every data, log, cache, state, backup and secrets folder. Excerpts only: a page may do more than its row says.
- **"Also in the mobile API?"** was answered by matching route names in `docs/specs/initial-build/operations.csv`, not by comparing behaviour. "unsure" means no clearly matching route was found.
- **The reverse gap.** Some admin work has no web page at all and exists only in the mobile API: permission grants, class-access rules, syllabus editing, enrol by token, feedback, the calendar, scheduled class notifications, the in-app notification inbox, the pending-registration nudge.

## Capabilities

| Area | Capability (verb phrase) | Who uses it (role) | PHP pages (file names) | Reads or writes | Also in the mobile API? (yes: route / no / unsure) | Outside services (email, WhatsApp, Sheets, push, PDF, payment, none) | Notes (max 15 words) |
|---|---|---|---|---|---|---|---|
| Account | Sign in with Google | Anyone | login.php, firebase-web-config.php, firebase-id-token-verifier.php | Writes (session) | yes: POST /auth/link | Firebase Auth | Google popup only; then a PHP session cookie. |
| Account | Sign out | Any member | logout.php | Writes (session) | no (the app signs out on the device) | Firebase Auth | Clears the session, then the browser's Firebase state. |
| Account | See the home page: own profile, own classes, the links one may open | Any member | index.php, index_profile.php | Reads | yes: GET /me, GET /classes, GET /me/permissions | none | Also routes pending links (join, MCQ, parent invite) after sign-in. |
| Account | Edit own profile (name, gender, contact, place, language) | Any member | profile.php, save_profile.php, geo_lookup.php | Writes | yes: PATCH /me, /geo/countries, /geo/postal, /geo/cities | none | Forced on first sign-in until required fields are filled. |
| Account | Read how to delete the account | Public | delete-account.php | Reads | partly: POST /me/deletion-request does the request | email (the member writes one) | No form by design; points to the app or email. |
| Account | Turn on browser notifications | Students and teachers | add_device.php, firebase-messaging-sw.php | Writes | yes: POST /devices | push (FCM web) | Web push; a service worker shows the message. |
| Account | Get pointed to the mobile app | Public | app.php, app_promo.php | Reads | yes: GET /app-version (same store data) | none | Banner on every page; /app redirects a phone to its store. |
| Members | Register for a class, or update the student profile | Any member | tsr_class.php, tsr_class_save.php | Writes | yes: GET /registration, POST /registration | none | Long form: education, occupation, skills, languages, locations. |
| Members | Open a class link and ask to join | Public, then member | join.php | Writes | yes: GET /join/{code}, POST /classes/join | none | Public preview; joining continues through sign-in and profile. |
| Members | Accept a parent link invitation | Parent (member) | link.php | Writes | yes: GET and POST /me/children/link/{code} | none | One-time code; shows little about the child. |
| Members | See parent-child links across members and revoke one | Super admin, gender admin | parent_links.php | Writes | unsure (per-child routes exist: /members/{child_token}/parent-links) | none | Cross-member list with filter; no matching list route found. |
| Members | See the donors list and download it | Super admin, finance | donors.php | Reads | yes: GET /admin/donors, /admin/donors/download | none | CSV download holds contact details. |
| Registrations | Review pending registrations of a gender | Super admin, gender admin, coordinator | manage_gents_registrations.php, manage_ladies_registrations.php | Reads | yes: GET /reports/registrations | none | Twin pages per gender; counts shown in the tab bar. |
| Registrations | Place a registrant in a class | Super admin, gender admin, coordinator | manage_gents_registrations.php, manage_ladies_registrations.php, save_student_class.php | Writes | yes: GET /registrations/{id}/classes, POST /registrations/{id}/place | none | Checked as students:enrol on the chosen class. |
| Registrations | Reject a registration with a reason | Super admin | manage_gents_registrations.php, manage_ladies_registrations.php | Writes | yes: POST /registrations/{id}/reject | none | Button shown only to holders of registrations:reject. |
| Registrations | Download pending registrations | Super admin, gender admin, coordinator | download_registrations.php | Reads | yes: GET /reports/registrations/download | none | CSV with contact details. |
| Registrations | Download placed registrations with their profile answers | Report readers | tsr_class_mis.php | Reads | yes: GET /reports/registrations/allocated/download | none | Menu label "Download Registrations"; output format not checked. |
| Classes | List the classes of a gender | Super admin, gender admin, coordinator | manage_gents_classes.php, manage_ladies_classes.php, manage_classes_nav.php | Reads | yes: GET /classes | none | Twin pages per gender; hosts the report menu. |
| Classes | Create a class | Super admin, gender admin | create_gents_class.php, create_ladies_class.php, save_class.php | Writes | yes: POST /classes, GET /classes/create-options | none | Coordinators cannot create. |
| Classes | Edit a class (details, teachers, tags) | Super admin, gender admin, coordinator | edit_class.php, save_class.php | Writes | yes: GET and PUT /classes/{class_id}, GET /classes/{class_id}/manage | none | The largest admin page; several jobs on one screen. |
| Classes | Add, remove or restore a student on a class roster | Super admin, gender admin, coordinator | edit_class.php, save_class_student.php | Writes | yes: POST /classes/{class_id}/students, .../remove, .../restore | none | |
| Classes | Add many students to a class by pasting names | Class managers | edit_class.php | Writes | yes: POST /classes/{class_id}/students/bulk | none | Creates member rows for people who never signed in. |
| Classes | Edit a student's name, email, mobile and notes | Class managers | edit_class.php | Writes | yes: PUT /classes/{class_id}/students/{token} | none | Email cannot change for a member who signs in. |
| Classes | Turn a class's "extra students" count into student rows | Class managers | edit_class.php | Writes | unsure (no route found) | none | Looks like a legacy data clean-up; ask if still needed. |
| Classes | Make a student the class's MCQ admin, or undo it | Teacher, super admin | view_class_student.php, update_class_admin.php, edit_class.php, save_class_student.php | Writes | yes: PUT /classes/{class_id}/students/{token}/class-admin | none | Two entry points: the class editor and the student page. |
| Classes | Deactivate a class and see the deactivated list and log | Super admin | manage_deactivated_classes.php | Writes | yes: GET /admin/deactivated-classes, .../candidates, POST /classes/{class_id}/deactivate | none | Type completed or shutdown, date, reason. |
| Classes | Transfer or promote students between classes; see the history | Super admin | student_transfers.php, save_student_transfer.php, edit_class.php | Writes | yes: /admin/transfers/classes, .../students, /admin/transfers/history, POST /admin/transfers | none | Source may be a deactivated class. |
| Teachers | List the teachers of a gender with their training levels | Super admin, gender admin | teachers.php | Reads | yes: GET /admin/teachers | none | Its CSV download branch produces an empty file. |
| Teachers | Change teachers' training levels, with a comment | Super admin, gender admin | teachers.php | Writes | yes: POST /admin/teachers/training | none | A batch is refused whole if one teacher is out of reach. |
| Teachers | Import the currently active teachers into the list | Super admin, gender admin | teachers.php | Writes | yes: POST /admin/teachers/import | none | |
| Teachers | Look up one person's class history (attending, attended, conducting, conducted) | Admins and coordinators (teachers:lookup) | view_teacher.php | Reads | yes: GET /teachers/{token} | none | Opened from the teachers list. |
| Conduction | See a class's sessions and who attended each | Teacher, MCQ admin, admins | class_sessions.php, class_sessions_api.php | Reads | yes: GET /classes/{class_id}/conduction, .../{session_id} | none | |
| Conduction | Record a class session: held or not, duration, topics, attendance, recitation | Teacher, MCQ admin, admins | class_sessions_add.php, class_sessions_api.php, choose_class.php | Writes | yes: POST /classes/{class_id}/conduction, GET .../new, .../check, /holy-quran, .../syllabus-topics | none | The chooser appears when the person records for several classes. |
| Conduction | Correct a recorded session | Teacher, MCQ admin, admins | class_sessions_add.php, class_sessions_api.php | Writes | yes: PUT /classes/{class_id}/conduction/{session_id} | none | Checked as sessions:update. |
| MCQ | List a class's MCQs | Teacher, MCQ admin, super admin | view_class_spot_quizzes.php | Reads | yes: GET /classes/{class_id}/mcq/manage | none | |
| MCQ | Write or edit an MCQ for a class | Teacher, MCQ admin, super admin | create_class_spot_quiz.php, edit_class_spot_quiz.php, save_class_spot_quiz.php | Writes | yes: POST /classes/{class_id}/mcq, GET and PUT /mcq/manage/{quiz_id} | none | |
| MCQ | Create a class MCQ from the standard MCQ bank | Teacher, MCQ admin, super admin | create_class_standard_quiz.php | Writes | yes: GET /classes/{class_id}/mcq/standard, POST .../standard/{mcq_id}/copy | none | |
| MCQ | Publish an MCQ and notify the class | Teacher, MCQ admin, super admin | publish_class_spot_quiz.php | Writes | yes: POST /mcq/manage/{quiz_id}/publish | push | Queues a push and writes in-app notification rows. |
| MCQ | Deactivate or reactivate an MCQ | Teacher, MCQ admin, super admin | deactivate_class_spot_quiz.php | Writes | yes: POST /mcq/manage/{quiz_id}/deactivate | none | |
| MCQ | See the scores of one MCQ | Teacher, MCQ admin, super admin | class_spot_quiz_scores.php | Reads | yes: GET /mcq/manage/{quiz_id}/scores | none | |
| MCQ | Print an MCQ paper or save it as PDF | Teacher, MCQ admin, super admin | print_spot_quiz.php | Reads | yes: GET /mcq/manage/{quiz_id}/sheet | PDF (the browser's print dialog) | No server PDF on the web; option order is locked first. |
| MCQ | Enter the answers of students who took the MCQ on paper | Teacher, MCQ admin, super admin | print_spot_quiz.php, save_offline_responses.php | Writes | yes: GET and POST /mcq/manage/{quiz_id}/offline | none | All questions or none per student. |
| MCQ | Copy an MCQ from one class to another | Super admin, gender admin, coordinator (mcqs:copy) | copy_spot_quiz.php | Writes | yes: /mcq/copy/classes, .../topics, .../quizzes, POST /mcq/manage/{quiz_id}/copy | none | Class list respects gender segregation. |
| MCQ | Refresh the standard MCQ bank from the spreadsheet | Super admin, members granted it | update_standard_mcqs.php | Writes | yes: GET /standard-mcqs/sources, POST /standard-mcqs/update | Sheets | Pick languages and levels; one run at a time. |
| MCQ | See my MCQs in a class and my scores | Student | view_student_spot_quizzes.php | Reads | yes: GET /classes/{class_id}/mcq/quizzes, .../my-scores | none | |
| MCQ | Open an MCQ link, answer it and submit | Student | mcq.php, spot_quiz.php, save_spot_quiz_response.php | Writes | yes: GET /mcq/by-code/{code}, /mcq/open, .../questions, POST .../responses | none | /mcq/&lt;code&gt; says why not when refused and lists open MCQs. |
| MCQ | See a class's students with MCQ, attendance and recitation totals | Teacher, MCQ admin, super admin | view_class_students.php | Reads | yes: GET /classes/{class_id}/students/performance | none | Date range; absolute or percentage view. |
| MCQ | See one student's detail within a class | Teacher, MCQ admin, super admin | view_class_student.php | Reads | unsure (GET /students/{token} may cover it) | none | Also holds the MCQ-admin button. |
| Reports | Explore the TSR dashboard (trend, non-conduction reasons, classes, teachers, students, locations, pace, closures) | Report readers (super admin, gender admin, coordinator) | dashboard.php | Reads | unsure (no matching route; /reports/this-week is narrower) | none | Largest page; 17 data calls; biggest single porting item. |
| Reports | Search a person and see their whole history ("Person 360") | Report readers | dashboard.php | Reads | unsure (GET /search and /admin/members/{token} are near) | none | A tab of the dashboard. |
| Reports | See "TSR at a glance" for a gender | Report readers | tsr_summary_report.php | Reads | yes: GET /reports/tsr | none | Conduction, MCQ, attendance, recitation over a period. |
| Reports | See the all-TSR summary report | Super admin, members granted it by name | summary_report.php | Reads | unsure (GET /reports/tsr looks the same per gender) | none | Near copy of the row above with its own permission. |
| Reports | See and download the weekly report | Report readers | class_reports_weekly_gents.php, class_reports_weekly_ladies.php | Reads | yes: GET /reports/weekly, .../download | none | Twin pages per gender; CSV. |
| Reports | See and download the monthly summary report | Report readers | class_reports_summary_gents.php, class_reports_summary_ladies.php | Reads | yes: GET /reports/summary, .../download | none | Twin pages per gender; CSV. |
| Reports | See and download the conduction report for a week | Report readers | class_reports_conduction.php | Reads | yes: GET /reports/conduction, .../download, .../download-all | none | CSV: summary, details, last week's details. |
| Reports | See the class sessions report and one class's session history | Report readers | class_sessions_report.php | Reads | yes: GET /reports/class-sessions, .../{class_id}, downloads | none | CSV export. |
| Reports | See the subject summary per class | Report readers | subject_summary_report.php | Reads | unsure (only /reports/subject-conduction found) | none | Conduction, duration and the four subjects per class. |
| Reports | See and download the subject conduction report | Report readers | class_subject_conduction_report.php | Reads | yes: GET /reports/subject-conduction, .../download | none | Column toggles; CSV. |
| Reports | See and download the student performance report | Report readers | student_performance_report.php | Reads | yes: GET /reports/students, .../download | none | CSV. |
| Reports | See and download the MCQ summary report | Report readers | mcq_summary_report.php | Reads | yes: GET /reports/mcq-summary, .../{class_id}, downloads | none | CSV. |
| Reports | See and download the MCQ adherence report | Report readers | mcq_adherence_report.php | Reads | yes: GET /reports/mcq-adherence, .../{class_id}, downloads | none | CSV. |
| Reports | See and download the active teachers report | Report readers | active_teachers_report.php | Reads | yes: GET /reports/active-teachers, .../download | none | CSV. |
| Reports | See the Quran recitation leaderboard and export it | Super admin, gender admin | quran_recitation_leaderboard.php, export_quran_leaderboard.php | Reads | yes: GET /reports/quran-leaderboard, .../download | none | The only xlsx export on the web. |
| Reports | Fetch classes with missing conduction as JSON or markdown | A program holding the report key; report readers | api_conduction_report.php | Reads | no | unsure (the caller is outside this folder) | X-API-Key or session; language options suggest it feeds reminder text. |
| Quiz competition | See the live Grand or Mega quiz and open today's episode | Any member | index_quiz.php | Reads | no (the app calls api/quiz_info.php, outside the route catalog) | Sheets (settings); an outside form link | Link is prefilled with the member's details. |
| Quiz competition | Serve the quiz status and schedule to the app | The mobile app, public | api/quiz_info.php | Reads | no (a web/api endpoint the app uses; not in operations.csv) | Sheets (cached settings) | Rate limited; optional Firebase and member token. |
| Quiz competition | Open the quiz admin screen | Members granted quiz:admin | score/quiz_admin.php | Reads | yes: GET /admin/quiz | none | Reached from a button on the home page. |
| Quiz competition | Edit the quiz settings and sync them with the spreadsheet | Members granted quiz:admin | score/manage_quiz_settings.php | Writes | partly: POST /admin/quiz/settings/refresh (editing: unsure) | Sheets | Series, type, episodes, dates, sheet ranges, colours. |
| Quiz competition | Pull the scores from the response sheets | Members granted quiz:admin | score/quiz_admin.php | Writes | yes: POST /admin/quiz/download | Sheets | Scoreboard is kept in state files, not the database. |
| Quiz competition | Draw or redraw the winners (daily, grand, mega, mega for students) | Members granted quiz:admin | score/quiz_admin.php | Writes | yes: POST /admin/quiz/winners/generate, .../regenerate | none | |
| Quiz competition | Publish scores and winners to the spreadsheet | Members granted quiz:admin | score/quiz_admin.php | Writes | yes: POST /admin/quiz/publish | Sheets; push (the model queues one) | Mapping of the "update" actions to this route is my reading. |
| Quiz competition | Show the winners on a reveal screen | Members granted quiz:admin | score/show_winners.php, score/show_mega_winner.php | Reads | unsure | none | Full-screen page with click-to-reveal, for a broadcast. |
| Quiz competition | See participation statistics by city | Members granted quiz:admin | score/stats.php | Reads | unsure (GET /admin/quiz may include them) | none | |
| Quiz competition | Reset the quiz data | Members granted quiz:admin | score/quiz_admin.php | Writes | yes: POST /admin/quiz/reset | none | Destructive. |
| Notifications | Send a push message to chosen students | Super admin | send_notification.php | Writes | yes: POST /notifications/send | push | Queued; the page does not learn the delivery result. |
| Notifications | Link or relink the WhatsApp account by QR code | Super admin | whatsapp_admin.php, api/whatsapp_proxy.php | Writes | yes: GET /admin/whatsapp/link, .../qr, POST .../relink, .../logout | WhatsApp (the notifier service) | The proxy keeps the notifier off the public network. |
| Notifications | Edit a WhatsApp reminder, send a test, run it now, read run history | Super admin | whatsapp_admin.php, api/whatsapp_proxy.php | Writes | yes: /admin/whatsapp/reminders, .../run, /admin/whatsapp/runs, /admin/whatsapp/test | WhatsApp | |
| Content | Read the teacher's guide for a level | Anyone with the link (no sign-in check seen) | guide.php | Reads | yes: GET /classes/{class_id}/guide, /me/guides/{slug} | a machine-translation widget | Stored in the database per level and language. |
| Content | Edit the guides per level and language | Super admin, members granted it | manage_guides.php | Writes | yes: GET /guides, GET and PUT /guides/{level_id} | none | |
| Content | Watch the how-to videos for class forms and MCQs | Teachers and MCQ admins | index.php | Reads | no | an outside video link | One file served from video-guides/, one outside link. |
| Admin | See who opened which admin page, and download the log | Super admin | admin_access_log.php, download_admin_access_log.php, header.php | Reads | yes: GET /admin/access-log, .../download | none | header.php writes a log row on every admin page view. |
| Admin | Work the account deletion queue (raise, hold, confirm, complete) | Super admin | account_deletion_requests.php | Writes | yes: GET and POST /admin/deletion-requests, .../hold, .../confirmation-sent, .../complete | Firebase account deletion; email (sent by hand, recorded here) | Complete cannot be undone; also purges old contact details. |
| Admin | Browse the mobile API reference | Super admin, members granted it | api_docs.php | Reads | no | none | Renders the generated api-docs.json. |
| Admin | Check that the web app, database and Firebase are up | Monitoring, the browser | health-check.php | Reads | partly: GET /health | Firebase | Public; called by the sign-in page's error script. |
| Admin | Collect browser sign-in errors on the server | The browser (public) | log-error.php | Writes (log file) | no | none | Anyone can post; writes one line per entry. |
| Admin | Count page views | Nobody directly | analytics.php | Writes (outside) | no | web analytics | Query strings are left out because they carry identifiers. |

86 rows.

## Pages not classified

Shared plumbing with no capability of its own:

- `connect.php`: opens the database connection and refreshes the session role. Not read (credentials).
- `functions.php`: shared helpers (roles, settings, session, CSRF, rate limit, push queue, Sheets helper, access logging).
- `footer.php`: closes the page layout.
- `session-config.php`: sets the session cookie's lifetime and flags.
- `firebase-admin-config.php`: loads the Firebase Admin SDK for push and account work.
- `firebase-server-error-handler.php`: logs sign-in errors; it also holds an email alert through PHP `mail()`, and I did not check whether that is switched on.

## Looks dead or unused

- `guide_l2.php`, `guide_l3.php`, `guide_l3_ur.php`, `guide_l4.php`: static guide text. `guide.php` now reads guides from the database, and the only other mention is the list of pages the access log skips.
- `view_spot_quizzes.php`, `create_spot_quiz.php`, `save_spot_quiz.php`, `deactivate_spot_quiz.php`, `spot_quiz_scores.php`: an older MCQ admin set under its own permission (`spot-quizzes:manage`, super admin only). They link only to each other; the home page always links to the `view_class_*` set instead.
- `view_class_spot_quiz.php`: a supervisor's view of one MCQ. No page links to it; it appears only in the access log's skip list.
- `firebase-token-verify.php`: an older token verifier that also answers a direct POST. Only the validation script below mentions it; `login.php` uses `firebase-id-token-verifier.php`.
- `validate-firebase-security.php`: a command-line check that answers 404 over HTTP. Nothing calls it.
- `syllabus/` (static HTML books): linked only from `guide_l4.php`, which is itself unused. Unsure whether people still hold direct links.
- In `teachers.php`, the `?download=` branch builds a CSV from an empty list.
- In `index.php`, the "active quiz campaign" lookup at the top sets variables that the page no longer shows, as far as I read.
- `excel/QuizWinners.xlsx` and `score/log.txt`: not opened; no code reference checked.

## Background or scheduled work started from web/

All are `web/cli/` scripts, guarded so they run from the command line only, started by the scheduler container's cron (`.docker/scheduler-crontab`):

- `cli/drain_push.php`, every minute: sends queued push messages through FCM.
- `cli/drain_whatsapp.php`, every 2 minutes (the gents channel): sends queued WhatsApp messages through the notifier service.
- `cli/drain_search.php`, every minute: brings the search index in line with changed records.
- `cli/reindex_search.php`, nightly: rebuilds the search index.
- `cli/run_due_reminders.php`, every minute: starts the WhatsApp reminders that are due.
- `cli/run_due_class_notifications.php`, every minute: queues the scheduled class notifications that are due.

Run by hand, not scheduled: `cli/find_student.php` (look a person up), `cli/verify_sheets_access.php` (can the service account reach each spreadsheet), `cli/seed_auth_emulator.php` (local sign-in accounts for synthetic members).

Work a page starts itself:

- `publish_class_spot_quiz.php`, `send_notification.php` and the quiz admin put rows on the push queue; the cron drain delivers them.
- `account_deletion_requests.php` purges expired contact details each time it is opened, because no scheduler does it.
- `whatsapp_admin.php` "Run now" asks the notifier service to start a reminder run.
- `update_standard_mcqs.php` and the quiz settings sync read the spreadsheets while the admin waits.
