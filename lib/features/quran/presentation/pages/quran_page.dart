import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../../data/models/quran_models.dart';
import '../cubit/quran_cubit.dart';
import '../cubit/quran_memorization_cubit.dart';
import '../cubit/quran_memorization_state.dart';
import '../cubit/quran_state.dart';
import '../widgets/oral_recitation_info_sheet.dart';
import '../widgets/quran_mini_player.dart';
import 'quran_audio_player_page.dart';
import 'quran_index_page.dart';
import 'quran_memorization_page.dart';
import 'quran_reader_page.dart';
import 'quran_search_page.dart';

/// Main Quran Hub Landing Page in Mishkat Quran.
///
/// Features a clear, dignified three-section architecture:
/// 1. المصحف الشريف — Mushaf & Recitation (Highest visual priority)
/// 2. المشغّل القرآني — Quran Audio Player
/// 3. التحفيظ والمراجعة — Hifz & Revision
class QuranPage extends StatelessWidget {
  const QuranPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuranCubit, QuranState>(
      builder: (context, state) {
        if (state.status == QuranStatus.loading ||
            state.status == QuranStatus.initial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == QuranStatus.failure || state.data == null) {
          return ContentStatePanel(
            icon: Icons.menu_book_outlined,
            title: 'تعذّر فتح المصحف',
            message: state.error ?? 'حدث خطأ أثناء تحميل بيانات القرآن.',
            action: MishkatPrimaryButton(
              onPressed: context.read<QuranCubit>().load,
              label: 'إعادة المحاولة',
            ),
          );
        }
        return _QuranHub(state: state);
      },
    );
  }
}

class _QuranHub extends StatelessWidget {
  const _QuranHub({required this.state});
  final QuranState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    final theme = Theme.of(context);

