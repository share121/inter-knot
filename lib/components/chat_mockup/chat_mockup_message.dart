import 'package:flutter/material.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';

class ChatMockupMessage extends StatelessWidget {
  const ChatMockupMessage({
    super.key,
    required this.side,
    required this.child,
    this.avatar,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final ChatMockupMessageSide side;
  final Widget child;
  final Widget? avatar;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth =
            constraints.maxWidth * ChatMockupTheme.bubbleMaxWidthFactor;
        final isRight = side == ChatMockupMessageSide.right;
        final isCenter = side == ChatMockupMessageSide.center;
        final avatarWidget = avatar;

        final content = Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: child,
          ),
        );

        final children = isCenter
            ? <Widget>[content]
            : isRight
                ? <Widget>[
                    content,
                    if (avatarWidget != null) ...[
                      const SizedBox(width: 8),
                      avatarWidget,
                    ],
                  ]
                : <Widget>[
                    if (avatarWidget != null) ...[
                      avatarWidget,
                      const SizedBox(width: 8),
                    ],
                    content,
                  ];

        return Container(
          margin: margin,
          child: Row(
            mainAxisAlignment: isCenter
                ? MainAxisAlignment.center
                : isRight
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        );
      },
    );
  }
}

enum ChatMockupMessageSide {
  left,
  right,
  center,
}
