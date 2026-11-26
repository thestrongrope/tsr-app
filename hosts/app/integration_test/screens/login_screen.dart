import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';

/// Finders for the sign-in screen.
///
/// Screen objects hold finders only, never assertions — assertions live in the
/// journeys, so that changing how an element is located cannot silently change
/// what a test claims.
///
/// The app declares no `Key`s on these widgets, so the fields are located
/// positionally within the form and the button by its label. Adding
/// `ValueKey`s would make this sturdier but would be a production change made
/// to serve a test; the design rules that out unless label finders prove
/// brittle in practice, at which point it becomes a deliberate, recorded
/// exception.
class LoginScreenObject {
  const LoginScreenObject(this.$);

  final PatrolIntegrationTester $;

  /// `labelText: 'Email'` on the first `TextFormField` of the form.
  PatrolFinder get emailField => $(TextFormField).at(0);

  /// `labelText: 'Password'` on the second.
  PatrolFinder get passwordField => $(TextFormField).at(1);

  /// Reads 'Sign In', or 'Signing in...' while the request is in flight.
  PatrolFinder get signInButton => $(ElevatedButton).containing('Sign In');

  /// Home's invitation to a guest (`SignInInvite`). The app opens on Home, not
  /// on this screen (#555), so a sign-in starts by tapping it.
  PatrolFinder get inviteButton => $('Sign in or register');


  PatrolFinder get appleButton => $('Continue with Apple');
}
