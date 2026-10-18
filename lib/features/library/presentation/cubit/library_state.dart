import 'package:equatable/equatable.dart';

import '../../data/models/library_models.dart';

enum LibraryStatus { initial, loading, ready, failure }

enum LibrarySection { books, khatma }

class LibraryState extends Equatable {
  const LibraryState({
    this.status = LibraryStatus.initial,
    this.section = LibrarySection.books,
    this.books = const [],
    this.favorites = const {},
    this.history = const [],
    this.query = '',
    this.selectedBook,
    this.entries = const [],
    this.error,
  });
  final LibraryStatus status;
  final LibrarySection section;
  final List<LibraryBook> books;
  final Set<String> favorites;
  final List<String> history;
  final String query;
  final LibraryBook? selectedBook;
  final List<LibraryEntry> entries;
  final String? error;

  LibraryState copyWith({
    LibraryStatus? status,
    LibrarySection? section,
    List<LibraryBook>? books,
    Set<String>? favorites,
    List<String>? history,
    String? query,
    LibraryBook? selectedBook,
    List<LibraryEntry>? entries,
    String? error,
  }) => LibraryState(
    status: status ?? this.status,
    section: section ?? this.section,
    books: books ?? this.books,
    favorites: favorites ?? this.favorites,
    history: history ?? this.history,
    query: query ?? this.query,
    selectedBook: selectedBook ?? this.selectedBook,
    entries: entries ?? this.entries,
    error: error ?? this.error,
  );

  @override
  List<Object?> get props => [
    status,
    section,
    books,
    favorites,
    history,
    query,
    selectedBook,
    entries,
    error,
  ];
}
