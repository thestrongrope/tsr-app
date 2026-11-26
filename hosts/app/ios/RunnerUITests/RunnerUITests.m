// Patrol's iOS test runner.
//
// Patrol drives native UI from an XCUITest bundle running in its own process,
// which is why this target has to exist at all: the Dart journeys in
// integration_test/journeys/ cannot reach native dialogs on their own. The
// Android half has always existed, at
// android/app/src/androidTest/java/com/thestrongrope/MainActivityTest.java;
// commit a9a9d8c7 added that side only, which is why iOS could never run.
//
// The macro expands into the XCTestCase subclass patrol_cli discovers, so this
// file is the whole target. Do not add test methods here -- the journeys are
// Dart.
@import XCTest;
@import patrol;
@import ObjectiveC.runtime;

PATROL_INTEGRATION_TEST_IOS_RUNNER(RunnerUITests)
