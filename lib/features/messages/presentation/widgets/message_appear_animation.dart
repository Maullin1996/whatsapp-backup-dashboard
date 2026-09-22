import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';

class MessageAppearAnimation extends StatelessWidget {
  final int index;
  final Widget child;

  const MessageAppearAnimation({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (index >= 15) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppDurations.messageItemAppear,
      curve: Curves.easeOut,
      builder: (_, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}
