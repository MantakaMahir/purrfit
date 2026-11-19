import 'package:flutter/cupertino.dart';

import 'app_colors.dart';

class AppTypography {
  const AppTypography._();

  static TextStyle largeTitle(BuildContext context) =>
      _style(context, 32, 38, FontWeight.w800);
  static TextStyle title1(BuildContext context) =>
      _style(context, 27, 33, FontWeight.w800);
  static TextStyle title2(BuildContext context) =>
      _style(context, 22, 28, FontWeight.w700);
  static TextStyle title3(BuildContext context) =>
      _style(context, 20, 25, FontWeight.w600);
  static TextStyle headline(BuildContext context) =>
      _style(context, 17, 22, FontWeight.w600);
  static TextStyle body(BuildContext context) =>
      _style(context, 17, 24, FontWeight.w400);
  static TextStyle bodyStrong(BuildContext context) =>
      _style(context, 17, 24, FontWeight.w600);
  static TextStyle callout(BuildContext context) =>
      _style(context, 16, 22, FontWeight.w400);
  static TextStyle subheadline(BuildContext context) =>
      _style(context, 15, 21, FontWeight.w400);
  static TextStyle footnote(BuildContext context) =>
      _style(context, 13, 18, FontWeight.w400);
  static TextStyle caption(BuildContext context) =>
      _style(context, 12, 16, FontWeight.w400);
  static TextStyle button(BuildContext context) =>
      _style(context, 17, 22, FontWeight.w600);

  static TextStyle _style(
    BuildContext context,
    double size,
    double lineHeight,
    FontWeight weight,
  ) {
    return TextStyle(
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      fontFamily: 'Manrope',
      letterSpacing: size >= 22 ? -0.45 : 0,
      color: AppColors.primaryText(context),
    );
  }
}
