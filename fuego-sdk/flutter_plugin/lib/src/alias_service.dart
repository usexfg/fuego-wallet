import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'fuego_sdk.dart';

/// Alias registration and resolution service
class AliasService {
  final FuegoSDK _sdk;

  AliasService(this._sdk);

  /// Register an alias for a wallet address
  Future<String> register({
    required String alias,
    required String walletAddress,
    required String walletFile,
    required String walletPassword,
  }) async {
    final aliasPtr = alias.toNativeUtf8();
    final addressPtr = walletAddress.toNativeUtf8();
    final walletFilePtr = walletFile.toNativeUtf8();
    final passwordPtr = walletPassword.toNativeUtf8();
    final txHashPtr = calloc<Uint8>(65);

    try {
      final result = _sdk.bindings.fuego_alias_register(
        aliasPtr.cast(),
        addressPtr.cast(),
        walletFilePtr.cast(),
        passwordPtr.cast(),
        txHashPtr.cast(),
        65,
      );

      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to register alias: ${FuegoError.fromCode(result)}');
      }

      return txHashPtr.cast<Utf8>().toDartString();
    } finally {
      calloc.free(aliasPtr);
      calloc.free(addressPtr);
      calloc.free(walletFilePtr);
      calloc.free(passwordPtr);
      calloc.free(txHashPtr);
    }
  }

  /// Resolve an alias to a wallet address
  Future<String> resolve(String alias) async {
    final aliasPtr = alias.toNativeUtf8();
    final addressPtr = calloc<Uint8>(128);

    try {
      final result = _sdk.bindings.fuego_alias_resolve(
        aliasPtr.cast(),
        addressPtr.cast(),
        128,
      );

      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to resolve alias: ${FuegoError.fromCode(result)}');
      }

      return addressPtr.cast<Utf8>().toDartString();
    } finally {
      calloc.free(aliasPtr);
      calloc.free(addressPtr);
    }
  }

  /// Get all aliases owned by a wallet address
  Future<List<String>> getOwned(String walletAddress) async {
    final addressPtr = walletAddress.toNativeUtf8();
    final aliasesPtrPtr = calloc<Pointer<Void>>();
    final countPtr = calloc<Size>();

    try {
      final result = _sdk.bindings.fuego_alias_get_owned(
        addressPtr.cast(),
        aliasesPtrPtr.cast(),
        countPtr,
      );

      if (result != FuegoError.FUEGO_OK.code) {
        throw Exception('Failed to get owned aliases: ${FuegoError.fromCode(result)}');
      }

      final count = countPtr.value;
      if (count == 0) {
        return [];
      }

      final aliases = <String>[];
      final aliasesArray = aliasesPtrPtr.value.cast<Pointer<Utf8>>();
      
      for (int i = 0; i < count; i++) {
        aliases.add(aliasesArray[i].toDartString());
      }

      // Free the aliases array
      _sdk.bindings.fuego_free_pointer_array(aliasesPtrPtr.cast(), count);
      
      return aliases;
    } finally {
      calloc.free(addressPtr);
      calloc.free(aliasesPtrPtr);
      calloc.free(countPtr);
    }
  }
}
