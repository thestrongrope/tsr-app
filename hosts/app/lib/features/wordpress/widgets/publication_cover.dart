import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/publication.dart';

/// A book-shaped placeholder cover tinted by language, showing what a tap
/// opens. The website sends no cover images yet; a real cover would replace
/// this widget's body.
///
/// Shared by the Publications list and the Library shelf so both show the same
/// cover.
class PublicationCover extends StatelessWidget {
  const PublicationCover({
    super.key,
    required this.publication,
    this.width = 64,
    this.height = 88,
    this.radius = AppTheme.radiusSM,
    this.iconSize = 28,
  });

  final Publication publication;
  final double width;
  final double height;
  final double radius;
  final double iconSize;

  static Color tintFor(String? language) {
    switch (language) {
      case 'English':
        return AppTheme.primaryGreen;
      case 'Urdu':
        return AppTheme.darkText;
      case 'Hindi':
        return AppTheme.warningOrange;
      case 'Multilingual':
        return AppTheme.accentGold;
      default:
        return AppTheme.mediumText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = tintFor(publication.language);
    final readsOnline = publication.readOnlineUrl != null;
    final label = readsOnline
        ? 'READ'
        : (publication.type ?? 'FILE').toUpperCase();

    return Container(
      key: const ValueKey('publicationCoverPlaceholder'),
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint, Color.lerp(tint, AppTheme.darkText, 0.25)!],
        ),
      ),
      child: Row(
        children: [
          // The spine.
          Container(
            width: AppTheme.spacingXS + 1,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(radius),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  readsOnline
                      ? Icons.menu_book_rounded
                      : Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                  size: iconSize,
                ),
                const SizedBox(height: AppTheme.spacingSM),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
