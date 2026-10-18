import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/local_storage_service.dart';
import '../../data/models/khatma_plan.dart';
import 'khatma_state.dart';

class KhatmaCubit extends Cubit<KhatmaState> {
  KhatmaCubit(this._storage) : super(const KhatmaState()) {
    load();
  }
  final LocalStorageService _storage;

  void load() {
    final saved = _storage.readMap('khatma');
    final plans = <KhatmaPlan>[
      if (saved['plans'] is List)
        for (final item in saved['plans'] as List)
          if (item is Map) KhatmaPlan.fromJson(Map<String, dynamic>.from(item)),
    ];
    final activeId = saved['activeId'] as String?;
    emit(
      KhatmaState(
        plans: plans,
        activeId: plans.any((item) => item.id == activeId)
            ? activeId
            : plans.firstOrNull?.id,
      ),
    );
  }

  Future<void> create({
    required String name,
    required int durationDays,
    required int startPage,
    String? reminderPrayer,
  }) async {
    final safeStart = startPage.clamp(1, 604);
    final duration = durationDays.clamp(1, 3650);
    final plan = KhatmaPlan(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'ختمتي' : name.trim(),
      durationDays: duration,
      dailyPages: ((604 - safeStart + 1) / duration).ceil().clamp(1, 604),
      startDate: DateTime.now(),
      startPage: safeStart,
      progressPage: safeStart - 1,
      status: KhatmaStatus.active,
      reminderPrayer: reminderPrayer,
      createdAt: DateTime.now(),
    );
    emit(KhatmaState(plans: [plan, ...state.plans], activeId: plan.id));
    await _persist();
  }

  Future<void> setActive(String id) async {
    if (!state.plans.any((item) => item.id == id)) return;
    emit(state.copyWith(activeId: id));
    await _persist();
  }

  Future<void> recordProgress(int page) async {
    final plan = state.active;
    if (plan == null) return;
    final safe = page.clamp(plan.startPage - 1, 604);
    final completed = safe >= 604;
    final updated = plan.copyWith(
      progressPage: safe,
      status: completed ? KhatmaStatus.completed : KhatmaStatus.active,
      completedAt: completed ? DateTime.now() : null,
      pausedAt: null,
    );
    await _replace(updated);
  }

  Future<void> completeToday() async {
    final plan = state.active;
    if (plan == null) return;
    await recordProgress(math.min(604, plan.progressPage + plan.dailyPages));
  }

  Future<void> togglePause() async {
    final plan = state.active;
    if (plan == null || plan.status == KhatmaStatus.completed) return;
    final paused = plan.status != KhatmaStatus.paused;
    await _replace(
      plan.copyWith(
        status: paused ? KhatmaStatus.paused : KhatmaStatus.active,
        pausedAt: paused ? DateTime.now() : null,
      ),
    );
  }

  Future<void> rebalance(int remainingDays) async {
    final plan = state.active;
    if (plan == null || plan.remainingPages == 0) return;
    final days = remainingDays.clamp(1, 3650);
    await _replace(
      plan.copyWith(
        durationDays: days,
        dailyPages: (plan.remainingPages / days).ceil().clamp(1, 604),
      ),
    );
  }

  Future<void> delete(String id) async {
    final plans = state.plans.where((item) => item.id != id).toList();
    emit(KhatmaState(plans: plans, activeId: plans.firstOrNull?.id));
    await _persist();
  }

  Future<void> _replace(KhatmaPlan plan) async {
    emit(
      state.copyWith(
        plans: [
          for (final item in state.plans)
            if (item.id == plan.id) plan else item,
        ],
      ),
    );
    await _persist();
  }

  Future<void> _persist() => _storage.writeMap('khatma', {
    'activeId': state.activeId,
    'plans': state.plans.map((item) => item.toJson()).toList(),
  });
}
