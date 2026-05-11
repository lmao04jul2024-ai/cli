import 'package:flutter/material.dart';

class StampGrid extends StatelessWidget {
  final int total;
  final int currentStamps;

  const StampGrid({
    super.key,
    required this.total,
    required this.currentStamps,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(total, (index) {
        final bool isFilled = index < currentStamps;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            // color: isFilled ? Colors.white : Colors.black38,
            color: Colors.black38,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFilled
                  ? Color.fromARGB(255, 255, 255, 255)
                  : Colors.white10,
              width: 1.5,
            ),
            boxShadow: isFilled
                ? [
                    BoxShadow(
                      color: const Color(0xFF007AFF).withOpacity(0.3),
                      blurRadius: 10,
                    ),
                  ]
                : [],
          ),
          child: isFilled
              ? Image.asset( 'assets/images/icon_64.png', width: 32, height: 32)
              // ? const Icon(Icons.stars, size: 22, color: Color(0xFF007AFF))
              : null,
        );
      }),
    );
  }
}
