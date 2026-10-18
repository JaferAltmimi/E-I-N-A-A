import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../../data/models/memorization_session.dart';
import '../../data/models/memorization_status.dart';
import '../../data/models/murajaah_models.dart';
import '../../data/models/quran_models.dart';
import '../../data/repositories/mushaf_layout_repository.dart';
import '../../domain/models/audio_repeat_config.dart';
import '../cubit/quran_cubit.dart';
import '../cubit/quran_memorization_cubit.dart';
import '../cubit/quran_memorization_state.dart';
import '../cubit/quran_state.dart';
import '../widgets/tafsir_knowledge_sheet.dart';
import 'quran_reader_page.dart';

/// Distraction-free interactive practice and recall drill page for Quran memorization.
class MemorizationSessionPage extends StatefulWidget {
  const MemorizationSessionPage({
    super.key,
    required this.quranData,
    this.initialRepeatCount = 3,
    this.initialDelaySeconds = 3,
    this.startWithAudio = false,
  });

  final QuranData quranData;
  final int initialRepeatCount;
  final int initialDelaySeconds;
  final bool startWithAudio;

  static Route<void> route({
    required QuranData quranData,
    int initialRepeatCount = 3,
    int initialDelaySeconds = 3,
    bool startWithAudio = false,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => MemorizationSessionPage(
        quranData: quranData,
        initialRepeatCount: initialRepeatCount,
        initialDelaySeconds: initialDelaySeconds,
        startWithAudio: startWithAudio,
      ),
    );
  }

  @override
  State<MemorizationSessionPage> createState() =>
      _MemorizationSessionPageState();
}

class _MemorizationSessionPageState extends State<MemorizationSessionPage> {
  late int _sessionRepeatCount;
  late int _sessionDelaySeconds;

