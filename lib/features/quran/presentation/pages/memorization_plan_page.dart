import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../../data/models/memorization_plan.dart';
import '../../data/models/quran_models.dart';
import '../cubit/quran_memorization_cubit.dart';

/// Form page for creating or editing a bounded Quran memorization plan.
class MemorizationPlanPage extends StatefulWidget {
  const MemorizationPlanPage({
    super.key,
    required this.quranData,
    this.existingPlan,
  });

  final QuranData quranData;
  final MemorizationPlan? existingPlan;

  static Route<bool> route({
    required QuranData quranData,
    MemorizationPlan? existingPlan,
  }) {
    return MaterialPageRoute<bool>(
      builder: (_) => MemorizationPlanPage(
        quranData: quranData,
        existingPlan: existingPlan,
      ),
    );
  }

  @override
  State<MemorizationPlanPage> createState() => _MemorizationPlanPageState();
}

class _MemorizationPlanPageState extends State<MemorizationPlanPage> {
  late int _selectedSurah;
  late int _startAyah;
  late int _endAyah;
  late int _dailyTarget;
  late TextEditingController _titleController;
  bool _reminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 7, minute: 0);
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.existingPlan;
    if (plan != null) {
      final pointStart = widget.quranData.pointForGlobal(plan.startGlobalAyah);
      final pointEnd = widget.quranData.pointForGlobal(plan.endGlobalAyah);
      _selectedSurah = plan.surah ?? pointStart.surah;
      _startAyah = pointStart.ayah;
      _endAyah = pointEnd.ayah;
      _dailyTarget = plan.dailyTarget;
      _titleController = TextEditingController(text: plan.title);
    } else {
      _selectedSurah = 1;
      final chapter = widget.quranData.chapter(_selectedSurah);
      _startAyah = 1;
      _endAyah = chapter.ayahs.length;
      _dailyTarget = 5;
      _titleController = TextEditingController(text: 'حفظ سورة ${chapter.name}');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _onSurahChanged(int surahNumber) {
    setState(() {
      _selectedSurah = surahNumber;
      final chapter = widget.quranData.chapter(surahNumber);
      _startAyah = 1;
      _endAyah = chapter.ayahs.length;
      _titleController.text = 'حفظ سورة ${chapter.name}';
    });
  }

  Future<void> _selectReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _reminderTime = picked);
    }
  }

  Future<void> _savePlan() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال اسم الخطة'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_startAyah > _endAyah) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('آية البداية يجب ألا تتجاوز آية النهاية'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final chapter = widget.quranData.chapter(_selectedSurah);
      final startGlobal = chapter.globalStart + _startAyah - 1;
      final endGlobal = chapter.globalStart + _endAyah - 1;

      final cubit = context.read<QuranMemorizationCubit>();
      final plan = widget.existingPlan;

      if (plan != null) {
        await cubit.updatePlan(
          plan.copyWith(
            title: title,
            surah: _selectedSurah,
            startGlobalAyah: startGlobal,
            endGlobalAyah: endGlobal,
            dailyTarget: _dailyTarget,
          ),
        );
      } else {
        await cubit.createPlan(
          title: title,
          surah: _selectedSurah,
          startGlobalAyah: startGlobal,
          endGlobalAyah: endGlobal,
          dailyTarget: _dailyTarget,
          reminderTime: _reminderEnabled ? _reminderTime : null,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              plan != null ? 'تم تعديل الخطة بنجاح' : 'تم إنشاء خطة الحفظ بنجاح',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.mishkat;
    final theme = Theme.of(context);
    final chapter = widget.quranData.chapter(_selectedSurah);
    final totalAyahsInSurah = chapter.ayahs.length;
    final totalAyahsInPlan = (_endAyah - _startAyah + 1).clamp(1, totalAyahsInSurah);
    final estimatedDays = (totalAyahsInPlan / _dailyTarget).ceil();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingPlan != null ? 'تعديل خطة الحفظ' : 'خطة حفظ جديدة',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: MishkatSpacing.page,
          children: [
            // Plan Title
            Text(
              'اسم الخطة',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: MishkatSpacing.xs),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'مثال: حفظ سورة الكهف',
                prefixIcon: const Icon(Icons.bookmark_border_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MishkatRadius.md),
                ),
              ),
            ),
            const SizedBox(height: MishkatSpacing.lg),

            // Surah Selector
            Text(
              'اختر السورة',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: MishkatSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(MishkatRadius.md),
                color: colors.surface,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedSurah,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: widget.quranData.chapters.map((c) {
                    return DropdownMenuItem<int>(
                      value: c.number,
                      child: Text(
                        '${c.number}. سورة ${c.name} (${c.ayahs.length} آية)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) _onSurahChanged(val);
                  },
                ),
              ),
            ),
            const SizedBox(height: MishkatSpacing.lg),

            // Ayah Range Selector
            Text(
              'نطاق الآيات (سورة ${chapter.name}: $totalAyahsInSurah آية)',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: MishkatSpacing.xs),
            MishkatCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'من الآية',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _startAyah,
                                isExpanded: true,
                                items: List.generate(totalAyahsInSurah, (i) => i + 1)
                                    .map(
                                      (a) => DropdownMenuItem(
                                        value: a,
                                        child: Text('$a'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _startAyah = val;
                                      if (_endAyah < _startAyah) {
                                        _endAyah = _startAyah;
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: MishkatSpacing.md),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: MishkatSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إلى الآية',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _endAyah,
                                isExpanded: true,
                                items: List.generate(
                                  totalAyahsInSurah - _startAyah + 1,
                                  (i) => _startAyah + i,
                                )
                                    .map(
                                      (a) => DropdownMenuItem(
                                        value: a,
                                        child: Text('$a'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _endAyah = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إجمالي الآيات المحددة:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        '$totalAyahsInPlan آية',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: MishkatSpacing.lg),

            // Daily Target
            Text(
              'الورد اليومي للآيات الجديد',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: MishkatSpacing.xs),
            MishkatCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_dailyTarget آيات يوميًا',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      Text(
                        'يستغرق الحفظ $estimatedDays يومًا تقريبًا',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MishkatSpacing.sm),
                  Slider(
                    value: _dailyTarget.toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '$_dailyTarget آيات',
                    activeColor: colors.primary,
                    onChanged: (val) {
                      setState(() => _dailyTarget = val.round());
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [3, 5, 7, 10, 15].map((target) {
                      final isSelected = _dailyTarget == target;
                      return ChoiceChip(
                        label: Text('$target آيات'),
                        selected: isSelected,
                        selectedColor: colors.primarySoft,
                        labelStyle: TextStyle(
                          color: isSelected ? colors.primary : colors.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          setState(() => _dailyTarget = target);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MishkatSpacing.lg),

            // Reminder Notification Option
            MishkatCard(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'تذكير يومي بالحفظ والمراجعة',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'إشعار يومي يذكرك بورد الحفظ وتثبيت الآيات',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                    value: _reminderEnabled,
                    activeTrackColor: colors.primary,
                    onChanged: (val) => setState(() => _reminderEnabled = val),
                  ),
                  if (_reminderEnabled) ...[
                    const Divider(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.access_time_rounded,
                        color: colors.primary,
                      ),
                      title: const Text('وقت التذكير اليومي'),
                      trailing: TextButton(
                        onPressed: _selectReminderTime,
                        child: Text(
                          _reminderTime.format(context),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: MishkatSpacing.xl),

            // Submit Button
            MishkatPrimaryAction(
              onPressed: _isSaving ? null : _savePlan,
              label: widget.existingPlan != null
                  ? 'حفظ تعديلات الخطة'
                  : 'بدء وتثبيت خطة الحفظ',
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              isFullWidth: true,
            ),
            const SizedBox(height: MishkatSpacing.lg),
          ],
        ),
      ),
    );
  }
}
