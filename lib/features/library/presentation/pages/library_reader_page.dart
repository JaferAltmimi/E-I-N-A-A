import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../cubit/library_cubit.dart';
import '../cubit/library_state.dart';

class LibraryReaderPage extends StatelessWidget {
  const LibraryReaderPage({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<LibraryCubit, LibraryState>(
    builder: (context, state) {
      final book = state.selectedBook;
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_forward_rounded),
            tooltip: 'رجوع',
          ),
          title: Text(book?.title ?? 'الكتاب'),
        ),
        body: book == null
            ? const ContentStatePanel(
                icon: Icons.menu_book_outlined,
                title: 'الكتاب غير متاح',
                message: 'ارجع إلى المكتبة واختر كتابًا.',
              )
            : ListView(
                padding: MishkatSpacing.page,
                children: [
                  Text(
                    book.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.mishkat.textSecondary,
                    ),
                  ),
                  const SizedBox(height: MishkatSpacing.sm),
                  Text(
                    'هذه نسخة عيّنة موثقة تضم ${state.entries.length} من أصل ${book.expectedItems} حديثًا.',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.mishkat.textMuted,
                    ),
                  ),
                  const SizedBox(height: MishkatSpacing.lg),
                  for (final entry in state.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MishkatSpacing.base),
                      child: MishkatCard(
                        padding: const EdgeInsets.all(MishkatSpacing.base),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'الحديث ${entry.number} · ${entry.chapter}',
                              style: TextStyle(
                                color: context.mishkat.gold,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.title,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (entry.narrator.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                entry.narrator,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.mishkat.textSecondary,
                                ),
                              ),
                            ],
                            const Divider(height: MishkatSpacing.xl),
                            Text(
                              entry.text,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontSize: 17,
                                height: 1.9,
                              ),
                            ),
                            const SizedBox(height: MishkatSpacing.md),
                            Text(
                              entry.reference,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: context.mishkat.textSecondary,
                              ),
                            ),
                            const SizedBox(height: MishkatSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(
                                        text:
                                            '${entry.title}\n\n${entry.text}\n\n${entry.reference}',
                                      ),
                                    );
                                    if (context.mounted) {
                                      context.showMessage('تم نسخ الحديث.');
                                    }
                                  },
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  label: const Text('نسخ'),
                                ),
                                if (entry.sourceUrl.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: () => launchUrl(
                                      Uri.parse(entry.sourceUrl),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                    label: const Text('المصدر'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      );
    },
  );
}
