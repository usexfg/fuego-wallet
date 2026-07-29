import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:imp_trading_chart/imp_trading_chart.dart' as imp;
import '../models/candlestick.dart';

class FuegoChart extends StatefulWidget {
  final List<Candlestick> candles;
  final String pair;
  final Color lineColor;
  final Color bgColor;

  const FuegoChart({
    super.key,
    required this.candles,
    this.pair = '',
    this.lineColor = const Color(0xFFFF5722),
    this.bgColor = const Color(0xFF0A0E14),
  });

  @override
  State<FuegoChart> createState() => _FuegoChartState();
}

class _FuegoChartState extends State<FuegoChart> {
  WebViewController? _controller;
  bool _isLoaded = false;
  bool _useWebView = false;
  bool _showTradingView = true; // Use TradingView (WebView) by default if available
  String _selectedPeriod = '1M';

  @override
  void initState() {
    super.initState();
    _useWebView = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (_useWebView) {
      _initController();
    }
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.bgColor)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoaded = true;
              });
              _sendDataToChart();
            }
          },
        ),
      )
      ..loadFlutterAsset('assets/charts/tv_chart.html');
  }

  @override
  void didUpdateWidget(covariant FuegoChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_useWebView && _isLoaded) {
      _sendDataToChart();
    }
  }

  void _sendDataToChart() {
    if (_controller == null || !_isLoaded) return;

    final data = {
      'pair': widget.pair,
      'candles': widget.candles.map((c) => c.toChartJson()).toList(),
    };

    final jsonStr = jsonEncode(data);
    _controller!.runJavaScript("updateChart('$jsonStr')");
    _controller!.runJavaScript("setPeriod('$_selectedPeriod')");
  }

  void _changePeriod(String period) {
    setState(() {
      _selectedPeriod = period;
    });
    if (_useWebView && _isLoaded && _controller != null) {
      _controller!.runJavaScript("setPeriod('$period')");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candles.isEmpty) return const SizedBox.shrink();

    final showTv = _showTradingView && _useWebView;

    return Container(
      decoration: BoxDecoration(
        color: widget.bgColor,
        borderRadius: BorderRadius.circular(0),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (showTv)
                  WebViewWidget(controller: _controller!)
                else
                  _buildNativeChart(),
                if (widget.pair.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.bgColor.withAlpha((0.8 * 255).round()),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.pair,
                        style: TextStyle(
                          color: widget.lineColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildControlBar(),
        ],
      ),
    );
  }

  Widget _buildNativeChart() {
    final impCandles = widget.candles
        .map((c) => imp.Candle(
              time: c.time,
              open: c.open,
              high: c.high,
              low: c.low,
              close: c.close,
              volume: c.volume,
            ))
        .toList();

    return imp.ImpChart.trading(
      candles: impCandles,
      lineColor: widget.lineColor,
      backgroundColor: Colors.transparent,
      pulseColor: widget.lineColor,
      enableGestures: true,
      showCrosshair: true,
      defaultVisibleCount: 80,
    );
  }

  Widget _buildControlBar() {
    final periods = ['1D', '1W', '1M', '3M', 'ALL'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: widget.bgColor.withAlpha((0.9 * 255).round()),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: periods.map((p) {
              final isSelected = _selectedPeriod == p;
              return GestureDetector(
                onTap: () => _changePeriod(p),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? widget.lineColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    p,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[500],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          if (_useWebView)
            Row(
              children: [
                _buildEngineToggle('TV', _showTradingView),
                const SizedBox(width: 4),
                _buildEngineToggle('Native', !_showTradingView),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEngineToggle(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showTradingView = label == 'TV';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[800] : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? Colors.grey[700]! : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[500],
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
