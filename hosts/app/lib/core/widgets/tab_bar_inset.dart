import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// [base] with the room a scrolling page needs at its foot so its last item
/// ends above the floating tab bar.
///
/// The tab scaffold lets the page run behind the bar (that is what the bar
/// blurs) and reports the bar's height as the page's bottom padding, so the
/// inset is [MediaQuery.paddingOf] plus a small gap. Outside the tabs it is
/// the phone's own bottom inset (the home indicator), which is also right.
EdgeInsets withTabBarInset(
  BuildContext context, [
  EdgeInsets base = EdgeInsets.zero,
]) {
  return base.copyWith(
    bottom: base.bottom + MediaQuery.paddingOf(context).bottom + _gap,
  );
}

/// A sliver that adds the same room at the end of a [CustomScrollView].
class TabBarInsetSliver extends StatelessWidget {
  const TabBarInsetSliver({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(height: withTabBarInset(context).bottom),
    );
  }
}

/// What the tab scaffold tells the pages inside it about the bar.
///
/// A page's own Scaffold strips the bottom padding in its floating-button
/// slot, so the button cannot read the bar from [MediaQuery]; the shell
/// publishes it here instead.
class TabBarScope extends InheritedWidget {
  const TabBarScope({super.key, required this.fabLift, required super.child});

  /// How far above the phone's own inset a floating button must sit to clear
  /// the bar.
  final double fabLift;

  static double fabLiftOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabBarScope>()?.fabLift ?? 0;

  @override
  bool updateShouldNotify(TabBarScope oldWidget) =>
      fabLift != oldWidget.fabLift;
}

/// Lifts a [FloatingActionButton] placed by a page's own scaffold above the
/// tab bar. That scaffold sits behind the bar and places the button from the
/// phone's inset alone.
class TabBarFabLift extends StatelessWidget {
  const TabBarFabLift({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: TabBarScope.fabLiftOf(context)),
      child: child,
    );
  }
}

const double _gap = AppTheme.spacingMD;
