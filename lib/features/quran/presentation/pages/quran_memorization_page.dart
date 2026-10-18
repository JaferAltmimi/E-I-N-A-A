import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../data/models/hifz_planning_models.dart';
import '../../data/models/memorization_plan.dart';
import '../../data/models/murajaah_models.dart';
import '../../data/models/quran_models.dart';
import '../cubit/quran_cubit.dart';
import '../cubit/quran_memorization_cubit.dart';
import '../cubit/quran_memorization_state.dart';
import '../widgets/oral_recitation_info_sheet.dart';
import 'memorization_plan_page.dart';
import 'memorization_session_page.dart';
import 'quran_memorization_analytics_page.dart';
import 'quran_reader_page.dart';

/// Task-first Hifz home: today's work, practice, then progress.
class QuranMemorizationPage extends StatelessWidget {
  const QuranMemorizationPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const QuranMemorizationPage());

  @override
  Widget build(BuildContext context) {
    final quranData = context.watch<QuranCubit>().state.data;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الحفظ والمراجعة',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          if (quranData != null)
            IconButton(
              tooltip: 'تحليلات الحفظ والمراجعة',
              icon: const Icon(Icons.insights_outlined),
              onPressed: () => Navigator.of(context).push(
                QuranMemorizationAnalyticsPage.route(quranData: quranData),
              ),
            ),
        ],
      ),
      body: quranData == null
          ? const Center(child: CircularProgressIndicator())
          : BlocBuilder<QuranMemorizationCubit, QuranMemorizationState>(
              builder: (context, state) {
                if (state.status == QuranMemorizationStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == QuranMemorizationStatus.failure) {
                  return _FailureView(message: state.error);
                }
                final plan = state.activePlan;
                final journey = state.calculateDailyJourney();
                return ListView(
                  padding: MishkatSpacing.page,
                  children: [
                    _WelcomeLine(hasPlan: plan != null),
                    const SizedBox(height: MishkatSpacing.base),
                    if (plan == null)
                      _EmptyPlanCard(
                        onCreate: () => _openPlan(context, quranData),
                        onOralRecitation: () =>
                            OralRecitationInfoSheet.show(context),
                      )
                    else
                      _TodayCard(
                        state: state,
                        journey: journey,
                        plan: plan,
                        quranData: quranData,
                      ),
                    if (plan == null && journey.isRecoveryMode) ...[
                      const SizedBox(height: MishkatSpacing.sm),
                      _RecoveryNotice(backlog: journey.recoveryBacklogCount),
                    ],
                    const MishkatSectionHeader(title: 'اختر طريقة التدريب'),
                    _PracticeMethods(state: state, quranData: quranData),
                    MishkatSectionHeader(
                      title: 'خططي',
                      trailing: MishkatTextAction(
                        label: 'خطة جديدة',
                        icon: Icons.add_rounded,
                        onPressed: () => _openPlan(context, quranData),
                      ),
                    ),
                    _PlansPanel(state: state, quranData: quranData),
                    const MishkatSectionHeader(title: 'التقدم'),
                    _ProgressSummary(
                      state: state,
                      onAnalytics: () => Navigator.of(context).push(
                        QuranMemorizationAnalyticsPage.route(
                          quranData: quranData,
                        ),
                      ),
                    ),
                    const SizedBox(height: MishkatSpacing.lg),
                    _RevisionDetails(state: state, quranData: quranData),
                  ],
                );
              },
            ),
    );
  }

  static void _openPlan(
    BuildContext context,
    QuranData quranData, {
    MemorizationPlan? plan,
  }) {
    Navigator.of(context).push(
      MemorizationPlanPage.route(quranData: quranData, existingPlan: plan),
    );
  }
}

class _WelcomeLine extends StatelessWidget {
  const _WelcomeLine({required this.hasPlan});
  final bool hasPlan;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        hasPlan ? 'ورد واحد واضح كل يوم' : 'ابدأ بخطة تناسب وقتك',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.3),
      ),
      const SizedBox(height: 4),
      Text(
        hasPlan
            ? 'احفظ، لقّن، ثم اختبر نفسك دون تشتيت.'
            : 'هدف صغير ثابت، ثم تلقين وتسميع ومراجعة في مكان واحد.',
        style: TextStyle(color: context.mishkat.textSecondary, height: 1.45),
      ),
    ],
  );
}

