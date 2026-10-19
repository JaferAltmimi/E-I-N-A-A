import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/offline_audio_download_controller.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../../../quran/presentation/cubit/quran_cubit.dart';
import '../../../quran/presentation/pages/quran_reader_page.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../data/models/khatma_plan.dart';
import '../cubit/khatma_cubit.dart';
import '../cubit/khatma_state.dart';

class KhatmaPage extends StatelessWidget {
  const KhatmaPage({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<KhatmaCubit, KhatmaState>(
    builder: (context, state) {
      final active = state.active;
      return ListView(
        key: const PageStorageKey('khatma'),
        padding: MishkatSpacing.page,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رحلة مع كتاب الله',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: context.mishkat.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ختمة القرآن',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'ورد يومي واضح، وتقدّم محفوظ تلقائيًا.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.mishkat.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              MishkatSecondaryAction(
                onPressed: () =>
                    showCreatePlanModal(context, active?.nextPage ?? 1),
                icon: const Icon(Icons.add_rounded),
                label: 'خطة جديدة',
              ),
            ],
          ),
          const SizedBox(height: MishkatSpacing.lg),
          if (active == null)
            _KhatmaStart(
              onCreate: (days) =>
                  showCreatePlanModal(context, 1, initialDuration: days),
            )
          else
            _ActivePlanCard(plan: active),
          if (state.plans.isNotEmpty) ...[
            const SizedBox(height: MishkatSpacing.lg),
            const SectionHeading(title: 'خططك'),
            for (final plan in state.plans)
              Padding(
                padding: const EdgeInsets.only(bottom: MishkatSpacing.sm),
                child: MishkatCard(
                  padding: const EdgeInsets.all(MishkatSpacing.base),
                  color: plan.id == state.activeId
                      ? context.mishkat.primarySoft
                      : context.mishkat.surface,
                  borderColor: plan.id == state.activeId
                      ? context.mishkat.primary
                      : context.mishkat.border,
                  onTap: () => context.read<KhatmaCubit>().setActive(plan.id),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: plan.id == state.activeId
                              ? context.mishkat.primary
                              : context.mishkat.surfaceMuted,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${(plan.progress * 100).round()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: plan.id == state.activeId
                                ? Colors.white
                                : context.mishkat.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: MishkatSpacing.base),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _status(plan),
                              style: TextStyle(
                                fontSize: 13,
                                color: context.mishkat.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: context.mishkat.textMuted,
                          size: 20,
                        ),
                        onSelected: (value) {
                          if (value == 'delete') {
                            context.read<KhatmaCubit>().delete(plan.id);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('حذف الخطة'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      );
    },
  );

  static String _status(KhatmaPlan plan) => switch (plan.status) {
    KhatmaStatus.active =>
      '${plan.remainingPages} صفحة متبقية · ${plan.dailyPages} يوميًا',
    KhatmaStatus.paused => 'متوقفة مؤقتًا',
    KhatmaStatus.completed => 'ختمة مكتملة — تقبّل الله',
  };

  static Future<void> showCreatePlanModal(
    BuildContext context,
    int suggestedPage, {
    int initialDuration = 30,
  }) async {
    final name = TextEditingController(text: 'ختمتي');
    final page = TextEditingController(text: '$suggestedPage');
    var duration = initialDuration;
    String? reminder = 'fajr';
    final create = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MishkatRadius.xl),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final safePage = (int.tryParse(page.text) ?? 1).clamp(1, 604);
          final daily = ((604 - safePage + 1) / duration).ceil();
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              MishkatSpacing.lg,
              MishkatSpacing.md,
              MishkatSpacing.lg,
              MediaQuery.viewInsetsOf(context).bottom + MishkatSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.mishkat.border,
                      borderRadius: BorderRadius.circular(MishkatRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: MishkatSpacing.lg),
                Text(
                  'أنشئ خطة ختمتك',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'اختر نقطة البداية والمدة، وسنحسب وردك اليومي.',
                  style: TextStyle(color: context.mishkat.textSecondary),
                ),
                const SizedBox(height: MishkatSpacing.base),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم الختمة'),
                ),
                const SizedBox(height: MishkatSpacing.md),
                TextField(
                  controller: page,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'ابدأ من الصفحة',
                  ),
                ),
                const SizedBox(height: MishkatSpacing.base),
                Text(
                  'مدة الختمة',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MishkatSpacing.sm),
                Wrap(
                  spacing: MishkatSpacing.sm,
                  runSpacing: MishkatSpacing.sm,
                  children: [
                    for (final option in const [
                      (days: 7, label: 'أسبوع'),
                      (days: 15, label: '15 يومًا'),
                      (days: 30, label: 'شهر'),
                      (days: 60, label: 'شهران'),
                      (days: 90, label: '3 أشهر'),
                    ])
                      _DurationOption(
                        label: option.label,
                        selected: duration == option.days,
                        onTap: () =>
                            setSheetState(() => duration = option.days),
                      ),
                  ],
                ),
                const SizedBox(height: MishkatSpacing.base),
                DropdownButtonFormField<String?>(
                  initialValue: reminder,
                  decoration: const InputDecoration(labelText: 'تذكير الورد'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('دون تذكير')),
                    DropdownMenuItem(value: 'fajr', child: Text('بعد الفجر')),
                    DropdownMenuItem(value: 'dhuhr', child: Text('بعد الظهر')),
                    DropdownMenuItem(value: 'asr', child: Text('بعد العصر')),
                    DropdownMenuItem(
                      value: 'maghrib',
                      child: Text('بعد المغرب'),
                    ),
                    DropdownMenuItem(value: 'isha', child: Text('بعد العشاء')),
                  ],
                  onChanged: (value) => reminder = value,
                ),
                const SizedBox(height: MishkatSpacing.base),
                Container(
                  padding: const EdgeInsets.all(MishkatSpacing.base),
                  decoration: BoxDecoration(
                    color: context.mishkat.primarySoft,
                    borderRadius: BorderRadius.circular(MishkatRadius.md),
                    border: Border.all(color: context.mishkat.border),
                  ),
                  child: Text(
                    'وردك: $daily صفحة يوميًا\nموعد الإتمام المتوقع: ${AppFormatters.gregorianDate(DateTime.now().add(Duration(days: duration - 1)))}',
                    style: TextStyle(
                      height: 1.65,
                      fontWeight: FontWeight.w800,
                      color: context.mishkat.primary,
                    ),
                  ),
                ),
                const SizedBox(height: MishkatSpacing.lg),
                MishkatPrimaryButton(
                  onPressed: () => Navigator.pop(context, true),
                  label: 'ابدأ الختمة',
                  icon: const Icon(Icons.check_rounded),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (create == true && context.mounted) {
      if (reminder != null) {
        final settings = context.read<SettingsCubit>();
        if (!settings.state.settings.notificationsEnabled) {
          await settings.setNotificationsEnabled(true);
        }
      }
      if (!context.mounted) return;
      await context.read<KhatmaCubit>().create(
        name: name.text,
        durationDays: duration,
        startPage: int.tryParse(page.text) ?? 1,
        reminderPrayer: reminder,
      );
    }
    name.dispose();
    page.dispose();
  }
}

class _ActivePlanCard extends StatelessWidget {
  const _ActivePlanCard({required this.plan});
  final KhatmaPlan plan;

  @override
  Widget build(BuildContext context) => MishkatCard(
    padding: const EdgeInsets.all(MishkatSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'بدأت ${AppFormatters.gregorianDate(plan.startDate)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.mishkat.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MishkatSpacing.md,
                vertical: MishkatSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: context.mishkat.primarySoft,
                borderRadius: BorderRadius.circular(MishkatRadius.pill),
                border: Border.all(color: context.mishkat.border),
              ),
              child: Text(
                AppFormatters.percent(plan.progress),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: context.mishkat.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: MishkatSpacing.base),
        ClipRRect(
          borderRadius: BorderRadius.circular(MishkatRadius.pill),
          child: LinearProgressIndicator(
            value: plan.progress,
            minHeight: 8,
            backgroundColor: context.mishkat.border,
            color: context.mishkat.primary,
          ),
        ),
        const SizedBox(height: MishkatSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                'أتممت ${plan.completedPages} من ${plan.totalPages} صفحة',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.mishkat.primary,
                ),
              ),
            ),
            Text(
              'متبقي ${plan.remainingPages}',
              style: TextStyle(
                fontSize: 12,
                color: context.mishkat.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: MishkatSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _PlanStat(
                label: 'المتبقي',
                value: '${plan.remainingDays} يومًا',
                icon: Icons.calendar_today_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PlanStat(
                label: 'موعد الإتمام',
                value: AppFormatters.gregorianDate(plan.targetDate),
                icon: Icons.flag_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: MishkatSpacing.md),
        Container(
          padding: const EdgeInsets.all(MishkatSpacing.base),
          decoration: BoxDecoration(
            color: context.mishkat.primarySoft,
            borderRadius: BorderRadius.circular(MishkatRadius.md),
            border: Border.all(color: context.mishkat.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'وردك التالي',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.mishkat.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'من صفحة ${plan.resumePage} إلى ${plan.todayEnd}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${plan.dailyPages} صفحة · ${plan.remainingPages} صفحة متبقية',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.mishkat.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MishkatSpacing.base),
        MishkatPrimaryAction(
          onPressed: plan.status != KhatmaStatus.active
              ? null
              : () => _openReader(context),
          icon: const Icon(Icons.menu_book_rounded),
          label: plan.completedPages == 0 ? 'ابدأ ورد اليوم' : 'تابع ورد اليوم',
          isFullWidth: true,
        ),
        const SizedBox(height: MishkatSpacing.sm),
        _KhatmaOfflineAction(plan: plan),
        const SizedBox(height: MishkatSpacing.sm),
        MishkatSecondaryAction(
          onPressed: plan.status != KhatmaStatus.active
              ? null
              : context.read<KhatmaCubit>().completeToday,
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: 'تسجيل القراءة حتى صفحة ${plan.todayEnd}',
          isFullWidth: true,
        ),
        const SizedBox(height: MishkatSpacing.xs),
        Center(
          child: MishkatTextAction(
            onPressed: plan.status == KhatmaStatus.completed
                ? null
                : context.read<KhatmaCubit>().togglePause,
            icon: plan.status == KhatmaStatus.paused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            label: plan.status == KhatmaStatus.paused
                ? 'استئناف الخطة'
                : 'إيقاف الخطة مؤقتًا',
          ),
        ),
      ],
    ),
  );

  Future<void> _openReader(BuildContext context) async {
    final startPage = plan.resumePage
        .clamp(plan.nextPage, plan.todayEnd)
        .toInt();
    await context.read<KhatmaCubit>().recordReadingPosition(
      planId: plan.id,
      currentPage: startPage,
    );
    if (!context.mounted) return;
    await context.read<QuranCubit>().openPage(startPage);
    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => QuranReaderPage(
            khatmaPlanId: plan.id,
            khatmaPlanName: plan.name,
            khatmaStartPage: startPage,
            khatmaTargetPage: plan.todayEnd,
          ),
        ),
      );
    }
  }
}

