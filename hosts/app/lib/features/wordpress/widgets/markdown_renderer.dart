import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// A simple markdown renderer for TSR Web API content
/// Handles basic markdown formatting without external dependencies
class MarkdownRenderer extends StatelessWidget {
  const MarkdownRenderer({super.key, required this.content});
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.trim().isEmpty) {
        // Empty line - add spacing
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      final widget = _parseLine(context, line, theme);
      if (widget != null) {
        widgets.add(widget);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget? _parseLine(BuildContext context, String line, ThemeData theme) {
    // Heading 1
    if (line.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Text(
          line.substring(2),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.darkText,
          ),
        ),
      );
    }

    // Heading 2
    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(
          line.substring(3),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.darkText,
          ),
        ),
      );
    }

    // Heading 3
    if (line.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          line.substring(4),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.darkText,
          ),
        ),
      );
    }

    // Heading 4
    if (line.startsWith('#### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          line.substring(5),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.darkText,
          ),
        ),
      );
    }

    // Blockquote
    if (line.startsWith('> ')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: AppTheme.primaryGreen, width: 4),
          ),
          color: AppTheme.lightGreen.withValues(alpha: 0.3),
        ),
        child: _buildRichText(context, line.substring(2), theme, isQuote: true),
      );
    }

    // Unordered list item
    if (line.startsWith('- ') || line.startsWith('* ')) {
      return Padding(
        padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '• ',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(child: _buildRichText(context, line.substring(2), theme)),
          ],
        ),
      );
    }

    // Ordered list item (simple detection)
    final orderedListMatch = RegExp(r'^(\d+)\.\s').firstMatch(line);
    if (orderedListMatch != null) {
      final number = orderedListMatch.group(1)!;
      final content = line.substring(orderedListMatch.end);
      return Padding(
        padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$number.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: _buildRichText(context, content, theme)),
          ],
        ),
      );
    }

    // Code block (single line with backticks)
    if (line.startsWith('```')) {
      // Skip code fence markers
      return const SizedBox.shrink();
    }

    // Horizontal rule
    if (line.trim() == '---' || line.trim() == '***') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Divider(color: AppTheme.mediumText.withValues(alpha: 0.3)),
      );
    }

    // Regular paragraph
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildRichText(context, line, theme),
    );
  }

  Widget _buildRichText(
    BuildContext context,
    String text,
    ThemeData theme, {
    bool isQuote = false,
  }) {
    final spans = <InlineSpan>[];
    var remaining = text;

    while (remaining.isNotEmpty) {
      // Check for bold (**text**)
      final boldMatch = RegExp(r'\*\*(.+?)\*\*').firstMatch(remaining);

      // Check for italic (*text* or _text_)
      final italicMatch = RegExp(
        r'(?<!\*)\*([^*]+)\*(?!\*)',
      ).firstMatch(remaining);
      final italicMatch2 = RegExp(r'_(.+?)_').firstMatch(remaining);

      // Check for inline code (`code`)
      final codeMatch = RegExp(r'`([^`]+)`').firstMatch(remaining);

      // Check for links [text](url)
      final linkMatch = RegExp(
        r'\[([^\]]+)\]\(([^)]+)\)',
      ).firstMatch(remaining);

      // Find the earliest match
      Match? earliestMatch;
      String? matchType;

      for (final entry in [
        ('bold', boldMatch),
        ('italic', italicMatch),
        ('italic2', italicMatch2),
        ('code', codeMatch),
        ('link', linkMatch),
      ]) {
        final match = entry.$2;
        if (match != null) {
          if (earliestMatch == null || match.start < earliestMatch.start) {
            earliestMatch = match;
            matchType = entry.$1;
          }
        }
      }

      if (earliestMatch == null) {
        // No more matches, add remaining text
        if (remaining.isNotEmpty) {
          spans.add(TextSpan(text: remaining));
        }
        break;
      }

      // Add text before match
      if (earliestMatch.start > 0) {
        spans.add(TextSpan(text: remaining.substring(0, earliestMatch.start)));
      }

      // Add matched span
      switch (matchType) {
        case 'bold':
          spans.add(
            TextSpan(
              text: earliestMatch.group(1),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
          break;
        case 'italic':
        case 'italic2':
          spans.add(
            TextSpan(
              text: earliestMatch.group(1),
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          );
          break;
        case 'code':
          spans.add(
            WidgetSpan(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  earliestMatch.group(1)!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: AppTheme.darkText,
                  ),
                ),
              ),
            ),
          );
          break;
        case 'link':
          spans.add(
            TextSpan(
              text: earliestMatch.group(1),
              style: TextStyle(
                color: AppTheme.primaryGreen,
                decoration: TextDecoration.underline,
              ),
            ),
          );
          break;
      }

      remaining = remaining.substring(earliestMatch.end);
    }

    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodyLarge?.copyWith(
          color: isQuote ? AppTheme.darkText : null,
          fontStyle: isQuote ? FontStyle.italic : null,
          height: 1.6,
        ),
        children: spans,
      ),
    );
  }
}
