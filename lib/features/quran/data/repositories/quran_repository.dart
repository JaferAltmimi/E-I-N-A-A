import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../../core/utils/app_formatters.dart';
import '../models/quran_models.dart';

class QuranRepository {
  QuranData? _cache;

  Future<QuranData> load() async {
    if (_cache case final QuranData data) return data;
    final raw = await Future.wait([
      rootBundle.loadString('assets/data/quran.json'),
      rootBundle.loadString('assets/data/hafs-kfqc-manifest.json'),
    ]);
    final quran = Map<String, dynamic>.from(jsonDecode(raw[0]) as Map);
    final manifest = Map<String, dynamic>.from(jsonDecode(raw[1]) as Map);
    final data = QuranData(
      chapters: (quran['surahs'] as List)
          .map(
            (item) =>
                QuranChapter.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
      juz: (quran['juz'] as List)
          .map(
            (item) => JuzStart.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
      pages: (manifest['pages'] as List)
          .map(
            (item) =>
                MushafPageInfo.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
    );
    _cache = data;
    return data;
  }

  List<QuranSearchResult> search(
    QuranData data,
    String query, {
    int limit = 80,
  }) {
    final normalized = AppFormatters.normalizeArabic(query);
    if (normalized.isEmpty) return const [];
    final number = int.tryParse(query.trim());
    final results = <QuranSearchResult>[];
    for (final chapter in data.chapters) {
      if (chapter.number == number ||
          AppFormatters.normalizeArabic(chapter.name).contains(normalized) ||
          AppFormatters.normalizeArabic(chapter.englishName)
              .contains(normalized)) {
        results.add(QuranSearchResult(chapter: chapter));
      }
      for (
        var index = 0;
        index < chapter.ayahs.length && results.length < limit;
        index++
      ) {
        final text = chapter.ayahs[index];
        if (AppFormatters.normalizeArabic(text).contains(normalized)) {
          results.add(
            QuranSearchResult(chapter: chapter, ayah: index + 1, text: text),
          );
        }
      }
      if (results.length >= limit) break;
    }
    return results;
  }
}
