import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/local_storage_service.dart';
import 'tasbih_state.dart';

class TasbihCubit extends Cubit<TasbihState> {
  TasbihCubit(this._storage)
    : super(TasbihState(total: _storage.readInt('tasbihTotal')));
  final LocalStorageService _storage;

  Future<void> increment() async {
    final count = state.count + 1;
    final total = state.total + 1;
    emit(state.copyWith(count: count, total: total));
    await _storage.writeInt('tasbihTotal', total);
  }

  void reset() => emit(state.copyWith(count: 0));
  void setTarget(int value) =>
      emit(TasbihState(total: state.total, target: value));
}
