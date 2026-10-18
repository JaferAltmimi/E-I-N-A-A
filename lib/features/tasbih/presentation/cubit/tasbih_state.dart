import 'package:equatable/equatable.dart';

class TasbihState extends Equatable {
  const TasbihState({this.count = 0, this.total = 0, this.target = 33});
  final int count;
  final int total;
  final int target;

  bool get completed => count >= target;
  double get progress => (count / target).clamp(0, 1);

  TasbihState copyWith({int? count, int? total, int? target}) => TasbihState(
    count: count ?? this.count,
    total: total ?? this.total,
    target: target ?? this.target,
  );

  @override
  List<Object?> get props => [count, total, target];
}
