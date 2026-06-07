import 'package:flutter/material.dart';

class ChatMockupTheme {
  const ChatMockupTheme._();

  static const Color background = Color(0xff050505);
  static const Color outgoing = Color(0xff315ee8);
  static const Color incoming = Colors.white;
  static const Color darkField = Color(0xff050505);
  static const Color borderDark = Color(0xff1a1a1a);
  static const Color mutedText = Color(0xff555555);
  static const Color warningGreen = Color(0xff99ff00);
  static const Color infoBlue = Color(0xff00a8ff);

  static const double canvasMaxWidth = 430;
  static const double avatarSize = 38;
  static const double bubbleMaxWidthFactor = 0.72;

  static const TextStyle titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 17,
    fontWeight: FontWeight.w900,
    height: 1.0,
    shadows: [
      Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 1.5),
    ],
  );

  static const TextStyle bubbleTextDark = TextStyle(
    color: Colors.black,
    fontSize: 16,
    fontWeight: FontWeight.w900,
    height: 1.1,
  );

  static const TextStyle bubbleTextLight = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w900,
    height: 1.1,
  );
}
