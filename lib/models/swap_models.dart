/// Swap and DEX models aligned with fuego-sdk types.
/// Maps 1:1 with Rust SDK types.rs SwapPair, SwapOffer, SwapStatus, etc.

/// Supported swap pair IDs matching fuego-suite.
/// SOL=0, ETH=1, XMR=2, BCH=3, ARB=4, BASE=5
enum SwapPairSdk {
  sol(0, 'SOL', 'XFG/SOL'),
  eth(1, 'ETH', 'XFG/ETH'),
  xmr(2, 'XMR', 'XFG/XMR'),
  bch(3, 'BCH', 'XFG/BCH'),
  arb(4, 'ARB', 'XFG/ARB'),
  base(5, 'BASE', 'XFG/BASE');

  final int id;
  final String ticker;
  final String displayName;
  const SwapPairSdk(this.id, this.ticker, this.displayName);

  static SwapPairSdk fromId(int id) =>
      SwapPairSdk.values.firstWhere((p) => p.id == id, orElse: () => SwapPairSdk.eth);

  static SwapPairSdk? tryFromId(int id) {
    for (final p in SwapPairSdk.values) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// Supported chains for SPV verification.
enum ChainTypeSdk {
  fuego(0, 'XFG', 'Fuego'),
  solana(1, 'SOL', 'Solana'),
  ethereum(2, 'ETH', 'Ethereum'),
  monero(3, 'XMR', 'Monero'),
  bitcoinCash(4, 'BCH', 'Bitcoin Cash'),
  arbitrum(5, 'ARB', 'Arbitrum'),
  base(6, 'BASE', 'Base');

  final int id;
  final String symbol;
  final String name;
  const ChainTypeSdk(this.id, this.symbol, this.name);

  bool get isEvm => this == ChainTypeSdk.ethereum || this == ChainTypeSdk.arbitrum || this == ChainTypeSdk.base;
  bool get isBtcFamily => this == ChainTypeSdk.bitcoinCash;

  static ChainTypeSdk fromId(int id) =>
      ChainTypeSdk.values.firstWhere((c) => c.id == id, orElse: () => ChainTypeSdk.fuego);
}

/// Swap state machine states.
enum SwapStateSdk {
  open,
  matched,
  makerLocked,
  takerLocked,
  makerRevealed,
  completed,
  cancelled;

  static SwapStateSdk fromString(String s) =>
      SwapStateSdk.values.firstWhere((v) => v.name == s, orElse: () => SwapStateSdk.open);
}

/// Swap offer on the orderbook.
class SwapOfferSdk {
  final String offerId;
  final String makerPubKey;
  final SwapPairSdk pair;
  final bool sellXfg;
  final int amount;
  final int rateNum;
  final int createdAt;
  final int expiresAt;

  const SwapOfferSdk({
    required this.offerId,
    required this.makerPubKey,
    required this.pair,
    required this.sellXfg,
    required this.amount,
    required this.rateNum,
    required this.createdAt,
    required this.expiresAt,
  });

  double get rate => rateNum > 0 ? amount / rateNum : 0;
  String get pairLabel => pair.displayName;

  factory SwapOfferSdk.fromJson(Map<String, dynamic> j) => SwapOfferSdk(
        offerId: j['offerId'] as String? ?? j['offer_id'] as String? ?? '',
        makerPubKey: j['makerPubKey'] as String? ?? j['maker_pubkey'] as String? ?? '',
        pair: SwapPairSdk.fromId(j['pair'] as int? ?? 0),
        sellXfg: j['sellXfg'] as bool? ?? j['sell_xfg'] as bool? ?? true,
        amount: j['amount'] as int? ?? 0,
        rateNum: j['rateNum'] as int? ?? j['rate'] as int? ?? 0,
        createdAt: j['createdAt'] as int? ?? j['created_at'] as int? ?? 0,
        expiresAt: j['expiresAt'] as int? ?? j['expires_at'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'offerId': offerId,
        'makerPubKey': makerPubKey,
        'pair': pair.id,
        'sellXfg': sellXfg,
        'amount': amount,
        'rateNum': rateNum,
        'createdAt': createdAt,
        'expiresAt': expiresAt,
      };
}

/// Active swap status.
class SwapStatusSdk {
  final String swapId;
  final SwapStateSdk state;
  final SwapPairSdk pair;
  final int amount;
  final String makerPubkey;
  final String? takerPubkey;
  final int createdAt;
  final int updatedAt;

  const SwapStatusSdk({
    required this.swapId,
    required this.state,
    required this.pair,
    required this.amount,
    required this.makerPubkey,
    this.takerPubkey,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SwapStatusSdk.fromJson(Map<String, dynamic> j) => SwapStatusSdk(
        swapId: j['swapId'] as String? ?? j['swap_id'] as String? ?? '',
        state: SwapStateSdk.fromString(j['state'] as String? ?? 'open'),
        pair: SwapPairSdk.fromId(j['pair'] as int? ?? 0),
        amount: j['amount'] as int? ?? 0,
        makerPubkey: j['makerPubkey'] as String? ?? j['maker_pubkey'] as String? ?? '',
        takerPubkey: j['takerPubkey'] as String? ?? j['taker_pubkey'] as String?,
        createdAt: j['createdAt'] as int? ?? j['created_at'] as int? ?? 0,
        updatedAt: j['updatedAt'] as int? ?? j['updated_at'] as int? ?? 0,
      );
}

/// Historical trade record.
class SwapTradeSdk {
  final String tradeId;
  final SwapPairSdk pair;
  final bool sellXfg;
  final int amount;
  final int price;
  final int timestamp;

  const SwapTradeSdk({
    required this.tradeId,
    required this.pair,
    required this.sellXfg,
    required this.amount,
    required this.price,
    required this.timestamp,
  });

  factory SwapTradeSdk.fromJson(Map<String, dynamic> j) => SwapTradeSdk(
        tradeId: j['tradeId'] as String? ?? j['trade_id'] as String? ?? '',
        pair: SwapPairSdk.fromId(j['pair'] as int? ?? 0),
        sellXfg: j['sellXfg'] as bool? ?? j['sell_xfg'] as bool? ?? true,
        amount: j['amount'] as int? ?? 0,
        price: j['price'] as int? ?? 0,
        timestamp: j['timestamp'] as int? ?? 0,
      );
}

/// Price data for a trading pair.
class SwapPriceSdk {
  final SwapPairSdk pair;
  final String bid;
  final String ask;
  final String last;
  final String volume24h;
  final String change24h;
  final String status;

  const SwapPriceSdk({
    required this.pair,
    required this.bid,
    required this.ask,
    required this.last,
    required this.volume24h,
    required this.change24h,
    this.status = '',
  });

  factory SwapPriceSdk.fromJson(Map<String, dynamic> j) => SwapPriceSdk(
        pair: SwapPairSdk.fromId(j['pair'] as int? ?? 0),
        bid: j['bid']?.toString() ?? '0',
        ask: j['ask']?.toString() ?? '0',
        last: j['last']?.toString() ?? '0',
        volume24h: j['volume_24h']?.toString() ?? j['volume24h']?.toString() ?? '0',
        change24h: j['change_24h']?.toString() ?? j['change24h']?.toString() ?? '0',
        status: j['status'] as String? ?? '',
      );
}

/// Orderbook level (bid or ask).
class OrderLevelSdk {
  final String price;
  final String amount;
  final int count;

  const OrderLevelSdk({
    required this.price,
    required this.amount,
    required this.count,
  });

  factory OrderLevelSdk.fromJson(Map<String, dynamic> j) => OrderLevelSdk(
        price: j['price']?.toString() ?? '0',
        amount: j['amount']?.toString() ?? '0',
        count: j['count'] as int? ?? 0,
      );
}

/// Orderbook state snapshot.
class OrderBookStateSdk {
  final List<OrderLevelSdk> bids;
  final List<OrderLevelSdk> asks;
  final String lastPrice;
  final String volume24h;

  const OrderBookStateSdk({
    required this.bids,
    required this.asks,
    required this.lastPrice,
    required this.volume24h,
  });

  factory OrderBookStateSdk.fromJson(Map<String, dynamic> j) => OrderBookStateSdk(
        bids: (j['bids'] as List<dynamic>?)
                ?.map((e) => OrderLevelSdk.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        asks: (j['asks'] as List<dynamic>?)
                ?.map((e) => OrderLevelSdk.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        lastPrice: j['last_price']?.toString() ?? j['lastPrice']?.toString() ?? '0',
        volume24h: j['volume_24h']?.toString() ?? j['volume24h']?.toString() ?? '0',
      );
}

/// HTLC hash lock result.
class HtlcHashLock {
  final String preimage;
  final String hash;

  const HtlcHashLock({required this.preimage, required this.hash});

  factory HtlcHashLock.fromJson(Map<String, dynamic> j) => HtlcHashLock(
        preimage: j['preimage'] as String? ?? '',
        hash: j['hash'] as String? ?? '',
      );
}

/// HTLC script build result.
class HtlcScript {
  final String script;
  final bool ok;
  final String? error;

  const HtlcScript({required this.script, required this.ok, this.error});

  factory HtlcScript.fromJson(Map<String, dynamic> j) => HtlcScript(
        script: j['script'] as String? ?? '',
        ok: j['ok'] as bool? ?? false,
        error: j['error'] as String?,
      );
}

/// Payment proof for cross-chain SPV verification.
class PaymentProofSdk {
  final ChainTypeSdk chain;
  final String txHash;
  final int amount;
  final String fromAddress;
  final String toAddress;
  final int confirmations;
  final int blockHeight;
  final String blockHash;
  final String merkleRoot;
  final List<String> merkleProof;
  final int txIndex;
  final int totalTxs;
  final bool verified;

  const PaymentProofSdk({
    required this.chain,
    required this.txHash,
    required this.amount,
    required this.fromAddress,
    required this.toAddress,
    required this.confirmations,
    required this.blockHeight,
    required this.blockHash,
    required this.merkleRoot,
    required this.merkleProof,
    required this.txIndex,
    required this.totalTxs,
    required this.verified,
  });

  factory PaymentProofSdk.fromJson(Map<String, dynamic> j) => PaymentProofSdk(
        chain: ChainTypeSdk.fromId(j['chain_id'] as int? ?? 0),
        txHash: j['tx_hash'] as String? ?? '',
        amount: j['amount'] as int? ?? 0,
        fromAddress: j['from_address'] as String? ?? '',
        toAddress: j['to_address'] as String? ?? '',
        confirmations: j['confirmations'] as int? ?? 0,
        blockHeight: j['block_height'] as int? ?? 0,
        blockHash: j['block_hash'] as String? ?? '',
        merkleRoot: j['merkle_root'] as String? ?? '',
        merkleProof: (j['merkle_proof'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        txIndex: j['tx_index'] as int? ?? 0,
        totalTxs: j['total_txs'] as int? ?? 0,
        verified: j['verified'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'chain_id': chain.id,
        'tx_hash': txHash,
        'amount': amount,
        'from_address': fromAddress,
        'to_address': toAddress,
        'confirmations': confirmations,
        'block_height': blockHeight,
        'block_hash': blockHash,
        'merkle_root': merkleRoot,
        'merkle_proof': merkleProof,
        'tx_index': txIndex,
        'total_txs': totalTxs,
        'verified': verified,
      };
}
