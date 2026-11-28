import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// Shown when this build is below the server's minimum.
///
/// The only screen a blocked user ever sees, so the wording is plain: what has
/// happened, and the one thing they can do about it. No branding flourish and
/// no alarm — being asked to update is ordinary, and a frightening screen about
/// it is worse than the inconvenience.
///
/// Deliberately has no back affordance and no dismiss: `canPop: false` on the
/// PopScope, no AppBar, no close button. A gate with a way round it is not a
/// gate, and the point of this screen is that the build behind it is one we
/// have decided must not keep talking to the API.
class UpdateRequiredScreen extends StatelessWidget {
  /// Where to send the user. An empty string hides the button rather than
  /// opening nothing — see the note in [_launch].
  final String storeUrl;

  const UpdateRequiredScreen({super.key, required this.storeUrl});

  Future<void> _launch() async {
    // If the server sent no URL there is nothing useful to do, and a button
    // that visibly does nothing is worse than no button. The message alone
    // still tells the user what to do.
    if (storeUrl.isEmpty) return;

    final uri = Uri.tryParse(storeUrl);
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.system_update_rounded,
                    size: 64,
                    color: AppTheme.primaryGreen,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Update required',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This version of the app is no longer supported. '
                    'Please update to continue.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.mediumText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (storeUrl.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: AppTheme.buttonHeightLarge,
                      child: ElevatedButton(
                        onPressed: _launch,
                        child: const Text('Update'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
