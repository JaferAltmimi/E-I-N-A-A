import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/local_storage_service.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../data/models/library_models.dart';
import '../../data/repositories/library_repository.dart';
import 'library_state.dart';

class LibraryCubit extends Cubit<LibraryState> {
  LibraryCubit(this._repository, this._storage) : super(const LibraryState());
  final LibraryRepository _repository;
  final LocalStorageService _storage;

  Future<void> load() async {
    emit(state.copyWith(status: LibraryStatus.loading));
    try {
      final books = await _repository.loadCatalog();
      final saved = _storage.readMap('library');
      emit(
        state.copyWith(
          status: LibraryStatus.ready,
          books: books,
          favorites: (saved['favorites'] as List? ?? const [])
              .map((item) => '$item')
              .toSet(),
          history: (saved['history'] as List? ?? const [])
              .map((item) => '$item')
              .toList(),
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          status: LibraryStatus.failure,
          error: 'تعذّر تحميل المكتبة: $error',
        ),
      );
    }
  }

  void setSection(LibrarySection value) => emit(state.copyWith(section: value));
  void search(String value) => emit(state.copyWith(query: value));

  List<LibraryBook> filteredBooks() {
    final query = AppFormatters.normalizeArabic(state.query);
    if (query.isEmpty) return state.books;
    return state.books
        .where(
          (book) => AppFormatters.normalizeArabic(
            '${book.title} ${book.author} ${book.category}',
          ).contains(query),
        )
        .toList();
  }

  Future<void> openBook(LibraryBook book) async {
    emit(state.copyWith(status: LibraryStatus.loading, selectedBook: book));
    try {
      final entries = await _repository.loadBook(book);
      final history = [
        book.id,
        ...state.history.where((id) => id != book.id),
      ].take(30).toList();
      emit(
        state.copyWith(
          status: LibraryStatus.ready,
          selectedBook: book,
          entries: entries,
          history: history,
        ),
      );
      await _persist();
    } on Object catch (error) {
      emit(
        state.copyWith(
          status: LibraryStatus.failure,
          error: 'تعذّر فتح الكتاب: $error',
        ),
      );
    }
  }

  Future<void> toggleFavorite(String id) async {
    final favorites = {...state.favorites};
    favorites.contains(id) ? favorites.remove(id) : favorites.add(id);
    emit(state.copyWith(favorites: favorites));
    await _persist();
  }

  Future<void> _persist() => _storage.writeMap('library', {
    'favorites': state.favorites.toList(),
    'history': state.history,
  });
}
