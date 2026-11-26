import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/router/deep_link_provider.dart';
import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../auth/models/auth_state.dart';
import '../../auth/providers/auth_provider.dart';

/// The class a join link names: `GET /join/{code}`, public. [open] is false
/// for a class that is no longer taking members.
class JoinPreview {
  const JoinPreview({
    required this.name,
    required this.level,
    required this.language,
    required this.gender,
    required this.open,
  });

  final String name;
  final String level;
  final String language;
  final String gender;
  final bool open;

  factory JoinPreview.fromJson(Map<String, dynamic> json) => JoinPreview(
    name: (json['name'] as String?) ?? '',
    level: (json['level'] as String?) ?? '',
    language: (json['language'] as String?) ?? '',
    gender: (json['gender'] as String?) ?? '',
    open: json['open'] == true,
  );
}

/// Null when the code names no class (the server answers 404).
final joinPreviewProvider = FutureProvider.autoDispose
    .family<JoinPreview?, String>((ref, code) async {
      try {
        final json = await ApiClient().get<Map<String, dynamic>>(
          '/join/${Uri.encodeComponent(code)}',
        );
        return JoinPreview.fromJson(json);
      } on ApiException catch (e) {
        if (e.statusCode == 404) return null;
        rethrow;
      }
    });

/// The web page where joining is finished. The app has no join action of its
/// own yet, so it hands over to the same page and the same rules the browser
/// uses (gender, class and profile checks all run there).
Uri joinWebUri(String code) =>
    Uri.https('account.thestrongrope.com', '/join/$code');

/// A join link (#815, #816, #817): shows the class the link names. A signed-out
/// member signs in and returns here; joining continues in the browser.
class JoinLinkScreen extends ConsumerWidget {
  const JoinLinkScreen({
    super.key,
    required this.code,
    this.openInBrowser = _openInBrowser,
  });

  final String code;

  /// A seam for tests.
  final Future<bool> Function(Uri uri) openInBrowser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(joinPreviewProvider(code));
    final signedIn =
        ref.watch(authStateProvider).status == AuthStatus.authenticated;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Join a class')),
      body: preview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(
          error: e,
          onRetry: () => ref.invalidate(joinPreviewProvider(code)),
        ),
        data: (p) => p == null
            ? const _Message(
                'We could not find this class. The link may be wrong.',
              )
            : _ClassPreview(
                preview: p,
                signedIn: signedIn,
                onSignIn: () {
                  ref
                      .read(pendingDeepLinkProvider.notifier)
                      .setPendingLink('/join/$code');
                  context.push(AppRoutes.login);
                },
                onContinue: () => _continue(context),
              ),
      ),
    );
  }

  Future<void> _continue(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await openInBrowser(joinWebUri(code));
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the browser.')),
      );
    }
  }
}

Future<bool> _openInBrowser(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  } catch (_) {
    return false;
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppTheme.spacing2XL),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ),
  );
}

class _ClassPreview extends StatelessWidget {
  const _ClassPreview({
    required this.preview,
    required this.signedIn,
    required this.onSignIn,
    required this.onContinue,
  });

  final JoinPreview preview;
  final bool signedIn;
  final VoidCallback onSignIn;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final details = [
      preview.level,
      preview.language,
      preview.gender,
    ].where((s) => s.isNotEmpty).join(' · ');

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      children: [
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(preview.name, style: textTheme.titleLarge),
              if (details.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingSM),
                Text(details, style: textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing2XL),
        if (!preview.open)
          Text(
            'This class is not taking new members.',
            style: textTheme.titleMedium,
          )
        else if (!signedIn)
          ElevatedButton(
            onPressed: onSignIn,
            child: const Text('Sign in to join'),
          )
        else
          ElevatedButton(
            onPressed: onContinue,
            child: const Text('Continue in the browser'),
          ),
      ],
    );
  }
}
