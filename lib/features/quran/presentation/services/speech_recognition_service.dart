import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Transcribed speech result payload emitted by a [SpeechRecognitionService].
class SpeechRecognitionResultData {
  const SpeechRecognitionResultData({
    required this.recognizedWords,
    required this.isFinal,
    this.confidence = 1.0,
    this.alternates = const [],
  });

  final String recognizedWords;
  final bool isFinal;
  final double confidence;
  final List<String> alternates;

  @override
  String toString() =>
      'SpeechRecognitionResultData(words: $recognizedWords, isFinal: $isFinal, conf: $confidence)';
}

/// Abstract contract decoupling speech recognition and microphone capture from the application.
abstract class SpeechRecognitionService {
  /// Initializes the recognition engine and checks hardware availability.
  Future<bool> initialize();

  /// Whether microphone and speech recognition permissions are currently granted.
  Future<bool> hasPermission();

  /// Explicitly requests microphone and speech recognition permissions from the OS.
  Future<bool> requestPermission();

  /// Opens application system settings on the device so the user can grant permission manually.
  Future<bool> openAppSettings();

  /// Whether the platform recognizer is available and ready.
  bool get isAvailable;

  /// Whether the recognizer is currently active and listening to the microphone.
  bool get isListening;

  /// Stream of recognized transcript results emitted in real-time.
  Stream<SpeechRecognitionResultData> get resultsStream;

  /// Stream of recognizer status changes ('listening', 'notListening', 'done').
  Stream<String> get statusStream;

  /// Stream of recognition errors.
  Stream<String> get errorStream;

  /// Starts capturing microphone audio and streaming recognized speech.
  Future<bool> startListening({String localeId = 'ar_SA'});

  /// Stops capturing microphone audio, completing the current stream.
  Future<void> stopListening();

  /// Immediately cancels audio capture and discards any pending recognition.
  Future<void> cancelListening();

  /// Releases platform resources and closes streams.
  Future<void> dispose();
}

/// Production implementation of [SpeechRecognitionService] backed by native platform ASR ([SpeechToText]).
class NativeSpeechRecognitionService implements SpeechRecognitionService {
  NativeSpeechRecognitionService({SpeechToText? speechToText})
      : _stt = speechToText ?? SpeechToText();

  final SpeechToText _stt;

  final _resultsController = StreamController<SpeechRecognitionResultData>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  bool _isInitialized = false;

  @override
  Stream<SpeechRecognitionResultData> get resultsStream => _resultsController.stream;

  @override
  Stream<String> get statusStream => _statusController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  bool get isAvailable => _isInitialized && _stt.isAvailable;

  @override
  bool get isListening => _stt.isListening;

  @override
  Future<bool> initialize() async {
    if (_isInitialized && _stt.isAvailable) return true;

    try {
      final available = await _stt.initialize(
        onError: _onError,
        onStatus: _onStatus,
        debugLogging: kDebugMode,
      );
      _isInitialized = available;
      return available;
    } catch (e) {
      _errorController.add('فشل تهيئة محرك التعرف الصوتي: $e');
      _isInitialized = false;
      return false;
    }
  }

