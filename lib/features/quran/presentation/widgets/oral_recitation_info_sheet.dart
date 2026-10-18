import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../../data/repositories/quran_repository.dart';
import '../pages/quran_oral_recitation_page.dart';
import '../pages/quran_reader_page.dart';
import '../services/speech_recognition_service.dart';

/// Modal bottom sheet presenting the technical boundaries, feasibility requirements,
/// and truthful status of the Audio-Assisted Oral Recitation & Mistake Correction feature.
class OralRecitationInfoSheet extends StatelessWidget {
  const OralRecitationInfoSheet({
    super.key,
    this.surahNumber = 1,
    this.startGlobalAyah,
    this.endGlobalAyah,
    this.planId,
  });

  final int surahNumber;
  final int? startGlobalAyah;
  final int? endGlobalAyah;
  final String? planId;

  static Future<void> show(
    BuildContext context, {
    int surahNumber = 1,
    int? startGlobalAyah,
    int? endGlobalAyah,
    String? planId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MishkatRadius.xl)),
      ),
      builder: (_) => OralRecitationInfoSheet(
        surahNumber: surahNumber,
        startGlobalAyah: startGlobalAyah,
        endGlobalAyah: endGlobalAyah,
        planId: planId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MishkatSpacing.lg,
          MishkatSpacing.base,
          MishkatSpacing.lg,
          MishkatSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: MishkatSpacing.base),

            // Icon + Title
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
                    Icons.record_voice_over_rounded,
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
                        'التسميع الشفهي الذكي',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'الاستماع لتلاوة المستخدم واكتشاف الأخطاء آنياً',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(MishkatRadius.sm),
                  ),
                  child: Text(
                    'متاح الآن',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MishkatSpacing.base),

            // Truthful Architecture Statement Card
            MishkatCard(
              color: colors.surfaceVariant.withValues(alpha: 0.5),
              padding: const EdgeInsets.all(MishkatSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_user_outlined, size: 18, color: colors.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'المصداقية والأمانة العلمية والتقنية',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'يتم التقاط الصوت محلياً على جهازك ومطابقة التلاوة مع الرسم العثماني لكشف السقط والأخطاء اللفظية بدقة، مع حماية تامة لخصوصيتك دون إرسال التسجيلات لأي خوادم خارجية.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colors.textSecondary,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MishkatSpacing.base),

            // Capabilities Checklist
            _buildCapabilityRow(
              icon: Icons.check_circle_outline_rounded,
              color: colors.primary,
              title: 'تشغيل تلاوات القراء ومزامنتها (Q12)',
              status: 'متاح ومدمج',
            ),
            const SizedBox(height: MishkatSpacing.xs),
            _buildCapabilityRow(
              icon: Icons.check_circle_outline_rounded,
              color: colors.primary,
              title: 'التسميع والاستحضار البصري في المصحف (Q13)',
              status: 'متاح ومدمج',
            ),
            const SizedBox(height: MishkatSpacing.xs),
            _buildCapabilityRow(
              icon: Icons.check_circle_outline_rounded,
              color: colors.primary,
              title: 'التقاط الصوت من الميكروفون (Q14)',
              status: 'متاح ومدمج',
            ),
            const SizedBox(height: MishkatSpacing.xs),
            _buildCapabilityRow(
              icon: Icons.check_circle_outline_rounded,
              color: colors.primary,
              title: 'المطابقة الصوتية للرسم العثماني وكشف الأخطاء',
              status: 'متاح ومدمج',
            ),
            const SizedBox(height: MishkatSpacing.lg),

            // Primary Action: Start Oral Recitation (Q14)
            MishkatPrimaryAction(
              onPressed: () {
                final navigator = Navigator.of(context);
                final quranRepo = context.read<QuranRepository>();
                SpeechRecognitionService? speechService;
                try {
                  speechService = context.read<SpeechRecognitionService>();
                } catch (_) {}
                navigator.pop();
                navigator.push(
                  MaterialPageRoute<void>(
                    builder: (_) => QuranOralRecitationPage(
                      surahNumber: surahNumber,
                      startGlobalAyah: startGlobalAyah,
                      endGlobalAyah: endGlobalAyah,
                      planId: planId,
                      quranRepository: quranRepo,
                      speechService: speechService,
                    ),
                  ),
                );
              },
              label: 'بدء التسميع الشفهي الآن',
              icon: const Icon(Icons.mic_rounded),
            ),
            const SizedBox(height: 8),

            // Secondary Action: Visual Recall (Q13)
            MishkatSecondaryAction(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const QuranReaderPage(
                      startRangeSelection: true,
                    ),
                  ),
                );
              },
              label: 'التسميع والاستحضار البصري في المصحف',
              icon: const Icon(Icons.visibility_off_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityRow({
    required IconData icon,
    required Color color,
    required String title,
    required String status,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          status,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
