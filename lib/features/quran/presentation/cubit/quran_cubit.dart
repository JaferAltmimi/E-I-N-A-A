import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/services/audio_repeat_controller.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../data/models/quran_audio_station.dart';
import '../../data/models/quran_models.dart';
import '../../data/repositories/quran_repository.dart';
import '../../domain/models/audio_repeat_config.dart';
import 'quran_state.dart';

class QuranCubit extends Cubit<QuranState> {
  QuranCubit({
    required this._repository,
    required this._storage,
    required this._audio,
    required this.reciter,
    required double fontSize,
    this.autoScroll = true,
  }) : super(QuranState(fontSize: fontSize)) {
    _playerSubscription = _audio.playerState.listen(_onPlayerState);
    _repeatController = AudioRepeatController(
      onPlayAyahRequested: (ayah) => _play(ayah, autoScroll: autoScroll),
      onSequenceCompleted: () {
        emit(
          state.copyWith(
            audioStatus: QuranAudioStatus.idle,
            audioGlobalAyah: null,
            repeatState: const AudioRepeatState(
              status: AudioRepeatStatus.completed,
            ),
          ),
        );
      },
    );
    _repeatSubscription = _repeatController.stateStream.listen(_onRepeatState);
  }

  final QuranRepository _repository;
  final LocalStorageService _storage;
  final QuranAudioService _audio;
  late final StreamSubscription<PlayerState> _playerSubscription;
  late final AudioRepeatController _repeatController;
  late final StreamSubscription<AudioRepeatState> _repeatSubscription;

  String reciter;
  bool _continuous = true;
  bool autoScroll;
  bool _advancingContinuously = false;

  QuranRepository get repository => _repository;
  QuranAudioService get audioService => _audio;
  AudioRepeatController get repeatController => _repeatController;
  bool get isContinuous => _continuous;
  void setContinuous(bool value) {
    _continuous = value;
    _repeatController.setContinuous(value);
  }

  void setAutoScroll(bool value) => autoScroll = value;

  Future<void> load() async {
    emit(state.copyWith(status: QuranStatus.loading, clearError: true));
    try {
      final data = await _repository.load();
      final saved = _storage.readMap('quran');
      final currentPage = ((saved['currentPage'] as num?)?.toInt() ?? 1).clamp(
        1,
        604,
      );
      QuranPoint? lastRead;
      if (saved['lastRead'] is Map) {
        try {
          final parsed = QuranPoint.fromJson(
            Map<String, dynamic>.from(saved['lastRead'] as Map),
          );
          if (parsed.global >= 1 &&
              parsed.global <= 6236 &&
              parsed.surah >= 1 &&
              parsed.surah <= 114) {
            lastRead = parsed;
          }
        } catch (_) {
          // Ignore corrupted lastRead entry
        }
      }
      final bookmarks = <QuranBookmark>[];
      final seenGlobals = <int>{};
      if (saved['bookmarks'] is List) {
        for (final item in saved['bookmarks'] as List) {
          if (item is Map) {
            try {
              final b = QuranBookmark.fromJson(Map<String, dynamic>.from(item));
              if (b.point.global >= 1 &&
                  b.point.global <= 6236 &&
                  !seenGlobals.contains(b.point.global)) {
                seenGlobals.add(b.point.global);
                bookmarks.add(b);
              }
            } catch (_) {
              // Safely ignore corrupted bookmark entry
            }
          }
        }
      }

      // Load saved repeat configuration
      var repeatConfig = AudioRepeatConfig.defaultConfig;
      final savedRepeat = _storage.readMap('audio_repeat_config');
      if (savedRepeat.isNotEmpty) {
        try {
          repeatConfig = AudioRepeatConfig.fromJson(savedRepeat);
        } catch (_) {}
      }
      _repeatController.updateConfig(repeatConfig);

      emit(
        state.copyWith(
          status: QuranStatus.ready,
          data: data,
          currentPage: currentPage,
          lastRead: lastRead,
          bookmarks: bookmarks,
          repeatConfig: repeatConfig,
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          status: QuranStatus.failure,
          error: 'تعذّر تحميل بيانات القرآن: $error',
        ),
      );
    }
  }

  void setMode(QuranIndexMode mode) => emit(state.copyWith(mode: mode));

  void search(String value) {
    final data = state.data;
    if (data == null) return;
    emit(
      state.copyWith(query: value, results: _repository.search(data, value)),
    );
  }

  void clearSearch() => emit(state.copyWith(query: '', results: []));

