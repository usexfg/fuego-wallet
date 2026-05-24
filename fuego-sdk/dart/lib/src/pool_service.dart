import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'fuego_sdk.dart';
import 'fuego_sdk_bindings.dart';

/// Pool reserves info
class PoolReserves {
  final int xfgReserve;
  final int heatReserve;
  final int totalLP;
  final int feeBps;
  final int kLast;

  PoolReserves({
    required this.xfgReserve,
    required this.heatReserve,
    required this.totalLP,
    required this.feeBps,
    required this.kLast,
  });

  double get xfgDisplay => xfgReserve / 10000000.0;
  double get heatDisplay => heatReserve / 10000000.0;
  double get lpDisplay => totalLP / 10000000.0;

  double get price => xfgReserve > 0
      ? heatReserve / xfgReserve.toDouble()
      : 0.0;
}

/// Pool swap result
class PoolSwapResult {
  final int inputAmount;
  final int outputAmount;
  final int feeAmount;
  final int priceImpactBps;

  PoolSwapResult({
    required this.inputAmount,
    required this.outputAmount,
    required this.feeAmount,
    required this.priceImpactBps,
  });

  double get inputDisplay => inputAmount / 10000000.0;
  double get outputDisplay => outputAmount / 10000000.0;
  double get feeDisplay => feeAmount / 10000000.0;
  double get priceImpactPercent => priceImpactBps / 100.0;
}

/// Pool liquidity result
class PoolLiquidityResult {
  final int lpTokens;
  final int xfgAmount;
  final int heatAmount;

  PoolLiquidityResult({
    required this.lpTokens,
    required this.xfgAmount,
    required this.heatAmount,
  });

  double get lpDisplay => lpTokens / 10000000.0;
  double get xfgDisplay => xfgAmount / 10000000.0;
  double get heatDisplay => heatAmount / 10000000.0;
}

/// Hearth AMM Pool Service
class PoolService {
  final FuegoSDK _sdk;

  PoolService(this._sdk);

  /// Initialize the pool with initial liquidity
  Future<FuegoError> initialize({
    required int xfgAmount,
    required int heatAmount,
    int feeBps = 30,
  }) async {
    final result = _sdk.bindings.fuego_pool_initialize(
      xfgAmount,
      heatAmount,
      feeBps,
    );
    return FuegoError.fromCode(result);
  }

  /// Get pool reserves
  Future<PoolReserves> getReserves() async {
    final reservesPtr = calloc<FuegoPoolReserves>();

    try {
      final result = _sdk.bindings.fuego_pool_get_reserves(reservesPtr);
      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to get pool reserves: ${FuegoError.fromCode(result)}');
      }
      return PoolReserves(
        xfgReserve: reservesPtr.ref.xfg_reserve,
        heatReserve: reservesPtr.ref.heat_reserve,
        totalLP: reservesPtr.ref.total_lp,
        feeBps: reservesPtr.ref.fee_bps,
        kLast: reservesPtr.ref.k_last,
      );
    } finally {
      calloc.free(reservesPtr);
    }
  }

  /// Execute a swap through the pool
  Future<PoolSwapResult> swap({
    required String inputAsset,
    required int inputAmount,
    int minOutput = 0,
  }) async {
    final assetPtr = inputAsset.toNativeUtf8();
    final swapResultPtr = calloc<FuegoPoolSwapResult>();

    try {
      final result = _sdk.bindings.fuego_pool_swap(
        assetPtr.cast(),
        inputAmount,
        minOutput,
        swapResultPtr,
      );

      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Pool swap failed: ${FuegoError.fromCode(result)}');
      }

      return PoolSwapResult(
        inputAmount: swapResultPtr.ref.input_amount,
        outputAmount: swapResultPtr.ref.output_amount,
        feeAmount: swapResultPtr.ref.fee_amount,
        priceImpactBps: swapResultPtr.ref.price_impact_bps,
      );
    } finally {
      calloc.free(assetPtr);
      calloc.free(swapResultPtr);
    }
  }

  /// Get estimated output without executing
  Future<int> getEstimatedOutput({
    required String inputAsset,
    required int inputAmount,
  }) async {
    final assetPtr = inputAsset.toNativeUtf8();
    final outputPtr = calloc<Uint64>();

    try {
      final result = _sdk.bindings.fuego_pool_get_estimated_output(
        assetPtr.cast(),
        inputAmount,
        outputPtr,
      );

      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to estimate output: ${FuegoError.fromCode(result)}');
      }

      return outputPtr.value;
    } finally {
      calloc.free(assetPtr);
      calloc.free(outputPtr);
    }
  }

  /// Add liquidity to the pool
  Future<PoolLiquidityResult> addLiquidity({
    required int xfgAmount,
    required int heatAmount,
    int minLP = 0,
  }) async {
    final resultPtr = calloc<FuegoPoolLiquidityResult>();

    try {
      final result = _sdk.bindings.fuego_pool_add_liquidity(
        xfgAmount,
        heatAmount,
        minLP,
        resultPtr,
      );

      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to add liquidity: ${FuegoError.fromCode(result)}');
      }

      return PoolLiquidityResult(
        lpTokens: resultPtr.ref.lp_tokens,
        xfgAmount: resultPtr.ref.xfg_amount,
        heatAmount: resultPtr.ref.heat_amount,
      );
    } finally {
      calloc.free(resultPtr);
    }
  }

  /// Remove liquidity from the pool
  Future<PoolLiquidityResult> removeLiquidity({
    required int lpAmount,
    int minXFG = 0,
    int minHEAT = 0,
  }) async {
    final resultPtr = calloc<FuegoPoolLiquidityResult>();

    try {
      final result = _sdk.bindings.fuego_pool_remove_liquidity(
        lpAmount,
        minXFG,
        minHEAT,
        resultPtr,
      );

      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to remove liquidity: ${FuegoError.fromCode(result)}');
      }

      return PoolLiquidityResult(
        lpTokens: resultPtr.ref.lp_tokens,
        xfgAmount: resultPtr.ref.xfg_amount,
        heatAmount: resultPtr.ref.heat_amount,
      );
    } finally {
      calloc.free(resultPtr);
    }
  }

  /// Get LP balance for a wallet
  Future<int> getLPBalance(String address) async {
    final addrPtr = address.toNativeUtf8();
    final balancePtr = calloc<Uint64>();

    try {
      final result = _sdk.bindings.fuego_pool_get_lp_balance(
        addrPtr.cast(),
        balancePtr,
      );

      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to get LP balance: ${FuegoError.fromCode(result)}');
      }

      return balancePtr.value;
    } finally {
      calloc.free(addrPtr);
      calloc.free(balancePtr);
    }
  }
}
