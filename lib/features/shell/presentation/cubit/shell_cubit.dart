import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ShellState extends Equatable {
  const ShellState({this.index = 0, this.offline = false});
  final int index;
  final bool offline;

  ShellState copyWith({int? index, bool? offline}) =>
      ShellState(index: index ?? this.index, offline: offline ?? this.offline);

  @override
  List<Object?> get props => [index, offline];
}

class ShellCubit extends Cubit<ShellState> {
  ShellCubit() : super(const ShellState()) {
    _initializeConnectivity();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  void select(int index) => emit(state.copyWith(index: index.clamp(0, 4)));

  Future<void> _initializeConnectivity() async {
    final initial = await _connectivity.checkConnectivity();
    _setConnectivity(initial);
    _subscription = _connectivity.onConnectivityChanged.listen(
      _setConnectivity,
    );
  }

  void _setConnectivity(List<ConnectivityResult> values) {
    emit(
      state.copyWith(
        offline:
            values.isEmpty ||
            values.every((item) => item == ConnectivityResult.none),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
