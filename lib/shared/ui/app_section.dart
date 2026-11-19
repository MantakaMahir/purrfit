import 'package:flutter/cupertino.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: AppTypography.headline(
          context,
        ).copyWith(color: AppColors.primaryText(context)),
      ),
    );
  }
}

class AppGap extends StatelessWidget {
  const AppGap({super.key, this.size = AppSpacing.sectionGap});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(height: size);
}
