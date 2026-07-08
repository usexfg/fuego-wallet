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

class OrderBookLevel {
  final double price;
  final double amount;
  final double total;

  const OrderBookLevel({
    required this.price,
    required this.amount,
    required this.total,
  });
}

class OrderBook {
  final List<OrderBookLevel> asks;
  final List<OrderBookLevel> bids;
  final double lastPrice;
  final double high24h;
  final double low24h;
  final double volume24h;

  const OrderBook({
    required this.asks,
    required this.bids,
    required this.lastPrice,
    required this.high24h,
    required this.low24h,
    required this.volume24h,
  });

  factory OrderBook.fromPool(PoolInfo pool) {
    final spot = double.tryParse(pool.spotPrice) ?? 1.58;
    final vol = double.tryParse(pool.volume24h) ?? 0;
    final asks = <OrderBookLevel>[];
    final bids = <OrderBookLevel>[];
    double cumulative = 0;
    for (var i = 0; i < 8; i++) {
      final spread = 0.001 * (i + 1);
      final askPrice = spot * (1 + spread);
      final bidPrice = spot * (1 - spread);
      final askAmt = (vol * 0.12) / (i + 1);
      final bidAmt = (vol * 0.12) / (i + 1);
      cumulative += askAmt;
      asks.add(OrderBookLevel(price: askPrice, amount: askAmt, total: cumulative));
    }
    cumulative = 0;
    for (var i = 0; i < 8; i++) {
      final spread = 0.001 * (i + 1);
      final bidPrice = spot * (1 - spread);
      final bidAmt = (vol * 0.12) / (i + 1);
      cumulative += bidAmt;
      bids.add(OrderBookLevel(price: bidPrice, amount: bidAmt, total: cumulative));
    }
    return OrderBook(
      asks: asks.reversed.toList(),
      bids: bids,
      lastPrice: spot,
      high24h: spot * 1.02,
      low24h: spot * 0.98,
      volume24h: vol,
    );
  }
}
