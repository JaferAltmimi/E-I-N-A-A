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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '$completed من ${category.items.length} مكتمل',
                        style: TextStyle(color: context.mishkat.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (category.items.isNotEmpty)
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: CircularProgressIndicator(
                      value: completed / category.items.length,
                      strokeWidth: 6,
                      backgroundColor: context.mishkat.surfaceMuted,
                    ),
                  ),
              ],
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
                  ),
                ),
          ],
        ),
      );
    },
  );

  Future<void> _editDua(
    BuildContext context, {
    int? index,
    DhikrItem? item,
  }) =>
      DuaEditorSheet.show(context, index: index, item: item);
}

class _DhikrCard extends StatelessWidget {
  const _DhikrCard({
    required this.category,
    required this.item,
    required this.index,
    required this.done,
  });
  final AdhkarCategory category;
  final DhikrItem item;
  final int index;
  final int done;

  @override
  Widget build(BuildContext context) {
    final remaining = (item.count - done).clamp(0, item.count);
    final completed = remaining == 0;
    return MishkatCard(
      padding: EdgeInsets.zero,
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
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontSize: 18, height: 1.9),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: completed
                        ? null
                        : () => context.read<AdhkarCubit>().increment(
                            category.id,
                            index,
                          ),
                    icon: Icon(
                      completed ? Icons.check : Icons.touch_app_outlined,
                    ),
                    label: Text(
                      completed ? 'تم' : '$remaining / ${item.count}',
                    ),
                  ),
                  const Spacer(),
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
