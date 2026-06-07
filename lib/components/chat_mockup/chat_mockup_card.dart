import 'package:flutter/material.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_bubble.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';

class ChatMockupActionCard extends StatelessWidget {
  const ChatMockupActionCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.actionText,
    this.isCenter = false,
    this.titleChild,
    this.onTitleTap,
    this.actionTextChild,
    this.onActionTextTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String actionText;
  final bool isCenter;
  final Widget? titleChild;
  final VoidCallback? onTitleTap;
  final Widget? actionTextChild;
  final VoidCallback? onActionTextTap;

  @override
  Widget build(BuildContext context) {
    final defaultTitle = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w900,
        height: 1.0,
      ),
    );

    return ChatMockupBubbleShell(
      isMe: true,
      isCenter: isCenter,
      showTail: !isCenter,
      color: ChatMockupTheme.outgoing,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onTitleTap,
              child: _DarkInputBar(
                icon: icon,
                iconColor: iconColor,
                child: titleChild ?? defaultTitle,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: CustomPaint(
                  painter: _PatternButtonBackgroundPainter(),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(
                        color: const Color(0xff2f2f2f),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: onActionTextTap != null
                          ? InkWell(
                              onTap: onActionTextTap,
                              child: actionTextChild ??
                                  Text(
                                    actionText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                      height: 1.0,
                                    ),
                                  ),
                            )
                          : actionTextChild ??
                              Text(
                                actionText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  height: 1.0,
                                ),
                              ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMockupReplyCard extends StatelessWidget {
  const ChatMockupReplyCard({
    super.key,
    this.replyLabel = 'REPLY',
    this.firstText = 'Click here to edit',
    this.secondText = 'Click here to edit',
    this.onFirstTextTap,
    this.onSecondTextTap,
    this.firstTextChild,
    this.secondTextChild,
  });

  final String replyLabel;
  final String firstText;
  final String secondText;
  final VoidCallback? onFirstTextTap;
  final VoidCallback? onSecondTextTap;
  final Widget? firstTextChild;
  final Widget? secondTextChild;

  @override
  Widget build(BuildContext context) {
    return ChatMockupBubbleShell(
      isMe: true,
      color: ChatMockupTheme.outgoing,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    replyLabel,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _WhiteEditBar(
              text: firstText,
              onTap: onFirstTextTap,
              child: firstTextChild,
            ),
            const SizedBox(height: 6),
            _WhiteEditBar(
              text: secondText,
              onTap: onSecondTextTap,
              child: secondTextChild,
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMockupCommissionCard extends StatelessWidget {
  const ChatMockupCommissionCard({
    super.key,
    this.title = 'Commission',
    this.subtitle = 'Click here to edit',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ChatMockupBubbleShell(
      isMe: true,
      color: ChatMockupTheme.outgoing,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMockupDividerText extends StatelessWidget {
  const ChatMockupDividerText({
    super.key,
    this.text = '-- Click here to edit --',
    this.child,
    this.onTap,
  });

  final String text;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text,
      style: const TextStyle(
        color: Color(0xff5b5b5b),
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    );

    final content = child ?? textWidget;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: onTap != null ? InkWell(onTap: onTap, child: content) : content,
      ),
    );
  }
}

class _DarkInputBar extends StatelessWidget {
  const _DarkInputBar({
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: ChatMockupTheme.darkField,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: ChatMockupTheme.borderDark, width: 1.6),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}

class _WhiteEditBar extends StatelessWidget {
  const _WhiteEditBar({
    required this.text,
    this.child,
    this.onTap,
  });

  final String text;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 15,
        fontWeight: FontWeight.w900,
        height: 1.0,
      ),
    );

    final content = child ?? textWidget;

    final bar = Container(
      height: 33,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(child: content),
    );

    return onTap == null ? bar : InkWell(onTap: onTap, child: bar);
  }
}

class _PatternButtonBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = const Color(0xff111111);
    canvas.drawRect(Offset.zero & size, base);

    final stripePaint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    const stripeWidth = 6.0;
    for (double x = -size.height; x < size.width; x += stripeWidth * 2) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + stripeWidth, 0)
        ..lineTo(x + size.height + stripeWidth, size.height)
        ..lineTo(x + size.height, size.height)
        ..close();
      canvas.drawPath(path, stripePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
