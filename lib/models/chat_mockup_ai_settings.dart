class ChatMockupAiSettings {
  const ChatMockupAiSettings({
    required this.endpoint,
    required this.model,
    required this.apiKey,
    required this.rolePrompt,
    required this.userPrompt,
    required this.directorSendPrompt,
    required this.roleSendPrompt,
    this.enableStreaming = true,
  });

  final String endpoint;
  final String model;
  final String apiKey;
  final String rolePrompt;
  final String userPrompt;
  final String directorSendPrompt;
  final String roleSendPrompt;

  /// When false, AI calls use non-streaming [ChatMockupAiApi.createChatCompletion].
  final bool enableStreaming;

  bool get isConfigured =>
      endpoint.trim().isNotEmpty &&
      model.trim().isNotEmpty &&
      apiKey.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'endpoint': endpoint,
      'model': model,
      'apiKey': apiKey,
      'rolePrompt': rolePrompt,
      'userPrompt': userPrompt,
      'directorSendPrompt': directorSendPrompt,
      'roleSendPrompt': roleSendPrompt,
      'enableStreaming': enableStreaming,
    };
  }

  factory ChatMockupAiSettings.fromJson(Map<String, dynamic> json) {
    String readString(String key) {
      final value = json[key];
      return value is String ? value : '';
    }

    bool readBool(String key, {bool fallback = true}) {
      final value = json[key];
      if (value is bool) return value;
      return fallback;
    }

    return ChatMockupAiSettings(
      endpoint: readString('endpoint'),
      model: readString('model'),
      apiKey: readString('apiKey'),
      rolePrompt: readString('rolePrompt'),
      userPrompt: readString('userPrompt'),
      directorSendPrompt: readString('directorSendPrompt'),
      roleSendPrompt: readString('roleSendPrompt'),
      enableStreaming: readBool('enableStreaming'),
    );
  }

  ChatMockupAiSettings copyWith({
    String? endpoint,
    String? model,
    String? apiKey,
    String? rolePrompt,
    String? userPrompt,
    String? directorSendPrompt,
    String? roleSendPrompt,
    bool? enableStreaming,
  }) {
    return ChatMockupAiSettings(
      endpoint: endpoint ?? this.endpoint,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      rolePrompt: rolePrompt ?? this.rolePrompt,
      userPrompt: userPrompt ?? this.userPrompt,
      directorSendPrompt: directorSendPrompt ?? this.directorSendPrompt,
      roleSendPrompt: roleSendPrompt ?? this.roleSendPrompt,
      enableStreaming: enableStreaming ?? this.enableStreaming,
    );
  }

  static const empty = ChatMockupAiSettings(
    endpoint: '',
    model: '',
    apiKey: '',
    rolePrompt: '',
    userPrompt: '',
    directorSendPrompt: '',
    roleSendPrompt: '',
  );
}

class AiCredentialPreset {
  const AiCredentialPreset({
    required this.id,
    required this.name,
    required this.endpoint,
    required this.model,
    required this.apiKey,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String endpoint;
  final String model;
  final String apiKey;
  final int updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'endpoint': endpoint,
      'model': model,
      'apiKey': apiKey,
      'updatedAt': updatedAt,
    };
  }

  factory AiCredentialPreset.fromJson(Map<String, dynamic> json) {
    String readString(String key, {String fallback = ''}) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
      return fallback;
    }

    int readInt(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    return AiCredentialPreset(
      id: readString('id', fallback: 'credential_default'),
      name: readString('name', fallback: '默认凭据'),
      endpoint: readString('endpoint'),
      model: readString('model'),
      apiKey: readString('apiKey'),
      updatedAt: readInt('updatedAt'),
    );
  }

