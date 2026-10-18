import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/offline_audio_download_controller.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../../../prayer_times/data/services/prayer_calculator.dart';
import '../../../quran/presentation/pages/offline_audio_downloads_page.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';
import '../../data/models/app_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.openPrayerSettings = false});
  final bool openPrayerSettings;

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<SettingsCubit, SettingsState>(
        listenWhen: (previous, current) =>
            previous.message != current.message && current.message != null,
        listener: (context, state) => context.showMessage(state.message!),
        builder: (context, state) {
          final settings = state.settings;
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_forward_rounded),
                tooltip: 'رجوع',
              ),
              title: const Text('الإعدادات'),
            ),
            body: ListView(
              padding: MishkatSpacing.page,
              children: [
                _SettingsIntro(settings: settings),
                const SectionHeading(title: 'الموقع'),
                _LocationSettings(state: state),
                const SectionHeading(title: 'التنبيهات'),
                _NotificationSettings(settings: settings),
                const SectionHeading(title: 'المظهر والقراءة'),
                _AppearanceSettings(settings: settings),
                const SizedBox(height: 16),
                _CalculationSettings(
                  settings: settings,
                  initiallyExpanded: openPrayerSettings,
                ),
                const SizedBox(height: 12),
                _AdvancedNotificationSettings(settings: settings),
                const SizedBox(height: 12),
                _DataSettings(),
                const SizedBox(height: 12),
                const MishkatCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'عن مشكاة',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'المصحف برواية حفص عن عاصم، والأذكار من حصن المسلم. المحتوى والمواقيت يعملان دون إنترنت، بينما تحتاج التلاوة إلى اتصال.',
                      ),
                      SizedBox(height: 8),
                      Text('الإصدار 1.2.0 (6)'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _SettingsIntro extends StatelessWidget {
  const _SettingsIntro({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 28,
        backgroundColor: context.mishkat.primarySoft,
        child: const Icon(Icons.tune, size: 28),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اضبط مشكاة كما يناسبك',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              settings.city.isEmpty ? 'ابدأ بتحديد موقعك' : settings.city,
              style: TextStyle(color: context.mishkat.textSecondary),
            ),
          ],
        ),
      ),
    ],
  );
}

class _LocationSettings extends StatelessWidget {
  const _LocationSettings({required this.state});
  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final settings = state.settings;
    return MishkatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                settings.hasLocation
                    ? Icons.location_on
                    : Icons.location_off_outlined,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.hasLocation
                          ? settings.city
                          : 'لم يتم تحديد الموقع',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      settings.locationAuto
                          ? 'يُحدّث من موقع الجهاز'
                          : 'اختيار يدوي',
                      style: TextStyle(color: context.mishkat.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: state.status == SettingsStatus.locating
                ? null
                : context.read<SettingsCubit>().useCurrentLocation,
            icon: state.status == SettingsStatus.locating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(
              state.status == SettingsStatus.locating
                  ? 'جارٍ تحديد الموقع…'
                  : 'استخدام موقعي الحالي',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue:
                LocationService.cities.any((city) => city.name == settings.city)
                ? settings.city
                : null,
            decoration: const InputDecoration(labelText: 'أو اختر مدينة'),
            items: [
              for (final city in LocationService.cities)
                DropdownMenuItem(value: city.name, child: Text(city.name)),
            ],
            onChanged: (value) {
              final city = LocationService.cities
                  .where((item) => item.name == value)
                  .firstOrNull;
              if (city != null) context.read<SettingsCubit>().selectCity(city);
            },
          ),
        ],
      ),
    );
  }
}

class _NotificationSettings extends StatelessWidget {
  const _NotificationSettings({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) => MishkatCard(
    child: Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text(
            'تنبيهات الصلاة',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text('تُجدول محليًا وتعمل والتطبيق مغلق'),
          value: settings.notificationsEnabled,
          onChanged: context.read<SettingsCubit>().setNotificationsEnabled,
        ),
        if (settings.notificationsEnabled) ...[
          const Divider(),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final prayer in PrayerCalculator.order.where(
                (item) => !item.noAdhan,
              ))
                FilterChip(
                  label: Text(prayer.name),
                  selected: settings.prayerNotifications[prayer.key] == true,
                  onSelected: (value) => context
                      .read<SettingsCubit>()
                      .setPrayerNotification(prayer.key, value),
                ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: context.read<SettingsCubit>().testNotification,
            icon: const Icon(Icons.notification_add_outlined),
            label: const Text('إرسال تنبيه تجريبي'),
          ),
        ],
      ],
    ),
  );
}

