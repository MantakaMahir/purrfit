import 'package:flutter/cupertino.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'app_card.dart';

class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.accent,
    this.gradient,
    this.compact = false,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? accent;
  final Gradient? gradient;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.accent(context);
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: AppCard(
          color: AppColors.surface(context),
          gradient: gradient,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null && !compact) ...[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: .12),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(value, style: AppTypography.title2(context)),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                style: AppTypography.footnote(
                  context,
                ).copyWith(color: AppColors.secondaryText(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
