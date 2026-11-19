import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator;

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_radii.dart';

class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.label = 'Progress',
  });

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0.0, 1.0);
    return Semantics(
      label: label,
      value: '${(progress * 100).round()} percent',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: Container(
            height: 10,
            color: AppColors.progressGray.withValues(alpha: .28),
            alignment: Alignment.centerLeft,
            child: AnimatedFractionallySizedBox(
              duration: AppMotion.duration(context, AppMotion.normal),
              curve: AppMotion.curve,
              widthFactor: progress,
              child: Container(color: AppColors.accent(context)),
            ),
          ),
        ),
      ),
    );
  }
}

class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    super.key,
    required this.value,
    required this.child,
    this.size = 108,
    this.label = 'Progress',
  });

  final double value;
  final Widget child;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0.0, 1.0);
    return Semantics(
      label: label,
      value: '${(progress * 100).round()} percent',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Determinate ring - no spinning "loading" animation at 0%.
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  color: AppColors.accent(context),
                  backgroundColor: AppColors.progressGray.withValues(
                    alpha: .28,
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