  @override
  void initState() {
    super.initState();
    _sessionRepeatCount = widget.initialRepeatCount.clamp(1, 10);
    _sessionDelaySeconds = widget.initialDelaySeconds.clamp(0, 10);
    if (widget.startWithAudio) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final session = context
            .read<QuranMemorizationCubit>()
            .state
            .activeSession;
        if (session == null || session.queue.isEmpty) return;
        context.read<QuranCubit>().startRepeatPlayback(
          AudioRepeatConfig(
            mode: AudioRepeatMode.perAyahRange,
            startGlobalAyah: session.queue.first,
            endGlobalAyah: session.queue.last,
            ayahRepeatCount: _sessionRepeatCount,
            delaySeconds: _sessionDelaySeconds,
          ),
          initialGlobalAyah: session.queue.first,
          customQueue: session.queue,
          autoScroll: false,
        );
      });
    }
  }

  Future<void> _confirmExit() async {
    final cubit = context.read<QuranMemorizationCubit>();
    final session = cubit.state.activeSession;

    if (session == null || session.isFinished) {
      cubit.endSession();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنهاء جلسة الحفظ'),
        content: const Text(
          'هل تريد إنهاء الجلسة الآن؟ يتم حفظ تقدمك والآيات التي راجعتها تلقائيًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('متابعة الجلسة'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: ctx.mishkat.error),
            child: const Text('إنهاء وحفظ'),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      cubit.endSession();
      Navigator.of(context).pop();
    }
  }

  Future<void> _openTafsir(int globalAyah) async {
    final layoutRepo = MushafLayoutRepository.instance;
    if (!layoutRepo.isLoaded) {
      await layoutRepo.load();
    }
    final bounds = layoutRepo.getAyah(globalAyah);
    if (bounds != null && mounted) {
      await TafsirKnowledgeSheet.show(
        context: context,
        ayah: bounds,
        quranData: widget.quranData,
      );
    }
  }

  Future<void> _openInMushaf(int globalAyah) async {
    final page = widget.quranData.pageForGlobal(globalAyah);
    final point = widget.quranData.pointForGlobal(globalAyah);
    await context.read<QuranCubit>().openPage(page, point: point);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuranReaderPage(initialGlobalAyah: globalAyah),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    final theme = Theme.of(context);

    return BlocBuilder<QuranMemorizationCubit, QuranMemorizationState>(
      builder: (context, memState) {
        final session = memState.activeSession;

        if (session == null || session.queue.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('جلسة الحفظ والمراجعة'),
              centerTitle: true,
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 64,
                    color: colors.primary,
                  ),
                  const SizedBox(height: MishkatSpacing.md),
                  const Text(
                    'لا توجد جلسة نشطة حالياً',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: MishkatSpacing.sm),
                  Text(
                    'اختر خطة أو ابدأ مراجعة من لوحة الحفظ.',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  const SizedBox(height: MishkatSpacing.xl),
                  MishkatPrimaryAction(
                    onPressed: () => Navigator.of(context).pop(),
                    label: 'العودة للوحة الحفظ',
                  ),
                ],
              ),
            ),
          );
        }

        if (session.isFinished) {
          return _buildFinishedView(context, memState, session);
        }

        final globalAyah = session.currentGlobalAyah;
        if (globalAyah == null) {
          return _buildFinishedView(context, memState, session);
        }
        final point = widget.quranData.pointForGlobal(globalAyah);
        final chapter = widget.quranData.chapter(point.surah);
        final ayahIndex = (point.ayah - 1).clamp(0, chapter.ayahs.length - 1);
        final ayahText = chapter.ayahs.isNotEmpty
            ? chapter.ayahs[ayahIndex]
            : '';
        final pageNumber = widget.quranData.pageForGlobal(globalAyah);
        final item = memState.getItem(globalAyah);

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'إنهاء الجلسة',
              onPressed: _confirmExit,
            ),
            title: Column(
              children: [
                Text(
                  session.sessionType == MemorizationSessionType.revision
                      ? 'جلسة مراجعة وتثبيت'
                      : 'جلسة حفظ الورد',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'الآية ${session.currentIndex + 1} من ${session.queue.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: LinearProgressIndicator(
                value: session.progress,
                backgroundColor: colors.border.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: MishkatSpacing.page,
              children: [
                // Context Card: Surah, Ayah, Page, and Status Badge
                MishkatCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: colors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: MishkatSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'سورة ${chapter.name}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'الآية ${point.ayah} · صفحة $pageNumber · الجزء ${((pageNumber - 1) ~/ 20) + 1}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StatusChip(status: item.status),
                    ],
                  ),
                ),
                const SizedBox(height: MishkatSpacing.lg),

                // Quran Text Recall Card
                _buildRecallCard(
                  context: context,
                  session: session,
                  ayahText: ayahText,
                  point: point,
                ),
                const SizedBox(height: MishkatSpacing.base),

                // Companion Action Tools (Listen, Tafsir, Mushaf, Bookmark)
                _buildCompanionTools(context: context, globalAyah: globalAyah),
                const SizedBox(height: MishkatSpacing.xl),

                // Self-Assessment Heading
                Text(
                  'تقييم الحفظ لهذه الآية',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: MishkatSpacing.sm),

                // 4-Level Self-Assessment Outcome Evaluation
                Column(
                  children: [
                    // Upper Row: Success Outcomes (Easy & Good)
                    Row(
                      children: [
                        // Easy Button
                        Expanded(
                          child: Material(
                            color: colors.primarySoft,
                            borderRadius: BorderRadius.circular(
                              MishkatRadius.md,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                MishkatRadius.md,
                              ),
                              onTap: () {
                                context
                                    .read<QuranMemorizationCubit>()
                                    .recordReviewOutcome(
                                      globalAyah: globalAyah,
                                      outcome: ReviewOutcome.easy,
                                      sessionId: session.id,
                                    );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.sentiment_very_satisfied_rounded,
                                      color: colors.primary,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'سهل',
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: MishkatSpacing.sm),

                        // Good / Knows Button
                        Expanded(
                          child: Material(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(
                              MishkatRadius.md,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                MishkatRadius.md,
                              ),
                              onTap: () {
                                context
                                    .read<QuranMemorizationCubit>()
                                    .recordReviewOutcome(
                                      globalAyah: globalAyah,
                                      outcome: ReviewOutcome.good,
                                      sessionId: session.id,
                                    );
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'أعرفها ومحفوظة',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MishkatSpacing.sm),

                    // Lower Row: Review Needed Outcomes (Difficult & Failed)
                    Row(
                      children: [
                        // Difficult / Needs Revision Button
                        Expanded(
                          child: Material(
                            color: colors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              MishkatRadius.md,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                MishkatRadius.md,
                              ),
                              onTap: () {
                                context
                                    .read<QuranMemorizationCubit>()
                                    .recordReviewOutcome(
                                      globalAyah: globalAyah,
                                      outcome: ReviewOutcome.difficult,
                                      sessionId: session.id,
                                    );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.replay_rounded,
                                      color: colors.warning,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'أحتاج مراجعة',
                                      style: TextStyle(
                                        color: colors.warning,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: MishkatSpacing.sm),

                        // Failed Button
                        Expanded(
                          child: Material(
                            color: colors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              MishkatRadius.md,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                MishkatRadius.md,
                              ),
                              onTap: () {
                                context
                                    .read<QuranMemorizationCubit>()
                                    .recordReviewOutcome(
                                      globalAyah: globalAyah,
                                      outcome: ReviewOutcome.failed,
                                      sessionId: session.id,
                                    );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.close_rounded,
                                      color: colors.error,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'لم أتذكر',
                                      style: TextStyle(
                                        color: colors.error,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: MishkatSpacing.base),

                // Navigation Row: Previous & Skip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (session.currentIndex > 0)
                      TextButton.icon(
                        onPressed: () {
                          context
                              .read<QuranMemorizationCubit>()
                              .previousSessionAyah();
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text('الآية السابقة'),
                      )
                    else
                      const SizedBox.shrink(),
                    if (session.currentIndex < session.queue.length - 1)
                      TextButton.icon(
                        onPressed: () {
                          context
                              .read<QuranMemorizationCubit>()
                              .advanceSession();
                        },
                        icon: const Icon(Icons.skip_next_rounded, size: 18),
                        label: const Text('تخطي للآية التالية'),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecallCard({
    required BuildContext context,
    required MemorizationSession session,
    required String ayahText,
    required QuranPoint point,
  }) {
    final colors = context.mishkat;
    final cubit = context.read<QuranMemorizationCubit>();

    if (session.isTextHidden) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: colors.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(MishkatRadius.xl),
          border: Border.all(
            color: colors.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: 48,
              color: colors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: MishkatSpacing.md),
            const Text(
              'استحضر الآية الكريمة غيباً',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'اقرأ الآية من حفظك، ثم اضغط لإظهار النص والتأكد من صحتها.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: MishkatSpacing.xl),
            MishkatPrimaryAction(
              onPressed: () => cubit.revealText(),
              label: 'إظهار نص الآية للتأكد',
              icon: const Icon(Icons.visibility_rounded),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(MishkatRadius.xl),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(MishkatRadius.sm),
                ),
                child: Text(
                  'نص الآية الكريمة',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.visibility_off_rounded, size: 20),
                tooltip: 'إخفاء النص للتدرب ثانية',
                onPressed: () => cubit.toggleTextHidden(),
              ),
            ],
          ),
          const SizedBox(height: MishkatSpacing.md),
          Text(
            ayahText,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 24,
              height: 2.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: MishkatSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: colors.gold.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(MishkatRadius.pill),
            ),
            child: Text(
              '﴿ ${point.ayah} ﴾',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold,
                color: colors.gold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanionTools({
    required BuildContext context,
    required int globalAyah,
  }) {
    final colors = context.mishkat;

    return BlocBuilder<QuranCubit, QuranState>(
      builder: (context, quranState) {
        final isPlaying =
            quranState.audioStatus == QuranAudioStatus.playing &&
            quranState.audioGlobalAyah == globalAyah;
        final isBookmarked = quranState.isAyahBookmarked(globalAyah);

        return Row(
          children: [
            // Play Audio
            Expanded(
              child: Material(
                color: isPlaying ? colors.primary : colors.surfaceVariant,
                borderRadius: BorderRadius.circular(MishkatRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(MishkatRadius.md),
                  onTap: () {
                    final cubit = context.read<QuranCubit>();
                    if (isPlaying) {
                      if (quranState.repeatState.isDelaying) {
                        cubit.skipDelay();
                      } else {
                        cubit.toggleAudio(continuous: false);
                      }
                    } else {
                      final config = AudioRepeatConfig(
                        mode: AudioRepeatMode.singleAyah,
                        startGlobalAyah: globalAyah,
                        endGlobalAyah: globalAyah,
                        ayahRepeatCount: _sessionRepeatCount,
                        delaySeconds: _sessionDelaySeconds,
                      );
                      cubit.startRepeatPlayback(
                        config,
                        initialGlobalAyah: globalAyah,
                      );
                    }
                  },
                  onLongPress: () => _openSessionRepeatSettings(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.volume_up_rounded,
                          color: isPlaying ? Colors.white : colors.primary,
                          size: 20,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPlaying
                              ? (quranState.repeatState.isDelaying
                                    ? 'ترديد (${quranState.repeatState.remainingDelaySeconds}ث)'
                                    : 'تكرار ${quranState.repeatState.currentAyahRepeat}/$_sessionRepeatCount')
                              : 'استماع ($_sessionRepeatCount×)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isPlaying
                                ? Colors.white
                                : colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Tafsir
            Expanded(
              child: Material(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(MishkatRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(MishkatRadius.md),
                  onTap: () => _openTafsir(globalAyah),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          color: colors.primary,
                          size: 20,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'التفسير',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Open in Mushaf
            Expanded(
              child: Material(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(MishkatRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(MishkatRadius.md),
                  onTap: () => _openInMushaf(globalAyah),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_stories_outlined,
                          color: colors.primary,
                          size: 20,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'في المصحف',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Bookmark for retention
            Expanded(
              child: Material(
                color: isBookmarked
                    ? colors.primarySoft
                    : colors.surfaceVariant,
                borderRadius: BorderRadius.circular(MishkatRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(MishkatRadius.md),
                  onTap: () {
                    context.read<QuranCubit>().toggleAyahBookmark(
                      globalAyah,
                      label: 'آية تحتاج تثبيت',
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: isBookmarked
                              ? colors.primary
                              : colors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isBookmarked ? 'محفوظة' : 'علامة',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isBookmarked
                                ? colors.primary
                                : colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openSessionRepeatSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إعدادات تكرار الاستماع في الجلسة',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'عدد التكرارات للآية:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [1, 2, 3, 5, 7, 10].map((c) {
                    return ChoiceChip(
                      label: Text('$c×'),
                      selected: _sessionRepeatCount == c,
                      onSelected: (_) {
                        setState(() => _sessionRepeatCount = c);
                        Navigator.of(ctx).pop();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text(
                  'مهلة الترديد (صمت للحفظ):',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [0, 1, 2, 3, 5, 7, 10].map((d) {
                    return ChoiceChip(
                      label: Text(d == 0 ? 'بدون' : '$d ث'),
                      selected: _sessionDelaySeconds == d,
                      onSelected: (_) {
                        setState(() => _sessionDelaySeconds = d);
                        Navigator.of(ctx).pop();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinishedView(
    BuildContext context,
    QuranMemorizationState state,
    MemorizationSession session,
  ) {
    final colors = context.mishkat;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('اكتملت الجلسة'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: MishkatSpacing.page,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.stars_rounded, size: 80, color: colors.gold),
              const SizedBox(height: MishkatSpacing.lg),
              Text(
                'تم إكمال الجلسة بنجاح!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: MishkatSpacing.xs),
              Text(
                'تقبّل الله منك وثبّت القرآن العظيم في قلبك وذاكرتك.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: MishkatSpacing.xl),
              MishkatCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${session.completedCount}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الآيات المراجعة',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 36, color: colors.border),
                    Column(
                      children: [
                        Text(
                          '${state.totalMemorizedCount}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'إجمالي المحفوظ',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 36, color: colors.border),
                    Column(
                      children: [
                        Text(
                          '${state.totalNeedsRevisionCount}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colors.warning,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'تحتاج تثبيت',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MishkatSpacing.xxl),
              MishkatPrimaryAction(
                onPressed: () {
                  context.read<QuranMemorizationCubit>().endSession();
                  Navigator.of(context).pop();
                },
                label: 'العودة إلى لوحة الحفظ',
                icon: const Icon(Icons.arrow_back_rounded),
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final MemorizationStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;

    Color bg;
    Color fg;
    switch (status) {
      case MemorizationStatus.memorized:
        bg = colors.primarySoft;
        fg = colors.primary;
      case MemorizationStatus.learning:
        bg = colors.surfaceVariant;
        fg = colors.textPrimary;
      case MemorizationStatus.needsRevision:
        bg = colors.warning.withValues(alpha: 0.15);
        fg = colors.warning;
      case MemorizationStatus.notStarted:
        bg = colors.border.withValues(alpha: 0.3);
        fg = colors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MishkatRadius.pill),
      ),
      child: Text(
        status.arabicLabel,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
