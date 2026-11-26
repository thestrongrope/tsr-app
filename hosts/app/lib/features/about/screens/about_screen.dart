import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../widgets/about_icon_tile.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// About Us: who The Strong Rope is and what it does.
///
/// Mirrors https://thestrongrope.com/about as bundled static content so the
/// page reads offline. Presentation only.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _whoWeAre = [
    'A cultural, religious, and social organization',
    'Formed by like-minded individuals',
    'Under the guidance of renowned religious scholars',
  ];

  static const _whatWeDo = [
    'Fasten to the teachings of the Holy Quran and the immaculate Ahlul Bayt (peace be on them)',
    'Culturally promote and defend the Shia Ithna Ashari Imamate faith',
    'Be present on all platforms including Print, Audio-Visual and Social media',
    'Develop a deeper understanding of religious traditions to enhance communal harmony',
    'Bring communities together and build a compassionate and just world',
    'Prepare for the early reappearance of the Twelfth Imam, Imam al-Mahdi (may Allah hasten his reappearance)',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('About Us')),
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
                  icon: Icons.mosque_outlined,
                  size: AppIconTile.largeSize,
                ),
                const SizedBox(height: AppTheme.spacingMD),
                Text(
                  'The Strong Rope',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  'The path of the Ahle Bait (a.s.) — connecting hearts to Islamic knowledge.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.sectionSpacing),
          const AppSectionHeader(title: 'Who we are'),
          const SizedBox(height: AppTheme.spacingMD),
          AppSurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _whoWeAre.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _BulletRow(text: _whoWeAre[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.sectionSpacing),
          const AppSectionHeader(title: 'What we do'),
          const SizedBox(height: AppTheme.spacingMD),
          AppSurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _whatWeDo.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _BulletRow(text: _whatWeDo[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.sectionSpacing),
          AppSurfaceCard(
            onTap: () => context.push(AppRoutes.contact),
            child: Row(
              children: [
                AppIconTile(
                  icon: Icons.forum_outlined,
                  background: AppTheme.accentGold.withValues(alpha: 0.15),
                  foreground: AppTheme.accentGold,
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connect with us',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.darkText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        'WhatsApp, Telegram, socials and more',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSM),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppTheme.mediumText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPadding,
        vertical: AppTheme.spacingMD,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 20,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
