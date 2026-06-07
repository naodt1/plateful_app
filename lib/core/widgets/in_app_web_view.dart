import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A true in-app browser screen — renders the page inside Plateful using a
/// WebView, so the user never leaves the app.
class InAppWebView extends StatefulWidget {
  final String url;
  final String? title;

  const InAppWebView({super.key, required this.url, this.title});

  static Future<void> open(BuildContext context, String url, {String? title}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InAppWebView(url: url, title: title),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<InAppWebView> createState() => _InAppWebViewState();
}

class _InAppWebViewState extends State<InAppWebView> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _pageTitle;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p),
          onPageFinished: (_) async {
            final t = await _controller.getTitle();
            if (mounted) setState(() => _pageTitle = t);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final loading = _progress < 100;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title ?? _pageTitle ?? 'Recipe Source',
          style: AppTextStyles.headingMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
        bottom: loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: 2,
                  backgroundColor: colors.surface,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
