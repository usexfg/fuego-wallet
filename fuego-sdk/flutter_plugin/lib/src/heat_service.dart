import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'fuego_sdk.dart';
import 'fuego_sdk_bindings.dart';

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

      return HEATProof._fromNative(proofPtr);
    } finally {
      calloc.free(txDataPtr);
      calloc.free(walletFilePtr);
      calloc.free(passwordPtr);
      calloc.free(proofPtr);
    }
  }

  /// Verify a HEAT proof
  Future<bool> verifyProof(HEATProof proof) async {
    final proofPtr = calloc<FuegoHEATProof>();
    final validPtr = calloc<Bool>();

    try {
      // Copy proof data to native
      proofPtr.ref.proof_size = proof.proofData.length;
      final proofDataPtr = proof.proofData.toNativeUtf8();
      proofPtr.ref.proof_data.cast<Uint8>().asTypedList(proof.proofData.length).setAll(0, proof.proofData.codeUnits);
      
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
      : proofData = native.proof_data.cast<Uint8>().asTypedList(native.proof_size).toList(),
        verificationResult = native.verification_result.cast<Utf8>().toDartString();
}
