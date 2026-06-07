import 'package:flutter/material.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';

class ChatMockupAvatar extends StatelessWidget {
  const ChatMockupAvatar({
    super.key,
    required this.image,
    this.size = ChatMockupTheme.avatarSize,
    this.borderColor = const Color(0xff1f1f1f),
  });

  final ImageProvider image;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image(
          image: image,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: Color(0xff202020),
            child: Icon(Icons.person, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
