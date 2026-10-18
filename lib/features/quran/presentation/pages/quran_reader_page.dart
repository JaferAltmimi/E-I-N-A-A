import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';
import '../../data/models/mushaf_layout_models.dart';
import '../../data/models/quran_models.dart';
import '../../data/repositories/mushaf_layout_repository.dart';
import '../cubit/mushaf_interaction_cubit.dart';
import '../cubit/mushaf_interaction_state.dart';
import '../cubit/quran_cubit.dart';
import '../cubit/quran_memorization_cubit.dart';
import '../cubit/quran_state.dart';
import '../cubit/quran_visual_recall_cubit.dart';
import '../cubit/quran_visual_recall_state.dart';
import '../widgets/ayah_action_sheet.dart';
import '../widgets/mushaf_ayah_overlay.dart';
import '../widgets/mushaf_interaction_layer.dart';
import '../widgets/mushaf_visual_mask_overlay.dart';
import '../widgets/mushaf_visual_recall_interaction_layer.dart';
import '../widgets/quran_mini_player.dart';
import '../widgets/tafsir_knowledge_sheet.dart';
import '../widgets/visual_recall_bottom_bar.dart';

QuranVisualRecallCubit? _tryGetVisualRecallCubit(BuildContext context) {
  try {
    return BlocProvider.of<QuranVisualRecallCubit>(context, listen: false);
  } catch (_) {
    return null;
  }
}

class QuranReaderPage extends StatefulWidget {
  const QuranReaderPage({
    super.key,
    this.initialGlobalAyah,
    this.visualRecallInitialQueue,
    this.visualRecallPlanId,
    this.startRangeSelection,
  });

  final int? initialGlobalAyah;
  final List<int>? visualRecallInitialQueue;
  final String? visualRecallPlanId;
  final bool? startRangeSelection;

  @override
  State<QuranReaderPage> createState() => _QuranReaderPageState();
}

class _QuranReaderPageState extends State<QuranReaderPage> {
  late final PageController _controller;
  bool _focus = false;
  bool _isPageZoomed = false;

  @override
  void initState() {
    super.initState();
    int initialPage = context.read<QuranCubit>().state.currentPage - 1;
    final targetGlobal = widget.initialGlobalAyah ??
        (widget.visualRecallInitialQueue != null &&
                widget.visualRecallInitialQueue!.isNotEmpty
            ? widget.visualRecallInitialQueue!.first
            : null);
    if (targetGlobal != null) {
      final layoutRepo = MushafLayoutRepository.instance;
      final targetPage = layoutRepo.isLoaded
          ? layoutRepo.pageForAyah(targetGlobal)
          : null;
      if (targetPage != null) {
        initialPage = targetPage - 1;
      }
    }
    _controller = PageController(initialPage: initialPage);
  }

  QuranVisualRecallCubit? _scopedRecallCubit;
  MushafInteractionCubit? _scopedInteractionCubit;

  @override
  void dispose() {
    _scopedRecallCubit?.close();
    _scopedInteractionCubit?.close();
    _controller.dispose();
    super.dispose();
  }

