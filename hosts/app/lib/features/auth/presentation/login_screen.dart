import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_config.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/auth_provider.dart';
import '../models/auth_state.dart';
import '../widgets/sign_in_options.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Track shown errors to prevent repeating on rebuilds
  String? _shownErrorMessage;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleGoogleSignIn() async {
    try {
      // Use the auth provider to sign in with Google
      await ref.read(authStateProvider.notifier).signInWithGoogle();
    } catch (e) {
      // Error handling is managed by the AuthNotifier and AuthState
      // The UI will react to state changes automatically
    }
  }

  void _handleAppleSignIn() async {
    try {
      await ref.read(authStateProvider.notifier).signInWithApple();
    } catch (e) {
      // Error handling is managed by the AuthNotifier and AuthState
    }
  }

  void _handleEmailSignIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    try {
      await ref
          .read(authStateProvider.notifier)
          .signInWithEmail(_emailController.text, _passwordController.text);
    } catch (e) {
      // Error handling is managed by the AuthNotifier and AuthState
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    // The sign-in error the auth state already holds, shown once when the screen
    // opens on it. Never read from the URL: thestrongrope://app is an exported
    // deep link, so text in `?error=` would reach the member in the app's own
    // voice (#428).
    final heldError = authState.status == AuthStatus.error
        ? authState.error
        : null;
    if (heldError != null &&
        heldError.isNotEmpty &&
        _shownErrorMessage != heldError) {
      // Mark as shown before scheduling
      _shownErrorMessage = heldError;
      // Schedule to avoid showing during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppSnackBar.showError(context, message: heldError);
      });
    }

    // Listen to auth state changes for error handling and success messages
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.status == AuthStatus.error && next.error != null) {
        // Marked shown so the build above does not show it a second time.
        _shownErrorMessage = next.error;
        AppSnackBar.showError(context, message: next.error!);
      } else if (next.status == AuthStatus.authenticated &&
          previous?.status == AuthStatus.loading) {
        AppSnackBar.showSuccess(
          context,
          message: AppConstants.loginSuccessMessage,
        );
      }
    });

    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: AppTheme.softCream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.largePadding),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // TSR Logo Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    AppConstants.logoPath,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to icon if image fails to load
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

              // App Title
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                AppConstants.appTagline,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppTheme.mediumText),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Login Form Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.largePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        AppConstants.loginTitle,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        AppConstants.loginSubTitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.mediumText,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),

                      SignInOptions(
                        showApple: showAppleSignIn,
                        isLoading: isLoading,
                        onGoogle: _handleGoogleSignIn,
                        onApple: _handleAppleSignIn,
                        onRegister: () => context.push(AppRoutes.register),
                        emailForm: _buildEmailForm(isLoading),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Footer
              Text(
                AppConstants.appDescription,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.mediumText),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// The email and password form, kept in the screen because it owns the
  /// controllers, the form key and the obscure-password toggle.
  Widget _buildEmailForm(bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            enabled: !isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) {
                return 'Please enter your email address';
              }
              if (!email.contains('@') || !email.contains('.')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            enabled: !isLoading,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleEmailSignIn(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() {
                  _obscurePassword = !_obscurePassword;
                }),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: isLoading ? null : _handleEmailSignIn,
            child: Text(isLoading ? 'Signing in...' : 'Sign In'),
          ),
        ],
      ),
    );
  }
}
