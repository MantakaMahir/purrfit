import 'package:flutter/cupertino.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

class AppChip extends StatelessWidget {
  const AppChip(this.label, {super.key, this.selected = false, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          label,
          style: AppTypography.footnote(context).copyWith(
            color: AppColors.secondaryText(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    final bg = selected
        ? AppColors.accent(context)
        : AppColors.secondarySurface(context);
    final fg = selected
        ? AppColors.inkOn(bg)
        : AppColors.secondaryText(context);
    return Semantics(
      button: onTap != null,
      selected: onTap == null ? null : selected,
      label: label,
      child: ExcludeSemantics(
        child: CupertinoButton(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          color: bg,
          onPressed: onTap,
          child: Text(
            label,
            style: AppTypography.subheadline(
              context,
            ).copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
