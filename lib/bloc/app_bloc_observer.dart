import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';

class AppBlocObserver extends BlocObserver {
  final _log = Logger('AppBlocObserver');

  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    _log.fine('BLoC created: ${bloc.runtimeType}');
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    _log.finest('${bloc.runtimeType} changed: $change');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    _log.severe('${bloc.runtimeType} error: $error', error, stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}
