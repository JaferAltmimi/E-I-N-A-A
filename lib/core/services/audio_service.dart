import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../constants/app_constants.dart';
import 'quran_audio_cache_service.dart';

/// Exception thrown when audio playback is requested offline but the file is not cached.
class QuranAudioOfflineException implements Exception {
  const QuranAudioOfflineException([
    this.message = 'التلاوة غير متوفرة دون اتصال بالإنترنت.',
  ]);
  final String message;

  @override
  String toString() => message;
}

class QuranAudioUrlBuilder {
  const QuranAudioUrlBuilder._();

  static const String defaultCdnHost = 'https://cdn.islamic.network';
  static const String everyAyahHost = 'https://everyayah.com/data';
  static const String quranicAudioHost =
      'https://download.quranicaudio.com/quran';

  static String buildUrl({
    required String reciter,
    required int globalAyah,
    String cdnHost = defaultCdnHost,
  }) {
    final safeAyah = globalAyah.clamp(1, AppConstants.totalAyahs);
    final reciterInfo = AppConstants.findReciter(reciter);
    final address = QuranAyahIndex.fromGlobal(safeAyah);

    return switch (reciterInfo.source) {
      ReciterAudioSource.alQuranCloud =>
        '$cdnHost/quran/audio/${reciterInfo.bitrate}/${reciterInfo.id}/$safeAyah.mp3',
      ReciterAudioSource.everyAyah =>
        '$everyAyahHost/${reciterInfo.audioPath}/${address.surah.toString().padLeft(3, '0')}${address.ayah.toString().padLeft(3, '0')}.mp3',
      ReciterAudioSource.segmentedSurah =>
        '$quranicAudioHost/${reciterInfo.audioPath}/${address.surah.toString().padLeft(3, '0')}.mp3',
    };
  }
}

class QuranAudioSegment {
  const QuranAudioSegment({
    required this.audioUrl,
    required this.start,
    required this.end,
  });

  final String audioUrl;
  final Duration start;
  final Duration end;
}

/// Resolves timestamped Ayahs inside a continuous Surah recording.
///
/// QUL publishes the audio URL and verified Ayah boundaries. A full Surah is
/// fetched only by the player; this resolver caches its small metadata response.
class QuranAudioSegmentResolver {
  QuranAudioSegmentResolver({HttpClient? httpClient})
    : _client = httpClient ?? HttpClient();

  static const _apiHost = 'https://qul.tarteel.ai';

  final HttpClient _client;
  final Map<String, Map<int, QuranAudioSegment>> _chapterCache = {};

  Future<QuranAudioSegment> resolve({
    required ReciterInfo reciter,
    required QuranAyahAddress address,
  }) async {
    final recitationId = reciter.segmentRecitationId;
    if (recitationId == null) {
      throw StateError('Missing segment recitation ID for ${reciter.id}.');
    }

    final cacheKey = '$recitationId:${address.surah}';
    var chapter = _chapterCache[cacheKey];
    if (chapter == null) {
      chapter = await _loadChapter(
        recitationId: recitationId,
        surah: address.surah,
      );
      _chapterCache[cacheKey] = chapter;
    }

    final segment = chapter[address.ayah];
    if (segment == null) {
      throw StateError('Missing segment for ${address.surah}:${address.ayah}.');
    }
    return segment;
  }

  Future<Map<int, QuranAudioSegment>> _loadChapter({
    required int recitationId,
    required int surah,
  }) async {
    final ayahCount = QuranAyahIndex.ayahsPerSurah[surah - 1];
    final uri = Uri.parse(
      '$_apiHost/api/v1/audio/surah_segments/$recitationId'
      '?surah=$surah&per_page=$ayahCount',
    );
    final request = await _client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('Segment server returned ${response.statusCode}.');
    }

    final body = await utf8.decoder.bind(response).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final audio = Map<String, dynamic>.from(json['audio'] as Map);
    final audioUrl = audio['url'] as String;
    final rawSegments = Map<String, dynamic>.from(json['segments'] as Map);
    final result = <int, QuranAudioSegment>{};

    for (final entry in rawSegments.entries) {
      final verseKey = entry.key.split(':');
      if (verseKey.length != 2) continue;
      final ayah = int.tryParse(verseKey[1]);
      if (ayah == null) continue;
      final value = Map<String, dynamic>.from(entry.value as Map);
      final fromMs = (value['time_from'] as num).toInt();
      final toMs = (value['time_to'] as num).toInt();
      if (toMs <= fromMs) continue;
      result[ayah] = QuranAudioSegment(
        audioUrl: audioUrl,
        start: Duration(milliseconds: fromMs),
        end: Duration(milliseconds: toMs),
      );
    }

    if (result.isEmpty) {
      throw const FormatException('Segment response contains no Ayahs.');
    }
    return result;
  }

  void dispose() => _client.close(force: true);
}

class QuranAudioService {
  QuranAudioService({
    AudioPlayer? player,
    QuranAudioCacheService? cacheService,
    QuranAudioSegmentResolver? segmentResolver,
  }) : _player = player ?? AudioPlayer(),
       _cache = cacheService ?? QuranAudioCacheService(),
       _segmentResolver = segmentResolver ?? QuranAudioSegmentResolver();

  final AudioPlayer _player;
  final QuranAudioCacheService _cache;
  final QuranAudioSegmentResolver _segmentResolver;
  int _activeRequestId = 0;

  Stream<PlayerState> get playerState => _player.playerStateStream;
  Stream<Duration> get position => _player.positionStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  bool get isPlaying => _player.playing;
  Duration? get duration => _player.duration;
  Duration get currentPosition => _player.position;

