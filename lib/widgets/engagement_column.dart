import 'package:flutter/material.dart';

class EngagementColumn extends StatelessWidget {
  final dynamic merchant;
  final bool isInfoMode;
  final VoidCallback onToggleAction;
  final VoidCallback onLike;
  final VoidCallback onRefer;
  final VoidCallback onShare;

  const EngagementColumn({
    super.key,
    required this.merchant,
    required this.isInfoMode,
    required this.onToggleAction,
    required this.onLike,
    required this.onRefer,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final bool wasLiked = merchant['isLiked'] ?? false;
    return Column(
      children: [
        // ... existing code in build method
        _buildCustomIconButton(
          !isInfoMode
              ? Image.asset(
                  'assets/images/icon_64.png',
                  width: 32,
                  height: 32,
                ) // Your custom logo for Stamps
              : const Icon(Icons.info_outline, color: Colors.white, size: 33),
          !isInfoMode ? "Stamps" : "Info",
          onTap: onToggleAction,
        ),
        // ...
        // _buildIconButton(
        //   isInfoMode ? Icons.payments : Icons.info_outline,
        //   isInfoMode ? "Stamps" : "Info",
        //   color: Color.fromARGB(255, 139, 225, 96),
        //   onTap: onToggleAction,
        // ),
        const SizedBox(height: 20),
        _buildIconButton(Icons.person_add, "Refer", onTap: onRefer),
        const SizedBox(height: 20),
        _buildIconButton(
          wasLiked ? Icons.thumb_up_alt : Icons.thumb_up_off_alt,
          merchant['likesCount']?.toString() ?? "0",
          onTap: onLike,
        ),
        const SizedBox(height: 20),
        _buildIconButton(Icons.share, "Share", onTap: onShare),
      ],
    );
  }

  Widget _buildIconButton(
    IconData icon,
    String label, {
    Color color = Colors.white,
    double size = 28,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: size),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomIconButton(
    Widget iconWidget,
    String label, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(child: iconWidget),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
              fontFamily: 'SF Pro', // Modern Fintech typography
            ),
          ),
        ],
      ),
    );
  }
}
