import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'fuego_sdk.dart';
import 'fuego_sdk_bindings.dart';

String _array8ToStr(ffi.Array<ffi.Int8> arr) {
  final bytes = <int>[];
  for (int i = 0; i < arr.length; i++) {
    final byte = arr[i];
    if (byte == 0) break;
    bytes.add(byte);
  }
  return String.fromCharCodes(bytes);
}

/// HEAT (Hybrid Efficient Anonymous Transfer) proof service
class HEATService {
  final FuegoSDK _sdk;

  HEATService(this._sdk);

  /// Generate a HEAT/zk-SNARK proof for a transaction
  Future<HEATProof> generateProof({
    required String transactionData,
    required String walletFile,
    required String walletPassword,
  }) async {
    final txDataPtr = transactionData.toNativeUtf8();
    final walletFilePtr = walletFile.toNativeUtf8();
    final passwordPtr = walletPassword.toNativeUtf8();
    final proofPtr = calloc<FuegoHEATProof>();

    try {
      final result = _sdk.bindings.fuego_heat_generate_proof(
        txDataPtr.cast(),
        walletFilePtr.cast(),
        passwordPtr.cast(),
        proofPtr,
      );

      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to generate HEAT proof: ${FuegoError.fromCode(result)}');
      }

      return HEATProof._fromNative(proofPtr.ref);
    } finally {
    }
  }

  /// Verify a HEAT proof
  Future<bool> verifyProof(HEATProof proof) async {
    final proofPtr = calloc<FuegoHEATProof>();
    final validPtr = calloc<Bool>();

    try {
      // Copy proof data to native
      proofPtr.ref.proof_size = proof.proofData.length;
      for (int i = 0; i < proof.proofData.length && i < 1024; i++) {
        proofPtr.ref.proof_data[i] = proof.proofData[i];
      }
      
      final result = _sdk.bindings.fuego_heat_verify_proof(proofPtr, validPtr);

      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to verify HEAT proof: ${FuegoError.fromCode(result)}');
      }

      return validPtr.value;
    } finally {
      calloc.free(proofPtr);
      calloc.free(validPtr);
    }
  }
}

/// HEAT proof data
class HEATProof {
  final List<int> proofData;
  final String verificationResult;

  HEATProof({
    required this.proofData,
    required this.verificationResult,
  });

  HEATProof._fromNative(FuegoHEATProof native)
      : proofData = List<int>.generate(
          native.proof_size < 1024 ? native.proof_size : 0,
          (i) => native.proof_data[i],
        ),
        verificationResult = _array8ToStr(native.verification_result);
}
