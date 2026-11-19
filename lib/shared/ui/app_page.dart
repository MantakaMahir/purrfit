import 'package:flutter/cupertino.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.leading,
    this.header,
    this.padding = AppSpacing.pagePadding,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final Widget? leading;

  /// Optional custom header row that replaces the default title row.
  final Widget? header;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.appBackground(context),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.pageGradient(context)),
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              padding,
              AppSpacing.lg,
              padding,
              AppSpacing.xxl + AppSpacing.lg,
            ),
            children: [
              header ??
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ?leading,
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.largeTitle(context),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
              const SizedBox(height: AppSpacing.xl),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
