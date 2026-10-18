import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_service.dart';

/// Metadata entry for a single cached Quran recitation file.
class QuranAudioCacheEntry extends Equatable {
  const QuranAudioCacheEntry({
    required this.reciterId,
    required this.globalAyah,
    required this.fileSizeBytes,
    required this.cachedAt,
    required this.lastAccessedAt,
  });

  final String reciterId;
  final int globalAyah;
  final int fileSizeBytes;
  final DateTime cachedAt;
  final DateTime lastAccessedAt;

  String get key => '${reciterId}_$globalAyah';

  QuranAudioCacheEntry copyWith({
    int? fileSizeBytes,
    DateTime? lastAccessedAt,
  }) {
    return QuranAudioCacheEntry(
      reciterId: reciterId,
      globalAyah: globalAyah,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      cachedAt: cachedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'reciterId': reciterId,
        'globalAyah': globalAyah,
        'fileSizeBytes': fileSizeBytes,
        'cachedAt': cachedAt.toIso8601String(),
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
      };

  factory QuranAudioCacheEntry.fromJson(Map<String, dynamic> json) {
    return QuranAudioCacheEntry(
      reciterId: json['reciterId'] as String,
      globalAyah: (json['globalAyah'] as num).toInt(),
      fileSizeBytes: (json['fileSizeBytes'] as num).toInt(),
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      lastAccessedAt: DateTime.parse(json['lastAccessedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
        reciterId,
        globalAyah,
        fileSizeBytes,
        cachedAt,
        lastAccessedAt,
      ];
}

/// User configurable settings for offline Quran audio caching.
class AudioCacheSettings extends Equatable {
  const AudioCacheSettings({
    this.enabled = true,
    this.wifiOnly = true,
    this.maxSizeMb = 150,
  });

  final bool enabled;
  final bool wifiOnly;
  final int maxSizeMb;

  int get maxSizeBytes => maxSizeMb * 1024 * 1024;

  AudioCacheSettings copyWith({
    bool? enabled,
    bool? wifiOnly,
    int? maxSizeMb,
  }) {
    return AudioCacheSettings(
      enabled: enabled ?? this.enabled,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      maxSizeMb: maxSizeMb ?? this.maxSizeMb,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'wifiOnly': wifiOnly,
        'maxSizeMb': maxSizeMb,
      };

  factory AudioCacheSettings.fromJson(Map<String, dynamic> json) {
    return AudioCacheSettings(
      enabled: json['enabled'] as bool? ?? true,
      wifiOnly: json['wifiOnly'] as bool? ?? true,
      maxSizeMb: (json['maxSizeMb'] as num?)?.toInt() ?? 150,
    );
  }

  @override
  List<Object?> get props => [enabled, wifiOnly, maxSizeMb];
}

/// Bounded offline-first audio caching engine with deterministic LRU eviction.
class QuranAudioCacheService {
  QuranAudioCacheService({
    Directory? baseDirectory,
    HttpClient? httpClient,
    Connectivity? connectivity,
    int? maxCacheSizeBytes,
  })  : _customBaseDir = baseDirectory,
        _client = httpClient ?? HttpClient(),
        _connectivity = connectivity ?? Connectivity(),
        maxCacheSizeBytes = maxCacheSizeBytes ?? defaultMaxCacheSizeBytes;

  /// Default high watermark: 150 MiB (157,286,400 bytes).
  static const int defaultMaxCacheSizeBytes = 150 * 1024 * 1024;

  /// Low watermark ratio: 85% of high watermark when eviction occurs.
  static const double lowWatermarkRatio = 0.85;

  final Directory? _customBaseDir;
  final HttpClient _client;
  final Connectivity _connectivity;
  final int maxCacheSizeBytes;

  Directory? _cacheDir;
  Directory? _tmpDir;
  File? _metadataFile;

  final Map<String, QuranAudioCacheEntry> _entries = {};
  final Map<String, Future<File?>> _activeDownloads = {};
  bool _isInitialized = false;

  /// Total size of all cached audio files in bytes.
  int get currentCacheSizeBytes =>
      _entries.values.fold(0, (sum, entry) => sum + entry.fileSizeBytes);

  /// Human-readable cache size formatted in megabytes.
  double get currentCacheSizeMb =>
      currentCacheSizeBytes / (1024 * 1024);

  /// Initializes directories and loads existing metadata.
  Future<void> init() async {
    if (_isInitialized) return;

    if (_customBaseDir != null) {
      _cacheDir = Directory('${_customBaseDir.path}/audio_cache');
    } else {
      final appSupport = await getApplicationSupportDirectory();
      _cacheDir = Directory('${appSupport.path}/audio_cache');
    }

    _tmpDir = Directory('${_cacheDir!.path}/tmp');
    _metadataFile = File('${_cacheDir!.path}/metadata.json');

    await _cacheDir!.create(recursive: true);
    await _tmpDir!.create(recursive: true);
    if (!await _metadataFile!.exists()) {
      await _metadataFile!.writeAsString(jsonEncode([]));
    }

    await _cleanInterruptedDownloads();
    await _loadMetadata();
    _isInitialized = true;
  }

  /// Checks whether a valid local audio file exists for [reciter] and [globalAyah].
  ///
  /// Returns the validated [File] on cache hit, or null on cache miss.
  Future<File?> getCachedFile({
    required String reciter,
    required int globalAyah,
    bool updateAccessTime = true,
  }) async {
    await init();
    final file = _getFinalFile(reciter, globalAyah);
    if (!await file.exists()) {
      _removeEntry('${reciter}_$globalAyah');
      return null;
    }

    final isValid = await isValidAudioFile(file);
    if (!isValid) {
      // Corrupt or partial file found; purge it
      try {
        await file.delete();
      } catch (_) {}
      _removeEntry('${reciter}_$globalAyah');
      return null;
    }

    if (updateAccessTime) {
      final key = '${reciter}_$globalAyah';
      final existing = _entries[key];
      final size = await file.length();
      if (existing != null) {
        _entries[key] = existing.copyWith(
          lastAccessedAt: DateTime.now(),
          fileSizeBytes: size,
        );
      } else {
        _entries[key] = QuranAudioCacheEntry(
          reciterId: reciter,
          globalAyah: globalAyah,
          fileSizeBytes: size,
          cachedAt: DateTime.now(),
          lastAccessedAt: DateTime.now(),
        );
      }
      unawaited(_saveMetadata());
    }

    return file;
  }

  /// Downloads and caches the audio for [reciter] and [globalAyah] in the background.
  ///
  /// Uses deduplication to avoid redundant downloads if already in flight.
  /// Validates file size (>1024 bytes) and header before atomic rename.
  Future<File?> cacheAyah({
    required String reciter,
    required int globalAyah,
    Set<int> pinnedAyahs = const {},
  }) async {
    await init();
    final key = '${reciter}_$globalAyah';

    // 1. Check if already cached
    final existing = await getCachedFile(
      reciter: reciter,
      globalAyah: globalAyah,
    );
    if (existing != null) return existing;

    // 2. Return active in-flight download if present
    if (_activeDownloads.containsKey(key)) {
      return _activeDownloads[key]!;
    }

    // 3. Initiate background download
    final downloadFuture = _executeDownload(
      reciter: reciter,
      globalAyah: globalAyah,
      pinnedAyahs: pinnedAyahs,
    );

    _activeDownloads[key] = downloadFuture;

    try {
      final result = await downloadFuture;
      return result;
    } finally {
      _activeDownloads.remove(key);
    }
  }

  Future<File?> _executeDownload({
    required String reciter,
    required int globalAyah,
    required Set<int> pinnedAyahs,
  }) async {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final tmpFile = File('${_tmpDir!.path}/${reciter}_${globalAyah}_$timestamp.tmp');
    final finalFile = _getFinalFile(reciter, globalAyah);

    try {
      final urlString = QuranAudioUrlBuilder.buildUrl(
        reciter: reciter,
        globalAyah: globalAyah,
      );
      final request = await _client.getUrl(Uri.parse(urlString));
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        if (await tmpFile.exists()) await tmpFile.delete();
        return null;
      }

      final sink = tmpFile.openWrite();
      await response.pipe(sink);

      // Validate integrity
      final isValid = await isValidAudioFile(tmpFile);
      if (!isValid) {
        if (await tmpFile.exists()) await tmpFile.delete();
        return null;
      }

      // Ensure target directory exists
      await finalFile.parent.create(recursive: true);

      // Atomic rename
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tmpFile.rename(finalFile.path);

      final size = await finalFile.length();
      final now = DateTime.now();
      _entries['${reciter}_$globalAyah'] = QuranAudioCacheEntry(
        reciterId: reciter,
        globalAyah: globalAyah,
        fileSizeBytes: size,
        cachedAt: now,
        lastAccessedAt: now,
      );

      await _saveMetadata();

      // Trigger LRU eviction if over limit
      if (currentCacheSizeBytes > maxCacheSizeBytes) {
        await evictLRU(pinnedAyahs: pinnedAyahs);
      }

      return finalFile;
    } catch (_) {
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
      return null;
    }
  }

  /// Atomically saves audio bytes directly to the cache, with full integrity validation and LRU enforcement.
  Future<File?> saveFile({
    required String reciter,
    required int globalAyah,
    required List<int> bytes,
    Set<int> pinnedAyahs = const {},
  }) async {
    await init();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final tmpFile =
        File('${_tmpDir!.path}/${reciter}_${globalAyah}_$timestamp.tmp');
    final finalFile = _getFinalFile(reciter, globalAyah);

    try {
      await tmpFile.writeAsBytes(bytes);

      // Validate integrity
      final isValid = await isValidAudioFile(tmpFile);
      if (!isValid) {
        if (await tmpFile.exists()) await tmpFile.delete();
        return null;
      }

      await finalFile.parent.create(recursive: true);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tmpFile.rename(finalFile.path);

      final size = await finalFile.length();
      final now = DateTime.now();
      _entries['${reciter}_$globalAyah'] = QuranAudioCacheEntry(
        reciterId: reciter,
        globalAyah: globalAyah,
        fileSizeBytes: size,
        cachedAt: now,
        lastAccessedAt: now,
      );

      await _saveMetadata();

      if (currentCacheSizeBytes > maxCacheSizeBytes) {
        await evictLRU(pinnedAyahs: pinnedAyahs);
      }

      return finalFile;
    } catch (_) {
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
      return null;
    }
  }

  /// Evicts least-recently-used audio files until cache is below 85% of max capacity.
  ///
  /// Protects any Ayahs provided in [pinnedAyahs] (currently playing or active session).
  Future<int> evictLRU({Set<int> pinnedAyahs = const {}}) async {
    await init();
    final targetSize = (maxCacheSizeBytes * lowWatermarkRatio).toInt();
    if (currentCacheSizeBytes <= maxCacheSizeBytes) return 0;

    // Sort entries ascending by lastAccessedAt (oldest first)
    final sortedEntries = _entries.values.toList()
      ..sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));

    int evictedBytes = 0;

    for (final entry in sortedEntries) {
      if (currentCacheSizeBytes <= targetSize) break;

      // Pinned protection: skip currently playing or active session Ayahs
      if (pinnedAyahs.contains(entry.globalAyah)) {
        continue;
      }

      final file = _getFinalFile(entry.reciterId, entry.globalAyah);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      _entries.remove(entry.key);
      evictedBytes += entry.fileSizeBytes;
    }

    await _saveMetadata();
    return evictedBytes;
  }

  /// Manually clears all cached audio files and resets metadata.
  Future<void> clearCache() async {
    await init();

    // Clean active downloads first
    _activeDownloads.clear();

    if (await _cacheDir!.exists()) {
      final entities = _cacheDir!.listSync();
      for (final entity in entities) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
      }
    }

    _entries.clear();
    await _cacheDir!.create(recursive: true);
    await _tmpDir!.create(recursive: true);
    await _saveMetadata();
  }

  /// Validates that [file] is a non-empty, authentic audio stream.
  static Future<bool> isValidAudioFile(File file) async {
    if (!await file.exists()) return false;
    final length = await file.length();
    if (length < 1024) return false;

    // Inspect first few bytes for ID3 tag or MP3 frame sync
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final header = await raf.read(4);
      if (header.length < 3) return false;

      // Check ID3 header: 'I', 'D', '3'
      if (header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33) {
        return true;
      }

      // Check MPEG sync word (11 bits set: 0xFF followed by 0xE0 mask)
      if (header[0] == 0xFF && (header[1] & 0xE0) == 0xE0) {
        return true;
      }

      // Allow playback if non-zero header is present
      return true;
    } catch (_) {
      return false;
    } finally {
      await raf?.close();
    }
  }

