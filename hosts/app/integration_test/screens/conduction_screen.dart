import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

/// Finders for Class Conduction — the list of sessions, and the add form that
/// is the only screen in the app where the class's whole student roster is
/// rendered.
///
/// Finders only, no assertions — see [LoginScreenObject] for why.
///
/// **Why the roster is reached through a form.** There are two attendance
/// views: the read-only detail sheet behind a session card, and the
/// add/edit form. The detail sheet is unreachable for this cohort — the API's
/// `isEditable` (tsr-account `web/models/sessions.php:73`) keys off
/// `created_at`, and the reset migration stamps every session with `NOW()` and
/// the reviewer's own token, so all eight come back `editable: true` and a
/// card tap pushes the edit form instead. The add form is used rather than the
/// edit form because it needs no session id and no date: it loads the roster
/// from the class itself.
///
/// Most of what is here reads. The exception is the not-conducted group at the
/// foot of this object, which drives the form's Save — see issue #376.
class ConductionScreenObject {
  const ConductionScreenObject(this.$);

  final PatrolIntegrationTester $;

  /// The ten invented students, in the migration's order. Every one is an
  /// `@demo.invalid` address in the seed, so asserting on these names is also
  /// the checklist's "every visible record belongs to an invented person".
  static const demoStudentNames = <String>[
    'Faiz Antaria',
    'Hasan Bhojani',
    'Imran Chariwala',
    'Kausar Dungarpuri',
    'Mehdi Esmailji',
    'Nabeel Fatehi',
    'Qasim Ghadiali',
    'Rehan Halai',
    'Sajjad Idrisi',
    'Yusuf Jariwala',
  ];

  /// Arrival on the conduction list is asserted on the FAB, not on the app bar
  /// title: that title is the literal text 'Class Conduction', the same string
  /// as the dashboard tile that was just tapped, and a finder that can match
  /// two routes mid-transition fails as though the data were wrong.
  PatrolFinder get addRecordButton => $('Add Record');

  /// The roster is **eleven** rows, not ten: the reviewer is enrolled in their
  /// own class (`class_students` carries the conducting enrolment), and the
  /// API's `totalStudents` is `count($students)` over that table — so the
  /// teacher is offered for attendance alongside the students they teach.
  /// Asserting ten here is what this journey got wrong first, and it failed
  /// unreadably: see the note in plan.md task 12.
  static const demoRosterSize = 11;

  /// The add form's class info card. The count comes from the class record,
  /// so it is the "number" half of "every visible name, number and record
  /// belongs to an invented person".
  PatrolFinder get rosterCountChip => $('$demoRosterSize students');

  /// One row per student in the add form's attendance sheet. The sheet builds
  /// a plain Column rather than a lazy list, so every row is in the tree
  /// whether or not it is on screen.
  PatrolFinder studentNamed(String name) => $(name);

  // ---- Syllabus topics (MIQDAD only) -------------------------------------
  //
  // The three parts below are exactly what the migration stores for the MIQDAD
  // class's newest conducted session, joined by ' :: '. Two separate things
  // have to be true about them, and this object carries finders for both:
  // the list must render them as parts rather than as the stored string, and
  // the add form must open with them already split across its three controls.

  static const syllabusTopic = 'Understanding the Holy Quran - Intermediate';
  static const syllabusSubtopic = 'Lesson 2';
  static const syllabusDetail = 'finished the vocabulary list';

  /// The separator the column stores. It must never reach a chip — it is
  /// punctuation for a parser, and appears in none of the 76,182 topic values
  /// teachers have written, which is why it was chosen.
  static const storedSeparator = ' :: ';

  /// What the chip should read once [topicForDisplay] has been applied.
  PatrolFinder get syllabusTopicChip =>
      $('Arabic: $syllabusTopic · $syllabusSubtopic · $syllabusDetail');

  /// The oldest MIQDAD session stores free text instead, the way every row
  /// written before the dropdowns existed does. It must survive to the screen
  /// untouched — reformatting a teacher's own words would be changing them.
  static const legacyTopic = 'UHQI L9 - revision';
  PatrolFinder get legacyTopicChip => $('Arabic: $legacyTopic');

  /// The add form's subject toggle. Ticking it reveals the topic controls.
  PatrolFinder get arabicToggle => $('Arabic');

  /// The two dropdowns, found by their labels rather than their values, so
  /// their presence is asserted separately from what they hold.
  PatrolFinder get topicDropdown => $('Topic');
  PatrolFinder get subtopicDropdown => $('Sub-topic');

