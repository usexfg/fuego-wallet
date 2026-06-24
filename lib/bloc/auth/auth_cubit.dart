import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuego_defi_sdk/fuego_defi_sdk.dart';

enum AuthStatus { initial, initializing, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? error;
  final String? userId;

  const AuthState({
    this.status = AuthStatus.initial,
    this.error,
    this.userId,
  });

  AuthState copyWith({AuthStatus? status, String? error, String? userId}) =>
      AuthState(
        status: status ?? this.status,
        error: error,
        userId: userId ?? this.userId,
      );

  @override
  String toString() => 'AuthState($status)';
}

class AuthCubit extends Cubit<AuthState> {
  final FuegoDefiSdk _sdk;

  AuthCubit(this._sdk) : super(const AuthState());

  Future<void> initialize() async {
    emit(const AuthState(status: AuthStatus.initializing));
    try {
      final signedIn = await _sdk.auth.isSignedIn();
      if (signedIn) {
        final user = await _sdk.auth.currentUser;
        emit(AuthState(
          status: AuthStatus.authenticated,
          userId: user?.toString(),
        ));
      } else {
        emit(const AuthState(status: AuthStatus.unauthenticated));
      }
    } catch (e) {
      emit(AuthState(status: AuthStatus.error, error: e.toString()));
    }
  }

  Future<void> signIn(String password) async {
    emit(const AuthState(status: AuthStatus.initializing));
    try {
      final user = await _sdk.auth.signIn(
        walletName: 'fuego',
        password: password,
      );
      emit(AuthState(status: AuthStatus.authenticated, userId: user.toString()));
    } catch (e) {
      emit(AuthState(status: AuthStatus.error, error: e.toString()));
    }
  }

  Future<void> signOut() async {
    try {
      await _sdk.auth.signOut();
    } catch (_) {}
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
