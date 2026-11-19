import 'package:flutter/cupertino.dart';

class AppColors {
  const AppColors._();

  // Light theme - warm, premium habit-app surfaces with strong readable ink.
  static const lightAppBackground = Color(0xFFFFF7F1);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightElevatedSurface = Color(0xFFFFEFE4);
  static const lightSecondarySurface = Color(0xFFFFF3EA);
  static const lightPrimaryText = Color(0xFF201713);
  static const lightSecondaryText = Color(0xFF5E4D45);
  static const lightTertiaryText = Color(0xFF8C7468);
  static const lightSeparator = Color(0xFFEEDBD0);
  // Darker brand accents keep normal-sized white text at WCAG AA contrast.
  static const lightAccent = Color(0xFFC5410C);
  static const lightAccentSoft = Color(0xFFFFD9C4);
  static const lightSuccess = Color(0xFF1B7A45);
  static const lightWarning = Color(0xFFB56A00);
  static const lightDanger = Color(0xFFC93644);

  // Dark theme - used when the system or the in-app toggle asks for dark.
  static const darkAppBackground = Color(0xFF17110E);
  static const darkSurface = Color(0xFF241A15);
  static const darkElevatedSurface = Color(0xFF30221B);
  static const darkSecondarySurface = Color(0xFF2A1F19);
  static const darkPrimaryText = Color(0xFFFFF8F2);
  static const darkSecondaryText = Color(0xFFD9C4B8);
  static const darkTertiaryText = Color(0xFFA88F82);
  static const darkSeparator = Color(0xFF4B362B);
  static const darkAccent = Color(0xFFFF8A4D);
  static const darkAccentSoft = Color(0xFF4A2C1F);
  static const darkSuccess = Color(0xFF69D68E);
  static const darkWarning = Color(0xFFFFC15C);
  static const darkDanger = Color(0xFFFF7280);

  // Brand palette - the four fun accents (+ soft tints) and a neutral gray.
  static const orange = lightAccent;
  static const orangeSoft = lightAccentSoft;
  static const yellow = Color(0xFF9A6500);
  static const yellowSoft = Color(0xFFFFE9A8);
  static const skyBlue = Color(0xFF126F91);
  static const skyBlueSoft = Color(0xFFCBEFF8);
  static const green = lightSuccess;
  static const greenSoft = Color(0xFFD6F0DD);
  static const progressGray = Color(0xFFB69F93);

  // Back-compat aliases used throughout the app.
  static const lightBlue = skyBlue;
  static const darkRed = orange;

  static bool isDark(BuildContext context) =>
      CupertinoTheme.brightnessOf(context) == Brightness.dark;

  /// Highest-contrast ink for content that sits on a solid [fill].
  ///
  /// Filled brand colors lighten in dark mode, so plain white text stops being
  /// readable on them; the warm ink stays legible on both palettes.
  static Color inkOn(Color fill) {
    final luminance = fill.computeLuminance();
    final whiteContrast = 1.05 / (luminance + 0.05);
    final inkContrast =
        (luminance + 0.05) / (lightPrimaryText.computeLuminance() + 0.05);
    return inkContrast >= whiteContrast
        ? lightPrimaryText
        : CupertinoColors.white;
  }

  static Gradient pageGradient(BuildContext context) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: isDark(context)
        ? [darkSurface, darkAppBackground]
        : [lightSurface, lightAppBackground],
  );

  static Color appBackground(BuildContext context) =>
      isDark(context) ? darkAppBackground : lightAppBackground;
  static Color surface(BuildContext context) =>
      isDark(context) ? darkSurface : lightSurface;
  static Color elevatedSurface(BuildContext context) =>
      isDark(context) ? darkElevatedSurface : lightElevatedSurface;
  static Color secondarySurface(BuildContext context) =>
      isDark(context) ? darkSecondarySurface : lightSecondarySurface;
  static Color primaryText(BuildContext context) =>
      isDark(context) ? darkPrimaryText : lightPrimaryText;
  static Color secondaryText(BuildContext context) =>
      isDark(context) ? darkSecondaryText : lightSecondaryText;
  static Color tertiaryText(BuildContext context) =>
      isDark(context) ? darkTertiaryText : lightTertiaryText;
  static Color separator(BuildContext context) =>
      isDark(context) ? darkSeparator : lightSeparator;
  static Color accent(BuildContext context) =>
      isDark(context) ? darkAccent : lightAccent;
  static Color accentSoft(BuildContext context) =>
      isDark(context) ? darkAccentSoft : lightAccentSoft;
  static Color success(BuildContext context) =>
      isDark(context) ? darkSuccess : lightSuccess;
  static Color warning(BuildContext context) =>
      isDark(context) ? darkWarning : lightWarning;
  static Color danger(BuildContext context) =>
      isDark(context) ? darkDanger : lightDanger;
}
