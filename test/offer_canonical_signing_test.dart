import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuego/bloc/dex/dex_cubit.dart';

void main() {
  group('offer canonical signing bytes', () {
    test('matches SwapOfferRelay::offerCanonicalHash layout', () {
      final bytes = DexCubit.canonicalOfferBytesForTest(
        offerId: 'abcd1234',
        pair: 3,
        xfgAmount: 10000000,
        rateNum: 170000000,
        ttlBlocks: 720,
        timestamp: 1755000000,
      );

      // offerId (utf8) ‖ u8(pair) ‖ u64LE(xfgAmount) ‖ u64LE(rateNum)
      // ‖ u8(isSoftOrder=0) ‖ u32LE(ttlBlocks) ‖ u8(slippage=0)
      // ‖ u64LE(timestamp)
      final expected = <int>[
        ...utf8.encode('abcd1234'),
        3,
        ..._le64(10000000),
        ..._le64(170000000),
        0,
        ..._le32(720),
        0,
        ..._le64(1755000000),
      ];
      expect(bytes, expected);
    });

    test('isSoftOrder and slippage bytes', () {
      final bytes = DexCubit.canonicalOfferBytesForTest(
        offerId: 'ff',
        pair: 0,
        xfgAmount: 1,
        rateNum: 2,
        ttlBlocks: 3,
        timestamp: 4,
        isSoftOrder: true,
        slippagePct: 5,
      );
      // byte after ttlBlocks is slippage (5), byte after rateNum is soft (1)
      final expected = <int>[
        ...utf8.encode('ff'),
        0,
        ..._le64(1),
        ..._le64(2),
        1,
        ..._le32(3),
        5,
        ..._le64(4),
      ];
      expect(bytes, expected);
    });
  });
}

List<int> _le32(int v) {
  final b = ByteData(4)..setUint32(0, v & 0xFFFFFFFF, Endian.little);
  return b.buffer.asUint8List().toList();
}

List<int> _le64(int v) {
  final b = ByteData(8)..setUint64(0, v, Endian.little);
  return b.buffer.asUint8List().toList();
}
