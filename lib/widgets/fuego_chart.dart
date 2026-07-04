import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/candlestick.dart';

class FuegoChart extends StatefulWidget {
  final List<Candlestick> candles;
  final String pair;
  final double? height;

  const FuegoChart({
    super.key,
    required this.candles,
    this.pair = '',
    this.height,
  });

  @override
  State<FuegoChart> createState() => _FuegoChartState();
}

class _FuegoChartState extends State<FuegoChart> {
  late final WebViewController _controller;
  bool _pageReady = false;
  String? _htmlContent;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0d1117));
    _loadHtml();
  }

  Future<void> _loadHtml() async {
    try {
      final html = await rootBundle.loadString('assets/charts/tv_chart.html');
      if (!mounted) return;
      _htmlContent = html;
      await _controller.loadHtmlString(html);
      if (mounted) setState(() => _pageReady = true);
    } catch (e) {
      debugPrint('FuegoChart load error: $e');
    }
  }

  @override
  void didUpdateWidget(FuegoChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pageReady) _pushData();
  }

  void _pushData() {
    if (!_pageReady) return;
    final data = jsonEncode({
      'candles': widget.candles
          .map((c) => {
                'time': c.time,
                'open': c.open,
                'high': c.high,
                'low': c.low,
                'close': c.close,
                'volume': c.volume,
              })
          .toList(),
      'pair': widget.pair,
    });
    _controller.runJavaScript('updateChart($data)');
    if (widget.pair.isNotEmpty) {
      _controller.runJavaScript("setPairLabel('${widget.pair}')");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF0d1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1a1a2e)),
      ),
      clipBehavior: Clip.hardEdge,
      child: _htmlContent == null
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF3b82f6),
                strokeWidth: 2,
              ),
            )
          : WebViewWidget(controller: _controller),
    );
  }
}
