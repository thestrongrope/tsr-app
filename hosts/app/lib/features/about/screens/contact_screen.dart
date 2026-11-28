import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../widgets/about_icon_tile.dart';
import '../models/contact_links.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Contact & socials: every official The Strong Rope channel in one place.
///
/// Each row opens outside the app via [launch], mirroring the Donate row in
/// the Me tab. Presentation only.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key, this.launch = _openInBrowser});

  /// Opens a URL outside the app; false when it could not be opened.
  final Future<bool> Function(Uri) launch;

  static Future<bool> _openInBrowser(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<void> _open(BuildContext context, ContactLink link) async {
    if (!await launch(link.url)) {
      if (context.mounted) {
        AppSnackBar.showError(context, message: "Couldn't open ${link.label}.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Contact & Socials')),
      body: ListView(
        padding: withTabBarInset(
          context,
          EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            AppTheme.spacingSM,
            AppTheme.screenPadding,
            AppTheme.spacing2XL,
          ),
        ),
        children: [
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppIconTile(
                  icon: Icons.forum_outlined,
                  size: AppIconTile.largeSize,
                ),
                const SizedBox(height: AppTheme.spacingMD),
                Text(
                  'Connect with us',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  'Message, follow, or watch The Strong Rope wherever you are.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.sectionSpacing),
          const AppSectionHeader(title: 'Channels'),
          const SizedBox(height: AppTheme.spacingMD),
          AppSurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < contactLinks.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _ContactRow(
                    link: contactLinks[i],
                    onTap: () => _open(context, contactLinks[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.link, required this.onTap});

  final ContactLink link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppTheme.radiusLG);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.cardPadding,
            vertical: AppTheme.spacingMD,
          ),
          child: Row(
            children: [
              AppIconTile(
                icon: link.icon,
                background: link.background ?? AppTheme.lightGreen,
                foreground: link.foreground ?? AppTheme.primaryGreen,
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.darkText,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      link.subtitle,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              const Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: AppTheme.mediumText,
                semanticLabel: 'Opens outside the app',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
