import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../../../quran/presentation/cubit/quran_cubit.dart';
import '../../../quran/presentation/pages/quran_reader_page.dart';
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
                      'خطط الختمة',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              MishkatSecondaryAction(
                onPressed: () => showCreatePlanModal(context, active?.nextPage ?? 1),
                icon: const Icon(Icons.add_rounded),
                label: 'خطة جديدة',
              ),
            ],
          ),
          const SizedBox(height: MishkatSpacing.lg),
          if (active == null)
            ContentStatePanel(
              icon: Icons.route_outlined,
              title: 'ابدأ ختمتك',
              message: 'اختر مدة مناسبة، وسيقسّم مشكاة صفحات المصحف إلى ورد يومي واضح.',
              action: MishkatPrimaryButton(
                onPressed: () => showCreatePlanModal(context, 1),
                label: 'إنشاء خطة ختمة',
                icon: const Icon(Icons.add_rounded),
              ),
            )
          else
            _ActivePlanCard(plan: active),
          if (state.plans.isNotEmpty) ...[
            const SizedBox(height: MishkatSpacing.lg),
            const SectionHeading(title: 'جميع الخطط'),
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
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
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
    int suggestedPage,
  ) async {
    final name = TextEditingController(text: 'ختمتي');
    final page = TextEditingController(text: '$suggestedPage');
    var duration = 30;
    String? reminder = 'fajr';
    final create = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MishkatRadius.xl)),
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
                  'خطة ختمة جديدة',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: MishkatSpacing.sm),
                Wrap(
                  spacing: MishkatSpacing.sm,
                  runSpacing: MishkatSpacing.sm,
                  children: [
                    for (final value in const [7, 15, 30, 60, 90])
                      ChoiceChip(
                        label: Text('$value يومًا'),
                        selected: duration == value,
                        onSelected: (_) =>
                            setSheetState(() => duration = value),
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
                    'وردك المقترح: $daily صفحة يوميًا · من صفحة $safePage حتى 604',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
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
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
        const SizedBox(height: MishkatSpacing.lg),
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
                'من صفحة ${plan.nextPage} إلى ${plan.todayEnd}',
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
          onPressed: plan.status == KhatmaStatus.completed
              ? null
              : () => _openReader(context),
          icon: const Icon(Icons.menu_book_rounded),
          label: 'ابدأ ورد اليوم',
          isFullWidth: true,
        ),
        const SizedBox(height: MishkatSpacing.sm),
        MishkatSecondaryAction(
          onPressed: plan.status == KhatmaStatus.completed
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
    await context.read<QuranCubit>().openPage(plan.nextPage);
    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const QuranReaderPage()),
      );
    }
  }
}
