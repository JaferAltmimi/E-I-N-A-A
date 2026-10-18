import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../../data/models/adhkar_models.dart';
import '../cubit/adhkar_cubit.dart';
import '../cubit/adhkar_state.dart';
import '../widgets/dua_editor_sheet.dart';

class AdhkarReaderPage extends StatelessWidget {
  const AdhkarReaderPage({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<AdhkarCubit, AdhkarState>(
    builder: (context, state) {
      final category = state.selected;
      if (category == null) {
        return const Scaffold(
          body: ContentStatePanel(
            icon: Icons.info_outline,
            title: 'الباب غير موجود',
            message: 'ارجع إلى فهرس الأذكار.',
          ),
        );
      }
      final progress = state.progress[category.id] ?? const <int, int>{};
      final completed = [
        for (var i = 0; i < category.items.length; i++)
          if ((progress[i] ?? 0) >= category.items[i].count) i,
      ].length;
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_right),
          ),
          title: Text(category.name),
          actions: [
            if (category.items.isNotEmpty && progress.isNotEmpty)
              IconButton(
                tooltip: 'بدء الورد من جديد',
                onPressed: () => _confirmReset(context, category),
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            if (category.custom)
              IconButton(
                tooltip: 'إضافة دعاء',
                onPressed: () => _editDua(context),
                icon: const Icon(Icons.add),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            MishkatCard(
              color: context.mishkat.primarySoft,
              borderColor: context.mishkat.primary.withValues(alpha: 0.14),
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
                              category.name,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              category.custom
                                  ? 'أدعية تحفظها للرجوع إليها'
                                  : 'من كتاب حصن المسلم',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.mishkat.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (category.items.isNotEmpty)
                        Container(
                          width: 58,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.mishkat.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${((completed / category.items.length) * 100).round()}٪',
                            style: TextStyle(
                              color: context.mishkat.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (category.items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: completed / category.items.length,
                        minHeight: 7,
                        backgroundColor: context.mishkat.surface,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      completed == category.items.length
                          ? 'أتممت الورد، تقبّل الله منك'
                          : '$completed من ${category.items.length} أذكار مكتملة',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.mishkat.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (category.custom && category.items.isEmpty)
              ContentStatePanel(
                icon: Icons.edit_note,
                title: 'أدعية خاصة بك',
                message: 'أضف دعاءً أو ذكرًا تريد الرجوع إليه باستمرار.',
                action: FilledButton.icon(
                  onPressed: () => _editDua(context),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة دعاء'),
                ),
              )
            else
              for (var index = 0; index < category.items.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DhikrCard(
                    category: category,
                    item: category.items[index],
                    index: index,
                    done: progress[index] ?? 0,
                    total: category.items.length,
                  ),
                ),
          ],
        ),
      );
    },
  );

  Future<void> _editDua(BuildContext context, {int? index, DhikrItem? item}) =>
      DuaEditorSheet.show(context, index: index, item: item);

  Future<void> _confirmReset(
    BuildContext context,
    AdhkarCategory category,
  ) async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بدء الورد من جديد؟'),
        content: const Text('سيعود عدّ جميع الأذكار في هذا الباب إلى الصفر.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إعادة العد'),
          ),
        ],
      ),
    );
    if (reset == true && context.mounted) {
      await context.read<AdhkarCubit>().resetCategory(category.id);
    }
  }
}

class _DhikrCard extends StatelessWidget {
  const _DhikrCard({
    required this.category,
    required this.item,
    required this.index,
    required this.done,
    required this.total,
  });
  final AdhkarCategory category;
  final DhikrItem item;
  final int index;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final remaining = (item.count - done).clamp(0, item.count);
    final completed = remaining == 0;
    return MishkatCard(
      padding: EdgeInsets.zero,
      color: completed
          ? context.mishkat.success.withValues(alpha: 0.07)
          : context.mishkat.surface,
      borderColor: completed
          ? context.mishkat.success.withValues(alpha: 0.30)
          : context.mishkat.border,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: completed
            ? null
            : () {
                HapticFeedback.selectionClick();
                context.read<AdhkarCubit>().increment(category.id, index);
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'الذكر ${index + 1} من $total',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.mishkat.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (completed)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 17,
                          color: context.mishkat.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'تم',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mishkat.success,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (item.title.isNotEmpty) ...[
                Text(
                  item.title,
                  style: TextStyle(
                    color: context.mishkat.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                item.text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  height: 1.95,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: completed
                          ? 'اكتمل الذكر'
                          : 'اضغط للعد، المتبقي $remaining من ${item.count}',
                      child: FilledButton.tonalIcon(
                        onPressed: completed
                            ? null
                            : () => context.read<AdhkarCubit>().increment(
                                category.id,
                                index,
                              ),
                        icon: Icon(
                          completed
                              ? Icons.check_rounded
                              : Icons.touch_app_outlined,
                        ),
                        label: Text(
                          completed
                              ? 'اكتمل'
                              : 'بقي $remaining من ${item.count}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'نسخ',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: item.text));
                      if (context.mounted) context.showMessage('تم نسخ الذكر.');
                    },
                    icon: const Icon(Icons.copy_outlined),
                  ),
                  IconButton(
                    tooltip: 'إعادة العد',
                    onPressed: () =>
                        context.read<AdhkarCubit>().reset(category.id, index),
                    icon: const Icon(Icons.refresh),
                  ),
                  if (category.custom)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          context.read<AdhkarCubit>().deleteCustom(index);
                        }
                        if (value == 'edit') _openEditor(context);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('تعديل')),
                        PopupMenuItem(value: 'delete', child: Text('حذف')),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context) =>
      DuaEditorSheet.show(context, index: index, item: item);
}
