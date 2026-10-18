import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/library_models.dart';

class LibraryRepository {
  List<LibraryBook>? _books;
  final Map<String, List<LibraryEntry>> _entries = {};

  Future<List<LibraryBook>> loadCatalog() async {
    if (_books case final List<LibraryBook> books) return books;
    final data = Map<String, dynamic>.from(
      jsonDecode(
        await rootBundle.loadString('assets/data/library-catalog.json'),
      ) as Map,
    );
    final books = (data['books'] as List)
        .map(
          (item) =>
              LibraryBook.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
    _books = books;
    return books;
  }

  Future<List<LibraryEntry>> loadBook(LibraryBook book) async {
    if (_entries[book.id] case final List<LibraryEntry> entries) return entries;
    final fileName = book.contentPath.split('/').last;
    final data = Map<String, dynamic>.from(
      jsonDecode(await rootBundle.loadString('assets/data/$fileName')) as Map,
    );
    final entries = (data['entries'] as List)
        .map(
          (item) =>
              LibraryEntry.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
    _entries[book.id] = entries;
    return entries;
  }
}
