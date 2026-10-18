import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../../../adhkar/presentation/pages/adhkar_page.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../library/presentation/pages/library_page.dart';
import '../../../qibla/presentation/pages/qibla_page.dart';
import '../../../quran/presentation/pages/quran_page.dart';
import '../../../settings/data/models/app_settings.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../cubit/shell_cubit.dart';

import '../widgets/mishkat_bottom_nav_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _onboardingPresented = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.read<SettingsCubit>().state.settings;
    if (!_onboardingPresented && !settings.onboardingSeen) {
      _onboardingPresented = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOnboarding());
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ShellCubit, ShellState>(
    builder: (context, state) {
      const pages = [
        HomePage(),
        QuranPage(),
        QiblaPage(),
        AdhkarPage(),
        LibraryPage(),
      ];
      const titles = [
        'مِشكاة',
        'القرآن الكريم',
        'اتجاه القبلة',
        'الأذكار',
        'المكتبة والختمة',
      ];

      return Scaffold(
        appBar: (state.index == 0 || state.index == 2)
            ? null
            : AppBar(
                title: Text(titles[state.index]),
                leading: IconButton(
                  tooltip: 'تبديل المظهر',
                  onPressed: () {
                    final dark = Theme.of(context).brightness == Brightness.dark;
                    context.read<SettingsCubit>().setTheme(
                      dark ? AppThemePreference.light : AppThemePreference.dark,
                    );
                  },
                  icon: Icon(
                    Theme.of(context).brightness == Brightness.dark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                  ),
                ),
                actions: [
                  IconButton(
                    tooltip: 'الإعدادات',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
                    ),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
        body: Column(
          children: [
            if (state.offline)
              Container(
                width: double.infinity,
                color: context.mishkat.primarySoft,
                padding: const EdgeInsets.symmetric(
                  horizontal: MishkatSpacing.base,
                  vertical: MishkatSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 18,
                      color: context.mishkat.primary,
                    ),
                    const SizedBox(width: MishkatSpacing.sm),
                    Expanded(
                      child: Text(
                        'أنت غير متصل — المصحف والأذكار والمواقيت ما زالت متاحة دون إنترنت.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.mishkat.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: IndexedStack(index: state.index, children: pages),
            ),
          ],
        ),
        bottomNavigationBar: MishkatBottomNavBar(
          selectedIndex: state.index,
          onItemSelected: context.read<ShellCubit>().select,
        ),
      );
    },
  );

  Future<void> _showOnboarding() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MishkatRadius.xl)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          MishkatSpacing.lg,
          MishkatSpacing.md,
          MishkatSpacing.lg,
          MediaQuery.viewInsetsOf(sheetContext).bottom + MishkatSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: context.mishkat.border,
                  borderRadius: BorderRadius.circular(MishkatRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: MishkatSpacing.lg),
            Text(
              'مرحبًا بك في مشكاة',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: context.mishkat.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: MishkatSpacing.xs),
            Text(
              'ابدأ بمواقيت مدينتك',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: MishkatSpacing.sm),
            Text(
              'نستخدم موقعك لحساب الصلاة والقبلة بدقة، ثم نحتفظ به على جهازك فقط دون إرساله لأي خادم.',
              style: TextStyle(
                fontSize: 14,
                color: context.mishkat.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: MishkatSpacing.lg),
            Container(
              padding: const EdgeInsets.all(MishkatSpacing.base),
              decoration: BoxDecoration(
                color: context.mishkat.primarySoft,
                borderRadius: BorderRadius.circular(MishkatRadius.md),
                border: Border.all(color: context.mishkat.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: context.mishkat.primary,
                    size: 22,
                  ),
                  const SizedBox(width: MishkatSpacing.md),
                  Expanded(
                    child: Text(
                      'تُحسب المواقيت والقبلة بالكامل على جهازك دون اتصال.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.mishkat.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MishkatSpacing.lg),
            MishkatPrimaryButton(
              onPressed: () async {
                await context.read<SettingsCubit>().useCurrentLocation();
                if (!mounted) return;
                if (sheetContext.mounted &&
                    context
                        .read<SettingsCubit>()
                        .state
                        .settings
                        .onboardingSeen) {
                  Navigator.pop(sheetContext);
                }
              },
              icon: const Icon(Icons.my_location_rounded),
              label: 'استخدام موقعي الحالي',
            ),
            const SizedBox(height: MishkatSpacing.sm),
            OutlinedButton(
              onPressed: () async {
                await context.read<SettingsCubit>().skipOnboarding();
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              child: const Text('سأختار مدينتي لاحقًا'),
            ),
          ],
        ),
      ),
    );
  }
}