class _KhatmaOfflineAction extends StatelessWidget {
  const _KhatmaOfflineAction({required this.plan});
  final KhatmaPlan plan;

  @override
  Widget build(BuildContext context) {
    OfflineAudioDownloadController? downloads;
    try {
      downloads = context.read<OfflineAudioDownloadController>();
    } catch (_) {}
    if (downloads == null) return const SizedBox.shrink();
    final controller = downloads;
    final quran = context.read<QuranCubit>();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final isThisTask = state.label == 'ورد ${plan.name} اليوم';
        final running = state.isRunning;
        return MishkatSecondaryAction(
          onPressed: plan.status != KhatmaStatus.active || running
              ? (isThisTask && running ? controller.cancel : null)
              : () async {
                  final data = quran.state.data;
                  if (data == null) return;
                  final reciter = AppConstants.findReciter(quran.reciter);
                  await controller.downloadPages(
                    reciter: reciter,
                    data: data,
                    startPage: plan.resumePage
                        .clamp(plan.nextPage, plan.todayEnd)
                        .toInt(),
                    endPage: plan.todayEnd,
                    label: 'ورد ${plan.name} اليوم',
                  );
                  if (context.mounted) {
                    final result = controller.state;
                    context.showMessage(
                      result.status == OfflineDownloadStatus.completed
                          ? 'تم حفظ ورد اليوم بالصوت وسيعمل دون إنترنت.'
                          : result.error ?? 'توقف التنزيل، حاول مرة أخرى.',
                    );
                  }
                },
          icon: Icon(
            isThisTask && running
                ? Icons.stop_circle_outlined
                : Icons.download_for_offline_outlined,
          ),
          label: isThisTask && running
              ? 'إيقاف التنزيل ${(state.progress * 100).round()}%'
              : 'حفظ صوت ورد اليوم دون إنترنت',
          isFullWidth: true,
        );
      },
    );
  }
}

