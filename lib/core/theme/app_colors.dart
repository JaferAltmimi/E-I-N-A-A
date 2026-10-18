import 'package:flutter/material.dart';

@immutable
class MishkatColors extends ThemeExtension<MishkatColors> {
  const MishkatColors({
    required this.brandDeep,
    required this.primaryStrong,
    required this.primarySoft,
    required this.gold,
    required this.surfaceMuted,
    required this.textSecondary,
    required this.border,
    required this.heroLabel,
    required this.heroBorder,
    // Expanded modern design tokens
    required this.primary,
    required this.primaryDark,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textMuted,
    required this.borderSubtle,
    required this.accentGoldSoft,
    required this.success,
    required this.warning,
    required this.error,
  });

  // Legacy & Primary tokens
  final Color brandDeep;
  final Color primaryStrong;
  final Color primarySoft;
  final Color gold;
  final Color surfaceMuted;
  final Color textSecondary;
  final Color border;
  final Color heroLabel;
  final Color heroBorder;

  // New design tokens
  final Color primary;
  final Color primaryDark;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color textPrimary;
  final Color textMuted;
  final Color borderSubtle;
  final Color accentGoldSoft;
  final Color success;
  final Color warning;
  final Color error;

  // Convenience semantic getters
  Color get surfaceInteractive => surfaceVariant;
  Color get selectedStateBg => primarySoft;
  Color get dividerColor => borderSubtle;

  /// Pure White + Deep Islamic Green (#0B3D32)
  static const light = MishkatColors(
    brandDeep: Color(0xFF0B3D32),
    primaryStrong: Color(0xFF0B3D32),
    primarySoft: Color(0xFFEBF3F0),
    gold: Color(0xFF9E7728),
    surfaceMuted: Color(0xFFF2F5F2),
    textSecondary: Color(0xFF5A6762),
    border: Color(0xFFE6EAE6),
    heroLabel: Color(0xFFD6E3DD),
    heroBorder: Color(0xFF3F6359),
    // Expanded tokens
    primary: Color(0xFF0B3D32),
    primaryDark: Color(0xFF06251E),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFAFAF8),
    surfaceVariant: Color(0xFFF2F5F2),
    textPrimary: Color(0xFF14211D),
    textMuted: Color(0xFF8C9993),
    borderSubtle: Color(0xFFF0F3EF),
    accentGoldSoft: Color(0xFFFAF6EE),
    success: Color(0xFF1E8259),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
  );

  /// Deep Green Black (#071A15) + Muted Emerald Surface (#0D241D)
  static const dark = MishkatColors(
    brandDeep: Color(0xFF071A15),
    primaryStrong: Color(0xFF3DB892),
    primarySoft: Color(0xFF13352A),
    gold: Color(0xFFD4AF37),
    surfaceMuted: Color(0xFF133128),
    textSecondary: Color(0xFFA3B5AE),
    border: Color(0xFF1B3C32),
    heroLabel: Color(0xFFD3DFD7),
    heroBorder: Color(0xFF35584E),
    // Expanded tokens
    primary: Color(0xFF3DB892),
    primaryDark: Color(0xFF0B3D32),
    background: Color(0xFF071A15),
    surface: Color(0xFF0D241D),
    surfaceVariant: Color(0xFF133128),
    textPrimary: Color(0xFFF2F5F3),
    textMuted: Color(0xFF6E8179),
    borderSubtle: Color(0xFF142F27),
    accentGoldSoft: Color(0xFF282315),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF87171),
  );

  @override
  MishkatColors copyWith({
    Color? brandDeep,
    Color? primaryStrong,
    Color? primarySoft,
    Color? gold,
    Color? surfaceMuted,
    Color? textSecondary,
    Color? border,
    Color? heroLabel,
    Color? heroBorder,
    Color? primary,
    Color? primaryDark,
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? textPrimary,
    Color? textMuted,
    Color? borderSubtle,
    Color? accentGoldSoft,
    Color? success,
    Color? warning,
    Color? error,
  }) => MishkatColors(
    brandDeep: brandDeep ?? this.brandDeep,
    primaryStrong: primaryStrong ?? this.primaryStrong,
    primarySoft: primarySoft ?? this.primarySoft,
    gold: gold ?? this.gold,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    textSecondary: textSecondary ?? this.textSecondary,
    border: border ?? this.border,
    heroLabel: heroLabel ?? this.heroLabel,
    heroBorder: heroBorder ?? this.heroBorder,
    primary: primary ?? this.primary,
    primaryDark: primaryDark ?? this.primaryDark,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceVariant: surfaceVariant ?? this.surfaceVariant,
    textPrimary: textPrimary ?? this.textPrimary,
    textMuted: textMuted ?? this.textMuted,
    borderSubtle: borderSubtle ?? this.borderSubtle,
    accentGoldSoft: accentGoldSoft ?? this.accentGoldSoft,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
  );

  @override
  MishkatColors lerp(covariant MishkatColors? other, double t) {
    if (other == null) return this;
    return MishkatColors(
      brandDeep: Color.lerp(brandDeep, other.brandDeep, t)!,
      primaryStrong: Color.lerp(primaryStrong, other.primaryStrong, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      heroLabel: Color.lerp(heroLabel, other.heroLabel, t)!,
      heroBorder: Color.lerp(heroBorder, other.heroBorder, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      accentGoldSoft: Color.lerp(accentGoldSoft, other.accentGoldSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

extension MishkatThemeX on BuildContext {
  MishkatColors get mishkat =>
      Theme.of(this).extension<MishkatColors>() ?? MishkatColors.light;
}
