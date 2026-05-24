import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

const int _coin = 10000000;

class HeatMetrics {
  final double heatSupply;
  final double burnedXfg;
  final double redemptionPrice;
  final double treasuryBalance;
  final double epochSwapFees;
  final bool isActivated;
  final double coverage;

  const HeatMetrics({
    this.heatSupply = 0,
    this.burnedXfg = 0,
    this.redemptionPrice = 0,
    this.treasuryBalance = 0,
    this.epochSwapFees = 0,
    this.isActivated = false,
    this.coverage = 0,
  });

  factory HeatMetrics.fromJson(Map<String, dynamic> json) {
    final heatSupplyAtomic = (json['heat_supply'] as num?)?.toDouble() ?? 0;
    final burnedXfgAtomic = (json['burned_xfg'] as num?)?.toDouble() ?? 0;
    final treasuryAtomic = (json['treasury_balance'] as num?)?.toDouble() ?? 0;
    final epochFeesAtomic = (json['epoch_swap_fees'] as num?)?.toDouble() ?? 0;

    final numVal = (json['redemption_price_num'] as num?)?.toDouble() ?? 0;
    final denomVal = (json['redemption_price_denom'] as num?)?.toDouble() ?? 1;

    final rawPrice = denomVal > 0 ? numVal / denomVal : 0.0;
    final supply = heatSupplyAtomic / _coin;
    final treasury = treasuryAtomic / _coin;

    return HeatMetrics(
      heatSupply: supply,
      burnedXfg: burnedXfgAtomic / _coin,
      redemptionPrice: rawPrice,
      treasuryBalance: treasury,
      epochSwapFees: epochFeesAtomic / _coin,
      isActivated: rawPrice > 0 && denomVal != _coin,
      coverage: supply > 0 ? (treasury / supply) * 100 : 0,
    );
  }

  static const HeatMetrics empty = HeatMetrics();
}

class AMMPoolInfo {
  final double reserveXfg;
  final double reserveHeat;
  final double spotPrice;
  final double poolRatio;
  final double totalLpShares;
  final double accumulatedLpFees;

  const AMMPoolInfo({
    this.reserveXfg = 0,
    this.reserveHeat = 0,
    this.spotPrice = 0,
    this.poolRatio = 0,
    this.totalLpShares = 0,
    this.accumulatedLpFees = 0,
  });

  factory AMMPoolInfo.fromJson(Map<String, dynamic> json) {
    final xfgAtomic = (json['reserve_xfg'] as num?)?.toDouble() ?? 0;
    final heatAtomic = (json['reserve_heat'] as num?)?.toDouble() ?? 0;
    final xfg = xfgAtomic / _coin;
    final heat = heatAtomic / _coin;

    return AMMPoolInfo(
      reserveXfg: xfg,
      reserveHeat: heat,
      spotPrice: (json['spot_price'] as num?)?.toDouble() ?? 0,
      poolRatio: heat > 0 ? xfg / heat : 0,
      totalLpShares: (json['total_lp_shares'] as num?)?.toDouble() ?? 0,
      accumulatedLpFees:
          ((json['accumulated_lp_fees'] as num?)?.toDouble() ?? 0) / _coin,
    );
  }

  static const AMMPoolInfo empty = AMMPoolInfo();
}

class HeatMetricsService {
  static final Logger _logger = Logger('HeatMetricsService');

  static const String _defaultBaseUrl = 'http://localhost:18280';

  static final HeatMetricsService instance = HeatMetricsService._();
  HeatMetricsService._();

  String _baseUrl = _defaultBaseUrl;
  final Duration _timeout = const Duration(seconds: 10);

  void setBaseUrl(String url) {
    _baseUrl = url;
  }

  String get baseUrl => _baseUrl;

  Future<Map<String, dynamic>> getNodeInfo() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/getinfo'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      _logger.warning('getNodeInfo failed: $e');
    }
    return {};
  }

  Future<HeatMetrics> getMetrics() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/heat_metrics'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return HeatMetrics.fromJson(data);
      }
    } catch (e) {
      _logger.warning('getMetrics failed: $e');
    }
    return HeatMetrics.empty;
  }

  Future<AMMPoolInfo> getAMMPoolInfo() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/amm_pool_info'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return AMMPoolInfo.fromJson(data);
      }
    } catch (e) {
      _logger.warning('getAMMPoolInfo failed: $e');
    }
    return AMMPoolInfo.empty;
  }

  Future<bool> testConnection() async {
    try {
      final result = await getNodeInfo();
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
