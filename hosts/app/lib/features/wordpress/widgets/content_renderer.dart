import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

class ContentRenderer extends StatelessWidget {
  const ContentRenderer({super.key, required this.htmlContent});
  final String htmlContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Html(
      data: htmlContent,
      style: {
        "body": Style(
          fontFamily: 'NotoSansArabic',
          fontSize: FontSize(theme.textTheme.bodyLarge?.fontSize ?? 16),
          lineHeight: const LineHeight(1.6),
          color: theme.colorScheme.onSurface,
        ),
        "p": Style(margin: Margins.only(bottom: 16)),
        ".ar": Style(
          fontFamily: 'Amiri',
          fontSize: FontSize(18),
          textAlign: TextAlign.right,
          direction: TextDirection.rtl,
        ),
        "blockquote": Style(
          backgroundColor: theme.colorScheme.surfaceContainerLowest,
          padding: HtmlPaddings.all(12),
          margin: Margins.only(bottom: 16),
          border: Border(
            left: BorderSide(color: theme.colorScheme.primary, width: 3),
          ),
        ),
      },
    );
  }
}
