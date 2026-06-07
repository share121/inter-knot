import 'package:flutter/material.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';

class ChatMockupTitleBar extends StatelessWidget {
  const ChatMockupTitleBar({
    super.key,
    this.title = 'Click here to edit chat title',
    this.isEditing = false,
    this.controller,
    this.focusNode,
    this.onTap,
    this.onSubmitted,
    this.onTapOutside,
    this.showConfirmButton = false,
    this.onConfirm,
  });

  final String title;
  final bool isEditing;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final TapRegionCallback? onTapOutside;
  final bool showConfirmButton;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    const titleStyle = ChatMockupTheme.titleStyle;
    final editableChild = isEditing
        ? TextField(
            controller: controller,
            focusNode: focusNode,
            style: titleStyle,
            cursorColor: const Color(0xff111111),
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Click here to edit chat title',
              hintStyle: titleStyle.copyWith(
                color: titleStyle.color?.withValues(alpha: 0.55),
              ),
              contentPadding: EdgeInsets.zero,
              suffixIcon: showConfirmButton
                  ? IconButton(
                      tooltip: '确认',
                      icon: const Icon(Icons.check_rounded, size: 18),
                      onPressed: onConfirm,
                    )
                  : null,
            ),
            onSubmitted: onSubmitted,
            onTapOutside: onTapOutside,
          )
        : Text(
            title,
            style: titleStyle,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.chat_bubble_rounded,
                color: Colors.grey,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: isEditing ? null : onTap,
                  child: editableChild,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(
            color: Color(0xff2a2a2a),
            thickness: 1,
            height: 1,
          ),
        ],
      ),
    );
  }
}
