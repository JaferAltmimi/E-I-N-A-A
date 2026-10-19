import '../../../../core/services/local_notification_service.dart';
import '../../../khatma/data/models/khatma_plan.dart';
import '../../../prayer_times/data/services/prayer_calculator.dart';
import '../../../quran/data/models/memorization_plan.dart';
import '../../../quran/data/repositories/quran_memorization_repository.dart';
import '../models/app_settings.dart';
import '../../../../core/services/local_storage_service.dart';

/// Builds one coherent notification calendar from the user's local data.
///
/// Keeping this planning in one place prevents one feature (for example Hifz)
/// from accidentally replacing the prayer or Khatma alarms.
class NotificationSchedulePlanner {
  const NotificationSchedulePlanner._();

  static const int _prayerBase = 100000;
  static const int _adhkarBase = 200000;
  static const int _khatmaBase = 300000;
  static const int memorizationReminderId = 800001;

  static List<ScheduledAppNotification> build({
    required LocalStorageService storage,
    required AppSettings settings,
    DateTime? now,
    int days = 14,
  }) {
    final current = now ?? DateTime.now();
    final items = <ScheduledAppNotification>[];

    if (settings.hasLocation) {
      _addPrayerBasedNotifications(
        items: items,
        storage: storage,
        settings: settings,
        now: current,
        days: days,
      );
    }

    _addMemorizationReminder(
      items: items,
      storage: storage,
      settings: settings,
      now: current,
    );

    items.sort((a, b) => a.at.compareTo(b.at));
    return items;
  }

  static void _addPrayerBasedNotifications({
    required List<ScheduledAppNotification> items,
    required LocalStorageService storage,
    required AppSettings settings,
    required DateTime now,
    required int days,
  }) {
    const calculator = PrayerCalculator();
    final khatmaPlans = _activeKhatmaPlans(storage);

    for (var day = 0; day < days; day++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: day));
      final times = calculator.calculate(
        date: date,
        latitude: settings.latitude!,
        longitude: settings.longitude!,
        methodKey: settings.method,
        methodAuto: !settings.methodSet,
        asr: settings.asr,
        highLatitudes: settings.highLatitudes,
        tune: settings.tune,
      );

      var prayerIndex = 0;
      for (final prayer in PrayerCalculator.order.where(
        (item) => !item.noAdhan,
      )) {
        final at = times[prayer.key];
        final enabled = settings.prayerNotifications[prayer.key] == true;
        if (at != null && enabled) {
          if (settings.preMinutes > 0) {
            final reminderAt = at.subtract(
              Duration(minutes: settings.preMinutes),
            );
            if (reminderAt.isAfter(now)) {
              items.add(
                ScheduledAppNotification(
                  id: _prayerBase + day * 20 + prayerIndex * 2,
                  title: 'اقتربت صلاة ${prayer.name}',
                  body: 'بقي ${settings.preMinutes} دقيقة على الأذان.',
                  at: reminderAt,
                  payload: 'prayer:${prayer.key}:pre',
                  sound: settings.adhanSound,
                  vibrate: settings.vibrate,
                  kind: AppNotificationKind.prayerReminder,
                ),
              );
            }
          }
          if (at.isAfter(now)) {
            final place = settings.city.trim();
            items.add(
              ScheduledAppNotification(
                id: _prayerBase + day * 20 + prayerIndex * 2 + 1,
                title: 'حان الآن موعد صلاة ${prayer.name}',
                body: place.isEmpty
                    ? 'حيّ على الصلاة — تقبّل الله طاعتك.'
                    : '$place — حيّ على الصلاة، حيّ على الفلاح.',
                at: at,
                payload: 'prayer:${prayer.key}',
                sound: settings.adhanSound,
                vibrate: settings.vibrate,
                soundName: settings.adhanSound ? settings.adhanFile : null,
                kind: AppNotificationKind.adhan,
              ),
            );
          }
        }
        prayerIndex++;
      }

