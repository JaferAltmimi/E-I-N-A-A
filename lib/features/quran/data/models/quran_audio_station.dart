import 'package:equatable/equatable.dart';

/// Category of an audio broadcast or stream.
enum AudioStationCategory {
  liveStream,
  radio,
}

/// Truthful availability state of an audio stream.
enum AudioStationAvailability {
  /// Stream URL is verified and playable.
  available,

  /// Stream endpoint is awaiting official verified source.
  awaitingSource,

  /// Stream is currently offline or unreachable.
  offline,
}

/// Metadata and streaming configuration for Quran live streams and radio stations.
class QuranAudioStation extends Equatable {
  const QuranAudioStation({
    required this.id,
    required this.title,
    required this.category,
    required this.subtitle,
    required this.availability,
    this.streamUrl,
    this.country,
    this.city,
    this.notes,
  });

  final String id;
  final String title;
  final AudioStationCategory category;
  final String subtitle;
  final AudioStationAvailability availability;
  final String? streamUrl;
  final String? country;
  final String? city;
  final String? notes;

  bool get isPlayable =>
      availability == AudioStationAvailability.available &&
      streamUrl != null &&
      streamUrl!.isNotEmpty;

  String get availabilityLabel {
    switch (availability) {
      case AudioStationAvailability.available:
        return 'متاح الآن';
      case AudioStationAvailability.awaitingSource:
        return 'بانتظار اعتماد المصدر الموثق';
      case AudioStationAvailability.offline:
        return 'غير متاح حالياً';
    }
  }

  @override
  List<Object?> get props => [
        id,
        title,
        category,
        subtitle,
        availability,
        streamUrl,
        country,
        city,
        notes,
      ];

  /// Canonical catalog of requested live streams and Quran radio stations.
  ///
  /// Every entry reflects its TRUTHFUL availability state.
  /// Unverified streams are explicitly marked as awaiting verified source.
  static const List<QuranAudioStation> defaultCatalog = [
    // ----------------------------------------------------
    // Live Streams (البث المباشر)
    // ----------------------------------------------------
    QuranAudioStation(
      id: 'stream_haram_makkah',
      title: 'بث المسجد الحرام',
      category: AudioStationCategory.liveStream,
      subtitle: 'مكة المكرمة · أطهر بقاع الأرض',
      availability: AudioStationAvailability.awaitingSource,
      country: 'المملكة العربية السعودية',
      city: 'مكة المكرمة',
      notes: 'في انتظار اعتماد رابط البث الصوتي المباشر الرسمي من رئاسة شؤون الحرمين.',
    ),
    QuranAudioStation(
      id: 'stream_masjid_nabawi',
      title: 'بث المسجد النبوي',
      category: AudioStationCategory.liveStream,
      subtitle: 'المدينة المنورة · مدينة رسول الله ﷺ',
      availability: AudioStationAvailability.awaitingSource,
      country: 'المملكة العربية السعودية',
      city: 'المدينة المنورة',
      notes: 'في انتظار اعتماد رابط البث الصوتي المباشر الرسمي من وكالة شؤون المسجد النبوي.',
    ),

    // ----------------------------------------------------
    // Quran Radio Stations (إذاعات القرآن الكريم)
    // ----------------------------------------------------
    QuranAudioStation(
      id: 'radio_cairo',
      title: 'إذاعة القرآن الكريم من القاهرة',
      category: AudioStationCategory.radio,
      subtitle: 'جمهورية مصر العربية · أعرق إذاعات القرآن',
      availability: AudioStationAvailability.awaitingSource,
      country: 'مصر',
      city: 'القاهرة',
      notes: 'في انتظار اعتماد رابط البث الرقمي المعتمد من اتحاد الإذاعة والتلفزيون.',
    ),
    QuranAudioStation(
      id: 'radio_riyadh',
      title: 'إذاعة القرآن الكريم من الرياض',
      category: AudioStationCategory.radio,
      subtitle: 'المملكة العربية السعودية · تلاوات وبرامج قرآنية',
      availability: AudioStationAvailability.awaitingSource,
      country: 'السعودية',
      city: 'الرياض',
      notes: 'في انتظار اعتماد رابط البث الرقمي المعتمد من هيئة الإذاعة والتلفزيون.',
    ),
    QuranAudioStation(
      id: 'radio_sharjah',
      title: 'إذاعة القرآن الكريم من الشارقة',
      category: AudioStationCategory.radio,
      subtitle: 'دولة الإمارات العربية المتحدة · تلاوات خاشعة',
      availability: AudioStationAvailability.available,
      streamUrl: 'https://l3.itworkscdn.net/smcquranlive/quranradiolive/icecast.audio',
      country: 'الإمارات',
      city: 'الشارقة',
      notes: 'بث مباشر معتمد عبر خوادم هيئة الشارقة للإذاعة والتلفزيون (Icecast AAC).',
    ),
    QuranAudioStation(
      id: 'radio_qatar',
      title: 'إذاعة القرآن الكريم من قطر',
      category: AudioStationCategory.radio,
      subtitle: 'دولة قطر · تلاوات بروايات متعددة',
      availability: AudioStationAvailability.awaitingSource,
      country: 'قطر',
      city: 'الدوحة',
      notes: 'في انتظار اعتماد رابط البث الرقمي المعتمد من المؤسسة القطرية للإعلام.',
    ),
    QuranAudioStation(
      id: 'radio_bahrain',
      title: 'إذاعة القرآن الكريم من البحرين',
      category: AudioStationCategory.radio,
      subtitle: 'مملكة البحرين · تلاوات عذبة مستمرة',
      availability: AudioStationAvailability.available,
      streamUrl: 'https://5c7b683162943.streamlock.net/live/ngrp:radio-106-1_all/playlist.m3u8',
      country: 'البحرين',
      city: 'المنامة',
      notes: 'بث مباشر معتمد عبر وزارة شؤون الإعلام في البحرين (HLS Stream).',
    ),
    QuranAudioStation(
      id: 'radio_sudan',
      title: 'إذاعة القرآن الكريم من السودان',
      category: AudioStationCategory.radio,
      subtitle: 'جمهورية السودان · برواية الدوري عن أبي عمرو',
      availability: AudioStationAvailability.awaitingSource,
      country: 'السودان',
      city: 'أم درمان',
      notes: 'في انتظار اعتماد رابط البث الرقمي المعتمد من الهيئة العامة للإذاعة والتلفزيون.',
    ),
    QuranAudioStation(
      id: 'radio_yemen',
      title: 'إذاعة القرآن الكريم من اليمن',
      category: AudioStationCategory.radio,
      subtitle: 'الجمهورية اليمنية · تلاوات وأصوات يمانية',
      availability: AudioStationAvailability.awaitingSource,
      country: 'اليمن',
      city: 'صنعاء / عدن',
      notes: 'في انتظار اعتماد رابط البث الرقمي المعتمد للشبكة الإذاعية.',
    ),
  ];
}