class _EmptyPlanCard extends StatelessWidget {
  const _EmptyPlanCard({
    required this.onCreate,
    required this.onOralRecitation,
  });
  final VoidCallback onCreate;
  final VoidCallback onOralRecitation;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    return MishkatCard(
      color: colors.primarySoft.withValues(alpha: .5),
      borderColor: colors.primary.withValues(alpha: .2),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: MishkatRadius.brLg,
            ),
            child: const Icon(
              Icons.route_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'أنشئ مسارك الأول',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'اختر السورة ومقداراً يومياً مثل 5 آيات أو صفحة، وسنرتب لك الحفظ والمراجعة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, height: 1.55),
          ),
          const SizedBox(height: 18),
          MishkatPrimaryAction(
            label: 'إنشاء خطة حفظ',
            icon: const Icon(Icons.add_rounded),
            isFullWidth: true,
            onPressed: onCreate,
          ),
          const SizedBox(height: 8),
          MishkatTextAction(
            label: 'أو ابدأ تسميعاً حراً',
            icon: Icons.mic_none_rounded,
            onPressed: onOralRecitation,
          ),
        ],
      ),
    );
  }
}

class _RecoveryNotice extends StatelessWidget {
  const _RecoveryNotice({required this.backlog});
  final int backlog;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.accentGoldSoft,
        borderRadius: MishkatRadius.brMd,
      ),
      child: Row(
        children: [
          Icon(Icons.spa_outlined, color: colors.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'وضع التعويض الهادئ',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$backlog آية تنتظر مراجعة لطيفة',
                  style: TextStyle(color: colors.textSecondary, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.state,
    required this.journey,
    required this.plan,
    required this.quranData,
  });
  final QuranMemorizationState state;
  final DailyHifzJourney journey;
  final MemorizationPlan plan;
  final QuranData quranData;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    final progress = state.planProgress(plan);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryDark,
        borderRadius: MishkatRadius.brXl,
        boxShadow: MishkatShadows.elevated(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'وردك اليومي المقترح',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .7),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .1),
                  borderRadius: MishkatRadius.brPill,
                ),
                child: Text(
                  '${(progress.percentage * 100).round()}٪',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (journey.isRecoveryMode) ...[
            const SizedBox(height: 8),
            const Text(
              'وضع التعويض الهادئ',
              style: TextStyle(
                color: Color(0xFFE7C76B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              for (final segment in journey.segments)
                Expanded(child: _SegmentStat(segment: segment)),
            ],
          ),
          const SizedBox(height: 16),
          MishkatPrimaryAction(
            label: journey.isEmpty
                ? 'أتممت ورد اليوم'
                : 'ابدأ ورد اليوم المتكامل (${journey.totalAyahs} آية)',
            icon: Icon(
              journey.isEmpty ? Icons.done_rounded : Icons.play_arrow_rounded,
            ),
            isFullWidth: true,
            onPressed: journey.isEmpty
                ? null
                : () => _showPracticeModeSheet(
                    context,
                    title: 'ورد اليوم المتكامل',
                    queue: journey.allAyahs,
                    quranData: quranData,
                    planId: plan.id,
                    startTraditional: () => context
                        .read<QuranMemorizationCubit>()
                        .startDailyJourneySession(journey: journey),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SegmentStat extends StatelessWidget {
  const _SegmentStat({required this.segment});
  final HifzJourneySegment segment;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${segment.title}: ${segment.count}',
    child: Column(
      children: [
        Text(
          '${segment.count}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          segment.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .65),
            fontSize: 10,
          ),
        ),
      ],
    ),
  );
}

class _PracticeMethods extends StatelessWidget {
  const _PracticeMethods({required this.state, required this.quranData});
  final QuranMemorizationState state;
  final QuranData quranData;

  @override
  Widget build(BuildContext context) {
    final plan = state.activePlan;
    return Column(
      children: [
        _MethodTile(
          icon: Icons.headphones_rounded,
          title: 'التلقين والتكرار',
          subtitle: 'اختر القارئ وعدد التكرارات والفاصل، ثم ابدأ.',
          onTap: plan == null
              ? () => _showNeedPlan(context)
              : () => _showTutorSetup(context, plan, quranData),
        ),
        const SizedBox(height: 10),
        _MethodTile(
          icon: Icons.mic_rounded,
          title: 'التسميع الذكي',
          subtitle: 'ميزة التسميع الشفهي والاستماع الذكي',
          badge: 'استماع مباشر',
          onTap: () => OralRecitationInfoSheet.show(
            context,
            surahNumber: plan?.surah ?? 1,
            startGlobalAyah: plan?.startGlobalAyah,
            endGlobalAyah: plan?.endGlobalAyah,
            planId: plan?.id,
          ),
        ),
        const SizedBox(height: 10),
        _MethodTile(
          icon: Icons.menu_book_rounded,
          title: 'التسميع البصري',
          subtitle: 'التسميع والاستحضار البصري في المصحف',
          onTap: plan == null
              ? () => _showNeedPlan(context)
              : () {
                  final queue = state.todayTargetAyahs(plan);
                  if (queue.isEmpty) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => QuranReaderPage(
                        initialGlobalAyah: queue.first,
                        visualRecallInitialQueue: queue,
                        visualRecallPlanId: plan.id,
                      ),
                    ),
                  );
                },
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    return MishkatCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: MishkatRadius.brMd,
            ),
            child: Icon(icon, color: colors.primary, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primarySoft,
                          borderRadius: MishkatRadius.brPill,
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: colors.textMuted),
        ],
      ),
    );
  }
}

