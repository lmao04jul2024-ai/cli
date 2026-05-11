import 'package:flutter/material.dart';

class NeumorphicCardWrapper extends StatelessWidget {
  final Widget child;
  final double padding;
  final double borderRadius;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const NeumorphicCardWrapper({
    super.key,
    required this.child,
    this.padding = 16.0,
    this.borderRadius = 20.0,
    this.backgroundColor = Colors.white,
    this.onTap,
  });

    @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}