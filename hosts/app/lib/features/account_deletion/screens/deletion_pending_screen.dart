import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/deletion_request.dart';
import '../providers/deletion_provider.dart';

/// The only screen reachable while a deletion request is live.
///
/// The API refuses everything outside a six-route allow-list until the request
/// is cancelled or completed, so there is nothing else worth showing. Cancelling
/// stays with the member, which is what Apple expects of a destructive action.
class DeletionPendingScreen extends ConsumerStatefulWidget {
  const DeletionPendingScreen({super.key});

  @override
  ConsumerState<DeletionPendingScreen> createState() =>
      _DeletionPendingScreenState();
}

class _DeletionPendingScreenState extends ConsumerState<DeletionPendingScreen> {
  bool _isCancelling = false;

  Future<void> _cancel() async {
    setState(() => _isCancelling = true);
    try {
      final request = await ref.read(deletionRepositoryProvider).cancel();
      // Leaving the restricted status is what releases the router.
      await ref
          .read(authStateProvider.notifier)
          .applyDeletionStatus(request.status);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      // A refusal that carries a deletion status is not a failure to report:
      // the request completed under us, and the interceptor is already moving
      // the app to the terminal screen. A toast here would land on top of it.
      if (e is ApiException && e.deletionStatus != null) return;
      AppSnackBar.showError(
        context,
        message: 'Could not cancel the request. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(authStateProvider).deletionStatus;
    final request = ref.watch(deletionRequestProvider);
    final onHold = status == DeletionStatus.awaitingPrizeDelivery;

    return Scaffold(
      backgroundColor: AppTheme.softCream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.largePadding),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppTheme.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  onHold ? Icons.card_giftcard : Icons.hourglass_top,
                  size: 48,
                  color: AppTheme.primaryGreen,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                onHold ? 'Deletion on hold' : 'Deletion requested',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.darkText,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                onHold
                    ? 'We are holding your details until a prize you won has '
                          'been delivered. Your account is deleted once that is '
                          'done.'
                    : 'Your account will be deleted within 60 days. Until then '
                          'the rest of the app stays closed.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.mediumText,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              request.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (data) => _RequestedOn(request: data),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isCancelling ? null : _cancel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                  child: Text(
                    _isCancelling ? 'Cancelling...' : 'Cancel deletion',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: _isCancelling
                    ? null
                    : () => ref.read(authStateProvider.notifier).signOut(),
                child: Text(
                  'Sign out',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mediumText,
                    decoration: TextDecoration.underline,
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

class _RequestedOn extends StatelessWidget {
  const _RequestedOn({required this.request});

  final DeletionRequest request;

  @override
  Widget build(BuildContext context) {
    final requestedAt = request.requestedAt;
    if (requestedAt == null) return const SizedBox.shrink();

    // Rendered in the device's own zone; the value arrives as UTC.
    final local = requestedAt.toLocal();
    final date = '${local.day}/${local.month}/${local.year}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            Text(
              'Requested on $date',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.darkText),
            ),
            const SizedBox(height: 4),
            Text(
              'Completes within ${request.expectedCompletionDays} days',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
            ),
          ],
        ),
      ),
    );
  }
}