  void _handleZoomChanged(bool isZoomed) {
    if (_isPageZoomed != isZoomed) {
      setState(() => _isPageZoomed = isZoomed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancestorRecallCubit = _tryGetVisualRecallCubit(context);
    QuranMemorizationCubit? memCubit;
    try {
      memCubit = context.read<QuranMemorizationCubit>();
    } catch (_) {}

    _scopedInteractionCubit ??= () {
      final cubit = MushafInteractionCubit()..load();
      if (widget.initialGlobalAyah != null) {
        cubit.selectAyahByGlobal(widget.initialGlobalAyah!);
      }
      return cubit;
    }();

    if (ancestorRecallCubit == null && memCubit != null) {
      _scopedRecallCubit ??= () {
        final quranCubit = context.read<QuranCubit>();
        final cubit = QuranVisualRecallCubit(
          memorizationCubit: memCubit!,
          storage: memCubit.repository.storage,
          audioService: quranCubit.audioService,
          reciter: quranCubit.reciter,
        );
        if (widget.visualRecallInitialQueue != null &&
            widget.visualRecallInitialQueue!.isNotEmpty) {
          cubit.startJourney(
            widget.visualRecallInitialQueue!,
            planId: widget.visualRecallPlanId,
          );
        } else if (widget.startRangeSelection == true &&
            widget.initialGlobalAyah != null) {
          cubit.enterRangeSelection(widget.initialGlobalAyah!);
        }
        return cubit;
      }();
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider<MushafInteractionCubit>.value(
          value: _scopedInteractionCubit!,
        ),
        if (ancestorRecallCubit == null && _scopedRecallCubit != null)
          BlocProvider<QuranVisualRecallCubit>.value(
            value: _scopedRecallCubit!,
          ),
      ],
      child: Builder(
        builder: (context) {
          final visualRecallCubit = _tryGetVisualRecallCubit(context);
          if (ancestorRecallCubit != null &&
              widget.visualRecallInitialQueue != null &&
              widget.visualRecallInitialQueue!.isNotEmpty &&
              !ancestorRecallCubit.state.hasActiveSession) {
            ancestorRecallCubit.startJourney(
              widget.visualRecallInitialQueue!,
              planId: widget.visualRecallPlanId,
            );
          }

          return MultiBlocListener(
            listeners: [
              BlocListener<MushafInteractionCubit, MushafInteractionState>(
                listenWhen: (previous, current) =>
                    !previous.isActionSheetOpen &&
                    current.isActionSheetOpen &&
                    current.selectedAyah != null,
                listener: (context, state) async {
                  final quranData = context.read<QuranCubit>().state.data;
                  if (quranData == null || state.selectedAyah == null) return;

                  final result = await AyahActionSheet.show(
                    context: context,
                    ayah: state.selectedAyah!,
                    quranData: quranData,
                  );

                  if (result == 'tafsir' && context.mounted) {
                    await TafsirKnowledgeSheet.show(
                      context: context,
                      ayah: state.selectedAyah!,
                      quranData: quranData,
                    );
                  } else if (result == 'visual_recall_single' && context.mounted) {
                    final recall = _tryGetVisualRecallCubit(context);
                    if (recall != null) {
                      context.read<MushafInteractionCubit>().clearSelection();
                      await recall.startSingleAyah(state.selectedAyah!.globalAyah);
                    }
                  } else if (result == 'visual_recall_range' && context.mounted) {
                    final recall = _tryGetVisualRecallCubit(context);
                    if (recall != null) {
                      context.read<MushafInteractionCubit>().clearSelection();
                      recall.enterRangeSelection(state.selectedAyah!.globalAyah);
                    }
                  }

                  if (context.mounted) {
                    context.read<MushafInteractionCubit>().setActionSheetOpen(false);
                  }
                },
              ),
              if (visualRecallCubit != null)
                BlocListener<QuranVisualRecallCubit, QuranVisualRecallState>(
                  bloc: visualRecallCubit,
                  listenWhen: (previous, current) =>
                      previous.currentGlobalAyah != current.currentGlobalAyah &&
                      current.currentGlobalAyah != null,
                  listener: (context, state) {
                    final nextAyah = state.currentGlobalAyah;
                    if (nextAyah == null) return;
                    final layoutRepo = MushafLayoutRepository.instance;
                    final targetPage = layoutRepo.isLoaded
                        ? layoutRepo.pageForAyah(nextAyah)
                        : null;
                    if (targetPage != null) {
                      final targetIndex = targetPage - 1;
                      if (_controller.hasClients &&
                          (_controller.page?.round() ?? targetIndex) != targetIndex) {
                        _controller.animateToPage(
                          targetIndex,
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                        );
                      }
                    }
                  },
                ),
          BlocListener<QuranCubit, QuranState>(
            listenWhen: (previous, current) =>
                previous.audioGlobalAyah != current.audioGlobalAyah ||
                previous.audioStatus != current.audioStatus,
            listener: (context, state) {
              final activeAyah = (state.audioStatus == QuranAudioStatus.playing ||
                      state.audioStatus == QuranAudioStatus.loading ||
                      state.audioStatus == QuranAudioStatus.paused)
                  ? state.audioGlobalAyah
                  : null;
              context.read<MushafInteractionCubit>().setPlayingAyah(activeAyah);
            },
          ),
        ],
        child: BlocConsumer<QuranCubit, QuranState>(
          listenWhen: (previous, current) =>
              previous.currentPage != current.currentPage,
          listener: (context, state) {
            final target = state.currentPage - 1;
            if (_controller.hasClients &&
                (_controller.page?.round() ?? target) != target) {
              _controller.animateToPage(
                target,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
              );
            }
          },
          buildWhen: (previous, current) =>
              previous.currentPage != current.currentPage ||
              previous.fontSize != current.fontSize ||
              previous.bookmarks != current.bookmarks ||
              previous.status != current.status ||
              previous.data != current.data,
          builder: (context, state) {
            final data = state.data!;
            final point = data.page(state.currentPage).first;
            final chapter = data.chapter(point.surah);
            return Scaffold(
              appBar: _focus
                  ? null
                  : AppBar(
                      leading: IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'العودة إلى الفهرس',
                        onPressed: () => Navigator.pop(context),
                      ),
                      title: Column(
                        children: [
                          Text('سورة ${chapter.name}'),
                          Text(
                            'صفحة ${state.currentPage} من 604 · الجزء ${_juzFor(data, point.global)}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      actions: [
                        IconButton(
                           tooltip: state.isCurrentPageBookmarked
                              ? 'حذف العلامة'
                              : 'حفظ علامة',
                          onPressed: context.read<QuranCubit>().toggleBookmark,
                          icon: Icon(
                            state.isCurrentPageBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                          ),
                        ),
                        IconButton(
                          tooltip: 'ملء الشاشة',
                          onPressed: () => setState(() => _focus = true),
                          icon: const Icon(Icons.fullscreen),
                        ),
                        IconButton(
                          tooltip: 'التسميع في المصحف',
                          onPressed: () => _showVisualRecallMenu(context),
                          icon: const Icon(Icons.school_outlined),
                        ),
                        IconButton(
                          tooltip: 'خيارات القراءة',
                          onPressed: () => _showOptions(context),
                          icon: const Icon(Icons.tune),
                        ),
                      ],
                    ),
              body: Stack(
                children: [
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: PageView.builder(
                      controller: _controller,
                      physics: _isPageZoomed
                          ? const NeverScrollableScrollPhysics()
                          : const PageScrollPhysics(),
                      itemCount: 604,
                      onPageChanged: (index) {
                        final page = index + 1;
                        final recall = _tryGetVisualRecallCubit(context);
                        final isRecallActive = recall != null &&
                            (recall.state.hasActiveSession ||
                                recall.state.isRangeSelecting);
                        if (!isRecallActive) {
                          context.read<QuranCubit>().openPage(page);
                        }
                        context.read<MushafInteractionCubit>().onPageChanged(page);
                      },
                      itemBuilder: (context, index) => _MushafPage(
                        key: ValueKey('mushaf-page-${index + 1}'),
                        page: index + 1,
                        scale: state.fontSize / 32,
                        isCurrent: (index + 1) == state.currentPage,
                        onZoomChanged: _handleZoomChanged,
                      ),
                    ),
                  ),
                  if (_focus)
                    PositionedDirectional(
                      top: MediaQuery.paddingOf(context).top + 8,
                      start: 8,
                      child: Material(
                        color: Theme.of(context).colorScheme.surface
                            .withValues(alpha: .9),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'إنهاء ملء الشاشة',
                          onPressed: () => setState(() => _focus = false),
                          icon: const Icon(Icons.fullscreen_exit),
                        ),
                      ),
                    ),
                ],
              ),
              bottomNavigationBar: _focus
                  ? null
                  : _buildBottomBar(context),
            );
          },
        ),
      );
    },
  ),
);
  }

