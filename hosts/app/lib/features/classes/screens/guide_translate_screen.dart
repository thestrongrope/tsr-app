import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Hosts the guide page's Google Translate widget loads from. Anything else
/// the page tries to open goes to the system browser (#694).
bool _isGoogleHost(String host) =>
    host == 'google.com' ||
    host.endsWith('.google.com') ||
    host.endsWith('.googleapis.com') ||
    host.endsWith('.gstatic.com');

/// True when the web view may load [target] itself. The main frame may only
/// stay on the guide page (a change of #fragment is fine); a subframe may
/// only be blank or Google's translate frame. Everything else, including the
/// guide's own links and the syllabus files, opens outside the app.
bool guideWebViewMayLoad(
  Uri target, {
  required Uri guide,
  required bool isMainFrame,
}) {
  if (target.scheme == 'about') return true;
  if (isMainFrame) {
    return target.scheme == guide.scheme &&
        target.host == guide.host &&
        target.port == guide.port &&
        target.path == guide.path &&
        target.query == guide.query;
  }
  return target.scheme == 'https' && _isGoogleHost(target.host);
}

/// What the screen gives the web view it builds.
class GuideWebHandlers {
  const GuideWebHandlers({
    required this.onNavigation,
    required this.onFailed,
    required this.onLoaded,
  });

  /// Decides a navigation; false stops the web view loading it.
  final bool Function(Uri target, bool isMainFrame) onNavigation;

  /// The page or its translate widget could not be loaded.
  final VoidCallback onFailed;

  /// The page loaded and the translate widget is on it.
  final VoidCallback onLoaded;
}

typedef GuideWebViewBuilder =
    Widget Function(Uri guide, GuideWebHandlers handlers);

/// The guide page in a web view, to read it in Hindi, Urdu, Gujarati or
/// Swahili through the page's own Google Translate widget (#694). The page is
/// public: nothing of the member's (token, cookie, data) is passed to it.
/// If it cannot load, the English guide is shown instead, with a message.
class GuideTranslateScreen extends StatefulWidget {
  const GuideTranslateScreen({
    super.key,
    required this.guideUrl,
    required this.englishHtml,
    this.launch,
    GuideWebViewBuilder? webViewBuilder,
  }) : webViewBuilder = webViewBuilder ?? _realWebView;

  /// The public guide page (the guide's share link).
  final Uri guideUrl;

  /// The English guide, shown if the translation cannot load.
  final String englishHtml;

  /// Opens a URL outside the app.
  final Future<bool> Function(Uri)? launch;

  final GuideWebViewBuilder webViewBuilder;

  @override
  State<GuideTranslateScreen> createState() => _GuideTranslateScreenState();
}

class _GuideTranslateScreenState extends State<GuideTranslateScreen> {
  bool _loaded = false;
  bool _failed = false;

  Future<void> _openOutside(Uri uri) async {
    const schemes = {'http', 'https', 'mailto', 'tel'};
    if (!schemes.contains(uri.scheme)) return;
    final launch = widget.launch ?? _launchExternally;
    await launch(uri);
  }

  bool _onNavigation(Uri target, bool isMainFrame) {
    if (guideWebViewMayLoad(
      target,
      guide: widget.guideUrl,
      isMainFrame: isMainFrame,
    )) {
      return true;
    }
    _openOutside(target);
    return false;
  }

  void _onFailed() {
    if (mounted && !_failed) setState(() => _failed = true);
  }

  void _onLoaded() {
    if (mounted && !_loaded) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Translate guide')),
      body: _failed ? _english() : _translated(),
    );
  }

  Widget _translated() {
    return Column(
      children: [
        const _Notice(
          icon: Icons.translate,
          text:
              'Choose a language below. The text is machine-translated by '
              'Google and may contain mistakes. Syllabus files are not '
              'translated. Choose English to read the original.',
        ),
        if (!_loaded) const LinearProgressIndicator(),
        Expanded(
          // The page runs behind the tab bar; the web view must end above it.
          child: Padding(
            padding: EdgeInsets.only(bottom: withTabBarInset(context).bottom),
            child: widget.webViewBuilder(
              widget.guideUrl,
              GuideWebHandlers(
                onNavigation: _onNavigation,
                onFailed: _onFailed,
                onLoaded: _onLoaded,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _english() {
    return Column(
      children: [
        const _Notice(
          icon: Icons.error_outline,
          text: 'The translation is unavailable. Showing the English guide.',
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: withTabBarInset(context, const EdgeInsets.all(16)),
            child: Html(
              data: widget.englishHtml,
              onLinkTap: (url, attributes, element) async {
                final uri = url == null ? null : Uri.tryParse(url);
                if (uri != null) await _openOutside(uri);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF8E1),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

Future<bool> _launchExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

Widget _realWebView(Uri guide, GuideWebHandlers handlers) =>
    _RealGuideWebView(guide: guide, handlers: handlers);

class _RealGuideWebView extends StatefulWidget {
  const _RealGuideWebView({required this.guide, required this.handlers});

  final Uri guide;
  final GuideWebHandlers handlers;

  @override
  State<_RealGuideWebView> createState() => _RealGuideWebViewState();
}

class _RealGuideWebViewState extends State<_RealGuideWebView> {
  late final WebViewController _controller;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // The Google Translate widget is a script, so JavaScript has to run.
      // Nothing is injected, and no channel gives the page a way back in.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            return widget.handlers.onNavigation(uri, request.isMainFrame)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (_) => _waitForWidget(),
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) _fail();
          },
          onHttpError: (error) {
            final request = error.request;
            if (request != null && request.uri == widget.guide) {
              _fail();
            }
          },
        ),
      )
      ..loadRequest(widget.guide);
  }

  void _fail() {
    if (_done) return;
    _done = true;
    widget.handlers.onFailed();
  }

  /// The page loading is not enough: Google's script may be blocked. Look for
  /// the widget's gadget for a few seconds before calling it unavailable.
  Future<void> _waitForWidget() async {
    for (var i = 0; i < 8 && !_done; i++) {
      try {
        final found = await _controller.runJavaScriptReturningResult(
          "document.querySelector('.goog-te-gadget') !== null",
        );
        if (found.toString() == 'true' || found.toString() == '1') {
          _done = true;
          widget.handlers.onLoaded();
          return;
        }
      } catch (_) {
        // The page is not ready to be asked; try again.
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    _fail();
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
