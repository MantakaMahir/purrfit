import 'package:flutter/cupertino.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'app_buttons.dart';
import 'app_mascot_message.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CupertinoActivityIndicator(),
        if (label != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            label!,
            style: AppTypography.subheadline(
              context,
            ).copyWith(color: AppColors.secondaryText(context)),
          ),
        ],
      ],
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppMascotMessage(
          title: 'Let’s try that again.',
          message: message,
          mood: MascotMood.error,
        ),
        const SizedBox(height: AppSpacing.md),
        AppSecondaryButton(label: 'Try again', onPressed: onRetry),
      ],
    );
  }
}