    return ListView(
      key: const PageStorageKey('quran-hub-landing'),
      padding: MishkatSpacing.page,
      children: [
        // ----------------------------------------------------
        // 1. Compact Header Area
        // ----------------------------------------------------
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مصحف المدينة · حفص عن عاصم',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'القرآن الكريم',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'آخر علامة مرجعية',
              icon: Icon(
                state.bookmarks.isNotEmpty
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
              ),
              onPressed: () => _openLatestBookmark(context),
            ),
            const SizedBox(width: MishkatSpacing.sm),
            IconButton.filledTonal(
              tooltip: 'البحث في القرآن',
              icon: const Icon(Icons.search_rounded),
              onPressed: () => Navigator.push(context, QuranSearchPage.route()),
            ),
          ],
        ),
        const SizedBox(height: MishkatSpacing.base),

        // ----------------------------------------------------
        // 2. Contextual Continuation Area (Last Read & Active Player)
        // ----------------------------------------------------
        _LastReadCard(
          state: state,
          onResume: () {
            final targetPoint =
                state.lastRead ?? state.data?.page(state.currentPage).first;
            final targetPage = targetPoint != null && state.data != null
                ? state.data!.pageForGlobal(targetPoint.global)
                : state.currentPage;
            _openReader(context, targetPage, point: targetPoint);
          },
          onOpenIndex: () {
            Navigator.push(
              context,
              QuranIndexPage.route(initialMode: QuranIndexMode.surahs),
            );
          },
        ),

        // Active Player Bar (if currently playing or paused)
        const QuranMiniPlayer(),
        const SizedBox(height: MishkatSpacing.lg),

        // ----------------------------------------------------
        // 3. Section A: المصحف الشريف (Hero Priority)
        // ----------------------------------------------------
        _MushafSectionCard(
          state: state,
          onOpenMushaf: () {
            Navigator.push(
              context,
              QuranIndexPage.route(initialMode: QuranIndexMode.surahs),
            );
          },
          onOpenIndex: () {
            Navigator.push(
              context,
              QuranIndexPage.route(initialMode: QuranIndexMode.surahs),
            );
          },
          onOpenJuz: () {
            Navigator.push(
              context,
              QuranIndexPage.route(initialMode: QuranIndexMode.juz),
            );
          },
          onOpenBookmarks: () {
            Navigator.push(
              context,
              QuranIndexPage.route(initialMode: QuranIndexMode.bookmarks),
            );
          },
          onOpenSearch: () {
            Navigator.push(context, QuranSearchPage.route());
          },
          onPageJump: () => _showPageJump(context),
        ),
        const SizedBox(height: MishkatSpacing.base),

        // ----------------------------------------------------
        // 4. Section B: المشغّل القرآني
        // ----------------------------------------------------
        _AudioSectionCard(
          state: state,
          onOpenPlayer: () {
            Navigator.push(context, QuranAudioPlayerPage.route());
          },
        ),
        const SizedBox(height: MishkatSpacing.base),

        // ----------------------------------------------------
        // 5. Section C: التحفيظ والمراجعة
        // ----------------------------------------------------
        _MemorizationSectionCard(
          quranData: state.data!,
          onOpenMemorization: () {
            Navigator.push(context, QuranMemorizationPage.route());
          },
          onOpenVisualRecall: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const QuranReaderPage(
                  startRangeSelection: true,
                ),
              ),
            );
          },
          onOpenOralInfo: () => OralRecitationInfoSheet.show(context),
        ),
        const SizedBox(height: MishkatSpacing.xl),
      ],
    );
  }

  Future<void> _openReader(
    BuildContext context,
    int page, {
    QuranPoint? point,
  }) async {
    await context.read<QuranCubit>().openPage(page, point: point);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuranReaderPage(initialGlobalAyah: point?.global),
      ),
    );
  }

  Future<void> _openLatestBookmark(BuildContext context) async {
    final bookmarks = state.bookmarks;
    if (bookmarks.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('لا توجد علامات مرجعية محفوظة بعد'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'الفهرس',
            onPressed: () {
              Navigator.push(
                context,
                QuranIndexPage.route(initialMode: QuranIndexMode.bookmarks),
              );
            },
          ),
        ),
      );
      return;
    }

    final latest = bookmarks.reduce(
      (curr, next) => curr.createdAt.isAfter(next.createdAt) ? curr : next,
    );
    await _openReader(context, latest.page, point: latest.point);
  }

  Future<void> _showPageJump(BuildContext context) async {
    final page = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MishkatRadius.xl)),
      ),
      builder: (context) => _PageJumpSheet(initialPage: state.currentPage),
    );
    if (page == null || !context.mounted) return;
    await _openReader(context, page.clamp(1, 604));
  }
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// Card 1: المصحف الشريف (Hero Card - Calm Minimal Light Design)
// -----------------------------------------------------------------------------
class _MushafSectionCard extends StatelessWidget {
  const _MushafSectionCard({
    required this.state,
    required this.onOpenMushaf,
    required this.onOpenIndex,
    required this.onOpenJuz,
    required this.onOpenBookmarks,
    required this.onOpenSearch,
    required this.onPageJump,
  });

  final QuranState state;
  final VoidCallback onOpenMushaf;
  final VoidCallback onOpenIndex;
  final VoidCallback onOpenJuz;
  final VoidCallback onOpenBookmarks;
  final VoidCallback onOpenSearch;
  final VoidCallback onPageJump;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MishkatCard(
      color: isDark ? colors.surface : colors.surface,
      borderColor: colors.borderSubtle,
      padding: const EdgeInsets.all(MishkatSpacing.base),
      onTap: onOpenIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(MishkatRadius.md),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: MishkatSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المصحف الشريف',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'اقرأ وتدبّر وتابع موضعك',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: colors.primary.withValues(alpha: 0.6),
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: MishkatSpacing.base),