class _KhatmaStart extends StatelessWidget {
  const _KhatmaStart({required this.onCreate});
  final ValueChanged<int> onCreate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: context.mishkat.primarySoft,
          borderRadius: MishkatRadius.brLg,
          border: Border.all(
            color: context.mishkat.primary.withValues(alpha: 0.16),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.mishkat.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.route_rounded,
                size: 30,
                color: context.mishkat.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'ابدأ رحلة ختمة جديدة',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              'نقسّم المصحف إلى ورد يومي يناسب وقتك، ونحفظ تقدمك حتى تتم الختمة بإذن الله.',
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.55,
                color: context.mishkat.textSecondary,
              ),
            ),
          ],
        ),
      ),
      const SectionHeading(
        title: 'اختر إيقاعك',
        padding: EdgeInsets.only(top: 22, bottom: 10),
      ),
      Row(
        children: [
          Expanded(
            child: _PlanPreset(
              days: 30,
              title: 'شهر',
              detail: '21 صفحة يوميًا',
              onTap: onCreate,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PlanPreset(
              days: 60,
              title: 'شهران',
              detail: '11 صفحة يوميًا',
              onTap: onCreate,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PlanPreset(
              days: 90,
              title: '3 أشهر',
              detail: '7 صفحات يوميًا',
              onTap: onCreate,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      MishkatPrimaryButton(
        onPressed: () => onCreate(30),
        label: 'إنشاء خطة مخصصة',
        icon: const Icon(Icons.tune_rounded),
        isFullWidth: true,
      ),
    ],
  );
}

class _PlanPreset extends StatelessWidget {
  const _PlanPreset({
    required this.days,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  final int days;
  final String title;
  final String detail;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => MishkatCard(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    onTap: () => onTap(days),
    child: Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          detail,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.3,
            color: context.mishkat.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _DurationOption extends StatelessWidget {
  const _DurationOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? context.mishkat.brandDeep : context.mishkat.surface,
    shape: StadiumBorder(
      side: BorderSide(
        color: selected ? context.mishkat.primary : context.mishkat.border,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : context.mishkat.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

class _PlanStat extends StatelessWidget {
  const _PlanStat({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: context.mishkat.surfaceMuted,
      borderRadius: MishkatRadius.brMd,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: context.mishkat.primary),
        const SizedBox(height: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: context.mishkat.textSecondary,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}
