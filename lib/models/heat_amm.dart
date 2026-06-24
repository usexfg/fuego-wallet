class HeatMetrics {
  final String supply;
  final String redemptionPrice;
  final String treasury;
  final String cdYield;
  final String poolXfg;
  final String poolHeat;
  final String piTarget;
  final double currentApy;

  const HeatMetrics({
    required this.supply,
    required this.redemptionPrice,
    required this.treasury,
    required this.cdYield,
    required this.poolXfg,
    required this.poolHeat,
    required this.piTarget,
    required this.currentApy,
  });

  factory HeatMetrics.fromJson(Map<String, dynamic> json) => HeatMetrics(
        supply: json['supply'] as String? ?? '0',
        redemptionPrice: json['redemption_price'] as String? ?? '0',
        treasury: json['treasury'] as String? ?? '0',
        cdYield: json['cd_yield'] as String? ?? '0',
        poolXfg: json['pool_xfg'] as String? ?? '0',
        poolHeat: json['pool_heat'] as String? ?? '0',
        piTarget: json['pi_target'] as String? ?? '0',
        currentApy: (json['current_apy'] as num?)?.toDouble() ?? 0,
      );
}

class AmmQuote {
  final String inputAmount;
  final String outputAmount;
  final String price;
  final String fee;
  final String priceImpact;

  const AmmQuote({
    required this.inputAmount,
    required this.outputAmount,
    required this.price,
    required this.fee,
    required this.priceImpact,
  });

  factory AmmQuote.fromJson(Map<String, dynamic> json) => AmmQuote(
        inputAmount: json['input_amount'] as String,
        outputAmount: json['output_amount'] as String,
        price: json['price'] as String,
        fee: json['fee'] as String,
        priceImpact: json['price_impact'] as String? ?? '0',
      );
}

class PoolInfo {
  final String xfgReserve;
  final String heatReserve;
  final String spotPrice;
  final String totalLpShares;
  final String lpFees24h;
  final String volume24h;

  const PoolInfo({
    required this.xfgReserve,
    required this.heatReserve,
    required this.spotPrice,
    required this.totalLpShares,
    required this.lpFees24h,
    required this.volume24h,
  });

  factory PoolInfo.fromJson(Map<String, dynamic> json) => PoolInfo(
        xfgReserve: json['xfg_reserve'] as String? ?? '0',
        heatReserve: json['heat_reserve'] as String? ?? '0',
        spotPrice: json['spot_price'] as String? ?? '0',
        totalLpShares: json['total_lp_shares'] as String? ?? '0',
        lpFees24h: json['lp_fees_24h'] as String? ?? '0',
        volume24h: json['volume_24h'] as String? ?? '0',
      );
}
