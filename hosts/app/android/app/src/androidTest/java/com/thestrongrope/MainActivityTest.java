package com.thestrongrope;

import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;
import pl.leancode.patrol.PatrolJUnitRunner;

/**
 * Entry point for Patrol's Android instrumentation runner. Each Dart test in
 * integration_test/ is surfaced here as a JUnit parameter, so the Android test
 * runner drives them one by one.
 *
 * MainActivity is this app's real launcher activity
 * (src/main/kotlin/com/thestrongrope/MainActivity.kt), not a bare
 * FlutterActivity, so it is named directly -- same package, no import needed.
 *
 * See docs/specs/patrol-integration-testing/design.md.
 */
@RunWith(Parameterized.class)
public class MainActivityTest {
    @Parameters(name = "{0}")
    public static Object[] testCases() {
        PatrolJUnitRunner instrumentation =
                (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.setUp(MainActivity.class);
        instrumentation.waitForPatrolAppService();
        return instrumentation.listDartTests();
    }

    public MainActivityTest(String dartTestName) {
        this.dartTestName = dartTestName;
    }

    private final String dartTestName;

    @Test
    public void runDartTest() {
        PatrolJUnitRunner instrumentation =
                (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.runDartTest(dartTestName);
    }
}
