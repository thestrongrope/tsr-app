import 'package:flutter/material.dart';

/// The widest a main screen's content gets, in logical pixels. Wider windows
/// (tablets) get empty margins either side instead of a stretched layout.
const double kMaxContentWidth = 840;

/// Centres [child] and caps it at [kMaxContentWidth]. Put it around a screen's
/// body; app bars and backgrounds stay full width.
class ContentWidthCap extends StatelessWidget {
  final Widget child;

  const ContentWidthCap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: child,
      ),
    );
  }
}
