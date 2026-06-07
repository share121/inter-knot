import 'dart:convert';

import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/models/chat_mockup_ai_settings.dart';

class ChatMockupAiSettingsStore {
  const ChatMockupAiSettingsStore();

  static const String legacyStorageKey = 'chat_mockup_ai_settings';
  static const String presetLibraryStorageKey = 'chat_mockup_ai_preset_library';

  Future<AiPresetLibrary> loadLibrary() async {
    final cached = box.read(presetLibraryStorageKey);
    if (cached is String && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is Map<String, dynamic>) {
          final library = AiPresetLibrary.fromJson(decoded);
          if (library.credentialPresets.isNotEmpty &&
              library.promptPresets.isNotEmpty) {
            return library;
          }
        }
      } catch (_) {
        // fallback to legacy migration
      }
    }

    final migrated = await _migrateFromLegacySettings();
    await saveLibrary(migrated);
    return migrated;
  }

  Future<ChatMockupAiSettings> load() async {
    final library = await loadLibrary();
    return library.toAiSettings();
  }

  Future<void> save(ChatMockupAiSettings settings) async {
    final library = await loadLibrary();
    final now = DateTime.now().millisecondsSinceEpoch;
    final selectedCredentialId = library.selectedCredentialPresetId.isEmpty &&
            library.credentialPresets.isNotEmpty
        ? library.credentialPresets.first.id
        : library.selectedCredentialPresetId;
    final selectedPromptId = library.selectedPromptPresetId.isEmpty &&
            library.promptPresets.isNotEmpty
        ? library.promptPresets.first.id
        : library.selectedPromptPresetId;
    final credentials = library.credentialPresets
        .map((preset) => preset.id == selectedCredentialId
            ? preset.copyWith(
                endpoint: settings.endpoint,
                model: settings.model,
                apiKey: settings.apiKey,
                updatedAt: now,
              )
            : preset)
        .toList();
    final prompts = library.promptPresets
        .map((preset) => preset.id == selectedPromptId
            ? preset.copyWith(
                rolePrompt: settings.rolePrompt,
                userPrompt: settings.userPrompt,
                directorSendPrompt: settings.directorSendPrompt,
                roleSendPrompt: settings.roleSendPrompt,
                updatedAt: now,
              )
            : preset)
        .toList();

    await saveLibrary(
      library.copyWith(
        credentialPresets: credentials,
        promptPresets: prompts,
        selectedCredentialPresetId: selectedCredentialId,
        selectedPromptPresetId: selectedPromptId,
        enableStreaming: settings.enableStreaming,
      ),
    );
  }

  Future<void> saveLibrary(AiPresetLibrary library) async {
    final encoded = jsonEncode(library.toJson());
    await box.write(presetLibraryStorageKey, encoded);
  }

  Future<AiPresetLibrary> _migrateFromLegacySettings() async {
    final cached = box.read(legacyStorageKey);
    ChatMockupAiSettings settings = ChatMockupAiSettings.empty;
    if (cached is String && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is Map<String, dynamic>) {
          settings = ChatMockupAiSettings.fromJson(decoded);
        }
      } catch (_) {
        settings = ChatMockupAiSettings.empty;
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    const defaultCredentialId = 'credential_default';
    const defaultPromptId = 'prompt_default';
    return AiPresetLibrary(
      version: 1,
      credentialPresets: [
        AiCredentialPreset(
          id: defaultCredentialId,
          name: '默认凭据',
          endpoint: settings.endpoint,
          model: settings.model,
          apiKey: settings.apiKey,
          updatedAt: now,
        ),
      ],
      promptPresets: [
        AiRolePromptPreset(
          id: defaultPromptId,
          name: '默认角色提示词',
          rolePrompt: settings.rolePrompt,
          userPrompt: settings.userPrompt,
          directorSendPrompt: settings.directorSendPrompt,
          roleSendPrompt: settings.roleSendPrompt,
          updatedAt: now,
        ),
      ],
      selectedCredentialPresetId: defaultCredentialId,
      selectedPromptPresetId: defaultPromptId,
    );
  }
}
