import 'package:flutter/cupertino.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.obscureText = false,
    this.keyboardType,
    this.minLines,
    this.maxLines,
    this.maxLength,
    this.semanticLabel,
    this.onChanged,
  });

  final TextEditingController controller;
  final String placeholder;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final String? semanticLabel;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: semanticLabel ?? placeholder,
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        obscureText: obscureText,
        keyboardType: keyboardType,
        minLines: obscureText ? 1 : (minLines ?? 1),
        maxLines: obscureText ? 1 : (maxLines ?? minLines ?? 1),
        maxLength: maxLength,
        onChanged: onChanged,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        style: AppTypography.body(context),
        placeholderStyle: AppTypography.body(
          context,
        ).copyWith(color: AppColors.secondaryText(context)),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppRadii.large),
          border: Border.all(color: AppColors.separator(context)),
        ),
      ),
    );
  }
}