  Future<void> openPage(int page, {QuranPoint? point}) async {
    final safePage = page.clamp(1, 604);
    final data = state.data;
    final lastRead =
        point ??
        (data != null
            ? data.pointForGlobal(data.page(safePage).first.global)
            : state.lastRead);
    emit(state.copyWith(currentPage: safePage, lastRead: lastRead));
    await _persist();
  }

  Future<void> openSurah(int surah, {int ayah = 1}) async {
    final data = state.data;
    if (data == null) return;
    final global = data.globalFor(surah, ayah);
    await openPage(
      data.pageForGlobal(global),
      point: QuranPoint(surah: surah, ayah: ayah, global: global),
    );
  }

  Future<void> openJuz(int juzNumber) async {
    final data = state.data;
    if (data == null || data.juz.isEmpty) return;
    final safeJuz = juzNumber.clamp(1, data.juz.length);
    final juz = data.juz[safeJuz - 1];
    final global = data.globalFor(juz.surah, juz.ayah);
    final page = data.pageForGlobal(global);
    emit(
      state.copyWith(
        currentPage: page,
        lastRead: QuranPoint(surah: juz.surah, ayah: juz.ayah, global: global),
      ),
    );
    await _persist();
  }

  Future<void> toggleBookmark([QuranPoint? point, String? note]) async {
    final data = state.data;
    final targetPoint =
        point ?? state.lastRead ?? data?.page(state.currentPage).first;
    if (targetPoint == null) return;
    await toggleAyahBookmark(targetPoint.global, label: note);
  }

  Future<void> toggleAyahBookmark(int globalAyah, {String? label}) async {
    final data = state.data;
    if (data == null) return;
    final list = List<QuranBookmark>.from(state.bookmarks);
    final existingIndex = list.indexWhere(
      (item) => item.point.global == globalAyah,
    );
    if (existingIndex >= 0) {
      list.removeAt(existingIndex);
    } else {
      final safe = globalAyah.clamp(1, 6236);
      final point = data.pointForGlobal(safe);
      final page = data.pageForGlobal(safe);
      list.insert(
        0,
        QuranBookmark(
          point: point,
          createdAt: DateTime.now(),
          label: label,
          page: page,
        ),
      );
    }
    emit(state.copyWith(bookmarks: list));
    await _persist();
  }

  Future<void> clearAllBookmarks() async {
    emit(state.copyWith(bookmarks: const []));
    await _persist();
  }

  Future<void> removeBookmark(int globalAyah) async {
    final list = List<QuranBookmark>.from(state.bookmarks)
      ..removeWhere((item) => item.point.global == globalAyah);
    emit(state.copyWith(bookmarks: list));
    await _persist();
  }

  Future<void> updateBookmarkNote(int globalAyah, String note) async {
    final list = state.bookmarks.map((b) {
      if (b.point.global == globalAyah) {
        return QuranBookmark(
          page: b.page,
          point: b.point,
          createdAt: b.createdAt,
          label: note.trim().isEmpty ? null : note.trim(),
        );
      }
      return b;
    }).toList();
    emit(state.copyWith(bookmarks: list));
    await _persist();
  }

  Future<void> setLastRead(int globalAyah) async {
    final data = state.data;
    if (data == null) return;
    final safeGlobal = globalAyah.clamp(1, 6236);
    final point = data.pointForGlobal(safeGlobal);
    final page = data.pageForGlobal(safeGlobal);
    emit(state.copyWith(currentPage: page, lastRead: point));
    await _persist();
  }

  void setFontSize(double value) =>
      emit(state.copyWith(fontSize: value.clamp(20, 60)));

  Future<void> playCurrent({required bool continuous, bool? autoScroll}) async {
    final data = state.data;
    if (data == null) return;
    _continuous = continuous;
    _repeatController.setContinuous(continuous);
    if (autoScroll != null) this.autoScroll = autoScroll;
    final global =
        state.audioGlobalAyah ?? data.page(state.currentPage).first.global;
    await _play(global, autoScroll: autoScroll);
  }

  Future<void> playAyah(
    int global, {
    bool continuous = true,
    bool? autoScroll,
  }) async {
    _continuous = continuous;
    _repeatController.setContinuous(continuous);
    if (autoScroll != null) this.autoScroll = autoScroll;
    await _play(global, autoScroll: autoScroll);
  }

  int _playbackRequestId = 0;

