import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/router/route_config.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/models/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/user.dart';
import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_classes.dart';
import '../../classes/providers/providers.dart';
import '../../classes/widgets/class_notification_settings_sheet.dart';
import '../widgets/danger_zone.dart';
import '../widgets/profile_widgets.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// The member's read-only profile, then the edit, sign-out and deletion
/// controls. Sign out is an ordinary outlined button; red is reserved for
/// Delete account.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'Edit profile',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(AppRoutes.editProfile),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.subtleGreenGradient),
        child: _body(context, ref, authState),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, AuthState authState) {
    final user = authState.user;
    if (user != null) return _buildContent(context, ref, user);
    if (authState.status == AuthStatus.loading) {
      return const ProfileSkeleton();
    }
    return ProfileLoadError(onRetry: () => ref.invalidate(authStateProvider));
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, User user) {
    return ListView(
      padding: withTabBarInset(
        context,
        const EdgeInsets.fromLTRB(
          AppTheme.screenPadding,
          AppTheme.spacingSM,
          AppTheme.screenPadding,
          AppTheme.spacing3XL,
        ),
      ),
      children: [
        ProfileHeroCard(
          name: user.name,
          email: user.email,
          picture: user.picture,
        ),
        const SizedBox(height: AppTheme.sectionSpacing),
        const AppSectionHeader(title: 'Personal information'),
        const SizedBox(height: AppTheme.spacingMD),
        AppSurfaceCard(
          child: Column(
            children: _divided([
              _InfoRow(Icons.badge_outlined, 'Full name', user.name),
              _InfoRow(Icons.email_outlined, 'Email', user.email),
              _InfoRow(
                Icons.people_outline,
                'Gender',
                _getGenderName(user.gender),
              ),
              _InfoRow(
                Icons.phone_android_outlined,
                'Mobile',
                user.mobile ?? '-',
              ),
              _InfoRow(
                Icons.cake_outlined,
                'Age range',
                _getAgeRangeName(user.ageRange),
              ),
              _InfoRow(
                Icons.language,
                'Language',
                _getLanguageName(user.language),
              ),
            ]),
          ),
        ),
        const SizedBox(height: AppTheme.sectionSpacing),
        const AppSectionHeader(title: 'Location details'),
        const SizedBox(height: AppTheme.spacingMD),
        AppSurfaceCard(
          child: Column(
            children: _divided([
              _InfoRow(Icons.location_city_outlined, 'City', user.city ?? '-'),
              _InfoRow(Icons.map_outlined, 'State', user.state ?? '-'),
              _InfoRow(Icons.public, 'Country', user.country ?? '-'),
              _InfoRow(
                Icons.markunread_mailbox_outlined,
                'Zip code',
                user.zip ?? '-',
              ),
            ]),
          ),
        ),
        const SizedBox(height: AppTheme.sectionSpacing),
        const AppSectionHeader(title: 'Account security'),
        const SizedBox(height: AppTheme.spacingMD),
        AppSurfaceCard(
          child: _InfoRow(
            Icons.vpn_key_outlined,
            'User token',
            user.token.toString(),
            selectable: true,
          ),
        ),
        const SizedBox(height: AppTheme.sectionSpacing),
        const AppSectionHeader(title: 'Notification preferences'),
        const SizedBox(height: AppTheme.spacingMD),
        _buildNotificationPreferences(context, ref),
        const SizedBox(height: AppTheme.sectionSpacing),
        _buildActionButtons(context, ref),
      ],
    );
  }

  Widget _buildNotificationPreferences(BuildContext context, WidgetRef ref) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage automated alerts for scheduled classes and session conduction reports.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.mediumText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          InkWell(
            onTap: () {
              final classesState = ref.read(classesProvider);
              showClassNotificationSettings(
                context,
                ref,
                hasConductingClasses: ref
                    .read(capabilitiesProvider)
                    .hasConductionReminders(classesState.classes),
              );
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: AppTheme.buttonHeightDefault,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
                vertical: AppTheme.spacingMD,
              ),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Text(
                      'Configure Schedule Reminders',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.darkText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppTheme.mediumText,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: AppTheme.buttonHeightLarge,
          child: ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.editProfile),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Profile'),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        SizedBox(
          width: double.infinity,
          height: AppTheme.buttonHeightLarge,
          // A standard outlined button: signing out is an ordinary action,
          // and red is reserved for Delete account below.
          child: OutlinedButton.icon(
            onPressed: () => _showLogoutDialog(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),
        ),
        const SizedBox(height: AppTheme.sectionSpacing),
        // Account deletion. Required in-app by App Store Review Guideline
        // 5.1.1(v); kept apart from Sign Out and the only red control.
        DangerZone(onDelete: () => context.push(AppRoutes.deleteAccount)),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(authStateProvider.notifier).signOut();
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  String _getGenderName(int? gender) {
    switch (gender) {
      case 1:
        return 'Male';
      case 2:
        return 'Female';
      default:
        return 'Not specified';
    }
  }

  String _getLanguageName(int? language) {
    switch (language) {
      case 1:
        return 'English';
      case 2:
        return 'Urdu';
      case 3:
        return 'Gujarati';
      default:
        return 'Not specified';
    }
  }

  String _getAgeRangeName(int? ageRange) {
    switch (ageRange) {
      case 1:
        return 'Less than 15';
      case 2:
        return '15 to 25';
      case 3:
        return '26 to 40';
      case 4:
        return 'Above 40';
      default:
        return 'Not specified';
    }
  }
}

/// Rows separated by dividers.
List<Widget> _divided(List<Widget> rows) {
  return [
    for (var i = 0; i < rows.length; i++) ...[
      if (i > 0) const Divider(height: AppTheme.spacingLG),
      rows[i],
    ],
  ];
}

/// One labelled fact: a green icon, a small label over the value. Long
/// values wrap instead of overflowing.
class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value, {this.selectable = false});

  final IconData icon;
  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.bodyLarge?.copyWith(
      color: AppTheme.darkText,
      fontWeight: FontWeight.w600,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingSM),
          decoration: BoxDecoration(
            color: AppTheme.lightGreen,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          ),
          child: Icon(icon, color: AppTheme.primaryGreen, size: 18),
        ),
        const SizedBox(width: AppTheme.spacingMD),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.mediumText,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXS),
              if (selectable)
                SelectableText(value, style: valueStyle)
              else
                Text(value, style: valueStyle),
            ],
          ),
        ),
      ],
    );
  }
}