  @override
  Future<bool> hasPermission() async {
    try {
      return await _stt.hasPermission;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final already = await hasPermission();
      if (already) return true;

      // On Android & iOS, SpeechToText.initialize triggers the native OS permission prompt
      final available = await initialize();
      final hasPerm = await hasPermission();
      return hasPerm || available;
    } catch (e) {
      _errorController.add('فشل طلب إذن الميكروفون: $e');
      return false;
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> startListening({String localeId = 'ar_SA'}) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }

    if (_stt.isListening) {
      await stopListening();
    }

    // Determine best available Arabic locale
    var targetLocale = localeId;
    try {
      final locales = await _stt.locales();
      final arabicLocales = locales.where((l) => l.localeId.startsWith('ar')).toList();
      if (arabicLocales.isNotEmpty) {
        final exact = arabicLocales.firstWhere(
          (l) => l.localeId == localeId || l.localeId.startsWith(localeId.split('_').first),
          orElse: () => arabicLocales.first,
        );
        targetLocale = exact.localeId;
      }
    } catch (_) {}

    try {
      await _stt.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 4),
          localeId: targetLocale,
        ),
      );
      return _stt.isListening;
    } catch (e) {
      _errorController.add('تعذّر بدء الاستماع عبر الميكروفون: $e');
      return false;
    }
  }

  @override
  Future<void> stopListening() async {
    if (_stt.isListening) {
      await _stt.stop();
    }
  }

  @override
  Future<void> cancelListening() async {
    if (_stt.isListening) {
      await _stt.cancel();
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    if (_resultsController.isClosed) return;

    if (kDebugMode) {
      debugPrint('[Q14_STT_CALLBACK] isFinal=${result.finalResult} conf=${result.confidence} words="${result.recognizedWords}"');
    }

    final alternates = result.alternates.map((a) => a.recognizedWords).toList();
    _resultsController.add(
      SpeechRecognitionResultData(
        recognizedWords: result.recognizedWords,
        isFinal: result.finalResult,
        confidence: result.confidence > 0 ? result.confidence : 1.0,
        alternates: alternates,
      ),
    );
  }

  void _onStatus(String status) {
    if (kDebugMode) {
      debugPrint('[Q14_STT_STATUS] status="$status"');
    }
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void _onError(SpeechRecognitionError error) {
    if (!_errorController.isClosed) {
      _errorController.add(error.errorMsg);
    }
  }

  @override
  Future<void> dispose() async {
    await cancelListening();
    await _resultsController.close();
    await _statusController.close();
    await _errorController.close();
  }
}

/// Controllable mock implementation of [SpeechRecognitionService] for deterministic testing.
class MockSpeechRecognitionService implements SpeechRecognitionService {
  MockSpeechRecognitionService({
    bool initialAvailable = true,
    bool initialPermission = true,
  })  : _isAvailable = initialAvailable,
        _hasPermission = initialPermission;

  bool _isAvailable;
  bool _hasPermission;
  bool _isListening = false;
  bool _isPermanentlyDenied = false;

  bool autoGrantOnRequest = false;

  int permissionRequestCount = 0;
  int openAppSettingsCount = 0;
  int initializeCount = 0;

  final _resultsController = StreamController<SpeechRecognitionResultData>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  void setAvailable(bool value) => _isAvailable = value;
  void setPermission(bool value) => _hasPermission = value;
  void setPermanentlyDenied(bool value) => _isPermanentlyDenied = value;

  @override
  Stream<SpeechRecognitionResultData> get resultsStream => _resultsController.stream;

  @override
  Stream<String> get statusStream => _statusController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  bool get isAvailable => _isAvailable;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> initialize() async {
    initializeCount++;
    return _isAvailable && _hasPermission;
  }

  @override
  Future<bool> hasPermission() async => _hasPermission;

  @override
  Future<bool> requestPermission() async {
    permissionRequestCount++;
    if (_isPermanentlyDenied) {
      _hasPermission = false;
      return false;
    }
    if (autoGrantOnRequest) {
      _hasPermission = true;
    }
    return _hasPermission;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCount++;
    return true;
  }

  @override
  Future<bool> startListening({String localeId = 'ar_SA'}) async {
    if (!_hasPermission || !_isAvailable) return false;
    _isListening = true;
    _statusController.add('listening');
    return true;
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
    _statusController.add('notListening');
  }

  @override
  Future<void> cancelListening() async {
    _isListening = false;
    _statusController.add('notListening');
  }

  /// Injects simulated speech transcripts during tests.
  void emitTranscript(String words, {bool isFinal = false, double confidence = 1.0}) {
    if (!_resultsController.isClosed) {
      _resultsController.add(
        SpeechRecognitionResultData(
          recognizedWords: words,
          isFinal: isFinal,
          confidence: confidence,
        ),
      );
    }
  }

  /// Injects simulated status events.
  void emitStatus(String status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  /// Injects simulated error events.
  void emitError(String error) {
    if (!_errorController.isClosed) {
      _errorController.add(error);
    }
  }

  @override
  Future<void> dispose() async {
    _isListening = false;
    await _resultsController.close();
    await _statusController.close();
    await _errorController.close();
  }
}
