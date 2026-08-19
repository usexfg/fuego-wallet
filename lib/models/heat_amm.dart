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
    inputAmount: json['input_amount']?.toString() ?? '0',
    outputAmount:
        json['output_amount']?.toString() ??
        json['expected_output']?.toString() ??
        '0',
    price: json['price']?.toString() ?? '0',
    fee: json['fee']?.toString() ?? '0',
    priceImpact:
        json['price_impact']?.toString() ??
        (((json['price_impact_bps'] as num?)?.toDouble() ?? 0) / 10000)
            .toString(),
  );
}

class PoolInfo {
  final String xfgReserve;
  final String heatReserve;
  final String spotPrice;
  final String totalLpShares;
  final String volume24h;

  const PoolInfo({
    required this.xfgReserve,
    required this.heatReserve,
    required this.spotPrice,
    required this.totalLpShares,
    this.volume24h = '0',
  });

  factory PoolInfo.fromJson(Map<String, dynamic> json) => PoolInfo(
    xfgReserve: _wholeAmount(json['reserve_xfg']),
    heatReserve: _wholeAmount(json['reserve_heat']),
    spotPrice: _wholeAmount(json['spot_price']),
    totalLpShares: json['total_lp_shares']?.toString() ?? '0',
    volume24h:
        json['volume_24h']?.toString() ?? json['volume24h']?.toString() ?? '0',
  );

  static String _wholeAmount(Object? value) {
    return value?.toString() ?? '0';
  }
}

class LpPosition {
  final String shares;
  final String originalXfg;
  final String originalHeat;
  final String currentValueXfg;
  final String currentValueHeat;
  final String earningsXfg;
  final String earningsHeat;

  const LpPosition({
    required this.shares,
    required this.originalXfg,
    required this.originalHeat,
    required this.currentValueXfg,
    required this.currentValueHeat,
    required this.earningsXfg,
    required this.earningsHeat,
  });
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

class OrderBookState {
  final double clearingPrice;
  final List<double> bidPrices;
  final List<double> bidDepths;
  final List<double> askPrices;
  final List<double> askDepths;

  const OrderBookState({
    required this.clearingPrice,
    required this.bidPrices,
    required this.bidDepths,
    required this.askPrices,
    required this.askDepths,
  });

  factory OrderBookState.fromJson(Map<String, dynamic> json) {
    double atomicAmount(Object? value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;

    final bidPrices = (json['bid_prices'] as List<dynamic>? ?? [])
        .map(atomicAmount)
        .toList();
    final bidDepths = (json['bid_depths'] as List<dynamic>? ?? [])
        .map(atomicAmount)
        .toList();
    final askPrices = (json['ask_prices'] as List<dynamic>? ?? [])
        .map(atomicAmount)
        .toList();
    final askDepths = (json['ask_depths'] as List<dynamic>? ?? [])
        .map(atomicAmount)
        .toList();
    return OrderBookState(
      clearingPrice: atomicAmount(json['clearing_price']),
      bidPrices: bidPrices,
      bidDepths: bidDepths,
      askPrices: askPrices,
      askDepths: askDepths,
    );
  }

  bool get isEmpty => bidPrices.isEmpty && askPrices.isEmpty;
}

class FuegoPrice {
  final double reserveXfg;
  final double reserveHeat;
  final double spotPrice;
  final String xfgHeatRatio;
  final String xfgSpotUsd;
  final double heatPegUsd;

  const FuegoPrice({
    required this.reserveXfg,
    required this.reserveHeat,
    required this.spotPrice,
    required this.xfgHeatRatio,
    required this.xfgSpotUsd,
    required this.heatPegUsd,
  });

  factory FuegoPrice.fromJson(Map<String, dynamic> json) {
    double atomicAmount(Object? value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;

    return FuegoPrice(
      reserveXfg: atomicAmount(json['reserve_xfg']),
      reserveHeat: atomicAmount(json['reserve_heat']),
      spotPrice: atomicAmount(json['spot_price']),
      xfgHeatRatio: json['xfg_heat_ratio']?.toString() ?? '0',
      xfgSpotUsd: json['xfg_spot_usd']?.toString() ?? '0',
      heatPegUsd: atomicAmount(json['heat_peg_usd']),
    );
  }
}

class OrderBook {
  final List<OrderBookLevel> asks;
  final List<OrderBookLevel> bids;
  final double lastPrice;

  const OrderBook({
    required this.asks,
    required this.bids,
    required this.lastPrice,
  });

  factory OrderBook.fromDaemon(OrderBookState state) {
    double cumulative = 0;
    final asks = <OrderBookLevel>[];
    for (var i = 0; i < state.askPrices.length; i++) {
      cumulative += state.askDepths[i];
      asks.add(
        OrderBookLevel(
          price: state.askPrices[i],
          amount: state.askDepths[i],
          total: cumulative,
        ),
      );
    }
    cumulative = 0;
    final bids = <OrderBookLevel>[];
    for (var i = 0; i < state.bidPrices.length; i++) {
      cumulative += state.bidDepths[i];
      bids.add(
        OrderBookLevel(
          price: state.bidPrices[i],
          amount: state.bidDepths[i],
          total: cumulative,
        ),
      );
    }
    return OrderBook(
      asks: asks.reversed.toList(),
      bids: bids,
      lastPrice: state.clearingPrice,
    );
  }
}
