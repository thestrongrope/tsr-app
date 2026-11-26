import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

/// Shown once the deletion has completed and this device has been cleared.
///
/// Reached from a `403` carrying `deletion_status: completed`, which the API
/// returns on every route for about two hours afterwards — including the status
/// endpoint, so this is the only signal the app gets.
class AccountDeletedScreen extends ConsumerWidget {
  const AccountDeletedScreen({super.key, this.someDataRemains = false});

  /// True when removing the member's data from this device failed in part.
  final bool someDataRemains;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.softCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.largePadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppTheme.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: AppTheme.primaryGreen,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Your account has been deleted',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.darkText,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                'Your personal details have been removed from this device and '
                'from our records. Signing in again will create a new account.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.mediumText,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              if (someDataRemains) ...[
                const SizedBox(height: 12),
                Text(
                  'Some data could not be removed from this device. Uninstall '
                  'the app to remove it.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mediumText,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    // Clearing the terminal status is what unlocks the router.
                    ref.read(authStateProvider.notifier).acknowledgeDeletion();
                    context.go(AppRoutes.login);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                  child: const Text(
                    'Back to sign in',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
