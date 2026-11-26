import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_config.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/responsive.dart';
import '../providers/auth_provider.dart';
import '../models/auth_state.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // Animations removed to improve initial load performance

  void _handleGoogleSignUp() async {
    try {
      await ref.read(authStateProvider.notifier).signInWithGoogle();
    } catch (_) {}
  }

  void _handleAppleSignUp() async {
    try {
      await ref.read(authStateProvider.notifier).signInWithApple();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final screenHeight = context.screenHeight;
    final screenWidth = context.screenWidth;

    // Listen to auth state changes for error handling and success messages
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.status == AuthStatus.error && next.error != null) {
        AppSnackBar.showError(context, message: next.error!);
      } else if (next.status == AuthStatus.authenticated &&
          previous?.status == AuthStatus.loading) {
        AppSnackBar.showSuccess(
          context,
          message: AppConstants.registerSuccessMessage,
        );
      }
    });

    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: AppTheme.softCream,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenHeight - context.viewPadding.top,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.largePadding,
                vertical: AppConstants.defaultPadding,
              ),
              child: Column(
                children: [
                  // Header Section with back button
                  Row(
                    children: [
                      CustomBackButton(onPressed: () => context.pop()),
                      const Spacer(),
                      Text(
                        'Register',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.darkText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48), // Balance the back button
                    ],
                  ),

                  SizedBox(height: screenHeight * 0.04),

                  // Logo and Welcome Section (static, no animations)
                  Column(
                    children: [
                      // TSR Logo with Enhanced Design
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                            BoxShadow(
                              color: AppTheme.primaryGreen.withValues(
                                alpha: 0.1,
                              ),
                              blurRadius: 60,
                              offset: const Offset(0, 30),
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(16),
                          child: ClipOval(
                            child: Image.asset(
                              AppConstants.logoPath,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.school_rounded,
                                  size: 60,
                                  color: AppTheme.primaryGreen,
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Welcome Title
                      Text(
                        AppConstants.registerWelcomeTitle,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: AppTheme.darkText,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 12),

                      Text(
                        AppConstants.registerWelcomeDesc,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.mediumText,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  SizedBox(height: screenHeight * 0.06),

                  // Register Form Card (static)
                  Container(
                    width: screenWidth,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        AppConstants.cardBorderRadius * 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                          blurRadius: 25,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(
                        AppConstants.largePadding * 1.5,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            AppConstants.registerTitle,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: AppTheme.darkText,
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 8),

                          Text(
                            AppConstants.registerSubTitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppTheme.mediumText,
                                  height: 1.4,
                                ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 32),

                          // Google Sign Up Button
                          SocialAuthButton.google(
                            onPressed: isLoading ? null : _handleGoogleSignUp,
                            label: isLoading
                                ? 'Creating Account...'
                                : 'Continue with Google',
                            isLoading: isLoading,
                          ),

                          // Apple Sign Up Button — iOS only, see showAppleSignIn
                          if (showAppleSignIn) ...[
                            const SizedBox(height: 16),
                            SocialAuthButton.apple(
                              onPressed: isLoading ? null : _handleAppleSignUp,
                              label: isLoading
                                  ? 'Creating Account...'
                                  : 'Continue with Apple',
                              isLoading: isLoading,
                            ),
                          ],

                          const SizedBox(height: 32),

                          // Benefits Section
                          _buildBenefitsSection(context),

                          const SizedBox(height: 24),

                          // Login Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppConstants.loginInstead,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.mediumText),
                              ),
                              GestureDetector(
                                onTap: () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go(AppRoutes.login);
                                  }
                                },
                                child: Text(
                                  AppConstants.loginLinkText,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.primaryGreen,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                        decorationColor: AppTheme.primaryGreen,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Footer (static)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.defaultPadding,
                    ),
                    child: Text(
                      AppConstants.appDescription,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightText,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsSection(BuildContext context) {
    const benefits = AppConstants.registerBenefits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppConstants.benefitsHeading,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.darkText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...benefits.map(
          (benefit) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    benefit.icon,
                    size: 20,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        benefit.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.darkText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        benefit.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.mediumText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
