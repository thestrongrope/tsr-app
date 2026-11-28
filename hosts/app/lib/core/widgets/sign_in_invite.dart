import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../router/route_config.dart';
import '../theme/app_theme.dart';
import '../../features/auth/models/auth_state.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'tab_bar_inset.dart';

/// Invites a guest to sign in or register, in place of a member's content.
///
/// The sign-in screen offers registering too, so one button covers both.
class SignInInvite extends StatelessWidget {
  const SignInInvite({super.key, required this.message});

  /// What signing in gives them here, e.g. "See your classes".
  final String message;

  static const buttonLabel = 'Sign in or register';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.darkText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => context.push(AppRoutes.login),
            child: const Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

/// Shows [child] to a signed-in member; to anyone else, a screen titled
/// [title] that invites them to sign in, so a guest never sees a member's data
/// or an error in its place.
class SignedInOnly extends ConsumerWidget {
  const SignedInOnly({
    super.key,
    required this.title,
    required this.message,
    required this.child,
    this.guestFooter,
  });

  final String title;
  final String message;
  final Widget child;

  /// Shown under the invitation, for what a guest can use without signing in.
  final Widget? guestFooter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authStateProvider).status;
    if (status == AuthStatus.authenticated) return child;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: guestFooter == null
          ? Center(child: SignInInvite(message: message))
          : ListView(
              padding: withTabBarInset(
                context,
                const EdgeInsets.symmetric(vertical: 16),
              ),
              children: [
                SignInInvite(message: message),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: guestFooter,
                ),
              ],
            ),
    );
  }
}
