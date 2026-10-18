import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _canUseExactAlarms = false;

  Future<void> initialize() async {
    if (kIsWeb) return;
    tz_data.initializeTimeZones();
    const initialization = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(initialization);
    if (defaultTargetPlatform == TargetPlatform.android) {
      _canUseExactAlarms =
          await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.canScheduleExactNotifications() ??
          false;
    }
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notificationsAllowed =
          await android?.requestNotificationsPermission() ?? true;
      if (!notificationsAllowed) return false;
      _canUseExactAlarms =
          await android?.canScheduleExactNotifications() ?? false;
      if (!_canUseExactAlarms) {
        _canUseExactAlarms =
            await android?.requestExactAlarmsPermission() ?? false;
      }
      return true;
    }
    return false;
  }

  Future<void> scheduleAll(List<ScheduledAppNotification> notifications) async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
    for (final item in notifications.take(60)) {
      if (!item.at.isAfter(DateTime.now())) continue;
      await _plugin.zonedSchedule(
        item.id,
        item.title,
        item.body,
        tz.TZDateTime.from(item.at, tz.local),
        _detailsFor(item),
        payload: item.payload,
        androidScheduleMode: _canUseExactAlarms
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> showTest({
    required bool sound,
    required bool vibrate,
    String? soundName,
  }) {
    final item = ScheduledAppNotification(
      id: 999999,
      title: 'مشكاة',
      body: 'التنبيهات تعمل بنجاح — بارك الله في وقتك.',
      at: DateTime.now(),
      sound: sound,
      vibrate: vibrate,
      soundName: soundName,
    );
    return _plugin.show(item.id, item.title, item.body, _detailsFor(item));
  }

  NotificationDetails _detailsFor(ScheduledAppNotification item) {
    final customSound = item.sound && item.soundName != null;
    final channelSuffix = !item.sound
        ? 'silent'
        : customSound
        ? item.soundName!
        : 'default';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'mishkat_prayers_$channelSuffix',
        'مواقيت الصلاة',
        channelDescription: 'تنبيهات الأذان والتذكير بالصلاة والأذكار',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        playSound: item.sound,
        sound: customSound
            ? RawResourceAndroidNotificationSound(item.soundName!)
            : null,
        enableVibration: item.vibrate,
      ),
      iOS: DarwinNotificationDetails(
        presentSound: item.sound,
        sound: customSound ? '${item.soundName}.caf' : null,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}

class ScheduledAppNotification {
  const ScheduledAppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    this.payload,
    this.sound = true,
    this.vibrate = true,
    this.soundName,
  });
  final int id;
  final String title;
  final String body;
  final DateTime at;
  final String? payload;
  final bool sound;
  final bool vibrate;
  final String? soundName;
}
