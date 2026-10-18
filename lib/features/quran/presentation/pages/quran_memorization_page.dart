import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../../data/models/hifz_planning_models.dart';
import '../../data/models/memorization_analytics_models.dart';
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

/// Main Dashboard page for Quran Memorization, Retention, and Revision (Hifz & Muraja'ah).
class QuranMemorizationPage extends StatelessWidget {
  const QuranMemorizationPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const QuranMemorizationPage(),
    );
  }

  void _openAnalytics(BuildContext context, QuranData quranData) {
    Navigator.of(context).push(
      QuranMemorizationAnalyticsPage.route(quranData: quranData),
    );
  }

  void _openCreatePlan(BuildContext context, QuranData quranData) {
    Navigator.of(context).push(
      MemorizationPlanPage.route(quranData: quranData),
    );
  }

  void _openEditPlan(
    BuildContext context,
    QuranData quranData,
    MemorizationPlan plan,
  ) {
    Navigator.of(context).push(
      MemorizationPlanPage.route(quranData: quranData, existingPlan: plan),
    );
  }

  void _startPlanSession(
    BuildContext context,
    QuranData quranData,
    MemorizationPlan plan,
  ) {
    context.read<QuranMemorizationCubit>().startPlanSession(plan);
    Navigator.of(context).push(
      MemorizationSessionPage.route(quranData: quranData),
    );
  }

  void _startRevisionSession(
    BuildContext context,
    QuranData quranData, {
    AdaptiveMurajaahCategory category = AdaptiveMurajaahCategory.all,
  }) {
    context.read<QuranMemorizationCubit>().startAdaptiveRevisionSession(
          category: category,
          limit: 20,
        );
    Navigator.of(context).push(
      MemorizationSessionPage.route(quranData: quranData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    final theme = Theme.of(context);
    final quranData = context.watch<QuranCubit>().state.data;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'الحفظ والمراجعة',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (quranData != null) ...[
            IconButton(
              icon: const Icon(Icons.auto_graph_rounded),
              tooltip: 'تحليلات الحفظ والمراجعة',
              onPressed: () => _openAnalytics(context, quranData),
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'خطة حفظ جديدة',
              onPressed: () => _openCreatePlan(context, quranData),
            ),
          ],
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
                  return Center(
                    child: Padding(
                      padding: MishkatSpacing.page,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: colors.error,
                          ),
                          const SizedBox(height: MishkatSpacing.md),
                          Text(
                            state.error ?? 'حدث خطأ أثناء تحميل بيانات الحفظ.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: MishkatSpacing.lg),
                          MishkatPrimaryAction(
                            onPressed: () =>
                                context.read<QuranMemorizationCubit>().load(),
                            label: 'إعادة المحاولة',
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final planSuggestion =
                    state.calculatePlanAdaptationSuggestion();

                return ListView(
                  padding: MishkatSpacing.page,
                  children: [
                    // Subtitle header
                    Text(
                      'خِطط الحفظ والتثبيت الذكي',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'تابع وردك اليومي وثبّت محفوظاتك بأولويات المراجعة.',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: MishkatSpacing.lg),

                    // Overall Mastery Metrics
                    _buildOverallStats(context, state, quranData),
                    const SizedBox(height: MishkatSpacing.xl),

                    // 🕌 Q11: Daily Journey Section ("وردك اليومي المقترح")
                    _DailyJourneyCard(
                      state: state,
                      quranData: quranData,
                    ),
                    const SizedBox(height: MishkatSpacing.xl),

                    // 🕌 Q13 & Oral Recitation: Visual Recall & Feasibility Card
                    _buildVisualRecallCard(context, state, quranData),
                    const SizedBox(height: MishkatSpacing.xl),

                    // 🕌 Q11: Plan Adaptation Suggestion Banner (if available)
                    if (planSuggestion != null) ...[
                      _buildPlanAdaptationCard(context, planSuggestion),
                      const SizedBox(height: MishkatSpacing.xl),
                    ],

                    // Active Plan Section
                    _buildActivePlanSection(context, state, quranData),
                    const SizedBox(height: MishkatSpacing.xl),

                    // Smart Revision Queue Section
                    _buildRevisionSection(context, state, quranData),
                    const SizedBox(height: MishkatSpacing.xl),

                    // All / Archived Plans Section
                    if (state.plans.isNotEmpty) ...[
                      _buildPlansListSection(context, state, quranData),
                      const SizedBox(height: MishkatSpacing.xxl),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _buildOverallStats(
    BuildContext context,
    QuranMemorizationState state,
    QuranData quranData,
  ) {
    final colors = context.mishkat;
    final totalMemorized = state.totalMemorizedCount;
    final percentage = ((totalMemorized / 6236) * 100).toStringAsFixed(1);

    return MishkatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'إحصائيات الحفظ الكلية',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: colors.textPrimary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _openAnalytics(context, quranData),
                    borderRadius: BorderRadius.circular(MishkatRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primarySoft,
                        borderRadius: BorderRadius.circular(MishkatRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_graph_rounded, size: 12, color: colors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'التحليلات',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      borderRadius: BorderRadius.circular(MishkatRadius.pill),
                    ),
                    child: Text(
                      '$percentage% من القرآن',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: MishkatSpacing.md),
          Row(
            children: [
              // Memorized
              Expanded(
                child: _StatBox(
                  label: 'المحفوظ',
                  value: '$totalMemorized',
                  subtext: 'من 6,236 آية',
                  color: colors.primary,
                  icon: Icons.check_circle_rounded,
                ),
              ),
              const SizedBox(width: MishkatSpacing.sm),

              // Learning
              Expanded(
                child: _StatBox(
                  label: 'قيد الحفظ',
                  value: '${state.totalLearningCount}',
                  subtext: 'آيات جارية',
                  color: colors.textPrimary,
                  icon: Icons.pending_actions_rounded,
                ),
              ),
              const SizedBox(width: MishkatSpacing.sm),

              // Needs Revision
              Expanded(
                child: _StatBox(
                  label: 'تحتاج تثبيت',
                  value: '${state.totalNeedsRevisionCount}',
                  subtext: 'أولوية مراجعة',
                  color: colors.warning,
                  icon: Icons.replay_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisualRecallCard(
    BuildContext context,
    QuranMemorizationState state,
    QuranData quranData,
  ) {
    final colors = context.mishkat;
    final theme = Theme.of(context);
    final active = state.activePlan;

    return MishkatCard(
      padding: const EdgeInsets.all(MishkatSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(MishkatRadius.md),
                ),
                child: Icon(
                  Icons.visibility_off_rounded,
                  color: colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: MishkatSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التسميع والاستحضار البصري في المصحف',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'تسميع تفاعلي على صفحة المصحف بحجب الآيات وكشفها',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MishkatSpacing.base),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => QuranReaderPage(
                          startRangeSelection: true,
                          visualRecallPlanId: active?.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('تحديد نطاق في المصحف', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: MishkatSpacing.sm),
              Expanded(
                child: MishkatPrimaryAction(
                  onPressed: () {
                    final targetQueue = active != null
                        ? [
                            for (int i = active.startGlobalAyah;
                                i <= active.endGlobalAyah;
                                i++)
                              i
                          ]
                        : null;
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => QuranReaderPage(
                          visualRecallInitialQueue: targetQueue,
                          visualRecallPlanId: active?.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: 'بدء التسميع',
                ),
              ),
            ],
          ),
          const SizedBox(height: MishkatSpacing.xs),
          TextButton.icon(
            onPressed: () => OralRecitationInfoSheet.show(context),
            icon: const Icon(Icons.mic_none_rounded, size: 16),
            label: const Text(
              'عن ميزة التسميع الشفهي والاستماع الذكي',
              style: TextStyle(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePlanSection(
    BuildContext context,
    QuranMemorizationState state,
    QuranData quranData,
  ) {
    final colors = context.mishkat;
    final theme = Theme.of(context);
    final activePlan = state.activePlan;

    if (activePlan == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(MishkatRadius.lg),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.playlist_add_check_circle_outlined,
              size: 44,
              color: colors.primary,
            ),
            const SizedBox(height: MishkatSpacing.sm),
            const Text(
              'لا توجد خطة حفظ نشطة حالياً',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'أنشئ خطة جديدة لتحديد وردك اليومي ومتابعة إنجازك في الحفظ والتثبيت.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: MishkatSpacing.md),
            MishkatPrimaryAction(
              onPressed: () => _openCreatePlan(context, quranData),
              label: 'إنشاء خطة حفظ',
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      );
    }

    final progress = state.planProgress(activePlan);
    final percentStr = (progress.percentage * 100).toStringAsFixed(0);
    final pointStart = quranData.pointForGlobal(activePlan.startGlobalAyah);
    final pointEnd = quranData.pointForGlobal(activePlan.endGlobalAyah);
    final surahName = activePlan.surah != null
        ? quranData.chapter(activePlan.surah!).name
        : quranData.chapter(pointStart.surah).name;
    final forecast = state.calculateCompletionForecast(activePlan);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(MishkatRadius.lg),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Title and Menu
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(MishkatRadius.md),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: MishkatSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activePlan.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'سورة $surahName (الآيات ${pointStart.ayah} – ${pointEnd.ayah})',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (val) {
                  final cubit = context.read<QuranMemorizationCubit>();
                  if (val == 'pause') {
                    cubit.pausePlan(activePlan.id);
                  } else if (val == 'edit') {
                    _openEditPlan(context, quranData, activePlan);
                  } else if (val == 'delete') {
                    cubit.deletePlan(activePlan.id);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('تعديل الخطة'),
                  ),
                  const PopupMenuItem(
                    value: 'pause',
                    child: Text('إيقاف مؤقت'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'حذف الخطة',
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: MishkatSpacing.base),

          // Progress bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'التقدم في الخطة',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${progress.memorized} من ${progress.total} آية ($percentStr%)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(MishkatRadius.pill),
            child: LinearProgressIndicator(
              value: progress.percentage,
              minHeight: 8,
              backgroundColor: colors.border.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
          const SizedBox(height: MishkatSpacing.md),

          // 🕌 Q11: Dual Completion Forecast
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(MishkatRadius.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 14, color: colors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'الختم المتوقع وفق الورد: ${forecast.targetBasedDescription}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (forecast.hasSufficientData &&
                    forecast.paceBasedDescription != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.speed_rounded, size: 14, color: colors.gold),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'الختم المتوقع وفق وتيرتك: ${forecast.paceBasedDescription}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (forecast.paceComparisonMessage != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    forecast.paceComparisonMessage!,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: MishkatSpacing.base),

          // Target Info & Start Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الورد اليومي',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      '${activePlan.dailyTarget} آيات يوميًا',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MishkatSpacing.sm),
              MishkatPrimaryAction(
                onPressed: () =>
                    _startPlanSession(context, quranData, activePlan),
                label: 'متابعة الورد',
                icon: const Icon(Icons.play_arrow_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionSection(
    BuildContext context,
    QuranMemorizationState state,
    QuranData quranData,
  ) {
    final colors = context.mishkat;
    final theme = Theme.of(context);
    final revisionQueue = state.generateRevisionQueue(limit: 20);
    final dueToday = state.dueTodayAyahs();
    final overdue = state.overdueAyahs();
    final weak = state.weakAyahs();

    return MishkatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sync_rounded,
                  color: colors.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: MishkatSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المراجعة الذكية والتثبيت',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'تحديد الآيات الأكثر احتياجاً للتثبيت وفق خوارزمية ذكية',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MishkatSpacing.md),

          // Adaptive Muraja'ah Badges
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(MishkatRadius.sm),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${dueToday.length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'مستحقة اليوم',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: MishkatSpacing.xs),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(MishkatRadius.sm),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${overdue.length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: overdue.isNotEmpty ? colors.error : colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'متأخرة',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: MishkatSpacing.xs),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(MishkatRadius.sm),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${weak.length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.warning,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'تحتاج تثبيت',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MishkatSpacing.sm),

          // Quick Category Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _CategoryChip(
                  label: 'شاملة',
                  icon: Icons.all_inclusive_rounded,
                  onTap: () => _startRevisionSession(
                    context,
                    quranData,
                    category: AdaptiveMurajaahCategory.all,
                  ),
                ),
                const SizedBox(width: 6),
                _CategoryChip(
                  label: 'مستحقة اليوم',
                  count: dueToday.length,
                  icon: Icons.calendar_today_rounded,
                  onTap: () => _startRevisionSession(
                    context,
                    quranData,
                    category: AdaptiveMurajaahCategory.dueToday,
                  ),
                ),
                const SizedBox(width: 6),
                _CategoryChip(
                  label: 'متأخرة',
                  count: overdue.length,
                  icon: Icons.timer_off_outlined,
                  onTap: () => _startRevisionSession(
                    context,
                    quranData,
                    category: AdaptiveMurajaahCategory.overdue,
                  ),
                ),
                const SizedBox(width: 6),
                _CategoryChip(
                  label: 'تحتاج تثبيت',
                  count: weak.length,
                  icon: Icons.bolt_rounded,
                  onTap: () => _startRevisionSession(
                    context,
                    quranData,
                    category: AdaptiveMurajaahCategory.weak,
                  ),
                ),
                const SizedBox(width: 6),
                _CategoryChip(
                  label: 'صعبة مؤخراً',
                  icon: Icons.error_outline_rounded,
                  onTap: () => _startRevisionSession(
                    context,
                    quranData,
                    category: AdaptiveMurajaahCategory.recentlyDifficult,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MishkatSpacing.md),

          if (revisionQueue.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(MishkatRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: colors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لديك ${revisionQueue.length} آية جاهزة للمراجعة وتثبيت الحفظ.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MishkatSpacing.base),
            MishkatPrimaryAction(
              onPressed: () => _startRevisionSession(context, quranData),
              label: 'بدء جلسة المراجعة',
              icon: const Icon(Icons.replay_rounded),
              isFullWidth: true,
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: colors.primarySoft.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(MishkatRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.done_all_rounded,
                    size: 20,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'أحسنت! لا توجد آيات متأخرة في المراجعة حالياً.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlansListSection(
    BuildContext context,
    QuranMemorizationState state,
    QuranData quranData,
  ) {
    final colors = context.mishkat;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'جميع خطط الحفظ (${state.plans.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () => _openCreatePlan(context, quranData),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('خطة جديدة'),
            ),
          ],
        ),
        const SizedBox(height: MishkatSpacing.xs),
        ...state.plans.map((plan) {
          final progress = state.planProgress(plan);
          final percentStr = (progress.percentage * 100).toStringAsFixed(0);

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MishkatRadius.md),
              side: BorderSide(color: colors.border.withValues(alpha: 0.5)),
            ),
            child: ListTile(
              title: Text(
                plan.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    '${progress.memorized} من ${progress.total} آية ($percentStr%) · ورد ${plan.dailyTarget} آيات',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(MishkatRadius.pill),
                    child: LinearProgressIndicator(
                      value: progress.percentage,
                      minHeight: 4,
                      backgroundColor: colors.border.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        plan.isCompleted ? colors.gold : colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (val) {
                  final cubit = context.read<QuranMemorizationCubit>();
                  if (val == 'resume') {
                    cubit.resumePlan(plan.id);
                  } else if (val == 'pause') {
                    cubit.pausePlan(plan.id);
                  } else if (val == 'delete') {
                    cubit.deletePlan(plan.id);
                  }
                },
                itemBuilder: (ctx) => [
                  if (!plan.isActive && !plan.isCompleted)
                    const PopupMenuItem(
                      value: 'resume',
                      child: Text('تفعيل ومتابعة'),
                    )
                  else if (plan.isActive && !plan.isCompleted)
                    const PopupMenuItem(
                      value: 'pause',
                      child: Text('إيقاف مؤقت'),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'حذف',
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPlanAdaptationCard(
    BuildContext context,
    PlanAdaptationSuggestion suggestion,
  ) {
    final colors = context.mishkat;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(MishkatRadius.lg),
        border: Border.all(
          color: colors.gold.withValues(alpha: 0.4),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.gold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  color: colors.gold,
                  size: 20,
                ),
              ),
              const SizedBox(width: MishkatSpacing.sm),
              Expanded(
                child: Text(
                  'اقتراح لموازنة خطة الحفظ',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            suggestion.reason,
            style: TextStyle(
              fontSize: 12.5,
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: MishkatSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  context
                      .read<QuranMemorizationCubit>()
                      .applyPlanAdaptation(suggestion);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم تحديث ورد الخطة إلى ${suggestion.recommendedTarget} آيات يومياً.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text(
                  suggestion.actionText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.gold,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MishkatRadius.pill),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.subtext,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String subtext;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(MishkatRadius.md),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 9.5,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    this.count,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    return Material(
      color: colors.surfaceVariant.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(MishkatRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(MishkatRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: colors.primary),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(MishkatRadius.pill),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyJourneyCard extends StatefulWidget {
  const _DailyJourneyCard({
    required this.state,
    required this.quranData,
  });

  final QuranMemorizationState state;
  final QuranData quranData;

  @override
  State<_DailyJourneyCard> createState() => _DailyJourneyCardState();
}

class _DailyJourneyCardState extends State<_DailyJourneyCard> {
  int? _targetOverride;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    final theme = Theme.of(context);
    final journey = widget.state.calculateDailyJourney(
      manualTargetOverride: _targetOverride,
    );

    final isRecovery = journey.isRecoveryMode;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(MishkatRadius.lg),
        border: Border.all(
          color: isRecovery
              ? colors.gold.withValues(alpha: 0.6)
              : colors.primary.withValues(alpha: 0.3),
          width: isRecovery ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (isRecovery ? colors.gold : colors.primary)
                .withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isRecovery
                      ? colors.gold.withValues(alpha: 0.15)
                      : colors.primarySoft,
                  borderRadius: BorderRadius.circular(MishkatRadius.md),
                ),
                child: Icon(
                  isRecovery ? Icons.spa_rounded : Icons.explore_rounded,
                  color: isRecovery ? colors.gold : colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: MishkatSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'وردك اليومي المقترح',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildWorkloadBadge(context, journey.workloadLevel),
                      ],
                    ),
                    if (isRecovery) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.healing_rounded, size: 12, color: colors.gold),
                          const SizedBox(width: 4),
                          Text(
                            'وضع التعويض الهادئ',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: colors.gold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MishkatSpacing.sm),

          // Rationale message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isRecovery
                  ? colors.gold.withValues(alpha: 0.08)
                  : colors.primarySoft.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(MishkatRadius.sm),
            ),
            child: Text(
              journey.rationaleMessage,
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: MishkatSpacing.md),

          // 3 Segment Cards
          Row(
            children: [
              Expanded(
                child: _JourneySegmentBox(
                  segment: journey.segments.firstWhere(
                    (s) => s.type == HifzJourneySegmentType.dueMurajaah,
                  ),
                  color: colors.primary,
                  icon: Icons.calendar_today_rounded,
                  onTap: journey.hasDueMurajaah
                      ? () => _startSegment(
                            context,
                            journey.segments.firstWhere(
                              (s) =>
                                  s.type ==
                                  HifzJourneySegmentType.dueMurajaah,
                            ),
                          )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _JourneySegmentBox(
                  segment: journey.segments.firstWhere(
                    (s) => s.type == HifzJourneySegmentType.weakConsolidation,
                  ),
                  color: colors.warning,
                  icon: Icons.bolt_rounded,
                  onTap: journey.hasWeakAyahs
                      ? () => _startSegment(
                            context,
                            journey.segments.firstWhere(
                              (s) =>
                                  s.type ==
                                  HifzJourneySegmentType.weakConsolidation,
                            ),
                          )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _JourneySegmentBox(
                  segment: journey.segments.firstWhere(
                    (s) => s.type == HifzJourneySegmentType.newHifz,
                  ),
                  color: colors.gold,
                  icon: Icons.auto_stories_rounded,
                  onTap: journey.hasNewHifz
                      ? () => _startSegment(
                            context,
                            journey.segments.firstWhere(
                              (s) => s.type == HifzJourneySegmentType.newHifz,
                            ),
                          )
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: MishkatSpacing.md),

          // Target Adjustment Row (if user has active plan)
          if (journey.plan != null && !journey.plan!.isCompleted) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تعديل ورد الحفظ الجديد اليوم:',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline_rounded,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      color: colors.textSecondary,
                      onPressed: journey.targetToday > 1
                          ? () {
                              setState(() {
                                _targetOverride = journey.targetToday - 1;
                              });
                            }
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(MishkatRadius.pill),
                      ),
                      child: Text(
                        '${journey.targetToday} آيات',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      color: colors.primary,
                      onPressed: journey.targetToday < 30
                          ? () {
                              setState(() {
                                _targetOverride = journey.targetToday + 1;
                              });
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: MishkatSpacing.sm),
          ],

          // Start Unified Journey Button
          if (journey.isNotEmpty) ...[
            MishkatPrimaryAction(
              onPressed: () {
                final allAyahs = [
                  ...journey.dueMurajaahQueue,
                  ...journey.weakAyahsQueue,
                  ...journey.newHifzQueue,
                ];
                _showPracticeModeSheet(
                  context: context,
                  title: 'ورد اليوم المتكامل',
                  ayahCount: journey.totalAyahs,
                  onVisualRecall: () {
                    if (allAyahs.isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QuranReaderPage(
                          initialGlobalAyah: allAyahs.first,
                          visualRecallInitialQueue: allAyahs,
                        ),
                      ),
                    );
                  },
                  onTraditionalSession: () {
                    context
                        .read<QuranMemorizationCubit>()
                        .startDailyJourneySession(journey: journey);
                    Navigator.of(context).push(
                      MemorizationSessionPage.route(quranData: widget.quranData),
                    );
                  },
                );
              },
              label: 'ابدأ ورد اليوم المتكامل (${journey.totalAyahs} آية)',
              icon: const Icon(Icons.play_arrow_rounded),
              isFullWidth: true,
            ),
            const SizedBox(height: 8),
            MishkatSecondaryAction(
              onPressed: () {
                final allAyahs = {
                  ...journey.dueMurajaahQueue,
                  ...journey.weakAyahsQueue,
                  ...journey.newHifzQueue,
                }.toList();
                context.read<QuranCubit>().playDailyJourney(allAyahs);
              },
              label: 'استمع لورد اليوم (${journey.totalAyahs} آية)',
              icon: const Icon(Icons.volume_up_rounded),
              isFullWidth: true,
            ),
          ]
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: Text(
                'أكملت وردك بنجاح بحمد الله!',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _startSegment(BuildContext context, HifzJourneySegment segment) {
    final activePlanId =
        context.read<QuranMemorizationCubit>().state.activePlan?.id;
    _showPracticeModeSheet(
      context: context,
      title: segment.title,
      ayahCount: segment.count,
      onVisualRecall: () {
        if (segment.isEmpty) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuranReaderPage(
              initialGlobalAyah: segment.queue.first,
              visualRecallInitialQueue: segment.queue,
              visualRecallPlanId: segment.type == HifzJourneySegmentType.newHifz
                  ? activePlanId
                  : null,
            ),
          ),
        );
      },
      onTraditionalSession: () {
        context
            .read<QuranMemorizationCubit>()
            .startJourneySegmentSession(segment);
        Navigator.of(context).push(
          MemorizationSessionPage.route(quranData: widget.quranData),
        );
      },
    );
  }

  void _showPracticeModeSheet({
    required BuildContext context,
    required String title,
    required int ayahCount,
    required VoidCallback onVisualRecall,
    required VoidCallback onTraditionalSession,
  }) {
    final colors = context.mishkat;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MishkatRadius.lg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'اختر طريقة التسميع: $title',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'المحتوى: $ayahCount آية',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Material(
                color: isDark
                    ? const Color(0xFF1B2E24)
                    : const Color(0xFFE8F2EC),
                borderRadius: BorderRadius.circular(MishkatRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(MishkatRadius.md),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onVisualRecall();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: colors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'التسميع في المصحف (بصري)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'حجب الآيات في صفحات المصحف الحقيقي وكشفها للاختبار',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Material(
                color: isDark
                    ? theme.colorScheme.surfaceContainerHighest
                    : colors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(MishkatRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(MishkatRadius.md),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onTraditionalSession();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.textSecondary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.style_outlined,
                            color: colors.textPrimary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'التسميع بالبطاقات (تقليدي)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'عرض بطاقات الآيات والتقييم الذاتي عبر الشاشة الكاملة',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkloadBadge(BuildContext context, WorkloadLevel level) {
    final colors = context.mishkat;
    final (label, color) = switch (level) {
      WorkloadLevel.light => ('جهد خفيف', colors.primary),
      WorkloadLevel.moderate => ('جهد متوازن', colors.warning),
      WorkloadLevel.heavy => ('مراجعة مكثفة', colors.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(MishkatRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _JourneySegmentBox extends StatelessWidget {
  const _JourneySegmentBox({
    required this.segment,
    required this.color,
    required this.icon,
    this.onTap,
  });

  final HifzJourneySegment segment;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    final hasItems = segment.isNotEmpty;

    return Material(
      color: hasItems
          ? color.withValues(alpha: 0.08)
          : colors.surfaceVariant.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(MishkatRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MishkatRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: hasItems ? color : colors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                '${segment.count}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: hasItems ? color : colors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                segment.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: hasItems ? colors.textPrimary : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