  AiCredentialPreset copyWith({
    String? id,
    String? name,
    String? endpoint,
    String? model,
    String? apiKey,
    int? updatedAt,
  }) {
    return AiCredentialPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      endpoint: endpoint ?? this.endpoint,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AiRolePromptPreset {
  const AiRolePromptPreset({
    required this.id,
    required this.name,
    required this.rolePrompt,
    required this.userPrompt,
    required this.directorSendPrompt,
    required this.roleSendPrompt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String rolePrompt;
  final String userPrompt;
  final String directorSendPrompt;
  final String roleSendPrompt;
  final int updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rolePrompt': rolePrompt,
      'userPrompt': userPrompt,
      'directorSendPrompt': directorSendPrompt,
      'roleSendPrompt': roleSendPrompt,
      'updatedAt': updatedAt,
    };
  }

  factory AiRolePromptPreset.fromJson(Map<String, dynamic> json) {
    String readString(String key, {String fallback = ''}) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
      return fallback;
    }

    int readInt(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    return AiRolePromptPreset(
      id: readString('id', fallback: 'prompt_default'),
      name: readString('name', fallback: '默认角色提示词'),
      rolePrompt: readString('rolePrompt'),
      userPrompt: readString('userPrompt'),
      directorSendPrompt: readString('directorSendPrompt'),
      roleSendPrompt: readString('roleSendPrompt'),
      updatedAt: readInt('updatedAt'),
    );
  }

  AiRolePromptPreset copyWith({
    String? id,
    String? name,
    String? rolePrompt,
    String? userPrompt,
    String? directorSendPrompt,
    String? roleSendPrompt,
    int? updatedAt,
  }) {
    return AiRolePromptPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      rolePrompt: rolePrompt ?? this.rolePrompt,
      userPrompt: userPrompt ?? this.userPrompt,
      directorSendPrompt: directorSendPrompt ?? this.directorSendPrompt,
      roleSendPrompt: roleSendPrompt ?? this.roleSendPrompt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AiPresetLibrary {
  const AiPresetLibrary({
    required this.version,
    required this.credentialPresets,
    required this.promptPresets,
    required this.selectedCredentialPresetId,
    required this.selectedPromptPresetId,
    this.enableStreaming = true,
  });

  final int version;
  final List<AiCredentialPreset> credentialPresets;
  final List<AiRolePromptPreset> promptPresets;
  final String selectedCredentialPresetId;
  final String selectedPromptPresetId;

  /// Global toggle: streaming vs one-shot completion for AI 代写.
  final bool enableStreaming;

  static const empty = AiPresetLibrary(
    version: 1,
    credentialPresets: <AiCredentialPreset>[],
    promptPresets: <AiRolePromptPreset>[],
    selectedCredentialPresetId: '',
    selectedPromptPresetId: '',
  );

  AiCredentialPreset? get selectedCredentialPreset {
    for (final preset in credentialPresets) {
      if (preset.id == selectedCredentialPresetId) {
        return preset;
      }
    }
    return credentialPresets.isEmpty ? null : credentialPresets.first;
  }

  AiRolePromptPreset? get selectedPromptPreset {
    for (final preset in promptPresets) {
      if (preset.id == selectedPromptPresetId) {
        return preset;
      }
    }
    return promptPresets.isEmpty ? null : promptPresets.first;
  }

  ChatMockupAiSettings toAiSettings() {
    final credential = selectedCredentialPreset;
    final prompt = selectedPromptPreset;
    return ChatMockupAiSettings(
      endpoint: credential?.endpoint ?? '',
      model: credential?.model ?? '',
      apiKey: credential?.apiKey ?? '',
      rolePrompt: prompt?.rolePrompt ?? '',
      userPrompt: prompt?.userPrompt ?? '',
      directorSendPrompt: prompt?.directorSendPrompt ?? '',
      roleSendPrompt: prompt?.roleSendPrompt ?? '',
      enableStreaming: enableStreaming,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'selectedCredentialPresetId': selectedCredentialPresetId,
      'selectedPromptPresetId': selectedPromptPresetId,
      'enableStreaming': enableStreaming,
      'credentialPresets':
          credentialPresets.map((item) => item.toJson()).toList(),
      'promptPresets': promptPresets.map((item) => item.toJson()).toList(),
    };
  }

  factory AiPresetLibrary.fromJson(Map<String, dynamic> json) {
    int readInt(String key, {int fallback = 1}) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return fallback;
    }

    String readString(String key) {
      final value = json[key];
      return value is String ? value : '';
    }

    List<AiCredentialPreset> parseCredentialPresets() {
      final value = json['credentialPresets'];
      if (value is! List) return const <AiCredentialPreset>[];
      return value
          .whereType<Map>()
          .map((e) => AiCredentialPreset.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    List<AiRolePromptPreset> parsePromptPresets() {
      final value = json['promptPresets'];
      if (value is! List) return const <AiRolePromptPreset>[];
      return value
          .whereType<Map>()
          .map((e) => AiRolePromptPreset.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final credentials = parseCredentialPresets();
    final prompts = parsePromptPresets();
    final selectedCredentialId = readString('selectedCredentialPresetId');
    final selectedPromptId = readString('selectedPromptPresetId');

    bool readBool(String key, {bool fallback = true}) {
      final value = json[key];
      if (value is bool) return value;
      return fallback;
    }

    return AiPresetLibrary(
      version: readInt('version'),
      credentialPresets: credentials,
      promptPresets: prompts,
      selectedCredentialPresetId: selectedCredentialId.isNotEmpty &&
              credentials.any((e) => e.id == selectedCredentialId)
          ? selectedCredentialId
          : (credentials.isEmpty ? '' : credentials.first.id),
      selectedPromptPresetId: selectedPromptId.isNotEmpty &&
              prompts.any((e) => e.id == selectedPromptId)
          ? selectedPromptId
          : (prompts.isEmpty ? '' : prompts.first.id),
      enableStreaming: readBool('enableStreaming'),
    );
  }

  factory AiPresetLibrary.parseImportJson(Map<String, dynamic> json) {
    int readRequiredInt(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      throw FormatException('字段 $key 类型错误，应为数字');
    }

    String readRequiredString(String key) {
      final value = json[key];
      if (value is! String) {
        throw FormatException('字段 $key 类型错误，应为字符串');
      }
      if (value.trim().isEmpty) {
        throw FormatException('字段 $key 不能为空');
      }
      return value;
    }

    List<Map<String, dynamic>> readMapList(String key) {
      final value = json[key];
      if (value is! List) {
        throw FormatException('字段 $key 类型错误，应为数组');
      }
      if (value.isEmpty) {
        throw FormatException('字段 $key 不能为空');
      }
      final list = <Map<String, dynamic>>[];
      for (final item in value) {
        if (item is! Map) {
          throw FormatException('字段 $key 包含非法项');
        }
        list.add(Map<String, dynamic>.from(item));
      }
      return list;
    }

    String requiredPresetString(
      Map<String, dynamic> item,
      String key,
      String listName,
      int index,
    ) {
      final value = item[key];
      if (value is! String) {
        throw FormatException('$listName[$index].$key 类型错误，应为字符串');
      }
      if (value.trim().isEmpty) {
        throw FormatException('$listName[$index].$key 不能为空');
      }
      return value;
    }

    final version = readRequiredInt('version');
    if (version != 1) {
      throw FormatException('不支持的预设版本: $version');
    }

    final selectedCredentialPresetId =
        readRequiredString('selectedCredentialPresetId');
    final selectedPromptPresetId = readRequiredString('selectedPromptPresetId');
    final credentialMaps = readMapList('credentialPresets');
    final promptMaps = readMapList('promptPresets');

    final credentials = <AiCredentialPreset>[];
    final credentialIdSet = <String>{};
    for (var i = 0; i < credentialMaps.length; i++) {
      final item = credentialMaps[i];
      final id = requiredPresetString(
        item,
        'id',
        'credentialPresets',
        i,
      );
      if (!credentialIdSet.add(id)) {
        throw FormatException('credentialPresets 中存在重复 id: $id');
      }
      requiredPresetString(item, 'name', 'credentialPresets', i);
      credentials.add(AiCredentialPreset.fromJson(item));
    }

    final prompts = <AiRolePromptPreset>[];
    final promptIdSet = <String>{};
    for (var i = 0; i < promptMaps.length; i++) {
      final item = promptMaps[i];
      final id = requiredPresetString(item, 'id', 'promptPresets', i);
      if (!promptIdSet.add(id)) {
        throw FormatException('promptPresets 中存在重复 id: $id');
      }
      requiredPresetString(item, 'name', 'promptPresets', i);
      prompts.add(AiRolePromptPreset.fromJson(item));
    }

    if (!credentialIdSet.contains(selectedCredentialPresetId)) {
      throw const FormatException(
          'selectedCredentialPresetId 不存在于 credentialPresets');
    }
    if (!promptIdSet.contains(selectedPromptPresetId)) {
      throw const FormatException('selectedPromptPresetId 不存在于 promptPresets');
    }

    bool readBool(String key, {bool fallback = true}) {
      final value = json[key];
      if (value is bool) return value;
      return fallback;
    }

    return AiPresetLibrary(
      version: version,
      credentialPresets: credentials,
      promptPresets: prompts,
      selectedCredentialPresetId: selectedCredentialPresetId,
      selectedPromptPresetId: selectedPromptPresetId,
      enableStreaming: readBool('enableStreaming'),
    );
  }

  AiPresetLibrary copyWith({
    int? version,
    List<AiCredentialPreset>? credentialPresets,
    List<AiRolePromptPreset>? promptPresets,
    String? selectedCredentialPresetId,
    String? selectedPromptPresetId,
    bool? enableStreaming,
  }) {
    return AiPresetLibrary(
      version: version ?? this.version,
      credentialPresets: credentialPresets ?? this.credentialPresets,
      promptPresets: promptPresets ?? this.promptPresets,
      selectedCredentialPresetId:
          selectedCredentialPresetId ?? this.selectedCredentialPresetId,
      selectedPromptPresetId:
          selectedPromptPresetId ?? this.selectedPromptPresetId,
      enableStreaming: enableStreaming ?? this.enableStreaming,
    );
  }
}