class _PlansPanel extends StatelessWidget {
  const _PlansPanel({required this.state, required this.quranData});
  final QuranMemorizationState state;
  final QuranData quranData;

  @override
  Widget build(BuildContext context) {
    if (state.plans.isEmpty) {
      return MishkatCard(
        padding: const EdgeInsets.all(14),
        child: Text(
          'لا توجد خطط بعد. أنشئ خطة واحدة واضحة وابدأ بخطوة صغيرة.',
          style: TextStyle(color: context.mishkat.textSecondary, height: 1.5),
        ),
      );
    }
    return Column(
      children: [
        for (var index = 0; index < state.plans.length; index++) ...[
          _PlanTile(
            plan: state.plans[index],
            state: state,
            quranData: quranData,
          ),
          if (index != state.plans.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.state,
    required this.quranData,
  });
  final MemorizationPlan plan;
  final QuranMemorizationState state;
  final QuranData quranData;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    final progress = state.planProgress(plan);
    return MishkatCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      borderColor: plan.isActive
          ? colors.primary.withValues(alpha: .35)
          : colors.border,
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress.percentage,
                  strokeWidth: 4,
                  backgroundColor: colors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(colors.primary),
                ),
                Text(
                  '${(progress.percentage * 100).round()}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        plan.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (plan.isActive) ...[
                      const SizedBox(width: 6),
                      Text(
                        'نشطة',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${plan.dailyTarget} آيات يومياً · ${progress.remaining} متبقية',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'خيارات الخطة',
            onSelected: (value) async {
              final cubit = context.read<QuranMemorizationCubit>();
              if (value == 'edit') {
                QuranMemorizationPage._openPlan(context, quranData, plan: plan);
              } else if (value == 'activate') {
                await cubit.resumePlan(plan.id);
              } else if (value == 'pause') {
                await cubit.pausePlan(plan.id);
              } else if (value == 'delete') {
                final approved = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('حذف الخطة؟'),
                    content: const Text(
                      'سيتم حذف الخطة فقط، مع إبقاء سجل الحفظ والمراجعة.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('إلغاء'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('حذف'),
                      ),
                    ],
                  ),
                );
                if (approved == true) await cubit.deletePlan(plan.id);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('تعديل الخطة')),
              PopupMenuItem(
                value: plan.isActive ? 'pause' : 'activate',
                child: Text(plan.isActive ? 'إيقاف مؤقت' : 'تفعيل الخطة'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('حذف الخطة')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({required this.state, required this.onAnalytics});
  final QuranMemorizationState state;
  final VoidCallback onAnalytics;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    return MishkatCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'إحصائيات الحفظ الكلية',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              MishkatTextAction(
                label: 'التفاصيل',
                icon: Icons.arrow_back_rounded,
                onPressed: onAnalytics,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Metric(
                label: 'المحفوظ',
                value: state.totalMemorizedCount,
                color: colors.success,
              ),
              _Metric(
                label: 'قيد الحفظ',
                value: state.totalLearningCount,
                color: colors.gold,
              ),
              _Metric(
                label: 'تحتاج مراجعة',
                value: state.totalNeedsRevisionCount,
                color: colors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: context.mishkat.textSecondary),
        ),
      ],
    ),
  );
}

class _RevisionDetails extends StatelessWidget {
  const _RevisionDetails({required this.state, required this.quranData});
  final QuranMemorizationState state;
  final QuranData quranData;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    final categories = AdaptiveMurajaahCategory.values
        .where((category) => category != AdaptiveMurajaahCategory.mistakeBased)
        .toList();
    return MishkatCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.refresh_rounded, color: colors.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'المراجعة الذكية والتثبيت',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ابدأ فقط بالنوع الذي تحتاجه الآن.',
            style: TextStyle(color: colors.textSecondary, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < categories.length; index++) ...[
                  ActionChip(
                    label: Text(categories[index].label),
                    onPressed: () =>
                        _startRevision(context, quranData, categories[index]),
                  ),
                  if (index != categories.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 46,
            color: context.mishkat.error,
          ),
          const SizedBox(height: 12),
          Text(
            message ?? 'تعذّر تحميل بيانات الحفظ.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          MishkatPrimaryAction(
            label: 'إعادة المحاولة',
            onPressed: () => context.read<QuranMemorizationCubit>().load(),
          ),
        ],
      ),
    ),
  );
}

