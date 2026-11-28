import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_config.dart';
import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_classes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/version/release_notes_screen.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/providers/user_notifications_provider.dart';
import '../widgets/profile_widgets.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// The Me tab's starting screen, for a signed-in member: profile and
/// notifications. A guest is shown an invitation instead (`SignedInOnly` in
/// the router).
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key, this.launch = _openInBrowser});

  /// Opens a URL outside the app; false when it could not be opened.
  final Future<bool> Function(Uri) launch;

  static final _donateUri = Uri.parse(AppConstants.donateUrl);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final canManageOwnParents = ref
        .watch(capabilitiesProvider)
        .canManageOwnParents;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Me')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.subtleGreenGradient),
        child: ListView(
          padding: withTabBarInset(
            context,
            const EdgeInsets.all(AppTheme.screenPadding),
          ),
          children: [
            if (user != null) ...[
              ProfileHeroCard(
                name: user.name,
                email: user.email,
                picture: user.picture,
                token: user.token,
              ),
              const SizedBox(height: AppTheme.sectionSpacing),
            ],
            _MeTile(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              onTap: () => context.push(AppRoutes.profile),
            ),
            _MeTile(
              icon: Icons.family_restroom_outlined,
              label: 'My Children',
              onTap: () => context.push(AppRoutes.myChildren),
            ),
            if (canManageOwnParents)
              _MeTile(
                icon: Icons.escalator_warning_outlined,
                label: 'My Parents',
                onTap: () => context.push(AppRoutes.myParents),
              ),
            _MeTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              badge: unreadCount,
              onTap: () => context.push(AppRoutes.notifications),
            ),
            _MeTile(
              icon: Icons.info_outline_rounded,
              label: 'About',
              onTap: () => context.push(AppRoutes.about),
            ),
            _MeTile(
              icon: Icons.verified_outlined,
              label: 'Accreditation',
              onTap: () => context.push(AppRoutes.accreditation),
            ),
            _MeTile(
              icon: Icons.forum_outlined,
              label: 'Contact',
              onTap: () => context.push(AppRoutes.contact),
            ),
            _MeTile(
              icon: Icons.rate_review_outlined,
              label: 'Send feedback',
              onTap: () => context.push(AppRoutes.sendFeedback),
            ),
            _MeTile(
              icon: Icons.volunteer_activism_outlined,
              label: 'Donate',
              onTap: () => _openDonate(context),
            ),
            const AppVersionTile(),
          ],
        ),
      ),
    );
  }

  Future<void> _openDonate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await launch(_donateUri)) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open the donation page.")),
      );
    }
  }

  static Future<bool> _openInBrowser(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _MeTile extends StatelessWidget {
  const _MeTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      child: AppSurfaceCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: ListTile(
          leading: Icon(icon, color: AppTheme.primaryGreen),
          title: Text(label),
          trailing: badge > 0
              ? Badge(label: Text(badge > 99 ? '99+' : '$badge'))
              : const Icon(Icons.arrow_forward_ios, size: 16),
        ),
      ),
    );
  }
}
