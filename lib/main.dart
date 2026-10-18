import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app/app.dart';
import 'app/app_bloc_observer.dart';
import 'core/services/audio_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/location_service.dart';
import 'features/adhkar/data/repositories/adhkar_repository.dart';
import 'features/khatma/presentation/cubit/khatma_cubit.dart';
import 'features/library/data/repositories/library_repository.dart';
import 'features/quran/data/repositories/quran_repository.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.dakomn.mishkatapp.quran_audio',
    androidNotificationChannelName: 'تشغيل القرآن الكريم',
    androidNotificationChannelDescription:
        'التلاوات وإذاعات القرآن الكريم أثناء استخدام التطبيقات الأخرى',
    androidNotificationOngoing: true,
  );
  Bloc.observer = const AppBlocObserver();

  final storage = LocalStorageService();
  await storage.init();
  final notifications = LocalNotificationService();
  await notifications.initialize();
  final settingsCubit = SettingsCubit(
    storage: storage,
    locationService: LocationService(),
    notifications: notifications,
  );
  await settingsCubit.load();

  runApp(
    MishkatApp(
      storage: storage,
      notifications: notifications,
      audioService: QuranAudioService(),
      quranRepository: QuranRepository(),
      adhkarRepository: AdhkarRepository(),
      libraryRepository: LibraryRepository(),
      settingsCubit: settingsCubit,
      khatmaCubit: KhatmaCubit(storage),
    ),
  );
}