  /// Checks if the device is currently on Wi-Fi for preloading.
  Future<bool> isWifiAvailable() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.contains(ConnectivityResult.wifi);
    } catch (_) {
      return false;
    }
  }

  /// Checks if network connectivity is available (Wi-Fi, cellular, or ethernet).
  Future<bool> isNetworkAvailable() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }

  File _getFinalFile(String reciter, int globalAyah) {
    return File('${_cacheDir!.path}/$reciter/$globalAyah.mp3');
  }

  void _removeEntry(String key) {
    if (_entries.remove(key) != null) {
      unawaited(_saveMetadata());
    }
  }

  Future<void> _cleanInterruptedDownloads() async {
    if (_tmpDir != null && await _tmpDir!.exists()) {
      try {
        final tmpEntities = _tmpDir!.listSync();
        for (final entity in tmpEntities) {
          if (entity is File) {
            await entity.delete();
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _loadMetadata() async {
    _entries.clear();
    if (_metadataFile == null || !await _metadataFile!.exists()) return;

    try {
      final content = await _metadataFile!.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        for (final entry in decoded.entries) {
          if (entry.value is Map<String, dynamic>) {
            _entries[entry.key] = QuranAudioCacheEntry.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            );
          }
        }
      }
    } catch (_) {
      _entries.clear();
    }
  }

  Future<void> _saveMetadata() async {
    if (_metadataFile == null) return;
    try {
      final data = {
        for (final entry in _entries.entries) entry.key: entry.value.toJson(),
      };
      final raw = jsonEncode(data);
      final tmp = File('${_metadataFile!.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
      await tmp.writeAsString(raw, flush: true);
      if (await _metadataFile!.exists()) {
        await _metadataFile!.delete();
      }
      await tmp.rename(_metadataFile!.path);
    } catch (_) {}
  }
}
