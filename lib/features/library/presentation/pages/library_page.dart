import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../../../khatma/presentation/pages/khatma_page.dart';
import '../../data/models/library_models.dart';
import '../cubit/library_cubit.dart';
import '../cubit/library_state.dart';
import 'library_reader_page.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<LibraryCubit, LibraryState>(
    builder: (context, state) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MishkatSpacing.base,
            MishkatSpacing.md,
            MishkatSpacing.base,
            0,
          ),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<LibrarySection>(
              segments: const [
                ButtonSegment(
                  value: LibrarySection.books,
                  icon: Icon(Icons.local_library_outlined, size: 18),
                  label: Text('المكتبة'),
                ),
                ButtonSegment(
                  value: LibrarySection.khatma,
                  icon: Icon(Icons.route_outlined, size: 18),
                  label: Text('الختمة'),
                ),
              ],
              selected: {state.section},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  context.read<LibraryCubit>().setSection(value.first),
            ),
          ),
        ),
        Expanded(
          child: state.section == LibrarySection.books
              ? _BooksView(state: state)
              : const KhatmaPage(),
        ),
      ],
    ),
  );
}

class _BooksView extends StatelessWidget {
  const _BooksView({required this.state});
  final LibraryState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == LibraryStatus.loading && state.books.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == LibraryStatus.failure && state.books.isEmpty) {
      return ContentStatePanel(
        icon: Icons.local_library_outlined,
        title: 'تعذّر تحميل المكتبة',
        message: state.error ?? 'حدث خطأ غير متوقع.',
        action: MishkatPrimaryButton(
          onPressed: context.read<LibraryCubit>().load,
          label: 'إعادة المحاولة',
        ),
      );
    }
    final books = context.read<LibraryCubit>().filteredBooks();
    return ListView(
      key: const PageStorageKey('library-books'),
      padding: MishkatSpacing.page,
      children: [
        Text(
          'قراءة موثقة',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: context.mishkat.gold,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text('المكتبة الإسلامية', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
        )),
        Text(
          'كتب مختارة تُحفظ داخل التطبيق للقراءة دون إنترنت.',
          style: TextStyle(color: context.mishkat.textSecondary),
        ),
        const SizedBox(height: MishkatSpacing.lg),
        TextField(
          onChanged: context.read<LibraryCubit>().search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'ابحث عن كتاب أو مؤلف',
          ),
        ),
        const SizedBox(height: MishkatSpacing.lg),
        const SectionHeading(title: 'الكتب المتاحة'),
        if (books.isEmpty)
          const ContentStatePanel(
            icon: Icons.search_off_rounded,
            title: 'لا توجد نتائج',
            message: 'جرّب اسمًا أو تصنيفًا آخر.',
          )
        else
          for (final book in books)
            Padding(
              padding: const EdgeInsets.only(bottom: MishkatSpacing.sm),
              child: _BookCard(
                book: book,
                favorite: state.favorites.contains(book.id),
              ),
            ),
        const SizedBox(height: MishkatSpacing.md),
        MishkatCard(
          padding: const EdgeInsets.all(MishkatSpacing.base),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_outlined,
                color: context.mishkat.primary,
                size: 22,
              ),
              const SizedBox(width: MishkatSpacing.md),
              Expanded(
                child: Text(
                  'تعرض المكتبة النصوص التي تتوفر لها حزمة موثقة ومصدر واضح فقط.',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.mishkat.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.favorite});
  final LibraryBook book;
  final bool favorite;

  @override
  Widget build(BuildContext context) => MishkatCard(
    padding: const EdgeInsets.all(MishkatSpacing.base),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 68,
              decoration: BoxDecoration(
                color: context.mishkat.primarySoft,
                borderRadius: BorderRadius.circular(MishkatRadius.md),
                border: Border.all(color: context.mishkat.border),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 28,
                color: context.mishkat.primary,
              ),
            ),
            const SizedBox(width: MishkatSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.mishkat.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MishkatSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.mishkat.surfaceMuted,
                      borderRadius: BorderRadius.circular(MishkatRadius.sm),
                    ),
                    child: Text(
                      '${book.category} · ${book.availableItems} من ${book.expectedItems} حديثًا',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.mishkat.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: favorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
              onPressed: () =>
                  context.read<LibraryCubit>().toggleFavorite(book.id),
              icon: Icon(
                favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: favorite ? Colors.redAccent : context.mishkat.textMuted,
                size: 22,
              ),
            ),
          ],
        ),
        const SizedBox(height: MishkatSpacing.md),
        Text(
          book.description,
          style: TextStyle(
            fontSize: 13,
            color: context.mishkat.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: MishkatSpacing.md),
        MishkatPrimaryButton(
          onPressed: () async {
            await context.read<LibraryCubit>().openBook(book);
            if (context.mounted &&
                context.read<LibraryCubit>().state.status ==
                    LibraryStatus.ready) {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const LibraryReaderPage(),
                ),
              );
            }
          },
          icon: const Icon(Icons.download_done_rounded),
          label: 'فتح النسخة المحفوظة',
        ),
      ],
    ),
  );
}
