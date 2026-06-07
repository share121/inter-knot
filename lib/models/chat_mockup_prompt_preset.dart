class ChatMockupPromptPreset {
  const ChatMockupPromptPreset({
    required this.order,
    required this.promptsById,
    required this.enabledById,
  });

  final List<String> order;
  final Map<String, String> promptsById;
  final Map<String, bool> enabledById;

  factory ChatMockupPromptPreset.fromTavernLikeJson(Map<String, dynamic> json) {
    final promptsById = <String, String>{};
    final prompts = json['prompts'];
    if (prompts is List) {
      for (final entry in prompts) {
        if (entry is! Map<String, dynamic>) continue;
        final identifier = entry['identifier'];
        final content = entry['content'];
        if (identifier is String &&
            identifier.isNotEmpty &&
            content is String) {
          promptsById[identifier] = content;
        }
      }
    }

    final order = <String>[];
    final enabledById = <String, bool>{};
    final promptOrder = json['prompt_order'];
    if (promptOrder is List && promptOrder.isNotEmpty) {
      final first = promptOrder.first;
      if (first is Map<String, dynamic>) {
        final rawOrder = first['order'];
        if (rawOrder is List) {
          for (final item in rawOrder) {
            if (item is! Map<String, dynamic>) continue;
            final identifier = item['identifier'];
            if (identifier is! String || identifier.isEmpty) continue;
            order.add(identifier);
            final enabled = item['enabled'] == true;
            enabledById[identifier] = enabled;
          }
        }
      }
    }

    return ChatMockupPromptPreset(
      order: order,
      promptsById: promptsById,
      enabledById: enabledById,
    );
  }
}
