import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../prayer_times/data/services/prayer_calculator.dart';
import '../../../settings/data/models/app_settings.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._settings, {this._calculator = const PrayerCalculator()})
    : super(HomeState(now: DateTime.now())) {
    _refresh(force: true);
    // Periodically refresh every 15 seconds to detect prayer transitions without thrashing the UI
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  final PrayerCalculator _calculator;
  late final Timer _timer;
  AppSettings _settings;

  void updateSettings(AppSettings settings) {
    _settings = settings;
    _refresh(force: true);
  }

  void _refresh({bool force = false}) {
    final now = DateTime.now();
    if (!_settings.hasLocation) {
      if (force || state.schedule != null || state.now.minute != now.minute) {
        emit(HomeState(now: now));
      }
      return;
    }

    final schedule = _calculator.schedule(
      now: now,
      latitude: _settings.latitude!,
      longitude: _settings.longitude!,
      methodKey: _settings.method,
      methodAuto: !_settings.methodSet,
      asr: _settings.asr,
      highLatitudes: _settings.highLatitudes,
      tune: _settings.tune,
    );

    if (force || state.schedule != schedule || state.now.minute != now.minute) {
      emit(HomeState(now: now, schedule: schedule));
    }
  }

  @override
  Future<void> close() {
    _timer.cancel();
    return super.close();
  }
}
