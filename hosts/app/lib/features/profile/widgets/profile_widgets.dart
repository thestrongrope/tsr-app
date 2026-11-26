import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// The member's avatar with an initials fallback: the photo draws over the
/// initial, so a missing, non-http or broken URL still shows a green monogram.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.picture,
    this.radius = 36,
  });

  final String name;
  final String? picture;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : 'U';
    final photo = picture;
    final hasPhoto =
        photo != null && photo.isNotEmpty && photo.startsWith('http');

    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppTheme.lightGreen,
        foregroundImage: hasPhoto ? NetworkImage(photo) : null,
        onForegroundImageError: hasPhoto ? (_, _) {} : null,
        child: Text(
          initial,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppTheme.primaryGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// The member at the top of a profile screen: avatar, name and email. Long
/// names wrap instead of clipping.
class ProfileHeroCard extends StatelessWidget {
  const ProfileHeroCard({
    super.key,
    required this.name,
    required this.email,
    this.picture,
    this.token,
  });

  final String name;
  final String email;
  final String? picture;

  /// The member's token number, shown as a line that copies it when tapped.
  /// Support identifies a member by it (#1147). Left out when null or when
  /// the member has none yet (0).
  final int? token;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSurfaceCard(
      child: Row(
        children: [
          ProfileAvatar(name: name, picture: picture),
          const SizedBox(width: AppTheme.spacingLG),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.mediumText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (token != null && token! > 0) _TokenLine(token: token!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Token 1234" with a copy icon; a tap puts the number on the clipboard.
class _TokenLine extends StatelessWidget {
  const _TokenLine({required this.token});

  final int token;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _copy(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Token $token',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.darkText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppTheme.spacingXS),
            const Icon(
              Icons.copy_rounded,
              size: 16,
              color: AppTheme.mediumText,
              semanticLabel: 'Copy token number',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: '$token'));
      messenger.showSnackBar(
        const SnackBar(content: Text('Token number copied')),
      );
    } on PlatformException {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't copy the token number.")),
      );
    }
  }
}

/// Stand-in shown while the profile loads; keeps the shape of the screen.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: withTabBarInset(
        context,
        const EdgeInsets.all(AppTheme.screenPadding),
      ),
      children: const [
        SkeletonBox(height: 96, radius: AppTheme.radiusLG),
        SizedBox(height: AppTheme.sectionSpacing),
        SkeletonBox(height: 24, width: 180, radius: AppTheme.radiusSM),
        SizedBox(height: AppTheme.spacingMD),
        SkeletonBox(height: 280, radius: AppTheme.radiusLG),
      ],
    );
  }
}

/// The profile could not be loaded: a plain message and Retry.
class ProfileLoadError extends StatelessWidget {
  const ProfileLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: withTabBarInset(
        context,
        const EdgeInsets.all(AppTheme.screenPadding),
      ),
      children: [
        AppSurfaceCard(
          child: AppErrorView(
            error: Exception('Could not load your profile.'),
            onRetry: onRetry,
          ),
        ),
      ],
    );
  }
}
