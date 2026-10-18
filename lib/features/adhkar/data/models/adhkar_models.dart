import 'package:equatable/equatable.dart';

class DhikrItem extends Equatable {
  const DhikrItem({required this.text, required this.count, this.title = ''});
  final String text;
  final int count;
  final String title;

  factory DhikrItem.fromJson(Map<String, dynamic> json) => DhikrItem(
    text: json['t'] as String? ?? json['text'] as String? ?? '',
    count:
        (json['c'] as num?)?.toInt() ?? (json['count'] as num?)?.toInt() ?? 1,
    title: json['title'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'count': count,
    'title': title,
  };

  @override
  List<Object?> get props => [text, count, title];
}

class AdhkarCategory extends Equatable {
  const AdhkarCategory({
    required this.id,
    required this.name,
    required this.items,
    this.custom = false,
  });
  final int id;
  final String name;
  final List<DhikrItem> items;
  final bool custom;

  factory AdhkarCategory.fromJson(Map<String, dynamic> json) => AdhkarCategory(
    id: (json['id'] as num).toInt(),
    name: json['cat'] as String,
    items: (json['items'] as List)
        .map(
          (item) => DhikrItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false),
  );

  @override
  List<Object?> get props => [id, name, items, custom];
}
