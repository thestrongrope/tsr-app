import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/auth/widgets/sign_in_options.dart';

Widget _wrap({bool showApple = false, bool isLoading = false}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SignInOptions(
          emailForm: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              ElevatedButton(onPressed: () {}, child: const Text('Sign In')),
            ],
          ),
          onGoogle: () {},
          onApple: () {},
          onRegister: () {},
          showApple: showApple,
          isLoading: isLoading,
        ),
      ),
    ),
  );
}

/// Vertical position of the first match, for asserting on-screen order.
double _topOf(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder.first).dy;

void main() {
  // The order is the point of this widget, not incidental layout: the email
  // form is last because it exists mainly to give store reviewers a credential.
  // A refactor that quietly restores the old order should fail here.
  testWidgets('offers social first, then the email form', (tester) async {
    await tester.pumpWidget(_wrap());

    final google = _topOf(tester, find.text('Continue with Google'));
    final email = _topOf(tester, find.byType(TextFormField));
    final signIn = _topOf(tester, find.text('Sign In'));
    final register = _topOf(tester, find.text('Create Account'));

    expect(google, lessThan(email), reason: 'Google must precede the form');
    expect(email, lessThan(signIn), reason: 'fields must precede Sign In');
    expect(
      signIn,
      lessThan(register),
      reason: 'Create Account belongs with the email block, after Sign In',
    );
  });

  testWidgets('has no guest option: the app opens as a guest already', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());

    expect(find.text('Continue as Guest'), findsNothing);
  });

  testWidgets('places Apple directly after Google when it is offered', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(showApple: true));

    final google = _topOf(tester, find.text('Continue with Google'));
    final apple = _topOf(tester, find.text('Continue with Apple'));
    final email = _topOf(tester, find.byType(TextFormField));

    expect(google, lessThan(apple));
    expect(apple, lessThan(email), reason: 'Apple stays above the email form');
  });

  testWidgets('hides Apple off iOS rather than showing it broken', (
    tester,
  ) async {
    // Android and web have no Services ID on the Firebase Apple provider, so
    // the button would fail if shown.
    await tester.pumpWidget(_wrap(showApple: false));

    expect(find.text('Continue with Apple'), findsNothing);
  });

  testWidgets('disables social entry while a sign-in is running', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(isLoading: true));

    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Signing in...'), findsOneWidget);
  });
}
