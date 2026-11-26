import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/profile_completion_provider.dart';
import '../models/profile_completion_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/personal_details_step.dart';
import '../widgets/additional_details_step.dart';

class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  ConsumerState<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState
    extends ConsumerState<ProfileCompletionScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize form with current user data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        ref
            .read(profileCompletionProvider.notifier)
            .initializeWithUser(currentUser);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileCompletionProvider);

    // Listen to profile completion state changes
    ref.listen<ProfileCompletionState>(profileCompletionProvider, (
      previous,
      next,
    ) {
      if (next.status == ProfileCompletionStatus.success) {
        // Navigate to home screen after successful completion
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile completed successfully!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        context.go('/home');
      } else if (next.status == ProfileCompletionStatus.error &&
          next.error != null) {
        // Only show snackbar if it's a new error or different message
        if (previous?.status != ProfileCompletionStatus.error ||
            previous?.error != next.error) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.error!),
              backgroundColor: AppTheme.errorRed,
              behavior: SnackBarBehavior.floating, // Added for better UX
            ),
          );
        }
      }
    });

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          title: Text(
            'Complete Your Profile',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            // Progress Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (profileState.currentStep + 1) / 2,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryGreen,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getStepTitle(profileState.currentStep),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                ],
              ),
            ),

            // Form content
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _buildStepContent(profileState.currentStep),
                  ),
                ),
              ),
            ),

            // Navigation buttons (Floating Glass/Clean)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    spreadRadius: 0,
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Back button
                  if (profileState.currentStep > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppTheme.mediumText),
                        ),
                        onPressed:
                            profileState.status ==
                                ProfileCompletionStatus.loading
                            ? null
                            : () => ref
                                  .read(profileCompletionProvider.notifier)
                                  .previousStep(),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Next/Complete button
                  Expanded(
                    flex: profileState.currentStep == 0 ? 1 : 1,
                    child: ElevatedButton(
                      onPressed:
                          profileState.status == ProfileCompletionStatus.loading
                          ? null
                          : () => _handleNextOrComplete(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child:
                          profileState.status == ProfileCompletionStatus.loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              profileState.currentStep == 1
                                  ? 'Complete Profile'
                                  : 'Next',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Personal Details';
      case 1:
        return 'Additional Information';
      default:
        return 'Step ${step + 1}';
    }
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return const PersonalDetailsStep();
      case 1:
        return const AdditionalDetailsStep();
      default:
        return const SizedBox.shrink();
    }
  }

  void _handleNextOrComplete() {
    final profileState = ref.read(profileCompletionProvider);

    if (profileState.currentStep == 1) {
      // Last step - submit the form
      ref.read(profileCompletionProvider.notifier).submitProfile(ref);
    } else {
      // Go to next step
      ref.read(profileCompletionProvider.notifier).nextStep();
    }
  }
}
