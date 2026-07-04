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
  WebViewController? _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0D1117))
      ..addJavaScriptChannel(
        'onCrosshairMove',
        onMessageReceived: (msg) {},
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _loaded = true;
            _pushChartData();
          },
        ),
      );

    _loadChart();
  }

  Future<void> _loadChart() async {
    await _controller!.loadFlutterAsset('assets/charts/tv_chart.html');
  }

  void _pushChartData() {
    if (!_loaded || _controller == null || widget.candles.isEmpty) return;
    final data = {
      'pair': widget.pair,
      'candles': widget.candles.map((c) => c.toChartJson()).toList(),
    };
    _controller!.runJavaScript('updateChart(${jsonEncode(data)});');
  }

  @override
  void didUpdateWidget(FuegoChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candles != widget.candles || oldWidget.pair != widget.pair) {
      _pushChartData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return const SizedBox.shrink();
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1f2937)),
      ),
      clipBehavior: Clip.hardEdge,
      child: WebViewWidget(controller: _controller!),
    );
  }
}
