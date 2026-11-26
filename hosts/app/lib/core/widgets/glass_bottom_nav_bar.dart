import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One tab in the [GlassBottomNavBar].
class GlassNavDestination {
  const GlassNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });

  /// Outlined icon shown while the tab is at rest.
  final IconData icon;

  /// Filled icon shown while the tab is selected.
  final IconData selectedIcon;

  final String label;

  /// A dot is shown on the icon when this is greater than zero.
  final int badgeCount;
}

/// The app's floating, frosted-glass tab bar.
///
/// A white translucent capsule over a blurred backdrop, with a hairline top
/// highlight and a soft shadow. The selected tab sits in a light pill that
/// slides between destinations, and every tab keeps its label visible.
///
/// The page scrolls behind the capsule, which is what the blur shows; the
/// scaffold reports the capsule's height as the bottom padding of the page
/// (see `withTabBarInset`), so the last item still ends above it.
///
/// The bar is solid, with no blur, where the member asks the phone for higher
/// contrast ([MediaQueryData.highContrast]) or the app is built with
/// `--dart-define=TSR_SOLID_TAB_BAR=true`. Flutter does not expose iOS
/// "Reduce Transparency" or any Android equivalent; high contrast is the
/// nearest signal on both. The build switch is the low-end-phone fallback:
/// there is no way to detect at run time that a phone cannot blur.
class GlassBottomNavBar extends StatelessWidget {
  const GlassBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
  }) : assert(destinations.length > 0);

  final int selectedIndex;
  final List<GlassNavDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  /// Height of the capsule itself, without the margin or safe-area inset.
  static const double barHeight = 64;

  static const double horizontalMargin = 18;
  static const double bottomMargin = AppTheme.spacingSM;

  static const double _iconSize = 21;
  static const double _labelSize = 11.5;
  static const double _labelLineHeight = 1.1;
  static const double _labelLetterSpacing = 0.1;
  static const double _iconLabelGap = AppTheme.spacingXS / 2;
  static const double _itemPadding = AppTheme.spacingXS;
  static const double _pillInset = AppTheme.spacingXS;
  static const double _pillRadius = 999;
  static const double _backdropBlurSigma = 30;

  static const double _shadowBlur = 24;
  static const Offset _shadowOffset = Offset(0, 10);
  static const double _softShadowBlur = 8;
  static const Offset _softShadowOffset = Offset(0, 2);
  static const double _shadowOpacity = 0.10;
  static const double _softShadowOpacity = 0.05;

  static const double _rimWidth = 1;
  static const double _rimOpacity = 0.70;
  static const double _hairlineHeight = 1;
  static const double _hairlineTop = 0.5;
  static const double _hairlineOpacity = 0.95;

  static const double _pillBorderWidth = 1;
  static const double _pillBorderOpacity = 0.95;
  static const double _pillShadowBlur = 5;
  static const Offset _pillShadowOffset = Offset(0, 1);
  static const double _pillShadowOpacity = 0.045;
  static const double _badgeSize = 7;
  static const double _iconScaleFrom = 0.86;

  /// A little extra colour behind the glass, as Apple's material does, so the
  /// blur is visible even over pale content. Each row sums to 1, so white,
  /// black and greys pass through unchanged and the contrast test can use them.
  static const List<double> _saturationMatrix = <double>[
    1.2756, -0.2503, -0.0253, 0, 0, //
    -0.0744, 1.0997, -0.0253, 0, 0, //
    -0.0744, -0.2503, 1.3247, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  /// The white tint over the blurred backdrop, at the capsule's top-left and
  /// bottom-right. Low enough to see content move behind the glass, high
  /// enough that the dark ink keeps 4.5:1 over pure black (see the contrast
  /// test, which uses the lower of the two).
  static const double surfaceTopOpacity = 0.72;
  static const double surfaceBottomOpacity = 0.60;

  /// The tint of the solid capsule, used when the bar does not blur.
  static const double solidSurfaceOpacity = 1;

  /// Every label is the dark ink: a solid colour, not the ink at partial
  /// opacity, so its contrast does not depend on what is behind the bar. The
  /// selected tab is told apart by its pill, weight and filled icon.
  static const Color unselectedInk = AppTheme.navBarInk;

  /// Build-time switch for phones that cannot afford the blur:
  /// `--dart-define=TSR_SOLID_TAB_BAR=true`.
  static const bool forceSolid = bool.fromEnvironment('TSR_SOLID_TAB_BAR');
  static const Duration _animationDuration = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    final selected = selectedIndex.clamp(0, destinations.length - 1);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : _animationDuration;
    final radius = BorderRadius.circular(barHeight / 2);
    final blurred = !forceSolid && !MediaQuery.highContrastOf(context);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: bottomMargin),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: horizontalMargin),
        child: SizedBox(
          height: barHeight,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _shadowOpacity),
                  blurRadius: _shadowBlur,
                  offset: _shadowOffset,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: _softShadowOpacity),
                  blurRadius: _softShadowBlur,
                  offset: _softShadowOffset,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: _Backdrop(
                blurred: blurred,
                child: Stack(
                  children: [
                    // The frosted pane. It stays light enough to show the blur,
                    // and opaque enough for the dark labels to keep their
                    // contrast over any content behind; solid when not blurred.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(
                                alpha: blurred
                                    ? surfaceTopOpacity
                                    : solidSurfaceOpacity,
                              ),
                              Colors.white.withValues(
                                alpha: blurred
                                    ? surfaceBottomOpacity
                                    : solidSurfaceOpacity,
                              ),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: _rimOpacity),
                            width: _rimWidth,
                          ),
                        ),
                      ),
                    ),
                    // The specular hairline that makes the top edge read as
                    // glass rather than a flat white card.
                    Positioned(
                      left: AppTheme.spacing2XL,
                      right: AppTheme.spacing2XL,
                      top: _hairlineTop,
                      child: IgnorePointer(
                        child: Container(
                          height: _hairlineHeight,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(
                                  alpha: _hairlineOpacity,
                                ),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Material(
                      type: MaterialType.transparency,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final itemWidth =
                              constraints.maxWidth / destinations.length;
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              AnimatedPositioned(
                                duration: duration,
                                curve: Curves.easeOutCubic,
                                left: itemWidth * selected + _pillInset,
                                top: _pillInset,
                                width: itemWidth - _pillInset * 2,
                                height: barHeight - _pillInset * 2,
                                child: const _SelectedPill(),
                              ),
                              Row(
                                children: [
                                  for (var i = 0; i < destinations.length; i++)
                                    Expanded(
                                      child: _NavItem(
                                        destination: destinations[i],
                                        selected: i == selected,
                                        duration: duration,
                                        onTap: () => onDestinationSelected(i),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one blur in the bar: the backdrop seen through the capsule, blurred and
/// a little more saturated. Without it the child is shown as it is.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.blurred, required this.child});

  final bool blurred;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!blurred) return child;
    return BackdropFilter(
      filter: ImageFilter.compose(
        outer: const ColorFilter.matrix(GlassBottomNavBar._saturationMatrix),
        inner: ImageFilter.blur(
          sigmaX: GlassBottomNavBar._backdropBlurSigma,
          sigmaY: GlassBottomNavBar._backdropBlurSigma,
        ),
      ),
      child: child,
    );
  }
}

class _SelectedPill extends StatelessWidget {
  const _SelectedPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GlassBottomNavBar._pillRadius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.navBarSelectedFillTop, AppTheme.navBarSelectedFill],
        ),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: GlassBottomNavBar._pillBorderOpacity,
          ),
          width: GlassBottomNavBar._pillBorderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: GlassBottomNavBar._pillShadowOpacity,
            ),
            blurRadius: GlassBottomNavBar._pillShadowBlur,
            offset: GlassBottomNavBar._pillShadowOffset,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final GlassNavDestination destination;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppTheme.navBarInk
        : GlassBottomNavBar.unselectedInk;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GlassBottomNavBar.barHeight / 2),
        child: Padding(
          padding: const EdgeInsets.all(GlassBottomNavBar._itemPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: duration,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale:
                        Tween<double>(
                          begin: GlassBottomNavBar._iconScaleFrom,
                          end: 1,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                    child: child,
                  ),
                ),
                child: Badge(
                  key: ValueKey(selected),
                  isLabelVisible: destination.badgeCount > 0,
                  backgroundColor: AppTheme.errorRed,
                  smallSize: GlassBottomNavBar._badgeSize,
                  child: Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: GlassBottomNavBar._iconSize,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: GlassBottomNavBar._iconLabelGap),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: Curves.easeOut,
                  style: TextStyle(
                    fontSize: GlassBottomNavBar._labelSize,
                    height: GlassBottomNavBar._labelLineHeight,
                    letterSpacing: GlassBottomNavBar._labelLetterSpacing,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                  child: Text(destination.label, maxLines: 1, softWrap: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
