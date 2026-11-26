import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../models/auth_state.dart';
import '../../../core/providers/permissions_provider.dart';
import '../../../core/widgets/permissions_unconfirmed_view.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final permissionsState = ref.watch(permissionsProvider);

    // Determine if we should show loading
    final isLoading =
        authState.status == AuthStatus.loading ||
        authState.status == AuthStatus.initial ||
        (authState.status == AuthStatus.authenticated &&
            permissionsState.loading);

    return Scaffold(
      backgroundColor: AppTheme.splashGreen,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  AppConstants.logoPath,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.school,
                      size: 80,
                      color: AppTheme.primaryGreen,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 32),

            // App Name
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              AppConstants.appTagline,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 48),

            // Loading indicator
            if (isLoading)
              Column(
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    authState.status == AuthStatus.authenticated
                        ? 'Loading...'
                        : 'Initializing...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Add a manual skip button in case auth gets stuck
                  TextButton(
                    onPressed: () {
                      // Force navigation to login by clearing auth state
                      ref
                          .read(authStateProvider.notifier)
                          .forceUnauthenticated();
                    },
                    child: Text(
                      'Skip to Login',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              )
            else if (authState.status == AuthStatus.authenticated &&
                permissionsState.unconfirmed)
              const SizedBox(
                height: 120,
                child: PermissionsUnconfirmedView(foreground: Colors.white),
              )
            else if (authState.status == AuthStatus.error)
              Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authState.error ?? 'Please try again',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