          // Primary Action: Dark Islamic Green button with white text
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MishkatRadius.md),
                ),
                elevation: 0,
              ),
              onPressed: onOpenMushaf,
              icon: const Icon(Icons.auto_stories_rounded, size: 20),
              label: const Text(
                'فتح المصحف',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: MishkatSpacing.sm),

          // Secondary Quick Actions Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SubtleActionChip(
                icon: Icons.format_list_bulleted_rounded,
                label: 'فهرس السور',
                onTap: onOpenIndex,
              ),
              _SubtleActionChip(
                icon: Icons.auto_stories_outlined,
                label: 'الأجزاء',
                onTap: onOpenJuz,
              ),
              _SubtleActionChip(
                icon: Icons.bookmark_rounded,
                label: state.bookmarks.isNotEmpty
                    ? 'العلامات (${state.bookmarks.length})'
                    : 'العلامات',
                onTap: onOpenBookmarks,
              ),
              _SubtleActionChip(
                icon: Icons.search_rounded,
                label: 'البحث',
                onTap: onOpenSearch,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Card 2: المشغّل القرآني
// -----------------------------------------------------------------------------
class _AudioSectionCard extends StatelessWidget {
  const _AudioSectionCard({
    required this.state,
    required this.onOpenPlayer,
  });

  final QuranState state;
  final VoidCallback onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MishkatCard(
      color: isDark ? colors.surface : colors.surface,
      borderColor: colors.borderSubtle,
      padding: const EdgeInsets.all(MishkatSpacing.base),
      onTap: onOpenPlayer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(MishkatRadius.md),
                ),
                child: Icon(
                  Icons.headphones_rounded,
                  color: colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: MishkatSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المشغّل القرآني',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'استمع إلى القرآن الكريم أينما كنت',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: colors.primary.withValues(alpha: 0.6),
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: MishkatSpacing.base),

          // Compact Metadata Row
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: const [
              _MetadataItem(
                icon: Icons.person_rounded,
                label: '12 قارئ معتمد',
              ),
              _MetadataItem(
                icon: Icons.mosque_rounded,
                label: 'بث المسجدين',
              ),
              _MetadataItem(
                icon: Icons.radio_rounded,
                label: 'إذاعات القرآن',
              ),
            ],
          ),
          const SizedBox(height: MishkatSpacing.base),

          // Direct Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: colors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MishkatRadius.md),
                ),
              ),
              onPressed: onOpenPlayer,
              icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
              label: const Text(
                'فتح المشغّل القرآني',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Card 3: التحفيظ والمراجعة
// -----------------------------------------------------------------------------
class _MemorizationSectionCard extends StatelessWidget {
  const _MemorizationSectionCard({
    required this.quranData,
    required this.onOpenMemorization,
    required this.onOpenVisualRecall,
    required this.onOpenOralInfo,
  });

  final QuranData quranData;
  final VoidCallback onOpenMemorization;
  final VoidCallback onOpenVisualRecall;
  final VoidCallback onOpenOralInfo;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<QuranMemorizationCubit, QuranMemorizationState>(
      builder: (context, memState) {
        final activePlan = memState.activePlan;
        final planProgress =
            activePlan != null ? memState.planProgress(activePlan) : null;

        return MishkatCard(
          color: isDark ? colors.surface : colors.surface,
          borderColor: colors.borderSubtle,
          padding: const EdgeInsets.all(MishkatSpacing.base),
          onTap: onOpenMemorization,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      borderRadius: BorderRadius.circular(MishkatRadius.md),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: colors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: MishkatSpacing.base),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'التحفيظ والمراجعة',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'خطط لحفظك، سمّع، وراجع تقدّمك',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: colors.primary.withValues(alpha: 0.6),
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: MishkatSpacing.base),

              // Active Plan or Feature Summary
              if (activePlan != null && planProgress != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(MishkatRadius.md),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'الخطة النشطة: ${activePlan.title}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'الورد: ${activePlan.dailyTarget} آيات',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(MishkatRadius.pill),
                        child: LinearProgressIndicator(
                          value: planProgress.percentage,
                          minHeight: 5,
                          backgroundColor: colors.border.withValues(alpha: 0.3),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(colors.primary),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'حفظ ${planProgress.memorized} من ${planProgress.total} آية (${(planProgress.percentage * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MishkatSpacing.base),
              ] else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: const [
                    _MetadataItem(
                      icon: Icons.checklist_rounded,
                      label: 'خطط حفظ ومراجعة',
                    ),
                    _MetadataItem(
                      icon: Icons.visibility_off_rounded,
                      label: 'تسميع بصري (Q13)',
                    ),
                    _MetadataItem(
                      icon: Icons.sync_rounded,
                      label: 'مراجعة ذكية مستحقة',
                    ),
                  ],
                ),
                const SizedBox(height: MishkatSpacing.base),
              ],

              // Actions Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MishkatRadius.md),
                        ),
                      ),
                      onPressed: onOpenMemorization,
                      icon: const Icon(Icons.dashboard_rounded, size: 16),
                      label: const Text(
                        'لوحة التحفيظ',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: MishkatSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MishkatRadius.md),
                        ),
                      ),
                      onPressed: onOpenVisualRecall,
                      icon: const Icon(Icons.visibility_off_rounded, size: 16),
                      label: const Text(
                        'التسميع البصري',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MishkatSpacing.xs),

              // Oral Recitation Info Shortcut
              Center(
                child: TextButton.icon(
                  onPressed: onOpenOralInfo,
                  icon: const Icon(Icons.record_voice_over_outlined, size: 14),
                  label: const Text(
                    'ميزة التسميع الشفهي والاستماع الذكي',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Continuation Area: Last Read Card
// -----------------------------------------------------------------------------
class _LastReadCard extends StatelessWidget {
  const _LastReadCard({
    required this.state,
    required this.onResume,
    required this.onOpenIndex,
  });

  final QuranState state;
  final VoidCallback onResume;
  final VoidCallback onOpenIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    final data = state.data!;
    final lastRead = state.lastRead;
    final point = lastRead ?? data.page(state.currentPage).first;
    final chapter = data.chapter(point.surah);

    return MishkatCard(
      color: colors.surfaceVariant.withValues(alpha: 0.5),
      borderColor: colors.borderSubtle,
      onTap: onResume,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(MishkatRadius.md),
            ),
            child: Icon(
              Icons.bookmark_rounded,
              color: colors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: MishkatSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lastRead != null ? 'متابعة آخر قراءة' : 'ابدأ القراءة',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: colors.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lastRead != null
                      ? 'سورة ${chapter.name} · صفحة ${state.currentPage} · آية ${point.ayah}'
                      : 'سورة الفاتحة · صفحة 1',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'فهرس القرآن',
            icon: Icon(
              Icons.format_list_bulleted_rounded,
              color: colors.textSecondary,
              size: 20,
            ),
            onPressed: onOpenIndex,
          ),
          TextButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.arrow_back_rounded, size: 15),
            label: const Text(
              'استئناف',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Page Jump Modal Sheet
// -----------------------------------------------------------------------------
class _PageJumpSheet extends StatefulWidget {
  const _PageJumpSheet({required this.initialPage});

  final int initialPage;

  @override
  State<_PageJumpSheet> createState() => _PageJumpSheetState();
}

class _PageJumpSheetState extends State<_PageJumpSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialPage}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          MishkatSpacing.lg,
          MishkatSpacing.md,
          MishkatSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + MishkatSpacing.xl,
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
                  borderRadius: BorderRadius.circular(MishkatRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: MishkatSpacing.lg),
            Text(
              'انتقال إلى صفحة',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: MishkatSpacing.base),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'رقم الصفحة (1 - 604)',
                hintText: 'مثال: 262',
              ),
              onSubmitted: (value) => Navigator.pop(context, int.tryParse(value)),
            ),
            const SizedBox(height: MishkatSpacing.base),
            MishkatPrimaryButton(
              onPressed: () => Navigator.pop(context, int.tryParse(_controller.text)),
              label: 'افتح الصفحة',
              icon: const Icon(Icons.menu_book_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Small Helper Widgets
// -----------------------------------------------------------------------------
class _SubtleActionChip extends StatelessWidget {
  const _SubtleActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MishkatRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceVariant.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(MishkatRadius.sm),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: colors.primary),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetadataItem extends StatelessWidget {
  const _MetadataItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
