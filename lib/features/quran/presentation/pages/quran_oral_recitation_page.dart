import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../../data/models/oral_recitation_models.dart';
import '../../data/repositories/quran_repository.dart';
import '../cubit/quran_memorization_cubit.dart';
import '../cubit/quran_oral_recitation_cubit.dart';
import '../cubit/quran_oral_recitation_state.dart';
import '../services/speech_recognition_service.dart';

/// Production page for real microphone-based Oral Recitation, real-time Quran alignment,
/// mistake inspection, and memorization progress recording.
class QuranOralRecitationPage extends StatelessWidget {
  const QuranOralRecitationPage({
    super.key,
    this.surahNumber = 1,
    this.startGlobalAyah,
    this.endGlobalAyah,
    this.planId,
    this.speechService,
    this.cubit,
    this.quranRepository,
  });

  final int surahNumber;
  final int? startGlobalAyah;
  final int? endGlobalAyah;
  final String? planId;
  final SpeechRecognitionService? speechService;
  final QuranOralRecitationCubit? cubit;
  final QuranRepository? quranRepository;

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider<QuranOralRecitationCubit>.value(
        value: cubit!,
        child: const _QuranOralRecitationView(),
      );
    }
    return BlocProvider<QuranOralRecitationCubit>(
      create: (ctx) {
        final repo = quranRepository ?? ctx.read<QuranRepository>();
        SpeechRecognitionService resolvedSpeech;
        if (speechService != null) {
          resolvedSpeech = speechService!;
        } else {
          try {
            resolvedSpeech = ctx.read<SpeechRecognitionService>();
          } catch (_) {
            resolvedSpeech = NativeSpeechRecognitionService();
          }
        }
        final cubit = QuranOralRecitationCubit(
          speechService: resolvedSpeech,
          quranRepository: repo,
          memorizationCubit: ctx.read<QuranMemorizationCubit>(),
        );
        cubit.prepareSession(
          surahNumber: surahNumber,
          startGlobalAyah: startGlobalAyah,
          endGlobalAyah: endGlobalAyah,
          planId: planId,
        );
        return cubit;
      },
      child: const _QuranOralRecitationView(),
    );
  }
}

class _QuranOralRecitationView extends StatefulWidget {
  const _QuranOralRecitationView();

  @override
  State<_QuranOralRecitationView> createState() => _QuranOralRecitationViewState();
}