  Future<void> _play(int global, {bool? autoScroll}) async {
    final data = state.data;
    if (data == null) return;
    final requestId = ++_playbackRequestId;
    final safe = global.clamp(1, 6236);
    final shouldScroll = autoScroll ?? this.autoScroll;
    final page = data.pageForGlobal(safe);
    if (shouldScroll && page != state.currentPage) {
      await openPage(page, point: data.pointForGlobal(safe));
    }
    if (requestId != _playbackRequestId) {
      return;
    }
    emit(
      state.copyWith(
        audioStatus: QuranAudioStatus.loading,
        audioGlobalAyah: safe,
        activeStation: null,
        clearError: true,
      ),
    );
    try {
      await _audio.playAyah(reciter: reciter, globalAyah: safe);
    } on QuranAudioOfflineException catch (e) {
      if (requestId != _playbackRequestId) return;
      emit(
        state.copyWith(audioStatus: QuranAudioStatus.failure, error: e.message),
      );
    } on Object {
      if (requestId != _playbackRequestId) return;
      emit(
        state.copyWith(
          audioStatus: QuranAudioStatus.failure,
          error: 'تعذّر تشغيل التلاوة. تحقق من اتصال الإنترنت.',
        ),
      );
    }
  }

  /// Plays a verified live stream or radio station through the single audio authority.
  ///
  /// Automatically stops any ongoing recitation or prior stream to avoid simultaneous playback.
  Future<void> playStation(QuranAudioStation station) async {
    final requestId = ++_playbackRequestId;
    _repeatController.stop();

    if (!station.isAudioPlayable || station.streamUrl == null) {
      emit(
        state.copyWith(
          audioStatus: QuranAudioStatus.failure,
          activeStation: station,
          audioGlobalAyah: null,
          error:
              station.notes ??
              'رابط البث غير معتمد حالياً. في انتظار اعتماد رابط رسمي موثق.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        audioStatus: QuranAudioStatus.loading,
        activeStation: station,
        audioGlobalAyah: null,
        clearError: true,
      ),
    );

    try {
      await _audio.playStreamUrl(
        station.streamUrl!,
        title: station.title,
        sourceLabel: station.sourceLabel,
      );
    } on QuranAudioOfflineException catch (e) {
      if (requestId != _playbackRequestId) return;
      emit(
        state.copyWith(audioStatus: QuranAudioStatus.failure, error: e.message),
      );
    } on Object {
      if (requestId != _playbackRequestId) return;
      emit(
        state.copyWith(
          audioStatus: QuranAudioStatus.failure,
          error: 'تعذّر الاتصال بالبث المباشر. تحقق من اتصال الإنترنت.',
        ),
      );
    }
  }

  Future<void> toggleAudio({required bool continuous, bool? autoScroll}) async {
    _continuous = continuous;
    _repeatController.setContinuous(continuous);
    if (autoScroll != null) this.autoScroll = autoScroll;

    if (state.activeStation != null) {
      if (_audio.isPlaying) {
        await _audio.pause();
      } else if (state.audioStatus == QuranAudioStatus.paused) {
        await _audio.resume();
      }
      return;
    }

    if (state.repeatState.isDelaying) {
      _repeatController.pause();
      emit(state.copyWith(audioStatus: QuranAudioStatus.paused));
    } else if (state.repeatState.isPaused &&
        state.repeatState.remainingDelaySeconds > 0) {
      _repeatController.resume();
      emit(state.copyWith(audioStatus: QuranAudioStatus.playing));
    } else if (_audio.isPlaying) {
      _repeatController.pause();
      await _audio.pause();
    } else if (state.audioStatus == QuranAudioStatus.paused) {
      _repeatController.resume();
      await _audio.resume();
    } else {
      await playCurrent(continuous: continuous, autoScroll: autoScroll);
    }
  }

  Future<void> stopAudio() async {
    _playbackRequestId++;
    _repeatController.stop();
    await _audio.stop();
    emit(
      state.copyWith(
        audioStatus: QuranAudioStatus.idle,
        audioGlobalAyah: null,
        activeStation: null,
        repeatState: const AudioRepeatState(),
      ),
    );
  }

  Future<void> nextAudioAyah({bool? autoScroll}) async {
    if (state.repeatConfig.mode != AudioRepeatMode.none) {
      _repeatController.next();
      return;
    }
    final current =
        state.audioGlobalAyah ??
        state.data?.page(state.currentPage).first.global ??
        1;
    if (current < 6236) {
      await _play(current + 1, autoScroll: autoScroll);
    } else {
      await stopAudio();
    }
  }

  Future<void> previousAudioAyah({bool? autoScroll}) async {
    if (state.repeatConfig.mode != AudioRepeatMode.none) {
      _repeatController.previous();
      return;
    }
    final current =
        state.audioGlobalAyah ??
        state.data?.page(state.currentPage).first.global ??
        1;
    if (current > 1) {
      await _play(current - 1, autoScroll: autoScroll);
    }
  }

  Future<void> seekAudio(Duration position) => _audio.seek(position);

  void skipDelay() => _repeatController.skipDelay();

  Future<void> setRepeatConfig(AudioRepeatConfig config) async {
    _repeatController.updateConfig(config);
    emit(state.copyWith(repeatConfig: config));
    await _storage.writeMap('audio_repeat_config', config.toJson());
  }

  Future<void> startRepeatPlayback(
    AudioRepeatConfig config, {
    int? initialGlobalAyah,
    List<int>? customQueue,
    bool? autoScroll,
  }) async {
    if (autoScroll != null) this.autoScroll = autoScroll;
    emit(state.copyWith(repeatConfig: config));
    await _storage.writeMap('audio_repeat_config', config.toJson());
    await _repeatController.start(
      config: config,
      initialGlobalAyah: initialGlobalAyah ?? state.audioGlobalAyah,
      customQueue: customQueue,
      continuous: _continuous,
    );
  }

  Future<void> playDailyJourney(
    List<int> queue, {
    AudioRepeatConfig? repeatConfig,
    bool? autoScroll,
  }) async {
    if (queue.isEmpty) return;
    final config =
        repeatConfig ??
        AudioRepeatConfig(
          mode: AudioRepeatMode.rangeLoop,
          startGlobalAyah: queue.first,
          endGlobalAyah: queue.last,
          rangeRepeatCount: 1,
          delaySeconds: 1,
        );
    await startRepeatPlayback(
      config,
      initialGlobalAyah: queue.first,
      customQueue: queue,
      autoScroll: autoScroll,
    );
  }

  void updateReciter(String value, {bool restartIfPlaying = true}) {
    if (reciter == value) return;
    reciter = value;
    if (restartIfPlaying &&
        (state.audioStatus == QuranAudioStatus.playing ||
            state.audioStatus == QuranAudioStatus.loading) &&
        state.audioGlobalAyah != null) {
      unawaited(_play(state.audioGlobalAyah!, autoScroll: false));
    }
  }

  void _onPlayerState(PlayerState player) {
    if (isClosed) return;
    if (player.processingState == ProcessingState.idle) {
      if (state.repeatState.isDelaying ||
          _advancingContinuously ||
          state.audioStatus == QuranAudioStatus.loading) {
        // just_audio briefly reports idle while replacing the completed Ayah
        // source. Keep the active Ayah intact until the next source is ready.
        return;
      }
      emit(
        state.copyWith(
          audioStatus: QuranAudioStatus.idle,
          audioGlobalAyah: null,
          activeStation: null,
        ),
      );
    } else if (player.processingState == ProcessingState.completed) {
      if (state.activeStation != null) {
        emit(
          state.copyWith(
            audioStatus: QuranAudioStatus.idle,
            activeStation: null,
          ),
        );
        return;
      }
      if (state.repeatConfig.mode != AudioRepeatMode.none) {
        _repeatController.onAyahPlaybackFinished();
      } else if (_continuous && (state.audioGlobalAyah ?? 6236) < 6236) {
        if (_advancingContinuously) return;
        _advancingContinuously = true;
        unawaited(
          nextAudioAyah(autoScroll: autoScroll).whenComplete(() {
            _advancingContinuously = false;
          }),
        );
      } else {
        emit(
          state.copyWith(
            audioStatus: QuranAudioStatus.idle,
            audioGlobalAyah: null,
            activeStation: null,
          ),
        );
      }
    } else if (player.playing) {
      emit(state.copyWith(audioStatus: QuranAudioStatus.playing));
    } else if (state.audioStatus == QuranAudioStatus.playing) {
      emit(state.copyWith(audioStatus: QuranAudioStatus.paused));
    }
  }

  void _onRepeatState(AudioRepeatState repeatState) {
    if (isClosed) return;
    if (repeatState.isDelaying) {
      emit(
        state.copyWith(
          repeatState: repeatState,
          audioStatus: QuranAudioStatus.playing,
          audioGlobalAyah: repeatState.currentAyah,
        ),
      );
    } else if (repeatState.isCompleted) {
      emit(
        state.copyWith(
          repeatState: repeatState,
          audioStatus: QuranAudioStatus.idle,
          audioGlobalAyah: null,
        ),
      );
    } else {
      emit(state.copyWith(repeatState: repeatState));
    }
  }

  Future<void> _persist() => _storage.writeMap('quran', {
    'currentPage': state.currentPage,
    'lastRead': state.lastRead?.toJson(),
    'bookmarks': state.bookmarks.map((item) => item.toJson()).toList(),
  });

  @override
  Future<void> close() async {
    await _playerSubscription.cancel();
    await _repeatSubscription.cancel();
    _repeatController.dispose();
    await _audio.dispose();
    return super.close();
  }
}
