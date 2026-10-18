class AppConstants {
  const AppConstants._();

  static const appName = 'مشكاة';
  static const totalQuranPages = 604;
  static const totalAyahs = 6236;
  static const kaabaLatitude = 21.4225;
  static const kaabaLongitude = 39.8262;

  static const reciters = <ReciterInfo>[
    ReciterInfo('ar.alafasy', 'مشاري العفاسي', 128),
    ReciterInfo('ar.abdulbasitmurattal', 'عبد الباسط — مرتل', 64),
    ReciterInfo('ar.abdurrahmaansudais', 'عبد الرحمن السديس', 64),
    ReciterInfo('ar.mahermuaiqly', 'ماهر المعيقلي', 128),
    ReciterInfo('ar.husary', 'محمود الحصري', 128),
    ReciterInfo('ar.minshawi', 'محمد صديق المنشاوي', 128),
    ReciterInfo('ar.saoodshuraym', 'سعود الشريم', 64),
    ReciterInfo('ar.hudhaify', 'علي الحذيفي', 128),
    ReciterInfo('ar.ahmedajamy', 'أحمد العجمي', 128),
    ReciterInfo('ar.muhammadayyoub', 'محمد أيوب', 128),
    ReciterInfo('ar.shaatree', 'أبو بكر الشاطري', 128),
    ReciterInfo('ar.hanirifai', 'هاني الرفاعي', 64),
  ];

  static ReciterInfo findReciter(String id) {
    for (final reciter in reciters) {
      if (reciter.id == id) return reciter;
    }
    return reciters.first;
  }
}

class ReciterInfo {
  const ReciterInfo(this.id, this.name, this.bitrate);
  final String id;
  final String name;
  final int bitrate;
}
