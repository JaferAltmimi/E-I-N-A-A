import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/services/audio_service.dart';
import '../core/services/local_notification_service.dart';
import '../core/services/local_storage_service.dart';
import '../core/theme/app_theme.dart';
import '../features/adhkar/data/repositories/adhkar_repository.dart';
import '../features/adhkar/presentation/cubit/adhkar_cubit.dart';
import '../features/home/presentation/cubit/home_cubit.dart';
import '../features/khatma/presentation/cubit/khatma_cubit.dart';
import '../features/library/data/repositories/library_repository.dart';
import '../features/library/presentation/cubit/library_cubit.dart';
import '../features/qibla/presentation/cubit/qibla_cubit.dart';
import '../features/quran/data/repositories/quran_memorization_repository.dart';
import '../features/quran/data/repositories/quran_repository.dart';
import '../features/quran/presentation/cubit/quran_cubit.dart';
import '../features/quran/presentation/cubit/quran_memorization_cubit.dart';
import '../features/settings/presentation/cubit/settings_cubit.dart';
import '../features/settings/presentation/cubit/settings_state.dart';
import '../features/shell/presentation/cubit/shell_cubit.dart';
import '../features/shell/presentation/pages/app_shell.dart';
import '../features/tasbih/presentation/cubit/tasbih_cubit.dart';

import '../features/quran/presentation/services/speech_recognition_service.dart';

class MishkatApp extends StatelessWidget {
  const MishkatApp({
    super.key,
    required this.storage,
    required this.notifications,
    required this.audioService,
    required this.quranRepository,
    required this.adhkarRepository,
    required this.libraryRepository,
    required this.settingsCubit,
    required this.khatmaCubit,
    this.speechService,
  });

  final LocalStorageService storage;
  final LocalNotificationService notifications;
  final QuranAudioService audioService;
  final QuranRepository quranRepository;
  final AdhkarRepository adhkarRepository;
  final LibraryRepository libraryRepository;
  final SettingsCubit settingsCubit;
  final KhatmaCubit khatmaCubit;
  final SpeechRecognitionService? speechService;

  @override
  Widget build(BuildContext context) {
    final settings = settingsCubit.state.settings;
    final qiblaCubit = QiblaCubit()
      ..setLocation(settings.latitude, settings.longitude);
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<QuranRepository>.value(value: quranRepository),
        RepositoryProvider<AdhkarRepository>.value(value: adhkarRepository),
        RepositoryProvider<LibraryRepository>.value(value: libraryRepository),
        if (speechService != null)
          RepositoryProvider<SpeechRecognitionService>.value(value: speechService!),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: settingsCubit),
          BlocProvider(create: (_) => ShellCubit()),
          BlocProvider(create: (_) => HomeCubit(settings)),
          BlocProvider(
            create: (ctx) => QuranCubit(
              repository: ctx.read<QuranRepository>(),
              storage: storage,
              audio: audioService,
              reciter: settings.reciter,
              fontSize: settings.quranFont,
            )..load(),
          ),
          BlocProvider(
            create: (ctx) => AdhkarCubit(ctx.read<AdhkarRepository>(), storage)..load(),
          ),
          BlocProvider.value(value: qiblaCubit),
          BlocProvider(create: (_) => TasbihCubit(storage)),
          BlocProvider.value(value: khatmaCubit),
          BlocProvider(
            create: (_) => QuranMemorizationCubit(
              repository: QuranMemorizationRepository(storage: storage),
              notificationService: notifications,
            )..load(),
          ),
          BlocProvider(
            create: (ctx) => LibraryCubit(ctx.read<LibraryRepository>(), storage)..load(),
          ),
        ],
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) => MaterialApp(
          title: 'مشكاة',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.light(state.settings.uiFontScale),
          darkTheme: AppTheme.dark(state.settings.uiFontScale),
          themeMode: state.settings.themeMode,
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.noScaling),
              child: child!,
            ),
          ),
          home: MultiBlocListener(
            listeners: [
              BlocListener<SettingsCubit, SettingsState>(
                listenWhen: (previous, current) =>
                    previous.settings != current.settings,
                listener: (context, value) {
                  final settings = value.settings;
                  context.read<HomeCubit>().updateSettings(settings);
                  context.read<QiblaCubit>().setLocation(
                    settings.latitude,
                    settings.longitude,
                  );
                  context.read<QuranCubit>()
                    ..updateReciter(settings.reciter)
                    ..setFontSize(settings.quranFont);
                },
              ),
            ],
            child: const AppShell(),
          ),
        ),
      ),
    ),
  );
}
}
