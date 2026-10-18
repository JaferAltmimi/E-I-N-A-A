import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/local_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../../../adhkar/data/models/adhkar_models.dart';
import '../../../adhkar/presentation/cubit/adhkar_cubit.dart';
import '../../../adhkar/presentation/cubit/adhkar_state.dart';
import '../../../adhkar/presentation/pages/adhkar_reader_page.dart';
import '../../../adhkar/presentation/widgets/dua_editor_sheet.dart';
import '../../../khatma/presentation/cubit/khatma_cubit.dart';
import '../../../khatma/presentation/cubit/khatma_state.dart';
import '../../../khatma/presentation/pages/khatma_page.dart';
import '../../../prayer_times/domain/models/prayer_models.dart';
import '../../../qibla/presentation/pages/qibla_page.dart';
import '../../../quran/presentation/cubit/quran_cubit.dart';
import '../../../quran/presentation/cubit/quran_memorization_cubit.dart';
import '../../../quran/presentation/cubit/quran_state.dart';
import '../../../quran/presentation/pages/quran_reader_page.dart';
import '../../../settings/data/models/app_settings.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../shell/presentation/cubit/shell_cubit.dart';
import '../../../tasbih/presentation/pages/tasbih_page.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) =>
          previous.schedule != current.schedule ||
          previous.now.day != current.now.day,
      builder: (context, state) {
        final settings = context.watch<SettingsCubit>().state.settings;
        final now = state.now;

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListView(
              key: const PageStorageKey('home-page-scroll'),
              padding: MishkatSpacing.page,
              children: [
                // 1. Home App Bar (Minimal, calm icon controls)
                _HomeAppBar(settings: settings),
                const SizedBox(height: MishkatSpacing.base),

                // 2. Editorial Greeting (No container, typography hierarchy)
                _GreetingSection(now: now),
                const SizedBox(height: MishkatSpacing.base),

                // 3. Smart Living Adhkar Moment (Tonal surface, not a button)
                _SmartAdhkarCta(now: now),
                const SizedBox(height: MishkatSpacing.md),

                // 4. Content Block: Date (Pure content, not a card button)
                _DateCard(now: now, hijriOffset: settings.hijriOffset),
                const SizedBox(height: MishkatSpacing.base),

                // 5. Next Prayer Hero Card (Strongest visual focal point)
                if (state.schedule == null)
                  _LocationPrompt(
                    onTap: context.read<SettingsCubit>().useCurrentLocation,
                  )
                else ...[
                  _NextPrayerHero(schedule: state.schedule!),
                  const SizedBox(height: MishkatSpacing.lg),

                  // 6. Unified Prayer Schedule (ONE timetable, not 6 buttons)
                  _PrayerScheduleSection(
                    schedule: state.schedule!,
                    settings: settings,
                  ),
                  const SizedBox(height: MishkatSpacing.base),

                  // 7. Qibla Shortcut Navigation Row
                  const _QiblaShortcut(),
                  const SizedBox(height: MishkatSpacing.lg),

                  // 8. Daily Adhkar (Tonal chips + text action)
                  const _DailyAdhkarSection(),
                  const SizedBox(height: MishkatSpacing.lg),

                  // 9. My Duas Section (Shortcut to add + latest 3 duas)
                  const _MyDuasSection(),
                  const SizedBox(height: MishkatSpacing.lg),

                  // 10. Daily Quran Moment (Clear primary vs secondary action)
                  const _DailyWirdSection(),
                  const SizedBox(height: MishkatSpacing.xxl),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Home App Bar
// ─────────────────────────────────────────────────────────────────────────────
class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // Brand Mark + Title
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 26),
            const SizedBox(width: MishkatSpacing.sm),
            Text(
              'مِشكاة',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
            ),
          ],
        ),
        const Spacer(),

        // Search: opens Quran search
        MishkatIconButton(
          tooltip: 'البحث في القرآن',
          icon: const Icon(Icons.search_rounded),
          onPressed: () {
            context.read<ShellCubit>().select(1);
          },
        ),
        const SizedBox(width: MishkatSpacing.xs),

        // Latest Bookmark shortcut
        BlocBuilder<QuranCubit, QuranState>(
          builder: (context, quranState) {
            final bookmarks = quranState.bookmarks;
            final hasBookmarks = bookmarks.isNotEmpty;
            final latestBookmark = hasBookmarks
                ? bookmarks.reduce(
                    (curr, next) =>
                        curr.createdAt.isAfter(next.createdAt) ? curr : next,
                  )
                : null;
            final surahName = latestBookmark != null && quranState.data != null
                ? quranState.data!.chapter(latestBookmark.point.surah).name
                : null;

            return MishkatIconButton(
              tooltip: latestBookmark != null
                  ? (surahName != null
                      ? 'آخر علامة: سورة $surahName (صفحة ${latestBookmark.page})'
                      : 'آخر علامة: صفحة ${latestBookmark.page}')
                  : 'آخر علامة مرجعية',
              color: context.mishkat.primary,
              icon: Icon(
                hasBookmarks
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
              ),
              onPressed: () async {
                if (latestBookmark != null) {
                  await context.read<QuranCubit>().openPage(
                        latestBookmark.page,
                        point: latestBookmark.point,
                      );
                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => QuranReaderPage(
                        initialGlobalAyah: latestBookmark.point.global,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('لا توجد علامات مرجعية محفوظة بعد'),
                      behavior: SnackBarBehavior.floating,
                      action: SnackBarAction(
                        label: 'فتح المصحف',
                        onPressed: () {
                          if (quranState.data != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => QuranReaderPage(
                                  initialGlobalAyah:
                                      quranState.lastRead?.global,
                                ),
                              ),
                            );
                          } else {
                            context.read<ShellCubit>().select(1);
                          }
                        },
                      ),
                    ),
                  );
                }
              },
            );
          },
        ),
        const SizedBox(width: MishkatSpacing.xs),

        // Theme toggle
        MishkatIconButton(
          tooltip: 'تبديل المظهر',
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
          onPressed: () {
            context.read<SettingsCubit>().setTheme(
                  isDark ? AppThemePreference.light : AppThemePreference.dark,
                );
          },
        ),
        const SizedBox(width: MishkatSpacing.xs),

        // Settings button
        MishkatIconButton(
          tooltip: 'الإعدادات',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Editorial Greeting (No Container — Whitespace as Hierarchy)
// ─────────────────────────────────────────────────────────────────────────────
class _GreetingSection extends StatelessWidget {
  const _GreetingSection({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final hour = now.hour;
    final String greeting;
    final String subtext;

    if (hour >= 5 && hour < 12) {
      greeting = 'صباح الخير';
      subtext = 'اجعل لسانك عامراً بذكر الله وطاعته';
    } else if (hour >= 12 && hour < 16) {
      greeting = 'نهارك طيب';
      subtext = 'طابت أوقاتك بالسكينة والبركة';
    } else if (hour >= 16 && hour < 22) {
      greeting = 'مساء الخير';
      subtext = 'تقبل الله طاعاتك وصالح أعمالك';
    } else {
      greeting = 'ليلة هادئة';
      subtext = 'اختم يومك بالاستغفار وذكر الله';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: context.mishkat.textPrimary,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          subtext,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.mishkat.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Smart Dynamic Adhkar CTA (A Living Daily Moment)
// ─────────────────────────────────────────────────────────────────────────────
class _SmartAdhkarCta extends StatelessWidget {
  const _SmartAdhkarCta({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final hour = now.hour;
    final String title;
    final String actionText;
    final IconData motifIcon;
    final int categoryId;

    if (hour >= 5 && hour < 12) {
      title = 'أذكار الصباح';
      actionText = 'ابدأ وردك الآن · حفظ وبركة ليومك';
      motifIcon = Icons.wb_sunny_outlined;
      categoryId = 1;
    } else if (hour >= 16 && hour < 22) {
      title = 'أذكار المساء';
      actionText = 'ابدأ وردك الآن · حصّن وقتك بالذكر';
      motifIcon = Icons.wb_twilight_rounded;
      categoryId = 1;
    } else if (hour >= 22 || hour < 5) {
      title = 'أذكار النوم';
      actionText = 'حصّن ليلتك بالذكر والسكينة';
      motifIcon = Icons.nights_stay_outlined;
      categoryId = 2;
    } else {
      title = 'أذكارك اليومية';
      actionText = 'أكمل وردك اليومي وأدعية اليوم';
      motifIcon = Icons.auto_awesome_rounded;
      categoryId = 1;
    }

    final colors = context.mishkat;

    return MishkatTonalSurface(
      color: colors.primarySoft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () {
        context.read<AdhkarCubit>().select(categoryId);
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AdhkarReaderPage()),
        );
      },
      child: Row(
        children: [
          // Decorative sparkle / moment motif
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              motifIcon,
              color: colors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: MishkatSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? colors.textPrimary
                            : colors.primaryDark,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  actionText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? colors.primaryStrong
                        : colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: colors.primary,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Date Information Block (Pure Content)
// ─────────────────────────────────────────────────────────────────────────────
class _DateCard extends StatelessWidget {
  const _DateCard({required this.now, required this.hijriOffset});
  final DateTime now;
  final int hijriOffset;

  @override
  Widget build(BuildContext context) {
    final hijriFull = AppFormatters.hijriDate(now, offset: hijriOffset);
    final hijriParts = hijriFull.split('،');
    final hijriDayMonthYear =
        hijriParts.length > 1 ? hijriParts[1].trim() : hijriFull;

    return MishkatInfoRow(
      primaryLabel: 'التقويم الهجري',
      primaryValue: hijriDayMonthYear,
      secondaryLabel: 'الميلادي',
      secondaryValue: AppFormatters.gregorianDate(now),
      primaryGold: true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Next Prayer Hero Card (Strongest Focal Point with Living Pattern)
// ─────────────────────────────────────────────────────────────────────────────
class _NextPrayerHero extends StatelessWidget {
  const _NextPrayerHero({required this.schedule});
  final PrayerSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final next = schedule.next;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark
        ? const [Color(0xFF0F3127), Color(0xFF071914)]
        : const [Color(0xFF0E473A), Color(0xFF06231D)];

    return ClipRRect(
      borderRadius: MishkatRadius.brLg,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: gradientColors,
          ),
          boxShadow: MishkatShadows.elevated(context),
        ),
        child: CustomPaint(
          painter: _IslamicPatternPainter(
            color: Colors.white.withValues(alpha: 0.05),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Row: Tag + Adhan Time
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: MishkatRadius.brPill,
                      ),
                      child: const Text(
                        'الصلاة القادمة',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE0EFEA),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'الأذان ${AppFormatters.time(next.at)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Center Prayer Name
                Text(
                  next.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 14),

                // Subtle Glowing Divider
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                const SizedBox(height: 14),

                // Countdown Focal Point Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'متبقي على الأذان',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: MishkatSpacing.sm),
                    // Isolated countdown timer (ticks without rebuilding HomePage)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: MishkatRadius.brMd,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                          width: 1,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: NextPrayerCountdown(
                          targetTime: next.at,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Faint, geometric Islamic star lines painted subtly in the hero card.
class _IslamicPatternPainter extends CustomPainter {
  const _IslamicPatternPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width * 0.88, size.height * 0.35);
    for (var r = 35.0; r <= 155.0; r += 30.0) {
      canvas.drawCircle(center, r, paint);
    }

    // 8-point geometric rays
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final start =
          center + Offset(math.cos(angle) * 20, math.sin(angle) * 20);
      final end =
          center + Offset(math.cos(angle) * 160, math.sin(angle) * 160);
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IslamicPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Unified Prayer Schedule Section (ONE Timetable)
// ─────────────────────────────────────────────────────────────────────────────
class _PrayerScheduleSection extends StatelessWidget {
  const _PrayerScheduleSection({
    required this.schedule,
    required this.settings,
  });

  final PrayerSchedule schedule;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final cityName = settings.city.isNotEmpty ? settings.city : 'موقعك الحالي';

    return MishkatPrayerSchedule(
      schedule: schedule,
      cityName: cityName,
      onLocationTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const SettingsPage(openPrayerSettings: true),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. Qibla Shortcut Navigation Row
// ─────────────────────────────────────────────────────────────────────────────
class _QiblaShortcut extends StatelessWidget {
  const _QiblaShortcut();

  @override
  Widget build(BuildContext context) {
    return MishkatShortcutTile(
      icon: Icons.explore_rounded,
      title: 'اتجاه القبلة',
      subtitle: 'اعرف اتجاه الكعبة والمسافة من موقعك',
      onTap: () {
        try {
          context.read<ShellCubit>().select(2);
        } catch (_) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const QiblaPage()),
          );
        }
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. Daily Adhkar Section (Tonal Chips + Text Action)
// ─────────────────────────────────────────────────────────────────────────────
class _DailyAdhkarSection extends StatefulWidget {
  const _DailyAdhkarSection();

  @override
  State<_DailyAdhkarSection> createState() => _DailyAdhkarSectionState();
}

class _DailyAdhkarSectionState extends State<_DailyAdhkarSection> {
  List<String> _selectedKeys = ['tasbih', 'prayer', 'after_prayer', 'ruqyah'];

  @override
  void initState() {
    super.initState();
    _loadCustomKeys();
  }

  void _loadCustomKeys() {
    final storage = LocalStorageService();
    final saved = storage.readList('home_daily_adhkar');
    if (saved.isNotEmpty) {
      _selectedKeys = saved.map((e) => e.toString()).toList();
    }
  }

  Future<void> _saveCustomKeys(List<String> keys) async {
    final storage = LocalStorageService();
    await storage.writeList('home_daily_adhkar', keys);
    setState(() {
      _selectedKeys = keys;
    });
  }

  @override
  Widget build(BuildContext context) {
    const allAvailable = <({
      String key,
      String title,
      int? categoryId,
      bool isTasbih
    })>[
      (key: 'tasbih', title: 'المسبحة', categoryId: null, isTasbih: true),
      (key: 'prayer', title: 'أذكار الصلاة', categoryId: 13, isTasbih: false),
      (
        key: 'after_prayer',
        title: 'بعد الصلاة',
        categoryId: 27,
        isTasbih: false
      ),
      (
        key: 'ruqyah',
        title: 'الرقية الشرعية',
        categoryId: 124,
        isTasbih: false
      ),
      (
        key: 'morning',
        title: 'الصباح والمساء',
        categoryId: 1,
        isTasbih: false
      ),
      (
        key: 'istighfar',
        title: 'الاستغفار والتوبة',
        categoryId: 129,
        isTasbih: false
      ),
      (key: 'sleep', title: 'أذكار النوم', categoryId: 2, isTasbih: false),
    ];

    final visibleItems = allAvailable
        .where((item) => _selectedKeys.contains(item.key))
        .toList();
    final colors = context.mishkat;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MishkatSectionHeader(
          title: 'أذكارك اليومية',
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          trailing: MishkatTextAction(
            label: 'تخصيص',
            icon: Icons.tune_rounded,
            onPressed: () => _showCustomizeSheet(allAvailable),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in visibleItems)
              MishkatPressable(
                onTap: () {
                  if (item.isTasbih) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TasbihPage(),
                      ),
                    );
                  } else if (item.categoryId != null) {
                    context.read<AdhkarCubit>().select(item.categoryId!);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AdhkarReaderPage(),
                      ),
                    );
                  }
                },
                child: Material(
                  color: colors.surfaceVariant.withValues(alpha: 0.8),
                  borderRadius: MishkatRadius.brPill,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.isTasbih
                              ? Icons.all_inclusive_rounded
                              : Icons.auto_awesome_rounded,
                          size: 15,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _showCustomizeSheet(
    List<({String key, String title, int? categoryId, bool isTasbih})>
        allItems,
  ) {
    final tempSelection = List<String>.from(_selectedKeys);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(MishkatRadius.xl)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.mishkat.border,
                        borderRadius:
                            BorderRadius.circular(MishkatRadius.pill),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'تخصيص الأذكار اليومية',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'اختر الأوراد التي تود ظهورها في شاشتك الرئيسية.',
                    style: TextStyle(color: context.mishkat.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  for (final item in allItems)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      value: tempSelection.contains(item.key),
                      activeColor: context.mishkat.primary,
                      onChanged: (checked) {
                        setSheetState(() {
                          if (checked == true) {
                            tempSelection.add(item.key);
                          } else {
                            tempSelection.remove(item.key);
                          }
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                  MishkatPrimaryAction(
                    onPressed: () {
                      _saveCustomKeys(tempSelection);
                      Navigator.pop(sheetContext);
                    },
                    label: 'حفظ التخصيص',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. My Duas Section (Shortcut to Add + Latest 3 Duas)
// ─────────────────────────────────────────────────────────────────────────────
class _MyDuasSection extends StatelessWidget {
  const _MyDuasSection();

  void _openAllDuas(BuildContext context) {
    context.read<AdhkarCubit>().select(0);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AdhkarReaderPage(),
      ),
    );
  }

  void _openAddDua(BuildContext context) {
    DuaEditorSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdhkarCubit, AdhkarState>(
      buildWhen: (previous, current) =>
          previous.customItems != current.customItems ||
          previous.progress[0] != current.progress[0],
      builder: (context, state) {
        final customItems = state.customItems;
        final colors = context.mishkat;

        if (customItems.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MishkatSectionHeader(
                title: 'أدعيتي',
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                trailing: MishkatTextAction(
                  label: 'إضافة دعاء',
                  icon: Icons.add_rounded,
                  onPressed: () => _openAddDua(context),
                ),
              ),
              MishkatTonalSurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit_note_rounded,
                        size: 24,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'لا توجد أدعية مضافة بعد',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'احفظ أدعيتك الخاصة والمأثورة للرجوع إليها وترديدها.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    MishkatSecondaryAction(
                      onPressed: () => _openAddDua(context),
                      icon: const Icon(Icons.add_rounded),
                      label: 'إضافة أول دعاء',
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final totalCount = customItems.length;
        final latestCount = math.min(3, totalCount);
        // Latest 3 duas in reverse chronological order (newest first)
        final latestEntries = <({int originalIndex, DhikrItem item})>[
          for (var i = totalCount - 1; i >= totalCount - latestCount; i--)
            (originalIndex: i, item: customItems[i]),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MishkatSectionHeader(
              title: 'أدعيتي',
              padding: const EdgeInsets.only(top: 8, bottom: 10),
              trailing: MishkatTextAction(
                label: 'إضافة دعاء',
                icon: Icons.add_rounded,
                onPressed: () => _openAddDua(context),
              ),
            ),
            for (final entry in latestEntries) ...[
              _HomeDuaCard(
                item: entry.item,
                originalIndex: entry.originalIndex,
                onTap: () => _openAllDuas(context),
              ),
              const SizedBox(height: MishkatSpacing.sm),
            ],
            if (totalCount > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Center(
                  child: MishkatTextAction(
                    label: 'عرض جميع أدعيتي ($totalCount)',
                    icon: Icons.chevron_left_rounded,
                    onPressed: () => _openAllDuas(context),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HomeDuaCard extends StatelessWidget {
  const _HomeDuaCard({
    required this.item,
    required this.originalIndex,
    required this.onTap,
  });

  final DhikrItem item;
  final int originalIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    final hasTitle = item.title.trim().isNotEmpty;
    final adhkarState = context.watch<AdhkarCubit>().state;
    final done = adhkarState.progress[0]?[originalIndex] ?? 0;
    final isCompleted = item.count > 0 && done >= item.count;

    return MishkatCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? colors.primary.withValues(alpha: 0.15)
                      : colors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.favorite_rounded,
                  size: 15,
                  color: isCompleted ? colors.primary : colors.gold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasTitle ? item.title.trim() : 'من أدعيتي',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: hasTitle
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                ),
              ),
              if (item.count > 1) ...[
                MishkatPressable(
                  onTap: isCompleted
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          context
                              .read<AdhkarCubit>()
                              .increment(0, originalIndex);
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? colors.primary.withValues(alpha: 0.15)
                          : colors.surfaceVariant,
                      borderRadius: MishkatRadius.brPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCompleted
                              ? Icons.check_rounded
                              : Icons.touch_app_outlined,
                          size: 12,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCompleted
                              ? 'مكتمل'
                              : (done > 0
                                  ? '$done / ${item.count}'
                                  : '${item.count}×'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              MishkatIconButton(
                tooltip: 'نسخ الدعاء',
                icon: const Icon(Icons.copy_rounded, size: 16),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: item.text));
                  if (context.mounted) {
                    context.showMessage('تم نسخ الدعاء.');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.text.trim(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  height: 1.7,
                  color: colors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 10. Daily Wird / Quran Moment (Clear Visual Hierarchy)
// ─────────────────────────────────────────────────────────────────────────────
class _DailyWirdSection extends StatelessWidget {
  const _DailyWirdSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MishkatSectionHeader(
          title: 'وردك اليومي',
          padding: EdgeInsets.only(top: 8, bottom: 10),
        ),
        BlocBuilder<KhatmaCubit, KhatmaState>(
          builder: (context, khatmaState) {
            final active = khatmaState.active;
            final quranState = context.watch<QuranCubit>().state;
            final currentPage = quranState.currentPage;
            final colors = context.mishkat;

            return MishkatTonalSurface(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Quran Last Read info
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: colors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 20,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: MishkatSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              active != null ? active.name : 'مصحفك المحفوظ',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'صفحة $currentPage من 604',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (active != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primarySoft,
                            borderRadius: MishkatRadius.brPill,
                          ),
                          child: Text(
                            '${(active.progress * 100).round()}%',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Progress bar if active Khatma
                  if (active != null) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: MishkatRadius.brPill,
                      child: LinearProgressIndicator(
                        value: active.progress,
                        minHeight: 6,
                        backgroundColor: colors.borderSubtle,
                        valueColor: AlwaysStoppedAnimation(colors.primary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ورد اليوم: ${active.dailyPages} صفحات',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          'متبقي ${active.remainingPages} صفحة',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    Text(
                      'لم تبدأ ختمة بعد — اجعل لك ورداً ثابتاً من القرآن يبارك في يومك.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Actions row: Primary Action + Secondary Action
                  Row(
                    children: [
                      // Strongest visual emphasis: Primary Action
                      Expanded(
                        flex: 5,
                        child: MishkatPrimaryAction(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => QuranReaderPage(
                                  initialGlobalAyah: context
                                      .read<QuranCubit>()
                                      .state
                                      .lastRead
                                      ?.global,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.auto_stories_rounded),
                          label: 'افتح مصحفي',
                        ),
                      ),
                      const SizedBox(width: MishkatSpacing.sm),
                      // Lighter treatment: Secondary Action
                      Expanded(
                        flex: 4,
                        child: MishkatSecondaryAction(
                          onPressed: () {
                            KhatmaPage.showCreatePlanModal(
                              context,
                              currentPage,
                            );
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: active != null ? 'خطة جديدة' : 'ابدأ ختمة',
                        ),
                      ),
                    ],
                  ),

                  // Q12: Daily Hifz Journey Audio shortcut if available
                  Builder(
                    builder: (context) {
                      final memCubit = context.watch<QuranMemorizationCubit?>();
                      if (memCubit == null) return const SizedBox.shrink();
                      final journey = memCubit.state.calculateDailyJourney();
                      if (journey.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: colors.primary.withValues(alpha: 0.35),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(MishkatRadius.md),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () {
                            final allAyahs = {
                              ...journey.dueMurajaahQueue,
                              ...journey.weakAyahsQueue,
                              ...journey.newHifzQueue,
                            }.toList();
                            context
                                .read<QuranCubit>()
                                .playDailyJourney(allAyahs);
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => QuranReaderPage(
                                  initialGlobalAyah: allAyahs.first,
                                ),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.volume_up_rounded,
                            size: 18,
                            color: colors.primary,
                          ),
                          label: Text(
                            'استمع لورد اليوم (${journey.totalAyahs} آية)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location Prompt Banner (if no location is configured)
// ─────────────────────────────────────────────────────────────────────────────
class _LocationPrompt extends StatelessWidget {
  const _LocationPrompt({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.mishkat.brandDeep,
        borderRadius: MishkatRadius.brLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ابدأ بمواقيت مدينتك',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'نحتاج موقعك لحساب أوقات الصلاة والقبلة محلياً على جهازك.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          MishkatPrimaryAction(
            onPressed: onTap,
            icon: const Icon(Icons.my_location_rounded),
            label: 'استخدام موقعي الحالي',
          ),
        ],
      ),
    );
  }
}
