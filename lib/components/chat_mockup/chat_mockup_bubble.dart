import 'package:flutter/material.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';

class ChatMockupTextBubble extends StatelessWidget {
  const ChatMockupTextBubble({
    super.key,
    required this.text,
    required this.isMe,
    this.textAlign = TextAlign.left,
  });

  final String text;
  final bool isMe;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        isMe ? ChatMockupTheme.outgoing : ChatMockupTheme.incoming;
    final textStyle =
        isMe ? ChatMockupTheme.bubbleTextLight : ChatMockupTheme.bubbleTextDark;

    return ChatMockupBubbleShell(
      isMe: isMe,
      color: bubbleColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          text,
          textAlign: textAlign,
          style: textStyle,
        ),
      ),
    );
  }
}

class ChatMockupEditableTextBubble extends StatelessWidget {
  const ChatMockupEditableTextBubble({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isMe,
    required this.hintText,
    this.textAlign = TextAlign.left,
    this.cursorColor = const Color(0xff111111),
    this.onSubmitted,
    this.retainKnockEditFocusOnTapOutside,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isMe;
  final String hintText;
  final TextAlign textAlign;
  final Color cursorColor;
  final ValueChanged<String>? onSubmitted;
  final bool Function()? retainKnockEditFocusOnTapOutside;

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        isMe ? ChatMockupTheme.outgoing : ChatMockupTheme.incoming;
    final textStyle =
        isMe ? ChatMockupTheme.bubbleTextLight : ChatMockupTheme.bubbleTextDark;

    return ChatMockupBubbleShell(
      isMe: isMe,
      color: bubbleColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: textAlign,
          maxLines: 3,
          minLines: 1,
          style: textStyle,
          cursorColor: cursorColor,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: hintText,
            hintStyle: textStyle.copyWith(
              color: textStyle.color?.withValues(alpha: 0.6),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          onSubmitted: onSubmitted,
          onEditingComplete: retainKnockEditFocusOnTapOutside == null
              ? null
              : () {
                  if (!retainKnockEditFocusOnTapOutside!()) return;
                  focusNode.requestFocus();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!context.mounted) return;
                    if (!retainKnockEditFocusOnTapOutside!()) return;
                    if (focusNode.canRequestFocus) {
                      focusNode.requestFocus();
                    }
                  });
                },
          onTapOutside: retainKnockEditFocusOnTapOutside == null
              ? null
              : (event) {
                  if (retainKnockEditFocusOnTapOutside!()) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!context.mounted) return;
                      if (!retainKnockEditFocusOnTapOutside!()) return;
                      if (focusNode.canRequestFocus) {
                        focusNode.requestFocus();
                      }
                    });
                  } else {
                    focusNode.unfocus();
                  }
                },
        ),
      ),
    );
  }
}

class ChatMockupEmojiBubble extends StatelessWidget {
  const ChatMockupEmojiBubble({
    super.key,
    required this.emoji,
    required this.isMe,
  });

  final String emoji;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return ChatMockupBubbleShell(
      isMe: isMe,
      color: isMe ? ChatMockupTheme.outgoing : ChatMockupTheme.incoming,
      child: SizedBox(
        width: 58,
        height: 42,
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}

class ChatMockupImageBubble extends StatelessWidget {
  const ChatMockupImageBubble({
    super.key,
    required this.image,
    required this.isMe,
    this.width = 104,
    this.height = 104,
    this.frameColor,
    this.fit = BoxFit.cover,
  });

  final ImageProvider image;
  final bool isMe;
  final double width;
  final double height;
  final Color? frameColor;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final background = frameColor ??
        (isMe ? ChatMockupTheme.outgoing : ChatMockupTheme.incoming);

    return ChatMockupBubbleShell(
      isMe: isMe,
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image(
            image: image,
            width: width,
            height: height,
            fit: fit,
          ),
        ),
      ),
    );
  }
}

class ChatMockupBubbleShell extends StatelessWidget {
  const ChatMockupBubbleShell({
    super.key,
    required this.isMe,
    required this.color,
    required this.child,
    this.isCenter = false,
    this.showTail = true,
  });

  final bool isMe;
  final Color color;
  final Widget child;
  final bool isCenter;
  final bool showTail;

  @override
  Widget build(BuildContext context) {
    final radius = isCenter
        ? BorderRadius.circular(20)
        : BorderRadius.only(
            topLeft: Radius.circular(isMe ? 20 : 8),
            topRight: Radius.circular(isMe ? 8 : 20),
            bottomLeft: const Radius.circular(20),
            bottomRight: const Radius.circular(20),
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
        if (showTail && !isCenter)
          Positioned(
            top: 12,
            left: isMe ? null : -8,
            right: isMe ? -8 : null,
            child: CustomPaint(
              size: const Size(10, 13),
              painter: _TailPainter(color: color, isMe: isMe),
            ),
          ),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({
    required this.color,
    required this.isMe,
  });

  final Color color;
  final bool isMe;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (isMe) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height / 2)
        ..lineTo(size.width, size.height)
        ..close();
    }
    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isMe != isMe;
  }
}