void _showNeedPlan(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('أنشئ خطة أولاً لتحديد آيات جلسة اليوم.'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void _startRevision(
  BuildContext context,
  QuranData quranData,
  AdaptiveMurajaahCategory category,
) {
  final cubit = context.read<QuranMemorizationCubit>();
  cubit.startAdaptiveRevisionSession(category: category, limit: 20);
  if (cubit.state.activeSession == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لا توجد آيات في هذه الفئة حالياً.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  Navigator.of(context)
      .push(MemorizationSessionPage.route(quranData: quranData));
}

void _showPracticeModeSheet(
  BuildContext context, {
  required String title,
  required List<int> queue,
  required QuranData quranData,
  required String? planId,
  required VoidCallback startTraditional,
}) {
  final colors = context.mishkat;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MishkatRadius.xl),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textMuted.withValues(alpha: .35),
                  borderRadius: MishkatRadius.brPill,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${queue.length} آية · اختر أسلوب الجلسة',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _SheetChoice(
              icon: Icons.menu_book_rounded,
              title: 'التسميع في المصحف (بصري)',
              subtitle: 'حجب الآيات وكشفها داخل صفحة المصحف.',
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => QuranReaderPage(
                      initialGlobalAyah: queue.first,
                      visualRecallInitialQueue: queue,
                      visualRecallPlanId: planId,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _SheetChoice(
              icon: Icons.style_outlined,
              title: 'التسميع بالبطاقات (تقليدي)',
              subtitle: 'بطاقة هادئة لكل آية مع تقييم ذاتي.',
              onTap: () {
                Navigator.pop(sheetContext);
                startTraditional();
                Navigator.of(context)
                    .push(MemorizationSessionPage.route(quranData: quranData));
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _SheetChoice extends StatelessWidget {
  const _SheetChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    return Material(
      color: colors.surfaceVariant.withValues(alpha: .55),
      borderRadius: MishkatRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: MishkatRadius.brMd,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

void _showTutorSetup(
  BuildContext context,
  MemorizationPlan plan,
  QuranData quranData,
) {
  var reciterId = context.read<QuranCubit>().reciter;
  var repetitions = 3;
  var pauseSeconds = 3;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MishkatRadius.xl),
      ),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final colors = sheetContext.mishkat;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textMuted.withValues(alpha: .35),
                      borderRadius: MishkatRadius.brPill,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'إعداد جلسة التلقين',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'استمع للآية، رددها في الفاصل، ثم انتقل تلقائياً.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: reciterId,
                  decoration: const InputDecoration(
                    labelText: 'القارئ',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  items: AppConstants.reciters
                      .map(
                        (reciter) => DropdownMenuItem(
                          value: reciter.id,
                          child: Text(reciter.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setSheetState(() => reciterId = value);
                  },
                ),
                const SizedBox(height: 16),
                _StepperSetting(
                  label: 'تكرار كل آية',
                  value: repetitions,
                  suffix: 'مرات',
                  onMinus: repetitions > 1
                      ? () => setSheetState(() => repetitions--)
                      : null,
                  onPlus: repetitions < 10
                      ? () => setSheetState(() => repetitions++)
                      : null,
                ),
                const SizedBox(height: 10),
                _StepperSetting(
                  label: 'فاصل للترديد',
                  value: pauseSeconds,
                  suffix: 'ثوانٍ',
                  onMinus: pauseSeconds > 0
                      ? () => setSheetState(() => pauseSeconds--)
                      : null,
                  onPlus: pauseSeconds < 10
                      ? () => setSheetState(() => pauseSeconds++)
                      : null,
                ),
                const SizedBox(height: 20),
                MishkatPrimaryAction(
                  label: 'ابدأ التلقين',
                  icon: const Icon(Icons.play_arrow_rounded),
                  isFullWidth: true,
                  onPressed: () {
                    context.read<QuranCubit>().updateReciter(reciterId);
                    try {
                      context.read<SettingsCubit>().setReciter(reciterId);
                    } catch (_) {
                      // The session still works when embedded without Settings.
                    }
                    context.read<QuranMemorizationCubit>().startPlanSession(
                      plan,
                    );
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MemorizationSessionPage.route(
                        quranData: quranData,
                        initialRepeatCount: repetitions,
                        initialDelaySeconds: pauseSeconds,
                        startWithAudio: true,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _StepperSetting extends StatelessWidget {
  const _StepperSetting({
    required this.label,
    required this.value,
    required this.suffix,
    this.onMinus,
    this.onPlus,
  });
  final String label;
  final int value;
  final String suffix;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: .55),
        borderRadius: MishkatRadius.brMd,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '$value $suffix',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(onPressed: onPlus, icon: const Icon(Icons.add_rounded)),
        ],
      ),
    );
  }
}
