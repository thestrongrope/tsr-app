import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../widgets/about_icon_tile.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Accreditation: the scholars who endorse The Strong Rope and the authority
/// letters from Naba Cultural Organization.
///
/// Mirrors https://thestrongrope.com/accreditation as bundled static content;
/// only the letter images load from the network, with placeholder and error
/// states like article thumbnails.
class AccreditationScreen extends StatelessWidget {
  const AccreditationScreen({super.key});

  static const _letters = [
    _AuthorityLetter(
      title: 'Authority letter — English',
      imageUrl: 'https://thestrongrope.com/uploads/TSR-Naba-English.jpeg',
    ),
    _AuthorityLetter(
      title: 'Authority letter — Farsi',
      imageUrl: 'https://thestrongrope.com/uploads/TSR-Naba-Farsi.jpeg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Accreditation')),
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
                  icon: Icons.verified_outlined,
                  size: AppIconTile.largeSize,
                ),
                const SizedBox(height: AppTheme.spacingMD),
                Text(
                  'Our Accreditation',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  'The Strong Rope works under the guidance and endorsement of '
                  'renowned scholars, and holds authority letters from Naba '
                  'Cultural Organization, I.R. Iran.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.sectionSpacing),
          const AppSectionHeader(title: 'Endorsements'),
          const SizedBox(height: AppTheme.spacingMD),
          const _EndorsementCard(
            imageUrl:
                'https://thestrongrope.com/uploads/maulana-zeeshan-haider-zaidi-1.jpg',
            name:
                'Hujjatul Islam wal Muslimeen Aali Janab Maulana Sayed Zeeshan Haider Zaidi Sahab',
            role:
                'Vakil (Representative) of Grand Ayatullah Shaikh Basheer Husain Najafi (d.z.a.)',
          ),
          const SizedBox(height: AppTheme.spacingMD),
          const _EndorsementCard(
            imageUrl: 'https://thestrongrope.com/uploads/kazim-sahab.png',
            name:
                'Hujjatul Islam wal Muslimeen Shaikh Kazim Alam al-Hoda Sahab',
            role: 'Principal, Hawzah Ilmiyyah Isna Ashariyyah, Kargil',
          ),
          const SizedBox(height: AppTheme.sectionSpacing),
          const AppSectionHeader(title: 'Authority letters'),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            'Naba Cultural Organization, I.R. Iran',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.darkText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          for (final letter in _letters) ...[
            _LetterCard(letter: letter),
            const SizedBox(height: AppTheme.spacingMD),
          ],
        ],
      ),
    );
  }
}

class _EndorsementCard extends StatelessWidget {
  const _EndorsementCard({
    required this.imageUrl,
    required this.name,
    required this.role,
  });

  final String imageUrl;
  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusLG),
            ),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const AspectRatio(aspectRatio: 16 / 10, child: SkeletonBox()),
              errorWidget: (context, url, error) => Container(
                color: AppTheme.lightGreen,
                padding: const EdgeInsets.all(AppTheme.cardPaddingLarge),
                child: const Center(
                  child: AppIconTile(
                    icon: Icons.person_outline_rounded,
                    size: AppIconTile.largeSize,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppIconTile(icon: Icons.verified_outlined),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.darkText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(role, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorityLetter {
  const _AuthorityLetter({required this.title, required this.imageUrl});

  final String title;
  final String imageUrl;
}

class _LetterCard extends StatelessWidget {
  const _LetterCard({required this.letter});

  final _AuthorityLetter letter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.cardPadding,
              AppTheme.cardPadding,
              AppTheme.cardPadding,
              AppTheme.spacingSM,
            ),
            child: Text(
              letter.title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.darkText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppTheme.radiusLG),
            ),
            child: CachedNetworkImage(
              imageUrl: letter.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const AspectRatio(aspectRatio: 3 / 4, child: SkeletonBox()),
              errorWidget: (context, url, error) => const Padding(
                padding: EdgeInsets.all(AppTheme.cardPadding),
                child: AppEmptySection(
                  icon: Icons.broken_image_outlined,
                  message:
                      'The letter image could not be loaded. Check your connection and try again.',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
