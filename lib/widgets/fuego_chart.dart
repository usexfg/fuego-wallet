import 'dart:convert';
import 'package:flutter/material.dart';
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
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0d1117))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {},
          onPageFinished: (_) {
            setState(() => _pageReady = true);
            _pushData();
          },
          onWebResourceError: (error) {
            if (mounted) setState(() => _error = true);
          },
        ),
      )
      ..loadFlutterAsset('assets/charts/tv_chart.html');
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
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (!_pageReady && !_error)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF3b82f6),
                strokeWidth: 2,
              ),
            ),
          if (_error)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Color(0xFF6b7280), size: 24),
                  SizedBox(height: 8),
                  Text('Chart unavailable',
                      style: TextStyle(color: Color(0xFF6b7280), fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
