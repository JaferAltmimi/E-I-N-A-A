import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../../data/models/adhkar_models.dart';
import '../cubit/adhkar_cubit.dart';
import '../cubit/adhkar_state.dart';
import 'adhkar_reader_page.dart';

class AdhkarPage extends StatelessWidget {
  const AdhkarPage({super.key});
  static const favorites = [1, 2, 3, 27, 129, 130, 13, 96];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdhkarCubit, AdhkarState>(
      builder: (context, state) {
        if (state.status == AdhkarStatus.initial ||
            state.status == AdhkarStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == AdhkarStatus.failure) {
          return ContentStatePanel(
            icon: Icons.auto_awesome_outlined,
            title: 'تعذّر تحميل الأذكار',
            message: state.error ?? 'حاول مرة أخرى.',
            action: MishkatPrimaryButton(
              onPressed: context.read<AdhkarCubit>().load,
              label: 'إعادة المحاولة',
            ),
          );
        }
        final categories = context.read<AdhkarCubit>().filteredCategories();
        return ListView(
          key: const PageStorageKey('adhkar-index'),
          padding: MishkatSpacing.page,
          children: [
            Text(
              'حصن المسلم',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: context.mishkat.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'الأذكار',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'ورد قريب، وعدّاد يحفظ تقدّمك.',
              style: TextStyle(color: context.mishkat.textSecondary),
            ),
            const SizedBox(height: MishkatSpacing.lg),
            TextField(
              onChanged: context.read<AdhkarCubit>().search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'ابحث في الأذكار والأدعية',
              ),
            ),
            if (state.query.isEmpty) ...[
              const SizedBox(height: MishkatSpacing.lg),
              const SectionHeading(title: 'الأكثر قراءة'),
              SizedBox(
                height: 104,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: favorites.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: MishkatSpacing.sm),
                  itemBuilder: (context, index) {
                    final category = index == 0
                        ? state.allCategories.first
                        : state.categories
                              .where((item) => item.id == favorites[index - 1])
                              .firstOrNull;
                    if (category == null) return const SizedBox.shrink();
                    return _QuickDhikr(
                      category: category,
                      onTap: () => _open(context, category),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: MishkatSpacing.lg),
            SectionHeading(
              title: state.query.isEmpty
                  ? 'جميع الأبواب'
                  : '${categories.length} نتيجة',
            ),
            if (categories.isEmpty)
              const ContentStatePanel(
                icon: Icons.search_off_rounded,
                title: 'لا توجد نتائج',
                message: 'جرّب عبارة أقصر أو كلمة أخرى.',
              )
            else
              for (final category in categories)
                Padding(
                  padding: const EdgeInsets.only(bottom: MishkatSpacing.xs),
                  child: MishkatCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MishkatSpacing.md,
                      vertical: MishkatSpacing.sm,
                    ),
                    onTap: () => _open(context, category),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.mishkat.primarySoft,
                            borderRadius: BorderRadius.circular(MishkatRadius.md),
                            border: Border.all(color: context.mishkat.border),
                          ),
                          child: Icon(
                            category.custom
                                ? Icons.edit_note_rounded
                                : Icons.auto_awesome_rounded,
                            color: context.mishkat.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: MishkatSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${category.items.length} ذكرًا',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.mishkat.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_left_rounded,
                          color: context.mishkat.textMuted,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  Future<void> _open(BuildContext context, AdhkarCategory category) async {
    context.read<AdhkarCubit>().select(category.id);
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const AdhkarReaderPage()),
    );
  }
}

class _QuickDhikr extends StatelessWidget {
  const _QuickDhikr({required this.category, required this.onTap});
  final AdhkarCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 140,
    child: MishkatCard(
      padding: const EdgeInsets.all(MishkatSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            category.custom
                ? Icons.edit_note_rounded
                : Icons.auto_awesome_rounded,
            color: context.mishkat.primary,
            size: 22,
          ),
          const Spacer(),
          Text(
            category.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}
