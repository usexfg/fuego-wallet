import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AuthStatus { initial, initializing, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? error;
  final String? address;

  const AuthState({
    this.status = AuthStatus.initial,
    this.error,
    this.address,
  });

  AuthState copyWith({AuthStatus? status, String? error, String? address}) =>
      AuthState(
        status: status ?? this.status,
        error: error,
        address: address ?? this.address,
      );

  @override
  String toString() => 'AuthState($status)';
}

class AuthCubit extends Cubit<AuthState> {
  static const _kAddress = 'fuego_address';
  static const _storage = FlutterSecureStorage();

  AuthCubit() : super(const AuthState());

  Future<void> initialize() async {
    emit(const AuthState(status: AuthStatus.initializing));
    try {
      final address = await _storage.read(key: _kAddress);
      if (address != null && address.isNotEmpty) {
        emit(AuthState(status: AuthStatus.authenticated, address: address));
      } else {
        emit(const AuthState(status: AuthStatus.unauthenticated));
      }
    } catch (_) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> signIn(String address) async {
    emit(const AuthState(status: AuthStatus.initializing));
    try {
      await _storage.write(key: _kAddress, value: address);
      emit(AuthState(status: AuthStatus.authenticated, address: address));
    } catch (e) {
      emit(AuthState(status: AuthStatus.error, error: e.toString()));
    }
  }

  Future<void> signOut() async {
    try {
      await _storage.delete(key: _kAddress);
    } catch (_) {}
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