      if (settings.adhkarNotifications) {
        final morning = times['sunrise']?.add(const Duration(minutes: 30));
        final evening = times['asr']?.add(const Duration(minutes: 30));
        if (morning != null && morning.isAfter(now)) {
          items.add(
            ScheduledAppNotification(
              id: _adhkarBase + day * 2,
              title: 'أذكار الصباح',
              body: 'ابدأ صباحك بذكر الله، واطمئن قلبك بوردك اليومي.',
              at: morning,
              payload: 'adhkar:morning',
              sound: true,
              vibrate: settings.vibrate,
              kind: AppNotificationKind.adhkar,
            ),
          );
        }
        if (evening != null && evening.isAfter(now)) {
          items.add(
            ScheduledAppNotification(
              id: _adhkarBase + day * 2 + 1,
              title: 'أذكار المساء',
              body: 'حان وقت أذكار المساء — حفظك الله حتى تصبح.',
              at: evening,
              payload: 'adhkar:evening',
              sound: true,
              vibrate: settings.vibrate,
              kind: AppNotificationKind.adhkar,
            ),
          );
        }
      }

      for (var planIndex = 0; planIndex < khatmaPlans.length; planIndex++) {
        final plan = khatmaPlans[planIndex];
        final prayer = plan.reminderPrayer;
        final prayerTime = prayer == null ? null : times[prayer];
        if (prayerTime == null) continue;
        final at = prayerTime.add(const Duration(minutes: 15));
        if (!at.isAfter(now)) continue;
        items.add(
          ScheduledAppNotification(
            id: _khatmaBase + day * 100 + planIndex,
            title: 'ورد ${plan.name}',
            body:
                'ورد اليوم ${plan.dailyPages} صفحة — من صفحة '
                '${plan.nextPage} إلى ${plan.todayEnd}.',
            at: at,
            payload: 'khatma:${plan.id}',
            sound: true,
            vibrate: settings.vibrate,
            kind: AppNotificationKind.khatma,
          ),
        );
      }
    }
  }

  static List<KhatmaPlan> _activeKhatmaPlans(LocalStorageService storage) {
    final raw = storage.readMap('khatma')['plans'];
    if (raw is! List) return const [];
    final plans = <KhatmaPlan>[];
    for (final value in raw) {
      if (value is! Map) continue;
      try {
        final plan = KhatmaPlan.fromJson(Map<String, dynamic>.from(value));
        if (plan.status == KhatmaStatus.active && plan.reminderPrayer != null) {
          plans.add(plan);
        }
      } on Object {
        // A damaged plan must not prevent the remaining reminders.
      }
    }
    return plans;
  }

  static void _addMemorizationReminder({
    required List<ScheduledAppNotification> items,
    required LocalStorageService storage,
    required AppSettings settings,
    required DateTime now,
  }) {
    MemorizationPlan? active;
    final raw = storage.readMap(
      QuranMemorizationRepository.storageKey,
    )['plans'];
    if (raw is List) {
      for (final value in raw) {
        if (value is! Map) continue;
        try {
          final plan = MemorizationPlan.fromJson(
            Map<String, dynamic>.from(value),
          );
          if (plan.isActive && !plan.isCompleted) {
            active = plan;
            break;
          }
        } on Object {
          // Continue with the next valid plan.
        }
      }
    }

    final hour = active?.reminderHour;
    final minute = active?.reminderMinute;
    if (hour == null || minute == null) {
      // A past item acts as a cancellation marker for a previously scheduled
      // repeating reminder while keeping the service API compact.
      items.add(
        ScheduledAppNotification(
          id: memorizationReminderId,
          title: '',
          body: '',
          at: DateTime.fromMillisecondsSinceEpoch(0),
          sound: false,
          vibrate: false,
          kind: AppNotificationKind.memorization,
        ),
      );
      return;
    }

    var at = DateTime(now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    items.add(
      ScheduledAppNotification(
        id: memorizationReminderId,
        title: 'ورد الحفظ والمراجعة',
        body: active == null
            ? 'حان موعد وردك اليومي من حفظ القرآن الكريم ومراجعته.'
            : 'حان موعد «${active.title}» — خطوة ثابتة كل يوم.',
        at: at,
        payload: 'memorization:${active?.id ?? ''}',
        sound: true,
        vibrate: settings.vibrate,
        repeatsDaily: true,
        kind: AppNotificationKind.memorization,
      ),
    );
  }
}
