import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/mishkat_widgets.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';
import '../cubit/qibla_cubit.dart';
import '../cubit/qibla_state.dart';
import '../widgets/mishkat_compass_widget.dart';

/// Redesigned Production-Grade Qibla Experience for Mishkat.
///
/// Features:
/// - Distinctive visual identity with serene Islamic styling.
/// - Clear distinction between North and Qibla direction.
/// - Dynamic turn guidance, shortest-arc smooth compass rotation.
/// - Real-time alignment haptic and visual celebration.
/// - Comprehensive handling for missing location, loading, missing sensor, and calibration.
/// - Lifecycle-aware sensor management to prevent battery drain and memory leaks.
class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key});

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> with WidgetsBindingObserver {
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Auto-start compass on page load if location is already set
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final qiblaState = context.read<QiblaCubit>().state;
        if (qiblaState.bearing != null &&
            qiblaState.status == QiblaStatus.ready) {
          context.read<QiblaCubit>().start();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.inactive) {
      context.read<QiblaCubit>().stop();
    } else if (lifecycleState == AppLifecycleState.resumed) {
      final qiblaState = context.read<QiblaCubit>().state;
      if (qiblaState.bearing != null) {
        context.read<QiblaCubit>().start();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<QiblaCubit, QiblaState>(
      listener: (context, state) {
        // Haptic feedback once upon entering alignment
        if (state.aligned && !_wasAligned) {
          HapticFeedback.mediumImpact();
        }
        _wasAligned = state.aligned;
      },
      builder: (context, state) {
        final settings = context.watch<SettingsCubit>().state.settings;
        final settingsStatus = context.watch<SettingsCubit>().state.status;
        final isLocating = settingsStatus == SettingsStatus.locating;

        final isPushedRoute = Navigator.canPop(context);

        final content = SafeArea(
          bottom: false,
          child: ListView(
            key: const PageStorageKey('qibla_scroll_view'),
            padding: const EdgeInsets.fromLTRB(
              MishkatSpacing.base,
              MishkatSpacing.sm,
              MishkatSpacing.base,
              100, // Bottom padding to clear floating nav bar
            ),
            children: [
              // ─────────────────────────────────────────────────────────────
              // 1. Header (الترويسة)
              // ─────────────────────────────────────────────────────────────
              _QiblaHeader(
                settings: settings,
                state: state,
                isLocating: isLocating,
                isPushedRoute: isPushedRoute,
              ),

              const SizedBox(height: MishkatSpacing.base),

              // ─────────────────────────────────────────────────────────────
              // 2. State-Specific Content
              // ─────────────────────────────────────────────────────────────
              if (!settings.hasLocation || state.status == QiblaStatus.noLocation)
                _NoLocationCard(isLocating: isLocating)
              else ...[
                // Guidance Banner
                _GuidanceBanner(state: state),

                const SizedBox(height: MishkatSpacing.lg),

                // Main Compass View
                MishkatCompassWidget(
                  heading: state.heading,
                  bearing: state.bearing,
                  aligned: state.aligned,
                  accuracy: state.accuracy,
                  isListening: state.status == QiblaStatus.listening,
                ),

                const SizedBox(height: MishkatSpacing.lg),

                // Metrics Row (Angle, Heading, Distance)
                _MetricsRow(state: state),

                const SizedBox(height: MishkatSpacing.base),

                // Controls: Start / Stop Compass
                _ControlsSection(state: state),

                // Sensor Unavailable Notice (if platform lacks magnetometer)
                if (state.status == QiblaStatus.unavailable ||
                    state.status == QiblaStatus.failure)
                  _SensorUnavailableCard(state: state),

                const SizedBox(height: MishkatSpacing.md),

                // Calibration & Best Practice Advice Card
                const _CalibrationTipCard(),
              ],
            ],
          ),
        );

        // If opened as a pushed standalone route, provide Scaffold with clean background
        if (isPushedRoute) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: content,
          );
        }

        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: content,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header Widget (الترويسة)
// ─────────────────────────────────────────────────────────────────────────────
class _QiblaHeader extends StatelessWidget {
  const _QiblaHeader({
    required this.settings,
    required this.state,
    required this.isLocating,
    required this.isPushedRoute,
  });

  final dynamic settings;
  final QiblaState state;
  final bool isLocating;
  final bool isPushedRoute;

  @override
  Widget build(BuildContext context) {
    final hasLoc = settings.hasLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Navigation row (Back button if pushed)
        if (isPushedRoute)
          Padding(
            padding: const EdgeInsets.only(bottom: MishkatSpacing.xs),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  tooltip: 'رجوع',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Text(
                  'رجوع',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.mishkat.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),

        // Islamic Category Tag
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'باتجاه البيت الحرام بمكة',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.mishkat.gold,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: MishkatSpacing.sm),

            // Live Compass Quality Badge
            _StatusBadge(state: state),
          ],
        ),

        const SizedBox(height: 2),

        // Main Title
        Text(
          'اتجاه القبلة',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.mishkat.textPrimary,
              ),
        ),

        const SizedBox(height: 2),

        // Subtitle & Location Chip
        Row(
          children: [
            Expanded(
              child: Text(
                'اعرف اتجاه الكعبة من موقعك الحالي بدقة.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.mishkat.textSecondary,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: MishkatSpacing.sm),

        // Location Chip with refresh capability
        if (hasLoc)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MishkatSpacing.md,
              vertical: MishkatSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: context.mishkat.surfaceMuted,
              borderRadius: BorderRadius.circular(MishkatRadius.pill),
              border: Border.all(color: context.mishkat.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: context.mishkat.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  settings.city,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.mishkat.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: isLocating
                      ? null
                      : () => context
                          .read<SettingsCubit>()
                          .useCurrentLocation(),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: isLocating
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: context.mishkat.primary,
                            ),
                          )
                        : Icon(
                            Icons.refresh_rounded,
                            size: 14,
                            color: context.mishkat.textSecondary,
                          ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dynamic Guidance Banner
// ─────────────────────────────────────────────────────────────────────────────
class _GuidanceBanner extends StatelessWidget {
  const _GuidanceBanner({required this.state});
  final QiblaState state;

  @override
  Widget build(BuildContext context) {
    final delta = state.delta;
    final aligned = state.aligned;
    final isListening = state.status == QiblaStatus.listening;

    late final String title;
    late final String subtitle;
    late final IconData icon;

    if (aligned) {
      title = 'أنت الآن باتجاه القبلة مباشرة';
      subtitle = 'وجّه صلاتك ودعاءك نحو المسجد الحرام الشريف';
      icon = Icons.check_circle_rounded;
    } else if (!isListening) {
      title = 'شغّل البوصلة للبدء';
      subtitle = 'اضغط «تشغيل البوصلة» ثم أدر هاتفك حتى تتطابق الإبرة';
      icon = Icons.explore_rounded;
    } else if (delta == null) {
      title = 'جارٍ قراءة المستشعر...';
      subtitle = 'حرّك الهاتف قليلاً لمعايرة الاتجاه';
      icon = Icons.screen_rotation_alt_rounded;
    } else {
      final deg = delta.abs().round();
      if (delta > 0) {
        title = 'استدر يمينًا بمقدار $deg°';
        subtitle = 'وجّه أعلى الهاتف نحو مؤشر الكعبة المشرفة';
        icon = Icons.turn_right_rounded;
      } else {
        title = 'استدر يسارًا بمقدار $deg°';
        subtitle = 'وجّه أعلى الهاتف نحو مؤشر الكعبة المشرفة';
        icon = Icons.turn_left_rounded;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark
        ? context.mishkat.primaryDark
        : context.mishkat.primary;
    final activeTextColor = Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(
        horizontal: MishkatSpacing.base,
        vertical: MishkatSpacing.md,
      ),
      decoration: BoxDecoration(
        color: aligned ? activeBg : context.mishkat.primarySoft,
        borderRadius: BorderRadius.circular(MishkatRadius.lg),
        border: Border.all(
          color: aligned ? activeBg : context.mishkat.border,
          width: aligned ? 1.5 : 1.0,
        ),
        boxShadow: aligned
            ? [
                BoxShadow(
                  color: context.mishkat.primary.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: aligned
                  ? Colors.white.withValues(alpha: 0.2)
                  : context.mishkat.surfaceMuted,
            ),
            child: Icon(
              icon,
              size: 24,
              color: aligned ? activeTextColor : context.mishkat.primary,
            ),
          ),
          const SizedBox(width: MishkatSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: aligned
                            ? activeTextColor
                            : context.mishkat.textPrimary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: aligned
                        ? activeTextColor.withValues(alpha: 0.85)
                        : context.mishkat.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metrics Row (Angle, Current Heading, Distance)
// ─────────────────────────────────────────────────────────────────────────────
class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.state});
  final QiblaState state;

  @override
  Widget build(BuildContext context) {
    final bearingText = state.bearing != null
        ? '${state.bearing!.round()}°'
        : '—';
    final headingText = state.heading != null
        ? '${state.heading!.round()}°'
        : '—';
    final distanceText = state.distanceKm != null
        ? '${state.distanceKm!.round()} كم'
        : '—';

    return Row(
      children: [
        // Metric 1: Qibla Bearing
        Expanded(
          child: _MetricCard(
            label: 'زاوية القبلة',
            value: bearingText,
            sublabel: 'من الشمال الحقيقي',
            icon: Icons.navigation_rounded,
          ),
        ),
        const SizedBox(width: MishkatSpacing.sm),

        // Metric 2: Device Heading
        Expanded(
          child: _MetricCard(
            label: 'اتجاه هاتفك',
            value: headingText,
            sublabel: state.status == QiblaStatus.listening
                ? 'مباشر الآن'
                : 'متوقف',
            icon: Icons.smartphone_rounded,
          ),
        ),
        const SizedBox(width: MishkatSpacing.sm),

        // Metric 3: Distance to Kaaba
        Expanded(
          child: _MetricCard(
            label: 'المسافة للكعبة',
            value: distanceText,
            sublabel: 'مسار مستقيم',
            icon: Icons.place_outlined,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.icon,
  });

  final String label;
  final String value;
  final String sublabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MishkatSpacing.sm,
        vertical: MishkatSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.mishkat.surfaceMuted,
        borderRadius: BorderRadius.circular(MishkatRadius.md),
        border: Border.all(color: context.mishkat.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: context.mishkat.primary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.mishkat.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            sublabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: context.mishkat.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Controls Section
// ─────────────────────────────────────────────────────────────────────────────
class _ControlsSection extends StatelessWidget {
  const _ControlsSection({required this.state});
  final QiblaState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == QiblaStatus.listening) {
      return MishkatSecondaryAction(
        onPressed: context.read<QiblaCubit>().stop,
        icon: const Icon(Icons.pause_circle_outline_rounded),
        label: 'إيقاف البوصلة',
        isFullWidth: true,
      );
    }

    return MishkatPrimaryAction(
      onPressed: context.read<QiblaCubit>().start,
      icon: const Icon(Icons.explore_rounded),
      label: 'تشغيل البوصلة التفاعلية',
      isFullWidth: true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Pill Badge (Top Right)
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});
  final QiblaState state;

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color color;
    late final IconData icon;

    if (state.aligned) {
      text = 'متطابق مع القبلة';
      color = context.mishkat.success;
      icon = Icons.check_circle_outline_rounded;
    } else if (state.status == QiblaStatus.listening) {
      text = 'نشط — دقة ${state.accuracyLabel}';
      color = context.mishkat.primary;
      icon = Icons.sensors_rounded;
    } else if (state.status == QiblaStatus.ready) {
      text = 'جاهزة للاستخدام';
      color = context.mishkat.textSecondary;
      icon = Icons.radio_button_checked_rounded;
    } else if (state.status == QiblaStatus.unavailable) {
      text = 'المستشعر غير متاح';
      color = context.mishkat.warning;
      icon = Icons.warning_amber_rounded;
    } else {
      text = 'الموقع مطلوب';
      color = context.mishkat.textMuted;
      icon = Icons.location_off_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(MishkatRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// No Location State Card
// ─────────────────────────────────────────────────────────────────────────────
class _NoLocationCard extends StatelessWidget {
  const _NoLocationCard({required this.isLocating});
  final bool isLocating;

  @override
  Widget build(BuildContext context) {
    return MishkatCard(
      padding: const EdgeInsets.all(MishkatSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.mishkat.primarySoft,
            ),
            child: Icon(
              Icons.location_off_outlined,
              size: 32,
              color: context.mishkat.primary,
            ),
          ),
          const SizedBox(height: MishkatSpacing.md),
          Text(
            'تحديد الموقع مطلوب',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: MishkatSpacing.xs),
          Text(
            'نحتاج إلى إحداثيات موقعك لحساب الزاوية الجغرافية الدقيقة باتجاه المسجد الحرام بمكة المكرمة.\nتُحسب القبلة محليًا بالكامل على جهازك دون إرسال بياناتك لأي جهة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: context.mishkat.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: MishkatSpacing.lg),
          MishkatPrimaryButton(
            onPressed: isLocating
                ? null
                : context.read<SettingsCubit>().useCurrentLocation,
            icon: isLocating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.my_location_rounded),
            label: isLocating ? 'جارٍ تحديد موقعك...' : 'استخدام موقعي الحالي',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sensor Unavailable Notice Card
// ─────────────────────────────────────────────────────────────────────────────
class _SensorUnavailableCard extends StatelessWidget {
  const _SensorUnavailableCard({required this.state});
  final QiblaState state;

  @override
  Widget build(BuildContext context) {
    final bearingText = state.bearing != null
        ? '${state.bearing!.round()}°'
        : '';

    return Container(
      margin: const EdgeInsets.only(top: MishkatSpacing.md),
      padding: const EdgeInsets.all(MishkatSpacing.base),
      decoration: BoxDecoration(
        color: context.mishkat.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(MishkatRadius.md),
        border: Border.all(
          color: context.mishkat.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: context.mishkat.warning,
            size: 20,
          ),
          const SizedBox(width: MishkatSpacing.md),
          Expanded(
            child: Text(
              'مستشعر البوصلة المباشر غير متوفر على هذا الجهاز.\n'
              'يمكنك الاستعانة بزاوية القبلة المحسوبة ($bearingText من الشمال الحقيقي) لتحديد الاتجاه يدويًا.',
              style: TextStyle(
                fontSize: 12.5,
                color: context.mishkat.textPrimary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calibration Tip Card
// ─────────────────────────────────────────────────────────────────────────────
class _CalibrationTipCard extends StatelessWidget {
  const _CalibrationTipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MishkatSpacing.base),
      decoration: BoxDecoration(
        color: context.mishkat.surfaceMuted,
        borderRadius: BorderRadius.circular(MishkatRadius.md),
        border: Border.all(color: context.mishkat.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            color: context.mishkat.primary,
            size: 20,
          ),
          const SizedBox(width: MishkatSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إرشادات لدقة البوصلة',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.mishkat.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'للحصول على قراءة دقيقة: حرّك الهاتف في الهواء على شكل الرقم 8 لمعايرة المستشعر، وابتعد عن الأجهزة الإلكترونية والأغطية المغناطيسية.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.mishkat.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
