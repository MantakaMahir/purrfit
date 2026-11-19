import 'package:flutter/cupertino.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_typography.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.gradient,
    this.leading,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  // Source compatibility for older screens; actions now use solid fills.
  final Gradient? gradient;
  final Widget? leading;
  @override
  Widget build(BuildContext context) => _TactileButton(
    label: label,
    onPressed: onPressed,
    loading: loading,
    primary: true,
    fill: backgroundColor ?? AppColors.accent(context),
    foreground: gradient == null ? foregroundColor : null,
    leading: leading,
  );
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient,
    this.foregroundColor,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  // Legacy tonal variants share the neutral secondary treatment.
  final Gradient? gradient;
  final Color? foregroundColor;
  @override
  Widget build(BuildContext context) => _TactileButton(
    label: label,
    onPressed: onPressed,
    primary: false,
    fill: AppColors.surface(context),
    foreground: AppColors.primaryText(context),
    leading: icon == null ? null : Icon(icon, size: 19),
  );
}

/// Cupertino owns activation, semantics and drag cancellation. Pointer events
/// only animate the base; they never dispatch the callback themselves.
class _TactileButton extends StatefulWidget {
  const _TactileButton({
    required this.label,
    required this.onPressed,
    required this.primary,
    required this.fill,
    this.foreground,
    this.leading,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final Color fill;
  final Color? foreground;
  final Widget? leading;
  final bool loading;
  @override
  State<_TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<_TactileButton> {
  bool _down = false;
  int? _pointer;
  bool get _enabled => widget.onPressed != null && !widget.loading;
  void _release() {
    _pointer = null;
    if (_down) setState(() => _down = false);
  }

  @override
  void didUpdateWidget(covariant _TactileButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) {
      _down = false;
      _pointer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pressed = _down && _enabled;
    final fg = !_enabled && !widget.loading
        ? AppColors.secondaryText(context)
        : widget.foreground ??
              (widget.primary
                  ? AppColors.inkOn(widget.fill)
                  : AppColors.primaryText(context));
    final face = !_enabled && !widget.loading
        ? AppColors.secondarySurface(context)
        : widget.fill;
    final base = widget.primary && (_enabled || widget.loading)
        ? Color.alphaBlend(const Color(0x33000000), widget.fill)
        : AppColors.separator(context);
    final depth = widget.primary ? 5.0 : 3.0;
    final radius = BorderRadius.circular(AppRadii.large);
    return Semantics(
      label: widget.loading ? '${widget.label}, loading' : null,
      liveRegion: widget.loading,
      child: Padding(
        padding: EdgeInsets.only(bottom: depth),
        child: Listener(
          onPointerDown: (event) {
            if (!_enabled || _pointer != null) return;
            _pointer = event.pointer;
            setState(() => _down = true);
          },
          onPointerMove: (event) {
            final size = context.size;
            if (event.pointer == _pointer &&
                size != null &&
                !(Offset.zero & size).contains(event.localPosition)) {
              _release();
            }
          },
          onPointerUp: (event) {
            if (event.pointer == _pointer) _release();
          },
          onPointerCancel: (event) {
            if (event.pointer == _pointer) _release();
          },
          child: AnimatedContainer(
            duration: AppMotion.duration(
              context,
              const Duration(milliseconds: 90),
            ),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, pressed ? depth - 1 : 0, 0),
            decoration: BoxDecoration(
              color: face,
              borderRadius: radius,
              border: Border.all(
                color: widget.primary ? face : AppColors.separator(context),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(color: base, offset: Offset(0, pressed ? 1 : depth)),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                minimumSize: const Size(48, 54),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                borderRadius: radius,
                pressedOpacity: 1,
                onPressed: !_enabled
                    ? null
                    : () {
                        widget.onPressed!();
                      },
                child: IconTheme(
                  data: IconThemeData(color: fg),
                  child: widget.loading
                      ? CupertinoActivityIndicator(color: fg)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.leading != null) ...[
                              widget.leading!,
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                widget.label,
                                textAlign: TextAlign.center,
                                style: AppTypography.button(context).copyWith(
                                  color: fg,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