class _AppearanceSettings extends StatelessWidget {
  const _AppearanceSettings({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) => MishkatCard(
    child: Column(
      children: [
        DropdownButtonFormField<AppThemePreference>(
          initialValue: settings.theme,
          decoration: const InputDecoration(labelText: 'مظهر التطبيق'),
          items: const [
            DropdownMenuItem(
              value: AppThemePreference.system,
              child: Text('حسب الجهاز'),
            ),
            DropdownMenuItem(
              value: AppThemePreference.light,
              child: Text('فاتح'),
            ),
            DropdownMenuItem(
              value: AppThemePreference.dark,
              child: Text('داكن'),
            ),
          ],
          onChanged: (value) {
            if (value != null) context.read<SettingsCubit>().setTheme(value);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<double>(
          initialValue: settings.uiFontScale,
          decoration: const InputDecoration(labelText: 'حجم خط الواجهة'),
          items: const [
            DropdownMenuItem(value: 1, child: Text('قياسي')),
            DropdownMenuItem(value: 1.125, child: Text('كبير')),
            DropdownMenuItem(value: 1.25, child: Text('كبير جدًا')),
          ],
          onChanged: (value) {
            if (value != null) {
              context.read<SettingsCubit>().setUiFontScale(value);
            }
          },
        ),
        const SizedBox(height: 14),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            'حجم المصحف · ${(settings.quranFont / 32 * 100).round()}%',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Slider(
          min: 20,
          max: 60,
          value: settings.quranFont,
          onChanged: context.read<SettingsCubit>().setQuranFont,
        ),
        DropdownButtonFormField<String>(
          initialValue: settings.reciter,
          decoration: const InputDecoration(labelText: 'قارئ التلاوة'),
          items: [
            for (final reciter in AppConstants.reciters)
              DropdownMenuItem(value: reciter.id, child: Text(reciter.name)),
          ],
          onChanged: (value) {
            if (value != null) context.read<SettingsCubit>().setReciter(value);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('إبقاء الشاشة مضاءة أثناء القراءة'),
          value: settings.keepAwake,
          onChanged: context.read<SettingsCubit>().setKeepAwake,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('الاهتزاز عند التفاعل'),
          value: settings.vibrate,
          onChanged: context.read<SettingsCubit>().setVibration,
        ),
      ],
    ),
  );
}

class _CalculationSettings extends StatelessWidget {
  const _CalculationSettings({
    required this.settings,
    required this.initiallyExpanded,
  });
  final AppSettings settings;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      key: const PageStorageKey('settings-calculation'),
      initiallyExpanded: initiallyExpanded,
      title: const Text(
        'الحساب والتقويم',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: const Text('طريقة الحساب والعصر والتعديلات اليدوية'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: settings.method,
          decoration: const InputDecoration(labelText: 'طريقة حساب المواقيت'),
          items: [
            for (final method in PrayerCalculator.methods.values)
              DropdownMenuItem(value: method.key, child: Text(method.name)),
          ],
          onChanged: (value) {
            if (value != null) context.read<SettingsCubit>().setMethod(value);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: settings.asr,
          decoration: const InputDecoration(labelText: 'حساب صلاة العصر'),
          items: const [
            DropdownMenuItem(value: 'Standard', child: Text('الجمهور')),
            DropdownMenuItem(value: 'Hanafi', child: Text('الحنفي')),
          ],
          onChanged: (value) {
            if (value != null) context.read<SettingsCubit>().setAsr(value);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: settings.highLatitudes,
          decoration: const InputDecoration(labelText: 'خطوط العرض العالية'),
          items: const [
            DropdownMenuItem(value: 'NightMiddle', child: Text('منتصف الليل')),
            DropdownMenuItem(value: 'OneSeventh', child: Text('سُبع الليل')),
            DropdownMenuItem(value: 'AngleBased', child: Text('نسبة الزاوية')),
            DropdownMenuItem(value: 'None', child: Text('دون معالجة')),
          ],
          onChanged: (value) {
            if (value != null) {
              context.read<SettingsCubit>().setHighLatitudes(value);
            }
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Text('تصحيح التاريخ الهجري')),
            IconButton(
              onPressed: settings.hijriOffset > -2
                  ? () => context.read<SettingsCubit>().setHijriOffset(
                      settings.hijriOffset - 1,
                    )
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Text(
              '${settings.hijriOffset > 0 ? '+' : ''}${settings.hijriOffset} يوم',
            ),
            IconButton(
              onPressed: settings.hijriOffset < 2
                  ? () => context.read<SettingsCubit>().setHijriOffset(
                      settings.hijriOffset + 1,
                    )
                  : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const Divider(height: 24),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            'تعديل يدوي بالدقائق',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        for (final prayer in PrayerCalculator.order)
          Row(
            children: [
              Expanded(child: Text(prayer.name)),
              IconButton(
                onPressed: () => context.read<SettingsCubit>().setTune(
                  prayer.key,
                  (settings.tune[prayer.key] ?? 0) - 1,
                ),
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '${(settings.tune[prayer.key] ?? 0) >= 0 ? '+' : ''}${settings.tune[prayer.key] ?? 0}',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: () => context.read<SettingsCubit>().setTune(
                  prayer.key,
                  (settings.tune[prayer.key] ?? 0) + 1,
                ),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
      ],
    ),
  );
}

class _AdvancedNotificationSettings extends StatelessWidget {
  const _AdvancedNotificationSettings({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      key: const PageStorageKey('settings-notifications'),
      title: const Text(
        'الصوت والتذكير',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: const Text('التذكير المبكر وأذكار الصباح والمساء'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        DropdownButtonFormField<int>(
          initialValue: settings.preMinutes,
          decoration: const InputDecoration(labelText: 'تذكير قبل الأذان'),
          items: const [
            DropdownMenuItem(value: 0, child: Text('دون تذكير مبكر')),
            DropdownMenuItem(value: 5, child: Text('قبل 5 دقائق')),
            DropdownMenuItem(value: 10, child: Text('قبل 10 دقائق')),
            DropdownMenuItem(value: 15, child: Text('قبل 15 دقيقة')),
            DropdownMenuItem(value: 20, child: Text('قبل 20 دقيقة')),
            DropdownMenuItem(value: 30, child: Text('قبل 30 دقيقة')),
          ],
          onChanged: (value) {
            if (value != null) {
              context.read<SettingsCubit>().setPreMinutes(value);
            }
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('صوت الأذان'),
          value: settings.adhanSound,
          onChanged: context.read<SettingsCubit>().setAdhanSound,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: settings.adhanFile,
          decoration: const InputDecoration(labelText: 'اختيار صوت الأذان'),
          items: List.generate(
            6,
            (index) => DropdownMenuItem(
              value: 'adhan${index + 1}',
              child: Text('أذان ${index + 1}'),
            ),
          ),
          onChanged: settings.adhanSound
              ? (value) {
                  if (value != null) {
                    context.read<SettingsCubit>().setAdhanFile(value);
                  }
                }
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('تذكير أذكار الصباح والمساء'),
          value: settings.adhkarNotifications,
          onChanged: context.read<SettingsCubit>().setAdhkarNotifications,
        ),
      ],
    ),
  );
}

class _DataSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      key: const PageStorageKey('settings-data'),
      title: const Text(
        'التنزيل والبيانات',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: const Text('المصحف والأذكار مرفقان ويعملان دون إنترنت'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.offline_pin_outlined),
          title: Text('جاهز دون إنترنت'),
          subtitle: Text(
            '604 صفحات مصحف وبيانات القرآن والأذكار مضمنة في التطبيق',
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.download_for_offline_outlined),
          title: const Text('إدارة التلاوات المحفوظة'),
          subtitle: const Text('تنزيل سورة أو حذفها وتشغيلها بلا شبكة'),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const OfflineAudioDownloadsPage(),
            ),
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('مسح جميع البيانات؟'),
                content: const Text(
                  'سيُحذف موضع القراءة والعلامات والختمات وتقدّم الأذكار والإعدادات وكل التلاوات المحفوظة من هذا الجهاز.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('مسح البيانات'),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              final settingsCubit = context.read<SettingsCubit>();
              final downloads = context.read<OfflineAudioDownloadController>();
              await settingsCubit.clearAllData();
              await downloads.cache.clearCache();
              if (context.mounted) {
                context.showMessage(
                  'تم مسح البيانات المحلية والتلاوات المحفوظة.',
                );
              }
            }
          },
          icon: const Icon(Icons.delete_outline),
          label: const Text('مسح جميع البيانات'),
        ),
      ],
    ),
  );
}
