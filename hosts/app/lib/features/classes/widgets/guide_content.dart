import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tab_bar_inset.dart';
import '../models/class_guide.dart';
import '../screens/guide_translate_screen.dart';

/// Opens a URL outside the app; false when it could not be opened.
typedef GuideLauncher = Future<bool> Function(Uri);

/// The default [GuideLauncher]: documents in their own app, the rest in the
/// browser.
Future<bool> openGuideLinkExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// The default share: hands the public link to the system share sheet.
Future<void> shareGuideLink(String url) async {
  await SharePlus.instance.share(ShareParams(text: url));
}

/// A guide's text, read-only, in the app's colours so it reads as part of the
/// app. Links open outside the app through [launch]. Shared by the class's
/// guide (#412) and a guide link (#1138).
class GuideBody extends StatelessWidget {
  const GuideBody({super.key, required this.html, required this.launch});

  final String html;
  final GuideLauncher launch;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: withTabBarInset(
        context,
        const EdgeInsets.all(AppTheme.spacingLG),
      ),
      child: Html(
        data: html,
        style: _guideStyle,
        onLinkTap: (url, attributes, element) async {
          final uri = url == null ? null : Uri.tryParse(url);
          if (uri != null) await launch(uri);
        },
      ),
    );
  }
}

/// The app bar actions of a loaded guide: Translate and Share, each only when
/// the guide has a public link.
List<Widget> guideActions(
  BuildContext context, {
  required ClassGuide? guide,
  required GuideLauncher launch,
  required Future<void> Function(String) share,
  required GuideWebViewBuilder? webViewBuilder,
}) {
  final shareUrl = guide?.shareUrl;
  final html = guide?.guide;
  if (shareUrl == null) return const [];
  return [
    if (html != null)
      IconButton(
        icon: const Icon(Icons.translate),
        tooltip: 'Translate',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GuideTranslateScreen(
              guideUrl: Uri.parse(shareUrl),
              englishHtml: html,
              launch: launch,
              webViewBuilder: webViewBuilder,
            ),
          ),
        ),
      ),
    IconButton(
      icon: const Icon(Icons.share_outlined),
      tooltip: 'Share guide',
      onPressed: () => share(shareUrl),
    ),
  ];
}

final Map<String, Style> _guideStyle = {
  'body': Style(
    color: AppTheme.darkText,
    fontSize: FontSize(15),
    margin: Margins.zero,
    padding: HtmlPaddings.zero,
  ),
  'h1': Style(color: AppTheme.primaryGreen, fontSize: FontSize(22)),
  'h2': Style(color: AppTheme.primaryGreen, fontSize: FontSize(19)),
  'h3': Style(color: AppTheme.primaryGreen, fontSize: FontSize(17)),
  'a': Style(color: AppTheme.primaryGreen),
};