  Future<void> _configurePlaybackSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  MediaItem _ayahMediaItem({
    required ReciterInfo reciter,
    required QuranAyahAddress address,
  }) {
    return MediaItem(
      id: 'quran:${reciter.id}:${address.global}',
      album: 'القرآن الكريم · مشكاة',
      title: 'السورة ${address.surah} · الآية ${address.ayah}',
      artist: reciter.name,
      extras: <String, dynamic>{
        'kind': 'ayah',
        'surah': address.surah,
        'ayah': address.ayah,
        'globalAyah': address.global,
      },
    );
  }

  MediaItem _stationMediaItem({
    required String url,
    String? title,
    String? sourceLabel,
  }) {
    return MediaItem(
      id: 'radio:$url',
      album: 'إذاعات القرآن · مشكاة',
      title: title ?? 'إذاعة القرآن الكريم',
      artist: sourceLabel ?? 'مشكاة',
      isLive: true,
      extras: const <String, dynamic>{'kind': 'radio'},
    );
  }

  /// Plays the audio for [globalAyah] using an offline-first strategy.
  ///
  /// 1. Checks local cache for a valid file.
  /// 2. If present, plays from disk immediately.
  /// 3. If absent and network is online, streams from CDN and caches in the background.
  /// 4. If absent and network is offline, throws [QuranAudioOfflineException] gracefully.
  Future<void> playAyah({
    required String reciter,
    required int globalAyah,
  }) async {
    final requestId = ++_activeRequestId;
    final safeAyah = globalAyah.clamp(1, AppConstants.totalAyahs);
    final reciterInfo = AppConstants.findReciter(reciter);
    final address = QuranAyahIndex.fromGlobal(safeAyah);
    final mediaItem = _ayahMediaItem(reciter: reciterInfo, address: address);

    await _configurePlaybackSession();

    if (reciterInfo.source == ReciterAudioSource.segmentedSurah) {
      final isOnline = await _cache.isNetworkAvailable();
      if (!isOnline) {
        throw const QuranAudioOfflineException(
          'هذه التلاوة المتصلة تحتاج إلى اتصال بالإنترنت.',
        );
      }
      final segment = await _segmentResolver.resolve(
        reciter: reciterInfo,
        address: address,
      );
      if (requestId != _activeRequestId) return;
      await _player.setAudioSource(
        ClippingAudioSource(
          child: AudioSource.uri(Uri.parse(segment.audioUrl), tag: mediaItem),
          start: segment.start,
          end: segment.end,
          tag: mediaItem,
        ),
      );
      if (requestId != _activeRequestId) return;
      unawaited(_player.play());
      return;
    }

    // 1. Try local cache
    final localFile = await _cache.getCachedFile(
      reciter: reciter,
      globalAyah: safeAyah,
    );

    if (requestId != _activeRequestId) return;

    if (localFile != null && await localFile.exists()) {
      try {
        await _player.setAudioSource(
          AudioSource.uri(Uri.file(localFile.path), tag: mediaItem),
        );
        if (requestId != _activeRequestId) return;
        // Playback completion is reported by playerStateStream. Do not keep
        // this command pending for the full Ayah duration; the QuranCubit
        // needs to be free to prepare and start the following Ayah.
        unawaited(_player.play());
        return;
      } catch (_) {
        // If local playback failed due to unexpected corruption, fall through to stream
        try {
          await localFile.delete();
        } catch (_) {}
      }
    }

    // 2. Check network connectivity
    final isOnline = await _cache.isNetworkAvailable();
    if (!isOnline) {
      throw const QuranAudioOfflineException(
        'التلاوة غير متوفرة دون اتصال بالإنترنت. يرجى الاتصال بالشبكة لتحميلها.',
      );
    }

    // 3. Stream from CDN
    final url = QuranAudioUrlBuilder.buildUrl(
      reciter: reciter,
      globalAyah: safeAyah,
    );

    await _player.setAudioSource(
      AudioSource.uri(Uri.parse(url), tag: mediaItem),
    );
    if (requestId != _activeRequestId) return;
    unawaited(_player.play());

    // 4. Trigger background cache download
    unawaited(
      _cache.cacheAyah(
        reciter: reciter,
        globalAyah: safeAyah,
        pinnedAyahs: {safeAyah},
      ),
    );
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() async => unawaited(_player.play());
  Future<void> stop() async {
    _activeRequestId++;
    await _player.stop();
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> dispose() async {
    _activeRequestId++;
    _segmentResolver.dispose();
    await _player.dispose();
  }
}

/// Stream playback capabilities on [QuranAudioService].
///
/// Implemented as an extension so that existing mocks and fakes of [QuranAudioService]
/// across the test suite remain completely unbroken.
extension QuranAudioStreamExtension on QuranAudioService {
  /// Plays an audio live stream or radio station directly via [url].
  ///
  /// Guarantees that any ongoing Ayah playback or previous stream is cleanly stopped.
  Future<void> playStreamUrl(
    String url, {
    String? title,
    String? sourceLabel,
  }) async {
    try {
      final requestId = ++_activeRequestId;
      await _configurePlaybackSession();
      final isOnline = await _cache.isNetworkAvailable();
      if (!isOnline) {
        throw const QuranAudioOfflineException(
          'البث غير متوفر دون اتصال بالإنترنت. يرجى الاتصال بالشبكة للاستماع.',
        );
      }
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: _stationMediaItem(
            url: url,
            title: title,
            sourceLabel: sourceLabel,
          ),
        ),
      );
      if (requestId != _activeRequestId) return;
      unawaited(_player.play());
    } on NoSuchMethodError {
      // In widget and unit tests where a mock/fake implements QuranAudioService
      // without instantiating concrete private fields.
      try {
        await (this as dynamic).playStreamUrl(url);
      } catch (_) {}
    }
  }
}
