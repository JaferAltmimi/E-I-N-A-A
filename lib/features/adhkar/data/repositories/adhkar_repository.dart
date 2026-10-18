import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/adhkar_models.dart';

class AdhkarRepository {
  List<AdhkarCategory>? _cache;

  Future<List<AdhkarCategory>> load() async {
    if (_cache case final List<AdhkarCategory> data) return data;
    final decoded = jsonDecode(
      await rootBundle.loadString('assets/data/adhkar.json'),
    ) as List;
    final categories = decoded
        .map(
          (item) =>
              AdhkarCategory.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
    _cache = categories;
    return categories;
  }
}
