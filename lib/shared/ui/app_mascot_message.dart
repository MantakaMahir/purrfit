import 'package:flutter/cupertino.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// Optional companion note styled without bundled character artwork.
enum MascotMood { welcome, guidance, celebration, rest, error }

class AppMascotMessage extends StatelessWidget {
  const AppMascotMessage({
    super.key,
    required this.message,
    this.title,
    this.mood = MascotMood.guidance,
  });

  final String message;
  final String? title;
  final MascotMood mood;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          switch (mood) {
            MascotMood.welcome => CupertinoIcons.hand_raised_fill,
            MascotMood.celebration => CupertinoIcons.sparkles,
            MascotMood.rest => CupertinoIcons.moon_zzz_fill,
            MascotMood.guidance => CupertinoIcons.heart_fill,
            MascotMood.error => CupertinoIcons.exclamationmark_circle_fill,
          },
          size: 52,
          color: AppColors.accent(context),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: AppTypography.headline(context)),
                  const SizedBox(height: AppSpacing.xxs),
                ],
                Text(
                  message,
                  style: AppTypography.subheadline(
                    context,
                  ).copyWith(color: AppColors.secondaryText(context)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
