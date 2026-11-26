import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/widgets.dart';

/// The ways into the app, in the order they are offered.
///
/// Deliberately presentational: it takes callbacks and holds no providers, so
/// the order can be tested without a Firebase app. `LoginScreen` reads
/// `authStateProvider`, and constructing that provider reaches
/// `FirebaseAuth.instance`, which a widget test has no way to satisfy.
///
/// The order is the point. The email form is last because its main job is
/// giving store reviewers a credential that does not depend on Google's
/// sign-in challenges, which reviewers routinely cannot clear on a handed-over
/// account. There is no guest option here: the app opens on Home as a guest
/// (#555), so signing in is something a guest chooses, not a gate to pass.
class SignInOptions extends StatelessWidget {
  const SignInOptions({
    super.key,
    required this.emailForm,
    required this.onGoogle,
    required this.onApple,
    required this.onRegister,
    required this.showApple,
    required this.isLoading,
  });

  /// The email and password form. Owned by the screen, which holds the
  /// controllers and form key.
  final Widget emailForm;

  final VoidCallback? onGoogle;
  final VoidCallback? onApple;
  final VoidCallback? onRegister;

  /// iOS only — see `showAppleSignIn`. Android and web would need a Services
  /// ID on the Firebase Apple provider, which is not configured.
  final bool showApple;

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SocialAuthButton.google(
          onPressed: isLoading ? null : onGoogle,
          label: isLoading ? 'Signing in...' : 'Continue with Google',
          isLoading: isLoading,
        ),

        if (showApple) ...[
          const SizedBox(height: 12),
          SocialAuthButton.apple(
            onPressed: isLoading ? null : onApple,
            label: isLoading ? 'Signing in...' : 'Continue with Apple',
            isLoading: isLoading,
          ),
        ],

        const SizedBox(height: 24),

        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                AppConstants.orDividerText,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),

        const SizedBox(height: 24),

        emailForm,

        const SizedBox(height: 24),

        // Registration creates an email account, so it belongs with the form
        // rather than with the social buttons.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('New to TSR? ', style: Theme.of(context).textTheme.bodyMedium),
            GestureDetector(
              onTap: onRegister,
              child: Text(
                'Create Account',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
