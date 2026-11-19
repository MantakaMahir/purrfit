import 'package:flutter/cupertino.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.color,
    this.gradient,
  });

  final Widget child;
  final double padding;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        // Legacy decorative gradients resolve to a calm surface. Semantic
        // states can still request a deliberate solid color.
        color: color ?? AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppRadii.xlarge),
        border: Border.all(
          color: AppColors.separator(context).withValues(alpha: .9),
        ),
      ),
      child: child,
    );
  }
}