  Future<void> _showVisualRecallMenu(BuildContext context) async {
    final recallCubit = _tryGetVisualRecallCubit(context);
    if (recallCubit == null) return;

    final state = recallCubit.state;
    final colors = context.mishkat;
    final theme = Theme.of(context);
    final currentPage = context.read<QuranCubit>().state.currentPage;

    await showModalBottomSheet<void>(
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
              const Text(
                'التسميع والاستحضار البصري',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'اختبر حفظك مباشرة على صفحة المصحف دون الاستعانة بالنظر',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (state.hasActiveSession || state.isRangeSelecting) ...[
                ListTile(
                  leading: Icon(Icons.close_rounded, color: colors.error),
                  title: const Text('إنهاء جلسة التسميع الحالية'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    if (state.isRangeSelecting) {
                      recallCubit.cancelRangeSelection();
                    } else {
                      recallCubit.endSession();
                    }
                  },
                ),
              ] else ...[
                ListTile(
                  leading: Icon(Icons.linear_scale_rounded, color: colors.primary),
                  title: const Text('تحديد مقطع للتسميع في هذه الصفحة'),
                  subtitle: Text('صفحة $currentPage'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    final layoutRepo = MushafLayoutRepository.instance;
                    final geom = layoutRepo.isLoaded ? layoutRepo.getPageGeometry(currentPage) : null;
                    final firstAyah = geom?.ayahs.firstOrNull?.globalAyah;
                    if (firstAyah != null) {
                      recallCubit.enterRangeSelection(firstAyah);
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.touch_app_outlined, color: colors.primary),
                  title: const Text('تسميع آية معينة'),
                  subtitle: const Text('اضغط مطولاً على أي آية واختر «تسميع الآية»'),
                  onTap: () => Navigator.of(sheetContext).pop(),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final recallCubit = _tryGetVisualRecallCubit(context);
    if (recallCubit != null) {
      return BlocBuilder<QuranVisualRecallCubit, QuranVisualRecallState>(
        bloc: recallCubit,
        buildWhen: (prev, curr) =>
            prev.phase != curr.phase ||
            prev.hasActiveSession != curr.hasActiveSession ||
            prev.isRangeSelecting != curr.isRangeSelecting ||
            prev.isCompleted != curr.isCompleted ||
            prev.isLoading != curr.isLoading ||
            prev.error != curr.error ||
            prev.currentIndex != curr.currentIndex,
        builder: (context, recallState) {
          if (recallState.hasActiveSession ||
              recallState.isRangeSelecting ||
              recallState.isCompleted) {
            return VisualRecallBottomBar(cubit: recallCubit);
          }
          return _ReaderBottomBar(onOptions: () => _showOptions(context));
        },
      );
    }
    return _ReaderBottomBar(onOptions: () => _showOptions(context));
  }

  int _juzFor(QuranData data, int global) {
    var value = 1;
    for (final juz in data.juz) {
      if (data.globalFor(juz.surah, juz.ayah) <= global) value = juz.number;
    }
    return value;
  }

  Future<void> _showOptions(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<QuranCubit>()),
        BlocProvider.value(value: context.read<SettingsCubit>()),
      ],
      child: const _ReaderOptionsSheet(),
    ),
  );
}

class MushafThemeColors {
  const MushafThemeColors._();

  static const lightBackground = Color(0xFFF6F1E8);
  static const lightInk = Color(0xFF231F20);

  static const darkBackground = Color(0xFF121C17);
  static const darkInk = Color(0xFFECE5D8);
}

typedef _MushafPage = MushafPage;

class MushafPage extends StatefulWidget {
  const MushafPage({
    super.key,
    required this.page,
    required this.scale,
    required this.isCurrent,
    this.onZoomChanged,
  });

  final int page;
  final double scale;
  final bool isCurrent;
  final ValueChanged<bool>? onZoomChanged;

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<_MushafPage> {
  late final TransformationController _transformationController;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController()
      ..addListener(_onTransformationChanged);
    _updateZoomState();
  }

  @override
  void didUpdateWidget(covariant _MushafPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scale != widget.scale || oldWidget.isCurrent != widget.isCurrent) {
      _updateZoomState();
      if (widget.isCurrent && !oldWidget.isCurrent) {
        widget.onZoomChanged?.call(_isZoomed);
      }
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    _updateZoomState();
  }

  void _updateZoomState() {
    final matrixScale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomed = matrixScale > 1.05 || widget.scale > 1.05;
    if (_isZoomed != isZoomed) {
      _isZoomed = isZoomed;
      if (widget.isCurrent) {
        widget.onZoomChanged?.call(_isZoomed);
      }
    }
  }

  void _resetZoom() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
      _updateZoomState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorFilter = isDark
        ? const ColorFilter.mode(MushafThemeColors.darkInk, BlendMode.srcIn)
        : null;

    final hasInteractionCubit =
        context.findAncestorWidgetOfExactType<BlocProvider<MushafInteractionCubit>>() != null;

    Widget buildPageContent(
      AyahBounds? selectedAyah,
      AyahBounds? playingAyah,
      List<AyahBounds> bookmarkedAyahs,
      MushafLayoutRepository? layoutRepo,
    ) {
      final effectiveLayoutRepo = layoutRepo ??
          (MushafLayoutRepository.instance.isLoaded
              ? MushafLayoutRepository.instance
              : null);
      final pageGeom = effectiveLayoutRepo?.getPageGeometry(widget.page);
      final viewBox = pageGeom?.viewBox ??
          (widget.page <= 2
              ? const Rect.fromLTWH(-53.3109, -198.4777, 345, 550)
              : const Rect.fromLTWH(0, 0, 345, 550));

      final visualRecallCubit = _tryGetVisualRecallCubit(context);

      Widget stack = Stack(
        fit: StackFit.expand,
        children: [
          SvgPicture.asset(
            'assets/mushaf/pages/${widget.page.toString().padLeft(3, '0')}.svg',
            fit: BoxFit.contain,
            colorFilter: colorFilter,
            placeholderBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
          ),
          if (selectedAyah != null || playingAyah != null || bookmarkedAyahs.isNotEmpty)
            MushafAyahOverlay(
              selectedAyah: selectedAyah,
              playingAyah: playingAyah,
              bookmarkedAyahs: bookmarkedAyahs,
              viewBox: viewBox,
            ),
          if (visualRecallCubit != null)
            BlocSelector<QuranVisualRecallCubit, QuranVisualRecallState, Set<int>>(
              bloc: visualRecallCubit,
              selector: (state) => state.activeMaskedGlobals,
              builder: (context, activeMaskedGlobals) {
                if (activeMaskedGlobals.isEmpty ||
                    effectiveLayoutRepo == null ||
                    !effectiveLayoutRepo.isLoaded) {
                  return const SizedBox.shrink();
                }
                final geom = effectiveLayoutRepo.getPageGeometry(widget.page);
                if (geom == null) return const SizedBox.shrink();

                final pageMaskedAyahs = geom.ayahs
                    .where((ayah) => activeMaskedGlobals.contains(ayah.globalAyah))
                    .toList();

                if (pageMaskedAyahs.isEmpty) return const SizedBox.shrink();

                return MushafVisualMaskOverlay(
                  maskedAyahs: pageMaskedAyahs,
                  viewBox: viewBox,
                  maskColor: isDark
                      ? MushafThemeColors.darkBackground
                      : MushafThemeColors.lightBackground,
                );
              },
            ),
        ],
      );

      if (visualRecallCubit != null) {
        stack = MushafVisualRecallInteractionLayer(
          page: widget.page,
          visualRecallCubit: visualRecallCubit,
          effectiveLayoutRepo: effectiveLayoutRepo,
          viewBox: viewBox,
          onDoubleTap: _resetZoom,
          child: stack,
        );
      }

      if (hasInteractionCubit) {
        stack = MushafInteractionLayer(
          page: widget.page,
          onDoubleTap: _resetZoom,
          child: stack,
        );
      }

      return stack;
    }

    return ColoredBox(
      color: isDark
          ? MushafThemeColors.darkBackground
          : MushafThemeColors.lightBackground,
      child: LayoutBuilder(
        builder: (context, constraints) => InteractiveViewer(
          transformationController: _transformationController,
          constrained: false,
          minScale: .8,
          maxScale: 4,
          boundaryMargin: _isZoomed
              ? const EdgeInsets.all(40)
              : EdgeInsets.zero,
          child: SizedBox(
            width: constraints.maxWidth * widget.scale.clamp(.82, 1.65),
            height: constraints.maxHeight * widget.scale.clamp(.82, 1.65),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: hasInteractionCubit
                  ? BlocSelector<MushafInteractionCubit, MushafInteractionState,
                      ({AyahBounds? selectedAyah, AyahBounds? playingAyah})>(
                      selector: (state) {
                        final selected = state.selectedPage == widget.page
                            ? state.selectedAyah
                            : null;
                        final playingGlobal = state.playingAyah;
                        final layoutRepo = context
                            .read<MushafInteractionCubit>()
                            .layoutRepository;
                        AyahBounds? playing;
                        if (playingGlobal != null && layoutRepo.isLoaded) {
                          final ayah = layoutRepo.getAyah(playingGlobal);
                          if (ayah?.page == widget.page) {
                            playing = ayah;
                          }
                        }
                        return (
                          selectedAyah: selected,
                          playingAyah: playing,
                        );
                      },
                      builder: (context, highlights) {
                        final bookmarks = context.select<QuranCubit, List<QuranBookmark>>(
                          (cubit) => cubit.state.getBookmarksForPage(widget.page),
                        );
                        final layoutRepo = context
                            .read<MushafInteractionCubit>()
                            .layoutRepository;
                        final List<AyahBounds> bookmarkedBounds = [];
                        if (bookmarks.isNotEmpty && layoutRepo.isLoaded) {
                          for (final b in bookmarks) {
                            final bounds = layoutRepo.getAyah(b.point.global);
                            if (bounds != null && bounds.page == widget.page) {
                              bookmarkedBounds.add(bounds);
                            }
                          }
                        }
                        return buildPageContent(
                          highlights.selectedAyah,
                          highlights.playingAyah,
                          bookmarkedBounds,
                          layoutRepo,
                        );
                      },
                    )
                  : buildPageContent(null, null, const [], null),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderBottomBar extends StatelessWidget {
  const _ReaderBottomBar({required this.onOptions});
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state.settings;
    final cubit = context.read<QuranCubit>();
    return BlocBuilder<QuranCubit, QuranState>(
      buildWhen: (previous, current) =>
          previous.audioStatus != current.audioStatus ||
          previous.currentPage != current.currentPage,
      builder: (context, state) {
        final playing = state.audioStatus == QuranAudioStatus.playing;
        return Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 10,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const QuranMiniPlayer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'الصفحة السابقة',
                        onPressed: state.currentPage > 1
                            ? () => cubit.openPage(state.currentPage - 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onOptions,
                          icon: const Icon(Icons.tune),
                          label: Text('صفحة ${state.currentPage}'),
                        ),
                      ),
                      IconButton(
                        tooltip: 'الصفحة التالية',
                        onPressed: state.currentPage < 604
                            ? () => cubit.openPage(state.currentPage + 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        tooltip: 'تشغيل التلاوة',
                        onPressed: () => cubit.toggleAudio(
                          continuous: settings.quranContinuous,
                          autoScroll: settings.quranAutoScroll,
                        ),
                        icon: Icon(
                          playing ? Icons.pause_circle : Icons.play_circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReaderOptionsSheet extends StatefulWidget {
  const _ReaderOptionsSheet();

  @override
  State<_ReaderOptionsSheet> createState() => _ReaderOptionsSheetState();
}

class _ReaderOptionsSheetState extends State<_ReaderOptionsSheet> {
  late final TextEditingController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = TextEditingController(
      text: '${context.read<QuranCubit>().state.currentPage}',
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuranCubit, QuranState>(
      builder: (context, quran) {
        return BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, settingsState) {
            final settings = settingsState.settings;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.paddingOf(context).bottom + 24,
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'خيارات القراءة',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('تم'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'حجم المصحف · ${(quran.fontSize / 32 * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Row(
                    children: [
                      const Text('أ', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Slider(
                          min: 20,
                          max: 60,
                          value: quran.fontSize,
                          onChanged: (value) {
                            context.read<QuranCubit>().setFontSize(value);
                            context.read<SettingsCubit>().setQuranFont(value);
                          },
                        ),
                      ),
                      const Text('أ', style: TextStyle(fontSize: 28)),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final preset in const [
                        (24, 'صغير'),
                        (32, 'ملائم'),
                        (44, 'كبير'),
                        (60, 'كبير جدًا'),
                      ])
                        ChoiceChip(
                          label: Text(preset.$2),
                          selected: quran.fontSize.round() == preset.$1,
                          onSelected: (_) {
                            context.read<QuranCubit>().setFontSize(
                              preset.$1.toDouble(),
                            );
                            context.read<SettingsCubit>().setQuranFont(
                              preset.$1.toDouble(),
                            );
                          },
                        ),
                    ],
                  ),
                  const Divider(height: 32),
                  TextField(
                    controller: _pageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'انتقال مباشر إلى صفحة',
                      suffixIcon: IconButton(
                        onPressed: () {
                          final page = int.tryParse(_pageController.text);
                          if (page != null) {
                            context.read<QuranCubit>().openPage(page);
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: settings.reciter,
                    decoration: const InputDecoration(labelText: 'القارئ'),
                    items: [
                      for (final reciter in AppConstants.reciters)
                        DropdownMenuItem(
                          value: reciter.id,
                          child: Text(reciter.name),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      context.read<SettingsCubit>().setReciter(value);
                      context.read<QuranCubit>().updateReciter(value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('متابعة التلاوة تلقائيًا'),
                    value: settings.quranContinuous,
                    onChanged: context.read<SettingsCubit>().setContinuousAudio,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تتبّع موضع التلاوة'),
                    value: settings.quranAutoScroll,
                    onChanged: context.read<SettingsCubit>().setAutoScroll,
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
