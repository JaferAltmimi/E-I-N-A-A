import 'dart:math' as math;

import 'package:equatable/equatable.dart';

enum KhatmaStatus { active, paused, completed }

class KhatmaPlan extends Equatable {
  const KhatmaPlan({
    required this.id,
    required this.name,
    required this.durationDays,
    required this.dailyPages,
    required this.startDate,
    required this.startPage,
    required this.progressPage,
    required this.status,
    required this.createdAt,
    this.lastReadPage,
    this.currentWardEndPage,
    this.reminderPrayer,
    this.pausedAt,
    this.completedAt,
  });

  final String id;
  final String name;
  final int durationDays;
  final int dailyPages;
  final DateTime startDate;
  final int startPage;
  final int progressPage;
  final int? lastReadPage;
  final int? currentWardEndPage;
  final KhatmaStatus status;
  final String? reminderPrayer;
  final DateTime createdAt;
  final DateTime? pausedAt;
  final DateTime? completedAt;

  int get totalPages => 604 - startPage + 1;
  int get completedPages => math.max(0, progressPage - startPage + 1);
  int get nextPage => math.min(604, math.max(startPage, progressPage + 1));
  int get resumePage =>
      math.min(604, math.max(nextPage, lastReadPage ?? nextPage));
  int get todayEnd {
    final savedTarget = currentWardEndPage;
    if (savedTarget != null && savedTarget >= nextPage) {
      return savedTarget.clamp(nextPage, 604).toInt();
    }
    return math.min(604, math.max(progressPage, nextPage + dailyPages - 1));
  }

  double get progress => (completedPages / totalPages).clamp(0, 1);
  int get remainingPages => math.max(0, 604 - progressPage);
  int get remainingDays => (remainingPages / dailyPages).ceil();
  DateTime get targetDate => startDate.add(Duration(days: durationDays - 1));
  int get elapsedDays => math.max(
    1,
    DateTime.now()
            .difference(
              DateTime(startDate.year, startDate.month, startDate.day),
            )
            .inDays +
        1,
  );

  factory KhatmaPlan.fromJson(Map<String, dynamic> json) => KhatmaPlan(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'ختمتي',
    durationDays: (json['durationDays'] as num?)?.toInt() ?? 30,
    dailyPages: (json['dailyPages'] as num?)?.toInt() ?? 21,
    startDate:
        DateTime.tryParse(json['startDate'] as String? ?? '') ?? DateTime.now(),
    startPage: (json['startPage'] as num?)?.toInt() ?? 1,
    progressPage: (json['progressPage'] as num?)?.toInt() ?? 0,
    lastReadPage: (json['lastReadPage'] as num?)?.toInt(),
    currentWardEndPage: (json['currentWardEndPage'] as num?)?.toInt(),
    status: KhatmaStatus.values.firstWhere(
      (item) => item.name == json['status'],
      orElse: () => KhatmaStatus.active,
    ),
    reminderPrayer: json['reminderPrayer'] as String?,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    pausedAt: DateTime.tryParse(json['pausedAt'] as String? ?? ''),
    completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'durationDays': durationDays,
    'dailyPages': dailyPages,
    'startDate': startDate.toIso8601String(),
    'startPage': startPage,
    'progressPage': progressPage,
    'lastReadPage': lastReadPage,
    'currentWardEndPage': currentWardEndPage,
    'status': status.name,
    'reminderPrayer': reminderPrayer,
    'createdAt': createdAt.toIso8601String(),
    'pausedAt': pausedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  KhatmaPlan copyWith({
    String? name,
    int? durationDays,
    int? dailyPages,
    int? progressPage,
    Object? lastReadPage = _unset,
    Object? currentWardEndPage = _unset,
    KhatmaStatus? status,
    Object? reminderPrayer = _unset,
    Object? pausedAt = _unset,
    Object? completedAt = _unset,
  }) => KhatmaPlan(
    id: id,
    name: name ?? this.name,
    durationDays: durationDays ?? this.durationDays,
    dailyPages: dailyPages ?? this.dailyPages,
    startDate: startDate,
    startPage: startPage,
    progressPage: progressPage ?? this.progressPage,
    lastReadPage: identical(lastReadPage, _unset)
        ? this.lastReadPage
        : lastReadPage as int?,
    currentWardEndPage: identical(currentWardEndPage, _unset)
        ? this.currentWardEndPage
        : currentWardEndPage as int?,
    status: status ?? this.status,
    reminderPrayer: identical(reminderPrayer, _unset)
        ? this.reminderPrayer
        : reminderPrayer as String?,
    createdAt: createdAt,
    pausedAt: identical(pausedAt, _unset)
        ? this.pausedAt
        : pausedAt as DateTime?,
    completedAt: identical(completedAt, _unset)
        ? this.completedAt
        : completedAt as DateTime?,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    durationDays,
    dailyPages,
    startDate,
    startPage,
    progressPage,
    lastReadPage,
    currentWardEndPage,
    status,
    reminderPrayer,
    createdAt,
    pausedAt,
    completedAt,
  ];
}

const _unset = Object();
