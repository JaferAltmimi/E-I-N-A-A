import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/services/local_notification_service.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../prayer_times/data/services/prayer_calculator.dart';
import '../../data/models/app_settings.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required this._storage,
    required this._locationService,
    required this._notifications,
  }) : super(const SettingsState());

  final LocalStorageService _storage;
  final LocationService _locationService;
  final LocalNotificationService _notifications;
  final PrayerCalculator _calculator = const PrayerCalculator();

  Future<void> load() async {
    final settings = AppSettings.fromJson(_storage.readMap('settings'));
    emit(SettingsState(status: SettingsStatus.ready, settings: settings));
    if (settings.keepAwake) unawaited(WakelockPlus.enable());
    if (settings.notificationsEnabled) {
      unawaited(rescheduleNotifications(settings));
    }
  }

  Future<void> useCurrentLocation() async {
    emit(state.copyWith(status: SettingsStatus.locating, clearMessage: true));
    try {
      final position = await _locationService.currentPosition();
      final current = state.settings;
      await _save(
        current.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
          city: position.label,
          locationAuto: true,
          method: current.methodSet ? current.method : position.suggestedMethod,
          onboardingSeen: true,
        ),
        reschedule: true,
      );
    } on LocationFailure catch (error) {
      emit(
        state.copyWith(status: SettingsStatus.failure, message: error.message),
      );
    } on Object {
      emit(
        state.copyWith(
          status: SettingsStatus.failure,
          message: 'تعذّر تحديد الموقع الآن. حاول مجددًا.',
        ),
      );
    }
  }

  Future<void> selectCity(NearbyCity city) => _save(
    state.settings.copyWith(
      latitude: city.latitude,
      longitude: city.longitude,
      city: city.name,
      locationAuto: false,
      method: state.settings.methodSet ? state.settings.method : city.method,
      onboardingSeen: true,
    ),
    reschedule: true,
  );

  Future<void> skipOnboarding() =>
      _save(state.settings.copyWith(onboardingSeen: true));

  Future<void> setTheme(AppThemePreference value) =>
      _save(state.settings.copyWith(theme: value));
  Future<void> setUiFontScale(double value) =>
      _save(state.settings.copyWith(uiFontScale: value));
  Future<void> setQuranFont(double value) =>
      _save(state.settings.copyWith(quranFont: value));
  Future<void> setReciter(String value) =>
      _save(state.settings.copyWith(reciter: value));
  Future<void> setAsr(String value) =>
      _save(state.settings.copyWith(asr: value), reschedule: true);
  Future<void> setHighLatitudes(String value) =>
      _save(state.settings.copyWith(highLatitudes: value), reschedule: true);
  Future<void> setHijriOffset(int value) =>
      _save(state.settings.copyWith(hijriOffset: value.clamp(-2, 2)));
  Future<void> setPreMinutes(int value) => _save(
    state.settings.copyWith(preMinutes: value.clamp(0, 60)),
    reschedule: true,
  );
  Future<void> setAdhkarNotifications(bool value) => _save(
    state.settings.copyWith(adhkarNotifications: value),
    reschedule: true,
  );
  Future<void> setAdhanSound(bool value) =>
      _save(state.settings.copyWith(adhanSound: value), reschedule: true);
  Future<void> setAdhanFile(String value) =>
      _save(state.settings.copyWith(adhanFile: value), reschedule: true);
  Future<void> setVibration(bool value) =>
      _save(state.settings.copyWith(vibrate: value), reschedule: true);
  Future<void> setAutoScroll(bool value) =>
      _save(state.settings.copyWith(quranAutoScroll: value));
  Future<void> setContinuousAudio(bool value) =>
      _save(state.settings.copyWith(quranContinuous: value));

  Future<void> setKeepAwake(bool value) async {
    if (value) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
    await _save(state.settings.copyWith(keepAwake: value));
  }

  Future<void> setMethod(String value) => _save(
    state.settings.copyWith(method: value, methodSet: true),
    reschedule: true,
  );

  Future<void> setTune(String prayer, int minutes) {
    final tune = Map<String, int>.from(state.settings.tune)
      ..[prayer] = minutes.clamp(-30, 30);
    return _save(state.settings.copyWith(tune: tune), reschedule: true);
  }

  Future<void> setPrayerNotification(String prayer, bool enabled) {
    final values = Map<String, bool>.from(state.settings.prayerNotifications)
      ..[prayer] = enabled;
    return _save(
      state.settings.copyWith(prayerNotifications: values),
      reschedule: true,
    );
  }

  Future<bool> setNotificationsEnabled(bool enabled) async {
    if (enabled && !await _notifications.requestPermission()) {
      emit(
        state.copyWith(
          status: SettingsStatus.failure,
          message: 'لم يُمنح إذن التنبيهات من إعدادات الجهاز.',
        ),
      );
      return false;
    }
    await _save(state.settings.copyWith(notificationsEnabled: enabled));
    if (enabled) {
      await rescheduleNotifications(state.settings);
    } else {
      await _notifications.cancelAll();
    }
    return true;
  }

  Future<void> testNotification() => _notifications.showTest(
    sound: state.settings.adhanSound,
    vibrate: state.settings.vibrate,
    soundName: state.settings.adhanSound ? state.settings.adhanFile : null,
  );

  Future<void> clearAllData() async {
    await _notifications.cancelAll();
    await _storage.clear();
    emit(
      const SettingsState(
        status: SettingsStatus.ready,
        settings: AppSettings(),
      ),
    );
  }

  Future<void> _save(AppSettings settings, {bool reschedule = false}) async {
    emit(
      state.copyWith(
        status: SettingsStatus.saving,
        settings: settings,
        clearMessage: true,
      ),
    );
    await _storage.writeMap('settings', settings.toJson());
    emit(
      state.copyWith(
        status: SettingsStatus.ready,
        settings: settings,
        clearMessage: true,
      ),
    );
    if (reschedule && settings.notificationsEnabled) {
      await rescheduleNotifications(settings);
    }
  }

  Future<void> rescheduleNotifications(AppSettings settings) async {
    if (!settings.notificationsEnabled || !settings.hasLocation) return;
    final now = DateTime.now();
    final items = <ScheduledAppNotification>[];
    var id = 1000;
    for (var day = 0; day < 7; day++) {
      final date = now.add(Duration(days: day));
      final times = _calculator.calculate(
        date: date,
        latitude: settings.latitude!,
        longitude: settings.longitude!,
        methodKey: settings.method,
        methodAuto: !settings.methodSet,
        asr: settings.asr,
        highLatitudes: settings.highLatitudes,
        tune: settings.tune,
      );
      for (final prayer in PrayerCalculator.order.where(
        (item) => !item.noAdhan,
      )) {
        final at = times[prayer.key];
        if (at == null ||
            !at.isAfter(now) ||
            settings.prayerNotifications[prayer.key] != true) {
          continue;
        }
        if (settings.preMinutes > 0) {
          final reminderAt = at.subtract(
            Duration(minutes: settings.preMinutes),
          );
          if (reminderAt.isAfter(now)) {
            items.add(
              ScheduledAppNotification(
                id: id++,
                title: 'اقتربت صلاة ${prayer.name}',
                body: 'بقي ${settings.preMinutes} دقيقة على الأذان.',
                at: reminderAt,
                payload: 'prayer:${prayer.key}:pre',
                sound: settings.adhanSound,
                vibrate: settings.vibrate,
              ),
            );
          }
        }
        items.add(
          ScheduledAppNotification(
            id: id++,
            title: 'حان الآن موعد صلاة ${prayer.name}',
            body: 'حيّ على الصلاة — تقبّل الله طاعتك.',
            at: at,
            payload: 'prayer:${prayer.key}',
            sound: settings.adhanSound,
            vibrate: settings.vibrate,
            soundName: settings.adhanSound ? settings.adhanFile : null,
          ),
        );
      }
      if (settings.adhkarNotifications) {
        final morning = times['sunrise']?.add(const Duration(minutes: 30));
        final evening = times['asr']?.add(const Duration(minutes: 30));
        if (morning != null && morning.isAfter(now)) {
          items.add(
            ScheduledAppNotification(
              id: id++,
              title: 'أذكار الصباح',
              body: 'ابدأ يومك بذكر الله.',
              at: morning,
              payload: 'adhkar:morning',
              sound: settings.adhanSound,
              vibrate: settings.vibrate,
            ),
          );
        }
        if (evening != null && evening.isAfter(now)) {
          items.add(
            ScheduledAppNotification(
              id: id++,
              title: 'أذكار المساء',
              body: 'آن أوان ورد المساء.',
              at: evening,
              payload: 'adhkar:evening',
              sound: settings.adhanSound,
              vibrate: settings.vibrate,
            ),
          );
        }
      }
    }
    items.sort((a, b) => a.at.compareTo(b.at));
    await _notifications.scheduleAll(items);
  }
}