  /// A value inside a dropdown.
  ///
  /// Asserted with `findsWidgets`, not `findsOneWidget`: DropdownButton builds
  /// every item into an IndexedStack so it can size itself, so how many Text
  /// widgets carry a given label is an implementation detail of the framework,
  /// not something this suite should pin.
  PatrolFinder dropdownValue(String value) => $(value);

  /// The optional detail. A plain TextFormField, so this one is unambiguous.
  PatrolFinder get detailField => $(syllabusDetail);

  // ---- Duration and the compulsory subjects --------------------------------
  //
  // The form has two rows of buttons, as the web form does: Hours (0-4) and
  // Minutes (0, 15, 30, 45), with a -/+ stepper under them. The total reads
  // `150 min` between the stepper's buttons.

  /// A button in the Hours or Minutes row. Scoped to its row, because a bare
  /// '0' is in both and '2' or '30' also match dates and counts elsewhere.
  PatrolFinder durationHour(int hours) => $(#durationHours).$('$hours');
  PatrolFinder durationMinute(int minutes) => $(#durationMinutes).$('$minutes');

  /// The total, as the stepper shows it.
  PatrolFinder durationTotal(int minutes) => $('$minutes min');

  /// The free-text box a ticked subject without a syllabus shows. Ticking a
  /// subject is the only thing that reveals a topic input, so counting these
  /// plus [topicDropdown] counts the ticked subjects. `skipOffstage: false`
  /// because the lower subjects are below the fold.
  PatrolFinder get freeTextTopicBoxes =>
      $(find.text('Topic covered (required)...', skipOffstage: false));
  PatrolFinder get topicDropdowns => $(find.text('Topic', skipOffstage: false));

  /// How many of the four compulsory subjects (Arabic, Aqaed, Ahkam, Akhlaq)
  /// are ticked: each shows exactly one topic input, a dropdown or a text box.
  int get tickedSubjectCount =>
      freeTextTopicBoxes.evaluate().length + topicDropdowns.evaluate().length;

  // ---- Not Conducted (issue #376) -----------------------------------------
  //
  // The only finders in this object that write. They drive the one path that
  // sent SQL NULL into five NOT NULL columns and 500'd every time: a class
  // marked Not Conducted. The bug was entirely server-side — the client sent
  // `false`, the API turned it into `null` — so this group exists to hold the
  // API honest through the real form rather than to test the widgets.

  /// The add form's AppBar title, scoped to the AppBar for the reason the
  /// teacher object records: an unscoped text finder can match the route being
  /// left during a push transition.
  PatrolFinder get addFormTitle => $(AppBar).$('Add Conduction');

  /// The 'Not Conducted' half of the Class Status toggle.
  ///
  /// **Only unambiguous once the form is on top.** The conduction *list* prints
  /// the same string on the seeded not-conducted card
  /// (`conduction_list_screen.dart:400`), so wait on [addFormTitle] before
  /// tapping this — by then the list route is offstage and skipped.
  PatrolFinder get notConductedOption => $('Not Conducted');

  /// The reason field.
  ///
  /// Choosing Not Conducted replaces the entire conducted half of the form —
  /// duration, Quran, subjects, attendance — with this one section
  /// (`conduction_form_screen.dart:325-344`), leaving exactly one
  /// TextFormField on screen. That is what makes the bare type finder safe
  /// here and nowhere else in this object.
  PatrolFinder get reasonField => $(TextFormField);

  /// The AppBar's Save action. Scoped because the form carries a second submit
  /// at the foot of its scroll labelled 'Save Conduction', and the AppBar one
  /// needs no scrolling to reach.
  PatrolFinder get saveButton => $(AppBar).$('Save');

  /// A reason no seeded row carries.
  ///
  /// The cohort's own not-conducted session reads 'Teacher travelling', so
  /// asserting on that string would pass against the fixture and prove nothing
  /// about the save. This one can only appear if the record was written.
  static const notConductedReason = 'Patrol: students unavailable';

  /// The saved record, as the list renders it
  /// (`conduction_list_screen.dart:484`).
  ///
  /// The list is ordered `conducted_on desc` (tsr-account
  /// `web/models/sessions.php:42`) and the new record carries today's date
  /// while every seeded one is a whole week or more old, so it sorts first and
  /// is built even though the list is lazy.
  PatrolFinder get savedReasonRow => $(notConductedReason);

  // ---- Saved on the device, not yet sent (issue #719 item 5) ----------------

  /// The card a record saved offline shows on the list until the server has it:
  /// 'DATE: waiting to send'. Matched by the phrase, because the date is the
  /// form's own default and the journey does not pin it.
  PatrolFinder get unsentRecord =>
      $(find.textContaining('waiting to send', findRichText: true));

  /// The card's way to drop the record.
  PatrolFinder get discardUnsent => $('Discard');
}