class _QuranOralRecitationViewState extends State<_QuranOralRecitationView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<QuranOralRecitationCubit>().checkAndRefreshPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    final theme = Theme.of(context);

    return BlocConsumer<QuranOralRecitationCubit, QuranOralRecitationState>(
      listener: (context, state) {
        if (state.errorMessage != null && state.lifecycle.isError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red.shade800,
            ),
          );
        }
      },
      builder: (context, state) {
        if (kDebugMode) {
          debugPrint('[Q14_UI_RENDER] session=${state.sessionId} '
              'ayah=${state.currentGlobalAyah} '
              'wordIdx=${state.currentWordIndex} '
              'committed=${state.committedTargetIndex} '
              'matched=${state.matchedWordsCount} '
              'omi=${state.omissionsCount} '
              'sub=${state.substitutionsCount} '
              'disc=${state.discrepancies.length} '
              'liveTranscript="${state.liveTranscript}"');
        }
        return Scaffold(
          appBar: AppBar(
            title: Column(
              children: [
                Text(
                  'التسميع الشفهي الذكي',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${state.surahName} · الآيات ${state.startGlobalAyah} - ${state.endGlobalAyah}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'إنهاء الجلسة',
                icon: const Icon(Icons.check_circle_outline_rounded),
                onPressed: state.hasActiveSession
                    ? () => context.read<QuranOralRecitationCubit>().finishSession()
                    : null,
              ),
            ],
          ),
          body: SafeArea(
            child: state.lifecycle.isCompleted
                ? _buildCompletedView(context, state)
                : Column(
                    children: [
                      _buildHeaderBanner(context, state),
                      Expanded(
                        child: _buildRecitationCanvas(context, state),
                      ),
                      if (state.liveTranscript.isNotEmpty)
                        _buildTranscriptTicker(context, state),
                      _buildControlDock(context, state),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderBanner(BuildContext context, QuranOralRecitationState state) {
    final colors = context.mishkat;

    final badgeColor = switch (state.lifecycle) {
      OralRecitationLifecycle.listening => colors.primary,
      OralRecitationLifecycle.paused => Colors.orange,
      OralRecitationLifecycle.requestingPermission ||
      OralRecitationLifecycle.initializingSpeechEngine ||
      OralRecitationLifecycle.permissionGranted =>
        Colors.blue,
      OralRecitationLifecycle.permissionDenied ||
      OralRecitationLifecycle.permissionPermanentlyDenied =>
        Colors.red,
      OralRecitationLifecycle.recognizerUnavailable => Colors.orange,
      _ => colors.textSecondary,
    };

    final badgeLabel = switch (state.lifecycle) {
      OralRecitationLifecycle.listening => 'جاري الاستماع...',
      OralRecitationLifecycle.paused => 'متوقف مؤقتاً',
      OralRecitationLifecycle.requestingPermission => 'جارٍ طلب الإذن...',
      OralRecitationLifecycle.permissionGranted => 'تم منح الإذن',
      OralRecitationLifecycle.initializingSpeechEngine => 'جارٍ تهيئة المحرك...',
      OralRecitationLifecycle.permissionDenied => 'الإذن مطلوب',
      OralRecitationLifecycle.permissionPermanentlyDenied => 'مرفوض من الإعدادات',
      OralRecitationLifecycle.recognizerUnavailable => 'المحرك غير متاح',
      _ => 'جاهز للتسميع',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: MishkatRadius.brSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.lifecycle.isListening)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: badgeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      Flexible(
                        child: Text(
                          badgeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.timer_outlined, size: 14, color: colors.textSecondary),
              const SizedBox(width: 4),
              Text(
                AppFormatters.duration(Duration(seconds: state.durationSeconds)),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${state.progressPercentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (state.progressPercentage / 100.0).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: colors.borderSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecitationCanvas(BuildContext context, QuranOralRecitationState state) {
    final colors = context.mishkat;

    final isPermissionGate = state.lifecycle.isRequestingPermission ||
        state.lifecycle.isInitializingSpeechEngine ||
        state.lifecycle.isPermissionDenied ||
        state.lifecycle.isPermissionPermanentlyDenied ||
        state.lifecycle.isRecognizerUnavailable;

    if (isPermissionGate) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: _buildPermissionGateCard(context, state),
        ),
      );
    }

    // Group aligned words by Ayah
    final ayahsMap = <int, List<RecitationWordAlignment>>{};
    for (final word in state.alignedWords) {
      ayahsMap.putIfAbsent(word.authoritativeWord.globalAyah, () => []).add(word);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ayahsMap.length,
      itemBuilder: (context, index) {
        final globalAyah = ayahsMap.keys.elementAt(index);
        final words = ayahsMap[globalAyah]!;
        final isCurrent = globalAyah == state.currentGlobalAyah;
        final isRevealed = state.revealedGlobals.contains(globalAyah);

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: MishkatCard(
            color: isCurrent
                ? colors.primarySoft.withValues(alpha: 0.35)
                : colors.surface,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ayah Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primarySoft,
                        borderRadius: MishkatRadius.brSm,
                      ),
                      child: Text(
                        'الآية ${words.first.authoritativeWord.ayahInSurah}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      iconSize: 18,
                      tooltip: isRevealed ? 'إخفاء النص' : 'كشف النص الأصلي',
                      icon: Icon(
                        isRevealed
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_outlined,
                        color: isRevealed ? colors.primary : colors.textSecondary,
                      ),
                      onPressed: () {
                        final cubit = context.read<QuranOralRecitationCubit>();
                        if (isRevealed) {
                          cubit.hideAyah(globalAyah);
                        } else {
                          cubit.revealAyah(globalAyah);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Ayah Words
                if (isRevealed)
                  Text(
                    words.map((w) => w.authoritativeWord.uthmaniText).join(' '),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 22,
                      height: 1.8,
                      color: colors.textPrimary,
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: words.map((w) => _buildWordChip(context, w)).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPermissionGateCard(BuildContext context, QuranOralRecitationState state) {
    final colors = context.mishkat;
    final cubit = context.read<QuranOralRecitationCubit>();

    if (state.lifecycle.isRequestingPermission || state.lifecycle.isInitializingSpeechEngine) {
      final isEngine = state.lifecycle.isInitializingSpeechEngine;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isEngine ? 'جارٍ تهيئة محرك التعرف الصوتي...' : 'جارٍ طلب إذن الميكروفون...',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isEngine
                ? 'يتم التحقق من جاهزية خدمات التعرف على الكلام...'
                : 'يُرجى الموافقة على طلب الإذن في نافذة النظام للمتابعة.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
        ],
      );
    }

    if (state.lifecycle.isPermissionPermanentlyDenied) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.settings_suggest_rounded, size: 36, color: Colors.red.shade700),
          ),
          const SizedBox(height: 16),
          const Text(
            'إذن الميكروفون مرفوض من إعدادات الجهاز',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'إذن الميكروفون مرفوض من إعدادات الجهاز. افتح إعدادات التطبيق وفعّل الميكروفون، ثم ارجع وحاول مرة أخرى.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          MishkatPrimaryAction(
            label: 'فتح إعدادات التطبيق',
            icon: const Icon(Icons.settings_outlined),
            isFullWidth: true,
            onPressed: () => cubit.openAppSettings(),
          ),
          const SizedBox(height: 10),
          MishkatSecondaryAction(
            label: 'إعادة التحقق من الإذن',
            icon: const Icon(Icons.refresh_rounded),
            isFullWidth: true,
            onPressed: () => cubit.checkAndRefreshPermission(),
          ),
        ],
      );
    }

    if (state.lifecycle.isRecognizerUnavailable) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded, size: 36, color: Colors.orange.shade700),
          ),
          const SizedBox(height: 16),
          const Text(
            'خدمة التعرف الصوتي غير متاحة',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'خدمة التعرف على الكلام غير متاحة على هذا الجهاز حاليًا.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          MishkatPrimaryAction(
            label: 'إعادة المحاولة',
            icon: const Icon(Icons.refresh_rounded),
            isFullWidth: true,
            onPressed: () => cubit.requestPermissionAndInitialize(),
          ),
        ],
      );
    }

    // Default permission needed / denied state
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mic_rounded, size: 36, color: colors.primary),
        ),
        const SizedBox(height: 16),
        const Text(
          'إذن الميكروفون مطلوب',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'نحتاج إلى إذن الميكروفون حتى نتمكن من الاستماع إلى تلاوتك ومطابقتها محلياً على جهازك دون إرسال التسجيلات لأي خوادم خارجية.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 20),
        MishkatPrimaryAction(
          label: 'السماح والمتابعة',
          icon: const Icon(Icons.mic_rounded),
          isFullWidth: true,
          onPressed: () => cubit.requestPermissionAndInitialize(),
        ),
        const SizedBox(height: 10),
        MishkatSecondaryAction(
          label: 'فتح إعدادات التطبيق',
          icon: const Icon(Icons.settings_outlined),
          isFullWidth: true,
          onPressed: () => cubit.openAppSettings(),
        ),
      ],
    );
  }

  Widget _buildWordChip(BuildContext context, RecitationWordAlignment word) {
    final colors = context.mishkat;

    Color bg;
    Color fg;
    Border? border;

    switch (word.status) {
      case WordAlignmentStatus.matched:
        bg = colors.primarySoft;
        fg = colors.primaryStrong;
        break;
      case WordAlignmentStatus.omission:
        bg = Colors.red.withValues(alpha: 0.12);
        fg = Colors.red.shade800;
        border = Border.all(color: Colors.red.shade400, width: 1);
        break;
      case WordAlignmentStatus.substitution:
        bg = Colors.red.shade700;
        fg = Colors.white;
        break;
      case WordAlignmentStatus.uncertain:
        bg = Colors.amber.withValues(alpha: 0.2);
        fg = Colors.amber.shade900;
        border = Border.all(color: Colors.amber.shade600, width: 1);
        break;
      case WordAlignmentStatus.repetition:
        bg = Colors.blue.withValues(alpha: 0.15);
        fg = Colors.blue.shade900;
        break;
      case WordAlignmentStatus.upcoming:
        bg = colors.surfaceVariant.withValues(alpha: 0.6);
        fg = colors.textSecondary.withValues(alpha: 0.6);
        break;
    }

    final displayText = word.status.isUpcoming
        ? '••••'
        : word.authoritativeWord.uthmaniText;

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: !word.status.isUpcoming
          ? () => _showDiscrepancyDetail(context, word)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: border,
        ),
        child: Text(
          displayText,
          style: TextStyle(
            fontFamily: word.status.isUpcoming ? 'Cairo' : 'Amiri',
            fontSize: word.status.isUpcoming ? 12 : 18,
            fontWeight: FontWeight.bold,
            color: fg,
          ),
        ),
      ),
    );
  }

  Widget _buildTranscriptTicker(BuildContext context, QuranOralRecitationState state) {
    final colors = context.mishkat;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.surfaceVariant.withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(Icons.graphic_eq_rounded, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          const Text(
            'مسموع: ',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              state.liveTranscript,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlDock(BuildContext context, QuranOralRecitationState state) {
    final cubit = context.read<QuranOralRecitationCubit>();
    final isBusy = state.lifecycle.isRequestingPermission ||
        state.lifecycle.isInitializingSpeechEngine;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          // Secondary: Stop / Finish
          Expanded(
            flex: 2,
            child: MishkatSecondaryAction(
              label: 'إنهاء',
              icon: const Icon(Icons.stop_rounded),
              isFullWidth: true,
              onPressed: state.hasActiveSession ? () => cubit.finishSession() : null,
            ),
          ),
          const SizedBox(width: 8),

          // Primary: Start / Pause / Resume
          Expanded(
            flex: 3,
            child: state.lifecycle == OralRecitationLifecycle.listening
                ? MishkatPrimaryAction(
                    label: 'إيقاف مؤقت',
                    icon: const Icon(Icons.pause_rounded),
                    isFullWidth: true,
                    onPressed: () => cubit.pauseRecitation(),
                  )
                : state.lifecycle == OralRecitationLifecycle.paused
                    ? MishkatPrimaryAction(
                        label: 'متابعة',
                        icon: const Icon(Icons.mic_rounded),
                        isFullWidth: true,
                        onPressed: () => cubit.resumeRecitation(),
                      )
                    : isBusy
                        ? MishkatPrimaryAction(
                            label: 'جارٍ التجهيز...',
                            icon: const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            isFullWidth: true,
                            onPressed: null,
                          )
                        : MishkatPrimaryAction(
                            label: 'بدء التسميع',
                            icon: const Icon(Icons.mic_rounded),
                            isFullWidth: true,
                            onPressed: () => cubit.startRecitation(),
                          ),
          ),
          const SizedBox(width: 8),

          // Reveal current
          Expanded(
            flex: 2,
            child: MishkatSecondaryAction(
              label: 'كشف',
              icon: const Icon(Icons.visibility_rounded),
              isFullWidth: true,
              onPressed: () => cubit.revealAyah(state.currentGlobalAyah),
            ),
          ),
        ],
      ),
    );
  }

  void _showDiscrepancyDetail(BuildContext context, RecitationWordAlignment word) {
    final colors = context.mishkat;
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MishkatRadius.lg)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    word.status.isMatched
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    color: word.status.isMatched ? colors.primary : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'تفاصيل الكلمة (${word.status.arabicLabel})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              MishkatCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('اللفظ القرآني الصحيح: ', style: TextStyle(fontSize: 12)),
                        const Spacer(),
                        Text(
                          word.authoritativeWord.uthmaniText,
                          style: const TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (word.recognizedWord != null) ...[
                      const Divider(height: 16),
                      Row(
                        children: [
                          const Text('اللفظ المسموع: ', style: TextStyle(fontSize: 12)),
                          const Spacer(),
                          Text(
                            word.recognizedWord!,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: word.status.isMatched
                                  ? colors.primary
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              MishkatPrimaryAction(
                label: 'حسناً',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletedView(BuildContext context, QuranOralRecitationState state) {
    final colors = context.mishkat;
    final summary = state.summary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.task_alt_rounded, color: colors.primary, size: 32),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'اكتملت جلسة التسميع',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '${state.surahName} · الآيات ${state.startGlobalAyah} - ${state.endGlobalAyah}',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),

          // Statistics Card
          MishkatCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'نسبة الصحة',
                        '${summary?.accuracyPercentage.toStringAsFixed(0) ?? 0}%',
                        colors.primary,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'الكلمات المطابقة',
                        '${summary?.matchedWords ?? 0} / ${summary?.totalWords ?? 0}',
                        colors.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'السقط والخطأ',
                        '${(summary?.omissionsCount ?? 0) + (summary?.substitutionsCount ?? 0)}',
                        (summary?.omissionsCount ?? 0) + (summary?.substitutionsCount ?? 0) > 0
                            ? Colors.red
                            : colors.primary,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'التقييم المقترح: ',
                        style: TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.primarySoft,
                        borderRadius: MishkatRadius.brSm,
                      ),
                      child: Text(
                        summary?.suggestedOutcome.arabicLabel ?? 'جيد',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Commit to Memorization Action
          if (state.isMemorizationCommitted)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primarySoft,
                borderRadius: MishkatRadius.brMd,
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: colors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'تم تسجيل النتيجة بنجاح في سجل ومراجعة الحفظ!',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else
            MishkatPrimaryAction(
              label: state.isCommittingToMemorization
                  ? 'جاري التسجيل...'
                  : 'اعتماد النتيجة في سجل الحفظ والمراجعة',
              icon: const Icon(Icons.bookmark_add_outlined),
              onPressed: state.isCommittingToMemorization
                  ? null
                  : () => context.read<QuranOralRecitationCubit>().commitToMemorization(),
            ),

          const SizedBox(height: 12),
          MishkatSecondaryAction(
            label: 'إجراء جلسة تسميع جديدة',
            icon: const Icon(Icons.replay_rounded),
            onPressed: () => context.read<QuranOralRecitationCubit>().prepareSession(
                  surahNumber: state.surahNumber,
                  startGlobalAyah: state.startGlobalAyah,
                  endGlobalAyah: state.endGlobalAyah,
                ),
          ),
          const SizedBox(height: 8),
          MishkatTextAction(
            label: 'العودة لمركز القرآن',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
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
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
