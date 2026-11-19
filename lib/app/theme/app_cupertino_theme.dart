import 'package:flutter/cupertino.dart';

import 'app_colors.dart';

class AppCupertinoTheme {
  const AppCupertinoTheme._();

  static CupertinoThemeData theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: primary,
      scaffoldBackgroundColor: isDark
          ? AppColors.darkAppBackground
          : AppColors.lightAppBackground,
      barBackgroundColor:
          (isDark ? AppColors.darkSurface : AppColors.lightSurface).withValues(
            alpha: .92,
          ),
      textTheme: CupertinoTextThemeData(
        primaryColor: primary,
        textStyle: TextStyle(
          fontFamily: 'Manrope',
          color: isDark
              ? AppColors.darkPrimaryText
              : AppColors.lightPrimaryText,
        ),
      ),
    );
  }
}
