import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:inter_knot/api/chat_mockup_ai_api.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_avatar.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_bubble.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_card.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_iframe_music_embed.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_item.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_message.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_story_planner.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_title_bar.dart';
import 'package:inter_knot/components/chat_mockup/story_planner_sheet.dart';
import 'package:inter_knot/helpers/android_input_lock.dart';
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/helpers/chat_mockup_ai_settings_store.dart';
import 'package:inter_knot/helpers/chat_mockup_ai_stream_preview.dart';
import 'package:inter_knot/helpers/chat_mockup_audio_url_validator.dart';
import 'package:inter_knot/helpers/chat_mockup_iframe_music_policy.dart';
import 'package:inter_knot/helpers/chat_mockup_resource_cache.dart';
import 'package:inter_knot/helpers/chat_mockup_resource_prefetcher.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:inter_knot/helpers/video_archive_codec.dart';
import 'package:inter_knot/helpers/video_player_session_store.dart';
import 'package:inter_knot/models/chat_mockup_ai_settings.dart';
import 'package:inter_knot/models/chat_mockup_prompt_preset.dart';
import 'package:inter_knot/models/video_upload_prepare_result.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';

enum ChatMockupAiMode { director, role }

enum ChatMockupEditableField {
  chatTitle,
  text,
  title,
  subtitle,
  firstReply,
  secondReply,
}

enum _ChatMockupSettingTargetScope {
  selected,
  selectedMultiple,
  allLeft,
  allRight,
}

enum _ChatMockupMessagePlacement {
  left,
  action,
  right,
}

enum _AiStreamSessionKind { director, role, continueFollowUp }

/// How AI output was resolved when finalizing a streaming reply.
enum _AiStreamDecodeKind {
  strictXml,
  orderedFieldExtraction,
  legacyJson,
  legacyRepairedJson,
  cachedProjection,
}

class _DirectorItemsBuild {
  const _DirectorItemsBuild({required this.items, this.qualityWarning});

  final List<ChatMockupItem> items;
  final String? qualityWarning;
}

class _StreamingAiFinalize {
  const _StreamingAiFinalize({
    required this.items,
    required this.decodeKind,
    this.qualityWarning,
  });

  final List<ChatMockupItem> items;
  final _AiStreamDecodeKind decodeKind;
  final String? qualityWarning;
}

class _ChatMockupRestoreOutcome {
  const _ChatMockupRestoreOutcome(
      {required this.neteaseOutchainOnWindowsCount});

  final int neteaseOutchainOnWindowsCount;
}

/// Bump when the default shape used for「空白故事」or demo template equivalence changes.
/// Stored on each [ChatMockupCanvasState.buildCurrentStorySnapshot] for archive logic.
const int kChatMockupStoryTemplateRevision = 1;

/// Result of [ChatMockupCanvasState.restoreStoryFromSnapshot].
enum ChatMockupStoryRestoreResult {
  /// Draft not loaded, browse mode, restore threw, or payload unusable.
  failed,

  /// User must stop preview first.
  failedPreviewActive,

  /// User must wait for or abort AI generation first.
  failedAiBusy,

  /// User must finish inline text editing first.
  failedEditingText,

  /// State applied but widget was disposed before follow-up UI work completed.
  failedUnmounted,

  /// Canvas matches snapshot and draft cache write succeeded.
  restoredPersisted,

  /// Payload applied but draft cache write failed (including after
  /// [ChatMockupCanvasState.forceSaveDraftCache]).
  restoredPersistFailed,
}

class _AiStreamSession {
  _AiStreamSession({
    required this.kind,
    required this.baseInsertPos,
    required this.xmlParser,
  });

  final _AiStreamSessionKind kind;
  final int baseInsertPos;
  final ChatMockupAiXmlStreamFieldParser xmlParser;
  final Map<String, String> keyToItemId = {};
  String? placeholderItemId;

  /// Monotonic field index for lineKey / finalize snapshot (includes empty fields).
  int completedFieldIndex = 0;

  /// Total stream rows appended this session (40 cap across all batches).
  int appendedItemCount = 0;

  /// Left character rows appended in continue mode (5 cap across all batches).
  int continueLeftMessageCount = 0;

  /// Last non-empty field-scan projection lines (finalize cache when decode fails).
  List<_AiProjectedLine>? lastProjectedLinesSnapshot;
}

class _AiProjectedLine {
  const _AiProjectedLine({
    required this.lineKey,
    required this.isAction,
    required this.side,
    required this.text,
  });

  final String lineKey;
  final bool isAction;
  final ChatMockupItemSide side;
  final String text;
}

class ChatMockupBrowsePlaybackState {
  const ChatMockupBrowsePlaybackState({
    required this.visibleItemCount,
    required this.playbackComplete,
  });

  final int visibleItemCount;
  final bool playbackComplete;
}

class ChatMockupCanvas extends StatefulWidget {
  const ChatMockupCanvas({
    super.key,
    this.onDraftLoadedChanged,
    this.initialPayload,
    this.initialPlaybackState,
    this.readOnly = false,
    this.browseMode = false,
    this.autoStartPlayback = false,
    this.lockAiMode = false,
    this.onPlaybackCompleted,
    this.onAiInitializedChanged,
    this.onEditingChanged,
  });

  final ValueChanged<bool>? onDraftLoadedChanged;
  final Map<String, dynamic>? initialPayload;
  final ChatMockupBrowsePlaybackState? initialPlaybackState;
  final bool readOnly;
  final bool browseMode;
  final bool autoStartPlayback;
  final bool lockAiMode;
  final VoidCallback? onPlaybackCompleted;
  final ValueChanged<bool>? onAiInitializedChanged;
  final ValueChanged<bool>? onEditingChanged;

  @override
  State<ChatMockupCanvas> createState() => ChatMockupCanvasState();
}

class ChatMockupCanvasState extends State<ChatMockupCanvas> {
  static const _chatTitleEditingId = '__chat_title__';
  static const _leftAvatarPath = 'assets/images/zzzicon.png';
  static const _rightAvatarPath = 'assets/images/Bangboo.gif';
  static const _stickerPath = 'assets/images/zzz.webp';
  static const _coverPath = 'assets/images/pc-page-bg.png';
  static const _jsonTypeGroup = XTypeGroup(label: 'JSON', extensions: ['json']);
  static const _txtTypeGroup = XTypeGroup(label: 'Text', extensions: ['txt']);
  static const _cleanExportHintMessage = 'Click here to edit';
  static const _cleanExportHintAction = '-- Click here to edit --';
  static const _cleanExportHintChatTitle = 'Click here to edit chat title';
  static const _draftAutoSaveDelay = Duration(milliseconds: 600);
  static const _leftAvatarSource = ChatMockupImageSource(
    type: ChatMockupImageSourceType.asset,
    value: _leftAvatarPath,
  );
  static const _rightAvatarSource = ChatMockupImageSource(
    type: ChatMockupImageSourceType.asset,
    value: _rightAvatarPath,
  );
  static const _defaultStickerSource = ChatMockupImageSource(
    type: ChatMockupImageSourceType.asset,
    value: _stickerPath,
  );
  static const _defaultCoverSource = ChatMockupImageSource(
    type: ChatMockupImageSourceType.asset,
    value: _coverPath,
  );

  /// Always holds only the **current** KnockKnock canvas draft; starting a new story overwrites it.
  /// Older stories are kept in the page-level local tape store (`knock_knock_local_story_tape`), not here.
  static const _draftCacheKey = 'chat_mockup_draft';
  static const _aiStreamingPlaceholderText = '…';
  static const _aiRepairedStructureUserNote = '已使用结构修补后的输出完成插入，建议检查最后几条消息';
  static const _importErrEncoding = 'IK_IMPORT_ENCODING';
  static const _importErrJsonSyntax = 'IK_IMPORT_JSON_SYNTAX';
  static const _importErrRootNotObject = 'IK_IMPORT_ROOT_NOT_OBJECT';
  static const Map<int, _ChatMockupMessagePlacement> _placementBySliderValue =
      <int, _ChatMockupMessagePlacement>{
    0: _ChatMockupMessagePlacement.left,
    1: _ChatMockupMessagePlacement.action,
    2: _ChatMockupMessagePlacement.right,
  };
  static const Map<_ChatMockupMessagePlacement, double>
      _sliderValueByPlacement = <_ChatMockupMessagePlacement, double>{
    _ChatMockupMessagePlacement.left: 0.0,
    _ChatMockupMessagePlacement.action: 1.0,
    _ChatMockupMessagePlacement.right: 2.0,
  };

  final List<ChatMockupItem> _items = [];
  final Set<String> _selectedItemIds = <String>{};
  final Set<String> _newlyAddedItemIds = <String>{};
  String _chatTitle = '';
  String? _primarySelectedItemId;
  String? _editingItemId;
  ChatMockupEditableField? _editingField;

  bool get isEditingText => _editingItemId != null && _editingField != null;
  String get _displayChatTitle =>
      _chatTitle.trim().isEmpty ? 'Click here to edit chat title' : _chatTitle;

  ChatMockupItemType? _pendingAddType;
  int _nextId = 0;

  static const double _bottomFollowTolerance = 24;
  late final ScrollController _scrollController;
  bool _isFollowingLatest = true;
  bool _showJumpToLatestButton = false;
  int _followLatestScrollToken = 0;

  bool _isPreviewing = false;
  bool _isPlaybackComplete = false;
  int _visibleItemCount = 0;
  int _previewRunId = 0;
  Timer? _playbackTimer;
  AudioPlayer? _previewMusicPlayer;
  int _musicSessionId = 0;
  Future<void> _musicQueueTail = Future<void>.value();
  StreamSubscription<ProcessingState>? _musicProcessingSub;
  StreamSubscription<PlayerState>? _musicPlayerStateSub;
  bool _previewAudioSessionConfigured = false;
  String? _previewMusicIframeUrl;
  bool _previewMusicIframeActive = false;
  String? _previewMusicIframeSourceItemId;
  bool _previewMusicIframeTearingDown = false;
  Completer<void>? _previewMusicIframeTeardownCompleter;
  bool _neteaseOutchainWindowsWarningShownThisSession = false;

  static const Duration _previewIframeTeardownTimeout = Duration(seconds: 3);

  /// Monotonic id for iframe teardown cycles; [_pendingIframeTeardownToken] holds
  /// the value [ChatMockupIframeMusicEmbed] must echo in [onTeardownComplete] (0 = none).
  int _iframeTeardownSeq = 0;
  int _pendingIframeTeardownToken = 0;

  Timer? _draftAutoSaveTimer;
  bool _isWaitingManual = false;
  bool _isDraftLoaded = false;
  bool _isSavingDraftCache = false;
  bool _hasPendingDraftAutoSave = false;
  Completer<void>? _draftCacheWriteCompleter;
  String? _loadError;
  String? _draftLoadErrorMessage;
  String? _invalidDraftRaw;
  String? _lastExportedSnapshot;
  bool _hasUnexportedChanges = false;
  bool get isDraftLoaded => _isDraftLoaded;
  bool get isAiInitialized => _isAiInitialized;
  bool get hasPendingInvalidDraft => _invalidDraftRaw != null;
  bool _lastEditingState = false;

  late final TextEditingController _editingController;
  late final FocusNode _editingFocusNode;
  bool _isCommittingEditing = false;

  final ChatMockupAiSettingsStore _aiSettingsStore =
      const ChatMockupAiSettingsStore();
  final ChatMockupAiApi _aiApi = const ChatMockupAiApi();
  ChatMockupAiSettings _aiSettings = ChatMockupAiSettings.empty;
  AiPresetLibrary _aiPresetLibrary = AiPresetLibrary.empty;
  ChatMockupPromptPreset? _promptPreset;
  bool _isAiInitialized = false;
  final Completer<void> _aiInitCompleter = Completer<void>();
  ChatMockupAiMode _aiMode = ChatMockupAiMode.director;
  bool _isAiSending = false;
  _AiStreamSession? _aiStreamSession;
  VoidCallback? _cancelActiveAiStream;
  bool _aiStreamAbortRequested = false;

  /// Bumped when discarding in-flight AI work (e.g. [startNewStory]); completions
  /// compare against the generation captured when the request started.
  int _canvasMutationGeneration = 0;
  late final TextEditingController _aiInputController;
  late final FocusNode _aiInputFocusNode;
  String? _videoRolePrompt;
  String? _videoUserPrompt;
  bool _browsePayloadIncludesAi = false;
  List<ChatMockupImageSource>? _cachedStickerSources;

  ChatMockupStoryPlanner _storyPlanner = ChatMockupStoryPlanner.empty();
  bool _plannerAiInFlight = false;

  final ChatMockupResourceCache _resourceCache = ChatMockupResourceCache();
  int _resourcePrefetchSession = 0;
  bool _resourcePrefetchRunning = false;
  int _resourcePrefetchDone = 0;
  int _resourcePrefetchTotal = 0;

  bool get hasUnexportedChanges {
    if (!_isDraftLoaded) {
      return _hasUnexportedChanges;
    }
    if (_lastExportedSnapshot == null) {
      return true;
    }
    return _currentExportSnapshot() != _lastExportedSnapshot;
  }

  void _notifyEditingChangedIfNeeded() {
    final next = isEditingText;
    if (_lastEditingState == next) return;
    _lastEditingState = next;
    widget.onEditingChanged?.call(next);
  }

  bool get _isBrowseMode => widget.browseMode;
  bool get _isReadOnlyCanvas => widget.readOnly || _isBrowseMode;

  @override
  void initState() {
    super.initState();
    _editingController = TextEditingController();
    _editingFocusNode = FocusNode();
    _scrollController = ScrollController();
    _aiInputController = TextEditingController();
    _aiInputController.addListener(_handleAiInputChanged);
    _aiInputFocusNode = FocusNode();
    if (widget.lockAiMode) {
      _aiMode = ChatMockupAiMode.role;
    }
    _seedVideoAiPromptsFromPayload(widget.initialPayload);
    unawaited(_initializeAi());
    unawaited(_initializeDraft());
    unawaited(_ensurePreviewAudioSession());
  }

  @override
  void dispose() {
    AndroidInputLock.unlock();
    _musicSessionId++;
    _musicQueueTail = _musicQueueTail.catchError((_) {}).then((_) async {
      await _silencePreviewMusic();
      await _disposePreviewMusicPlayer();
    });
    unawaited(_musicQueueTail);
    _playbackTimer?.cancel();
    _draftAutoSaveTimer?.cancel();
    if (_aiStreamSession != null) {
      _rollbackAiStreamSession();
      if (_isDraftLoaded && !_isBrowseMode && !hasPendingInvalidDraft) {
        _markUnexportedChanges();
        unawaited(_writeDraftCache(
          ignorePendingInvalid: false,
          clearInvalidOnSuccess: false,
        ));
      }
    }
    if (_cancelActiveAiStream != null) {
      _aiStreamAbortRequested = true;
    }
    _cancelActiveAiStream?.call();
    _cancelActiveAiStream = null;
    _editingController.dispose();
    _editingFocusNode.dispose();
    _scrollController.dispose();
    _aiInputController.removeListener(_handleAiInputChanged);
    _aiInputController.dispose();
    _aiInputFocusNode.dispose();
    _invalidateResourceCacheSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDraftLoaded) {
      return const ColoredBox(
        color: ChatMockupTheme.background,
        child: SizedBox.expand(),
      );
    }
    if (_loadError != null) {
      return ColoredBox(
        color: ChatMockupTheme.background,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              color: const Color(0xff1f1f1f),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '影片数据加载失败',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      _loadError!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final visibleItems = _visibleItems();
    return ColoredBox(
      color: ChatMockupTheme.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
            child: Column(
              children: [
                ChatMockupTitleBar(
                  title: _displayChatTitle,
                  isEditing: _editingItemId == _chatTitleEditingId &&
                      _editingField == ChatMockupEditableField.chatTitle,
                  controller: _editingController,
                  focusNode: _editingFocusNode,
                  onTap: _isReadOnlyCanvas
                      ? null
                      : () => _startEditing(
                            _chatTitleEditingId,
                            ChatMockupEditableField.chatTitle,
                            initialValue: _chatTitle,
                            shouldSelectItem: false,
                          ),
                  onSubmitted: (_) => _commitEditing(),
                  onTapOutside: (_) {
                    if (AndroidInputLock.isLocked) {
                      if (_editingFocusNode.canRequestFocus) {
                        _editingFocusNode.requestFocus();
                      }
                      return;
                    }
                    _commitEditing();
                  },
                  showConfirmButton: AndroidInputLock.requiresExplicitConfirm &&
                      isEditingText &&
                      _editingField == ChatMockupEditableField.chatTitle &&
                      _editingFocusNode.hasFocus,
                  onConfirm: _commitEditing,
                ),
                if (_resourcePrefetchRunning) _buildResourcePrefetchBanner(),
                if (!_isReadOnlyCanvas) _buildAddControls(),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Stack(
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: _handleScrollNotification,
                    child: ReorderableListView.builder(
                      scrollController: _scrollController,
                      buildDefaultDragHandles: false,
                      // ignore: deprecated_member_use
                      onReorder: _onReorder,
                      padding: const EdgeInsets.only(bottom: 24),
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          color: Colors.transparent,
                          elevation: 8,
                          child: child,
                        );
                      },
                      itemCount: visibleItems.length,
                      itemBuilder: (context, index) {
                        return _buildItem(visibleItems[index], index);
                      },
                    ),
                  ),
                  if (_showJumpToLatestButton)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: _buildJumpToLatestButton(),
                    ),
                ],
              ),
            ),
          ),
          _buildBottomControls(),
        ],
      ),
    );
  }

  void _seedVideoAiPromptsFromPayload(Map<String, dynamic>? payload) {
    if (!_isBrowseMode || payload == null) return;
    final ai = payload['ai'];
    if (ai is! Map<String, dynamic>) return;
    _browsePayloadIncludesAi = true;
    _videoRolePrompt =
        ai['rolePrompt'] is String ? ai['rolePrompt'] as String : '';
    _videoUserPrompt =
        ai['userPrompt'] is String ? ai['userPrompt'] as String : '';
  }

  String _browseRolePromptOr(String fallback) {
    if (_browsePayloadIncludesAi) return _videoRolePrompt ?? '';
    return _videoRolePrompt ?? fallback;
  }

  String _browseUserPromptOr(String fallback) {
    if (_browsePayloadIncludesAi) return _videoUserPrompt ?? '';
    return _videoUserPrompt ?? fallback;
  }

  Future<void> _initializeAi() async {
    final library = await _aiSettingsStore.loadLibrary();
    final settings = library.toAiSettings();
    ChatMockupPromptPreset? preset;
    try {
      final jsonText =
          await rootBundle.loadString('assets/prompts/Tavo_default.json');
      final decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) {
        preset = ChatMockupPromptPreset.fromTavernLikeJson(decoded);
      }
    } catch (_) {
      preset = null;
    }
    if (!mounted) return;
    setState(() {
      _aiPresetLibrary = library;
      if (_isBrowseMode) {
        _aiSettings = settings.copyWith(
          rolePrompt: _browseRolePromptOr(settings.rolePrompt),
          userPrompt: _browseUserPromptOr(settings.userPrompt),
        );
      } else {
        _aiSettings = settings;
      }
      _promptPreset = preset;
      _isAiInitialized = true;
    });
    if (!_aiInitCompleter.isCompleted) {
      _aiInitCompleter.complete();
    }
    widget.onAiInitializedChanged?.call(true);
  }

  void _handleAiInputChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> showAiSettings() async {
    if (!_isDraftLoaded) return;
    if (!mounted) return;
    if (!_isAiInitialized) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('AI 设置加载中...')));
      return;
    }

    var editingLibrary = _aiPresetLibrary;
    final endpointController = TextEditingController(
      text: editingLibrary.selectedCredentialPreset?.endpoint ?? '',
    );
    final modelController = TextEditingController(
      text: editingLibrary.selectedCredentialPreset?.model ?? '',
    );
    final apiKeyController = TextEditingController(
      text: editingLibrary.selectedCredentialPreset?.apiKey ?? '',
    );
    final rolePromptController = TextEditingController(
      text: editingLibrary.selectedPromptPreset?.rolePrompt ?? '',
    );
    final userPromptController = TextEditingController(
      text: editingLibrary.selectedPromptPreset?.userPrompt ?? '',
    );
    final directorSendPromptController = TextEditingController(
      text: editingLibrary.selectedPromptPreset?.directorSendPrompt ?? '',
    );
    final roleSendPromptController = TextEditingController(
      text: editingLibrary.selectedPromptPreset?.roleSendPrompt ?? '',
    );

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xff161616),
        builder: (ctx) {
          final rootMessenger = ScaffoldMessenger.of(context);
          final sheetNavigator = Navigator.of(ctx);
          String nowId() => DateTime.now().microsecondsSinceEpoch.toString();

          void pullCurrentPresetDataIntoControllers() {
            final credential = editingLibrary.selectedCredentialPreset;
            final prompt = editingLibrary.selectedPromptPreset;
            endpointController.text = credential?.endpoint ?? '';
            modelController.text = credential?.model ?? '';
            apiKeyController.text = credential?.apiKey ?? '';
            rolePromptController.text = prompt?.rolePrompt ?? '';
            userPromptController.text = prompt?.userPrompt ?? '';
            directorSendPromptController.text =
                prompt?.directorSendPrompt ?? '';
            roleSendPromptController.text = prompt?.roleSendPrompt ?? '';
          }

          Future<void> saveToStateAndStore({
            bool closeAfterSave = false,
            String? successMessage,
          }) async {
            final now = DateTime.now().millisecondsSinceEpoch;
            final selectedCredentialId =
                editingLibrary.selectedCredentialPresetId;
            final selectedPromptId = editingLibrary.selectedPromptPresetId;
            final credentials = editingLibrary.credentialPresets
                .map((preset) => preset.id == selectedCredentialId
                    ? preset.copyWith(
                        endpoint: endpointController.text.trim(),
                        model: modelController.text.trim(),
                        apiKey: apiKeyController.text,
                        updatedAt: now,
                      )
                    : preset)
                .toList();
            final prompts = editingLibrary.promptPresets
                .map((preset) => preset.id == selectedPromptId
                    ? preset.copyWith(
                        rolePrompt: rolePromptController.text,
                        userPrompt: userPromptController.text,
                        directorSendPrompt: directorSendPromptController.text,
                        roleSendPrompt: roleSendPromptController.text,
                        updatedAt: now,
                      )
                    : preset)
                .toList();
            editingLibrary = editingLibrary.copyWith(
              credentialPresets: credentials,
              promptPresets: prompts,
            );
            await _aiSettingsStore.saveLibrary(editingLibrary);
            if (!mounted) return;
            final projectedSettings = editingLibrary.toAiSettings();
            setState(() {
              _aiPresetLibrary = editingLibrary;
              _aiSettings = _isBrowseMode
                  ? projectedSettings.copyWith(
                      rolePrompt: _browseRolePromptOr(
                        projectedSettings.rolePrompt,
                      ),
                      userPrompt: _browseUserPromptOr(
                        projectedSettings.userPrompt,
                      ),
                    )
                  : projectedSettings;
            });
            if (!mounted) return;
            if (closeAfterSave) {
              sheetNavigator.pop();
            }
            if (successMessage != null && successMessage.isNotEmpty) {
              rootMessenger.showSnackBar(
                SnackBar(content: Text(successMessage)),
              );
            }
          }

          Widget presetManagerRow({
            required String title,
            required List<DropdownMenuItem<String>> items,
            required String selectedId,
            required ValueChanged<String> onSelect,
            required Future<void> Function() onCreate,
            required Future<void> Function() onRename,
            required Future<void> Function() onSaveAs,
            required Future<void> Function() onDelete,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        value: selectedId,
                        isExpanded: true,
                        dropdownColor: const Color(0xff262626),
                        items: items,
                        onChanged: (value) {
                          if (value == null) return;
                          onSelect(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '新增',
                      onPressed: () => unawaited(onCreate()),
                      icon: const Icon(Icons.add, color: Colors.white70),
                    ),
                    IconButton(
                      tooltip: '重命名',
                      onPressed: () => unawaited(onRename()),
                      icon: const Icon(Icons.edit, color: Colors.white70),
                    ),
                    IconButton(
                      tooltip: '另存为',
                      onPressed: () => unawaited(onSaveAs()),
                      icon:
                          const Icon(Icons.copy_rounded, color: Colors.white70),
                    ),
                    IconButton(
                      tooltip: '删除',
                      onPressed: () => unawaited(onDelete()),
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.white70),
                    ),
                  ],
                ),
              ],
            );
          }

          Widget field({
            required String label,
            required TextEditingController controller,
            bool obscureText = false,
            int minLines = 1,
            int maxLines = 1,
            String? hintText,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  obscureText: obscureText,
                  minLines: obscureText ? 1 : minLines,
                  maxLines: obscureText ? 1 : maxLines,
                  onTap: AndroidInputLock.lock,
                  onTapOutside: (_) {
                    if (AndroidInputLock.isLocked) return;
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xff202020),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xff2a2a2a)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xff2a2a2a)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            );
          }

          return StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> createCredentialPreset() async {
                final id = 'credential_${nowId()}';
                final now = DateTime.now().millisecondsSinceEpoch;
                final next = AiCredentialPreset(
                  id: id,
                  name: '新凭据',
                  endpoint: endpointController.text.trim(),
                  model: modelController.text.trim(),
                  apiKey: apiKeyController.text,
                  updatedAt: now,
                );
                setSheetState(() {
                  editingLibrary = editingLibrary.copyWith(
                    credentialPresets: [
                      ...editingLibrary.credentialPresets,
                      next
                    ],
                    selectedCredentialPresetId: id,
                  );
                });
              }

              Future<void> createPromptPreset() async {
                final id = 'prompt_${nowId()}';
                final now = DateTime.now().millisecondsSinceEpoch;
                final next = AiRolePromptPreset(
                  id: id,
                  name: '新提示词',
                  rolePrompt: rolePromptController.text,
                  userPrompt: userPromptController.text,
                  directorSendPrompt: directorSendPromptController.text,
                  roleSendPrompt: roleSendPromptController.text,
                  updatedAt: now,
                );
                setSheetState(() {
                  editingLibrary = editingLibrary.copyWith(
                    promptPresets: [...editingLibrary.promptPresets, next],
                    selectedPromptPresetId: id,
                  );
                });
              }

              Future<void> renamePreset({
                required String title,
                required String initialName,
                required void Function(String) onRename,
              }) async {
                final controller = TextEditingController(text: initialName);
                try {
                  final result = await showDialog<String>(
                    context: ctx,
                    builder: (dialogCtx) => AlertDialog(
                      title: Text(title),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        onTap: AndroidInputLock.lock,
                        onTapOutside: (_) {
                          if (AndroidInputLock.isLocked) return;
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            AndroidInputLock.unlock();
                            Navigator.of(dialogCtx).pop();
                          },
                          child: const Text('取消'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            AndroidInputLock.unlock();
                            Navigator.of(dialogCtx).pop(controller.text.trim());
                          },
                          child: const Text('确认'),
                        ),
                      ],
                    ),
                  );
                  if (result == null || result.isEmpty) return;
                  onRename(result);
                } finally {
                  AndroidInputLock.unlock();
                  controller.dispose();
                }
              }

              Future<void> deleteSelected({
                required String title,
                required String content,
                required VoidCallback onConfirmed,
              }) async {
                final ok = await showDialog<bool>(
                  context: ctx,
                  builder: (dialogCtx) => AlertDialog(
                    title: Text(title),
                    content: Text(content),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(false),
                        child: const Text('取消'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(true),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
                if (ok == true) onConfirmed();
              }

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    12 + MediaQuery.of(ctx).viewInsets.bottom,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI 预设管理',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        presetManagerRow(
                          title: '凭据预设',
                          selectedId: editingLibrary.selectedCredentialPresetId,
                          items: editingLibrary.credentialPresets
                              .map((item) => DropdownMenuItem<String>(
                                    value: item.id,
                                    child: Text(item.name),
                                  ))
                              .toList(),
                          onSelect: (value) {
                            setSheetState(() {
                              editingLibrary = editingLibrary.copyWith(
                                selectedCredentialPresetId: value,
                              );
                            });
                            pullCurrentPresetDataIntoControllers();
                          },
                          onCreate: createCredentialPreset,
                          onRename: () async {
                            final selected =
                                editingLibrary.selectedCredentialPreset;
                            if (selected == null) return;
                            await renamePreset(
                              title: '重命名凭据预设',
                              initialName: selected.name,
                              onRename: (name) {
                                setSheetState(() {
                                  editingLibrary = editingLibrary.copyWith(
                                    credentialPresets: editingLibrary
                                        .credentialPresets
                                        .map((item) => item.id == selected.id
                                            ? item.copyWith(name: name)
                                            : item)
                                        .toList(),
                                  );
                                });
                              },
                            );
                          },
                          onSaveAs: () async {
                            final id = 'credential_${nowId()}';
                            final now = DateTime.now().millisecondsSinceEpoch;
                            setSheetState(() {
                              editingLibrary = editingLibrary.copyWith(
                                credentialPresets: [
                                  ...editingLibrary.credentialPresets,
                                  AiCredentialPreset(
                                    id: id,
                                    name:
                                        '${editingLibrary.selectedCredentialPreset?.name ?? '凭据'} 副本',
                                    endpoint: endpointController.text.trim(),
                                    model: modelController.text.trim(),
                                    apiKey: apiKeyController.text,
                                    updatedAt: now,
                                  ),
                                ],
                                selectedCredentialPresetId: id,
                              );
                            });
                          },
                          onDelete: () async {
                            if (editingLibrary.credentialPresets.length <= 1) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('至少保留一个凭据预设')),
                              );
                              return;
                            }
                            await deleteSelected(
                              title: '删除凭据预设',
                              content: '删除后无法撤销。',
                              onConfirmed: () {
                                final deletingId =
                                    editingLibrary.selectedCredentialPresetId;
                                final nextList = editingLibrary
                                    .credentialPresets
                                    .where((item) => item.id != deletingId)
                                    .toList();
                                setSheetState(() {
                                  editingLibrary = editingLibrary.copyWith(
                                    credentialPresets: nextList,
                                    selectedCredentialPresetId:
                                        nextList.first.id,
                                  );
                                });
                                pullCurrentPresetDataIntoControllers();
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        field(
                          label: '接口地址（OpenAI-compatible）',
                          controller: endpointController,
                          hintText: '可填服务地址；会自动补 /chat/completions',
                        ),
                        const SizedBox(height: 12),
                        field(
                          label: '模型',
                          controller: modelController,
                          hintText: '例如 gpt-4.1-mini 或你接口支持的模型名',
                        ),
                        const SizedBox(height: 12),
                        field(
                          label: 'API key（仅本机保存）',
                          controller: apiKeyController,
                          obscureText: true,
                          hintText: '不会进入导出 JSON / 草稿 JSON',
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            '流式生成回复',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: const Text(
                            '关闭则一次性等待完整响应（兼容部分接口）',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          value: editingLibrary.enableStreaming,
                          onChanged: (value) {
                            setSheetState(() {
                              editingLibrary = editingLibrary.copyWith(
                                  enableStreaming: value);
                            });
                          },
                        ),
                        const SizedBox(height: 18),
                        presetManagerRow(
                          title: '角色提示词预设',
                          selectedId: editingLibrary.selectedPromptPresetId,
                          items: editingLibrary.promptPresets
                              .map((item) => DropdownMenuItem<String>(
                                    value: item.id,
                                    child: Text(item.name),
                                  ))
                              .toList(),
                          onSelect: (value) {
                            setSheetState(() {
                              editingLibrary = editingLibrary.copyWith(
                                selectedPromptPresetId: value,
                              );
                            });
                            pullCurrentPresetDataIntoControllers();
                          },
                          onCreate: createPromptPreset,
                          onRename: () async {
                            final selected =
                                editingLibrary.selectedPromptPreset;
                            if (selected == null) return;
                            await renamePreset(
                              title: '重命名提示词预设',
                              initialName: selected.name,
                              onRename: (name) {
                                setSheetState(() {
                                  editingLibrary = editingLibrary.copyWith(
                                    promptPresets: editingLibrary.promptPresets
                                        .map((item) => item.id == selected.id
                                            ? item.copyWith(name: name)
                                            : item)
                                        .toList(),
                                  );
                                });
                              },
                            );
                          },
                          onSaveAs: () async {
                            final id = 'prompt_${nowId()}';
                            final now = DateTime.now().millisecondsSinceEpoch;
                            setSheetState(() {
                              editingLibrary = editingLibrary.copyWith(
                                promptPresets: [
                                  ...editingLibrary.promptPresets,
                                  AiRolePromptPreset(
                                    id: id,
                                    name:
                                        '${editingLibrary.selectedPromptPreset?.name ?? '提示词'} 副本',
                                    rolePrompt: rolePromptController.text,
                                    userPrompt: userPromptController.text,
                                    directorSendPrompt:
                                        directorSendPromptController.text,
                                    roleSendPrompt:
                                        roleSendPromptController.text,
                                    updatedAt: now,
                                  ),
                                ],
                                selectedPromptPresetId: id,
                              );
                            });
                          },
                          onDelete: () async {
                            if (editingLibrary.promptPresets.length <= 1) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('至少保留一个提示词预设')),
                              );
                              return;
                            }
                            await deleteSelected(
                              title: '删除提示词预设',
                              content: '删除后无法撤销。',
                              onConfirmed: () {
                                final deletingId =
                                    editingLibrary.selectedPromptPresetId;
                                final nextList = editingLibrary.promptPresets
                                    .where((item) => item.id != deletingId)
                                    .toList();
                                setSheetState(() {
                                  editingLibrary = editingLibrary.copyWith(
                                    promptPresets: nextList,
                                    selectedPromptPresetId: nextList.first.id,
                                  );
                                });
                                pullCurrentPresetDataIntoControllers();
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        field(
                          label: '角色卡提示词',
                          controller: rolePromptController,
                          minLines: 3,
                          maxLines: 8,
                          hintText: '用于描述角色信息（不会进入导出 JSON）',
                        ),
                        const SizedBox(height: 12),
                        field(
                          label: '用户身份提示词',
                          controller: userPromptController,
                          minLines: 3,
                          maxLines: 8,
                          hintText: '用于描述用户身份（不会进入导出 JSON）',
                        ),
                        const SizedBox(height: 12),
                        field(
                          label: '导演模式发送时提示词',
                          controller: directorSendPromptController,
                          minLines: 3,
                          maxLines: 8,
                          hintText: '例如：角色是谁、需要几轮对话、详细描述情景',
                        ),
                        const SizedBox(height: 12),
                        field(
                          label: '角色模式发送时提示词',
                          controller: roleSendPromptController,
                          minLines: 3,
                          maxLines: 8,
                          hintText: '例如：角色是谁、回复语气、希望推进的情景细节',
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                await saveToStateAndStore(
                                  successMessage: 'AI 预设已保存（仅本机）',
                                );
                              },
                              child: const Text('保存'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                await saveToStateAndStore(
                                  closeAfterSave: true,
                                  successMessage: 'AI 预设已保存（仅本机）',
                                );
                              },
                              child: const Text('保存并关闭'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final ok = await _exportTextFile(
                                  content: const JsonEncoder.withIndent('  ')
                                      .convert(editingLibrary.toJson()),
                                  fileName: 'chat_mockup_ai_presets.json',
                                  mimeType: 'application/json',
                                  acceptedTypeGroups: const [_jsonTypeGroup],
                                  successMessage: '已导出 AI 预设',
                                  cancelledMessage: '已取消导出 AI 预设',
                                );
                                if (!ok) return;
                              },
                              child: const Text('导出预设'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: ctx,
                                  builder: (dialogCtx) => AlertDialog(
                                    title: const Text('确认覆盖导入'),
                                    content: const Text(
                                      '导入将覆盖当前本地 AI 预设，是否继续？',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogCtx).pop(false),
                                        child: const Text('取消'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(dialogCtx).pop(true),
                                        child: const Text('继续导入'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) {
                                  rootMessenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('已取消覆盖导入'),
                                    ),
                                  );
                                  return;
                                }
                                final file = await openFile(
                                  acceptedTypeGroups: const [_jsonTypeGroup],
                                  confirmButtonText: '导入',
                                );
                                if (file == null) {
                                  rootMessenger.showSnackBar(
                                    const SnackBar(
                                        content: Text('已取消导入 AI 预设')),
                                  );
                                  return;
                                }
                                try {
                                  final decoded =
                                      await _decodeJsonFileAsMap(file);
                                  final imported =
                                      AiPresetLibrary.parseImportJson(decoded);
                                  setSheetState(() {
                                    editingLibrary = imported;
                                  });
                                  pullCurrentPresetDataIntoControllers();
                                  await saveToStateAndStore(
                                    successMessage: 'AI 预设导入成功',
                                  );
                                } catch (error) {
                                  if (!mounted) return;
                                  final raw = error.toString();
                                  String message =
                                      _mapImportErrorMessage(error);
                                  if (raw.contains('不支持的预设版本')) {
                                    message = '导入失败：预设版本不支持';
                                  } else if (raw.contains('重复 id')) {
                                    message = '导入失败：预设 ID 冲突';
                                  } else if (raw.contains('类型错误') ||
                                      raw.contains('不能为空') ||
                                      raw.contains('不存在于')) {
                                    message = '导入失败：预设结构或字段不合法';
                                  }
                                  rootMessenger.showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                }
                              },
                              child: const Text('导入预设'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      endpointController.dispose();
      modelController.dispose();
      apiKeyController.dispose();
      rolePromptController.dispose();
      userPromptController.dispose();
      directorSendPromptController.dispose();
      roleSendPromptController.dispose();
    }
  }

  List<ChatMockupItem> _initialItems() {
    return [
      _createItem(
        type: ChatMockupItemType.message,
        side: ChatMockupItemSide.left,
        text: 'Click on messages to edit and show actions.',
      ),
      _createItem(
        type: ChatMockupItemType.message,
        side: ChatMockupItemSide.right,
        text: 'Click on chat icons to change them.',
      ),
      _createItem(
        type: ChatMockupItemType.sticker,
        side: ChatMockupItemSide.right,
        imageSource: _defaultStickerSource,
      ),
      _createItem(
          type: ChatMockupItemType.action, side: ChatMockupItemSide.center),
      _createItem(
          type: ChatMockupItemType.emoji, side: ChatMockupItemSide.left),
      _createItem(
          type: ChatMockupItemType.emoji, side: ChatMockupItemSide.right),
      _createItem(
        type: ChatMockupItemType.customImage,
        side: ChatMockupItemSide.left,
        imageSource: _defaultCoverSource,
      ),
      _createItem(
          type: ChatMockupItemType.replyOptions,
          side: ChatMockupItemSide.right),
      _createItem(
          type: ChatMockupItemType.commission, side: ChatMockupItemSide.right),
    ];
  }

  Widget _buildPreviewControls() {
    if (_isBrowseMode && !_isPlaybackComplete) {
      return const SizedBox.shrink();
    }
    if (_isPreviewing) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(
          children: [
            ElevatedButton(onPressed: _stopPreview, child: const Text('停止预览')),
            const SizedBox(width: 8),
            if (_isWaitingManual)
              ElevatedButton(
                onPressed: _continuePreviewManually,
                child: const Text('点击继续'),
              ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ElevatedButton(
            onPressed: _resourcePrefetchRunning
                ? null
                : () => unawaited(_startPreviewAfterPrefetch()),
            child: const Text('预览'),
          ),
          _buildAiModeControl(),
        ],
      ),
    );
  }

  /// Preview plus local-only「剧情构思」entry (sheet not shown in browse / while previewing).
  Widget _buildPreviewPlannerRow() {
    if (_isBrowseMode || _isReadOnlyCanvas) {
      return _buildPreviewControls();
    }
    if (_isPreviewing) {
      return _buildPreviewControls();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ElevatedButton(
            onPressed: _resourcePrefetchRunning
                ? null
                : () => unawaited(_startPreviewAfterPrefetch()),
            child: const Text('预览'),
          ),
          _buildAiModeControl(),
          TextButton(
            onPressed: _isAiSending ? null : _openStoryPlannerSheet,
            child: const Text('剧情构思'),
          ),
        ],
      ),
    );
  }

  Future<void> _openStoryPlannerSheet() async {
    if (!_isDraftLoaded || _isBrowseMode || _isReadOnlyCanvas) return;
    if (!_isAiInitialized) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 设置加载中…')),
      );
      return;
    }
    _revalidatePlannerForPersistIfNeeded();
    final controller = StoryPlannerSheetController(
      getPlanner: () => _storyPlanner,
      applyPlanner: (next) {
        if (!mounted) return;
        setState(() => _storyPlanner = next);
        _markUnexportedChanges();
      },
      getItems: () => List<ChatMockupItem>.from(_items),
      buildPlotHistory: _buildAiChatHistoryFromItems,
      runOutlineAi: _runPlannerOutlineAi,
      runIdeationAi: _runPlannerIdeationAi,
      rollbackPlannerChatLastUserIfMatches:
          rollbackPlannerChatLastUserIfMatches,
      getPlannerAiBusy: () => _plannerAiInFlight,
      setPlannerAiBusy: (v) {
        if (!mounted) return;
        setState(() => _plannerAiInFlight = v);
      },
      isAiInitialized: () => _isAiInitialized,
      isAiConfigured: () => _aiSettings.isConfigured,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StoryPlannerSheet(controller: controller),
    );
  }

  /// Syncs [_storyPlanner] with current [_items] when revalidation drops invalid coverage.
  ///
  /// Call before persisting (draft / export snapshot) or before planner AI so state matches
  /// items. [_buildJsonPayload] does **not** mutate planner — it only embeds a revalidated
  /// view for JSON strings (e.g. export fingerprint) without updating memory.
  void _revalidatePlannerForPersistIfNeeded() {
    final next = revalidateStoryPlanner(items: _items, planner: _storyPlanner);
    if (identical(next, _storyPlanner)) return;
    setState(() => _storyPlanner = next);
    _markUnexportedChanges();
  }

  String _stripOuterMarkdownFence(String raw) {
    var t = raw.trim();
    if (t.startsWith('```')) {
      final firstNl = t.indexOf('\n');
      if (firstNl != -1) {
        t = t.substring(firstNl + 1);
      } else {
        t = t.substring(3);
      }
      final fence = t.lastIndexOf('```');
      if (fence != -1) {
        t = t.substring(0, fence);
      }
    }
    return t.trim();
  }

  int _plotTurnCount() {
    var c = 0;
    for (final it in _items) {
      if (it.type != ChatMockupItemType.message &&
          it.type != ChatMockupItemType.action) {
        continue;
      }
      if ((it.text ?? '').trim().isEmpty) continue;
      c++;
    }
    return c;
  }

  String _lastNPlotTurnsText(int n) {
    if (n <= 0 || _items.isEmpty) return '';
    final picked = <ChatMockupItem>[];
    for (var i = _items.length - 1; i >= 0 && picked.length < n; i--) {
      final it = _items[i];
      if (it.type != ChatMockupItemType.message &&
          it.type != ChatMockupItemType.action) {
        continue;
      }
      if ((it.text ?? '').trim().isEmpty) continue;
      picked.add(it);
    }
    if (picked.isEmpty) return '';
    return _buildAiChatHistoryFromItems(picked.reversed.toList());
  }

  Future<bool> _runPlannerOutlineAi(
    void Function(String accumulated)? onStreamChunk,
  ) async {
    if (!_aiSettings.isConfigured) return false;
    if (_editingItemId != null || _isPreviewing || _isAiSending) return false;

    _revalidatePlannerForPersistIfNeeded();

    // 方案 A：正文改动导致 coverage 失效时，旧总纲不可信；禁止在旧总纲上追加，须先清空大纲。
    if (_storyPlanner.outlineDirty) {
      return false;
    }

    final gaps = computeUncoveredRanges(
      items: _items,
      coverage: _storyPlanner.coverage,
    );
    if (gaps.isEmpty) {
      return false;
    }
    final g = gaps.first;
    final slice = _items.sublist(g.startIndex, g.endIndex + 1);
    final uncoveredText = _buildAiChatHistoryFromItems(slice);
    if (uncoveredText.trim().isEmpty) {
      return false;
    }

    final prior = _storyPlanner.outlineSummary.trim();
    final fullHistory = _buildAiChatHistoryFromItems(_items);

    final systemParts = <String>[
      '你是剧情编辑，只输出普通中文说明文字（可分段），不要输出 JSON，不要使用 Markdown 代码块。',
      '任务：根据下面「尚未写入总纲的剧情」写一段事实性摘要，概括这段里已经发生的事（角色动机、关键事件、情绪转折即可），不要续写未来。',
      if (prior.isNotEmpty) ...[
        '【已有总纲】（只作参照，禁止复述或改写其中的句子；只写下面新剧情带来的追加信息）\n$prior',
        '只输出「追加摘要」：承接总纲时间线，只覆盖「待追加的剧情」里的新内容；不要重述总纲里已有的情节。',
      ] else ...[
        '当前还没有总纲：请把「待总结的剧情」写成一段完整的「已发生剧情」结构化回忆。',
      ],
      '【待总结的剧情】（仅此段）\n$uncoveredText',
      '【全剧情参考】（理解语境用）\n$fullHistory',
    ];
    final system = systemParts.join('\n\n');

    final mutationGen = _canvasMutationGeneration;
    try {
      final raw = await _consumeAiCompletion(
        mutationGen: mutationGen,
        messages: [
          {'role': 'system', 'content': system},
          {
            'role': 'user',
            'content':
                prior.isEmpty ? '请直接输出总纲正文（纯文本）。' : '请直接输出要追加到总纲的纯文本段落（纯文本）。',
          },
        ],
        onStreamingAccumulated: onStreamChunk,
      );
      if (!mounted || mutationGen != _canvasMutationGeneration) return false;
      final append = _stripOuterMarkdownFence(raw);
      if (append.isEmpty) return false;

      final merged = prior.isEmpty ? append : '$prior\n\n$append'.trim();
      final h = hashPlotSlice(slice);
      final covId = 'cov_${DateTime.now().microsecondsSinceEpoch}';
      final newSeg = PlannerCoverageSegment(
        id: covId,
        startItemId: g.startItemId,
        endItemId: g.endItemId,
        textHash: h,
      );
      setState(() {
        _storyPlanner = _storyPlanner.copyWith(
          outlineSummary: merged,
          coverage: [..._storyPlanner.coverage, newSeg],
          outlineDirty: false,
        );
      });
      _markUnexportedChanges();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _runPlannerIdeationAi(
    String _,
    void Function(String accumulated)? onStreamChunk,
  ) async {
    if (!_aiSettings.isConfigured) {
      throw StateError('AI 未配置');
    }
    if (_editingItemId != null || _isPreviewing || _isAiSending) {
      throw StateError('正文生成或编辑进行中');
    }

    _revalidatePlannerForPersistIfNeeded();

    final outline = _storyPlanner.outlineSummary.trim();
    final recentPlot = _lastNPlotTurnsText(25);
    final fullPlot = _buildAiChatHistoryFromItems(_items);
    final turnCount = _plotTurnCount();

    final systemParts = <String>[
      '你是剧情构思助手，只输出普通说明文字（可分段），不要输出插入聊天画布的 JSON，不要使用 turns 类 JSON 或 action/user/character 字段。',
      '「已发生剧情总纲」与正文转写只代表过去；你的任务是和用户讨论接下来可能发生什么、伏笔与节奏。',
      if (outline.isNotEmpty) '【已发生剧情总纲】\n$outline',
      if (turnCount > 25) ...[
        if (recentPlot.isNotEmpty) '【最近 25 轮正文（消息/动作）】\n$recentPlot',
      ] else if (fullPlot.trim().isNotEmpty) ...[
        '【完整正文】\n$fullPlot',
      ],
    ];
    final system = systemParts.join('\n\n');

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': system},
    ];
    for (final m in _storyPlanner.chat) {
      final role = m.role == 'assistant' ? 'assistant' : 'user';
      messages.add({'role': role, 'content': m.content});
    }

    final mutationGen = _canvasMutationGeneration;
    final raw = await _consumeAiCompletion(
      mutationGen: mutationGen,
      messages: messages,
      onStreamingAccumulated: onStreamChunk,
    );
    if (!mounted || mutationGen != _canvasMutationGeneration) {
      return null;
    }
    return raw;
  }

  /// Drops the last planner chat turn if it is a user message matching [userContent] (trim 对齐).
  void rollbackPlannerChatLastUserIfMatches(String userContent) {
    if (_storyPlanner.chat.isEmpty) return;
    final last = _storyPlanner.chat.last;
    final expected = userContent.trim();
    if (last.role != 'user' || last.content.trim() != expected) return;
    setState(() {
      _storyPlanner = _storyPlanner.copyWith(
        chat: _storyPlanner.chat
            .sublist(0, _storyPlanner.chat.length - 1)
            .toList(),
      );
    });
    _markUnexportedChanges();
  }

  Widget _buildBottomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPreviewPlannerRow(),
        _buildAiComposer(),
      ],
    );
  }

  bool get _canSendAi {
    if (!_isDraftLoaded) return false;
    if (_isAiSending) return false;
    if (_plannerAiInFlight) return false;
    if (!_aiSettings.isConfigured) return false;
    if (_editingItemId != null) return false;
    if (_isPreviewing) return false;
    if (_isBrowseMode && !_isPlaybackComplete) return false;
    final input = _aiInputController.text.trim();
    return input.isNotEmpty;
  }

  /// 导演/角色模式入口；与输入框解耦，放在「预览」行，避免占用消息框宽度。
  Widget _buildAiModeControl() {
    final disabled = !_isDraftLoaded || _isPreviewing;
    if (widget.lockAiMode) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text('角色模式', style: TextStyle(color: Colors.white70)),
      );
    }
    return DropdownButton<ChatMockupAiMode>(
      value: _aiMode,
      dropdownColor: const Color(0xff262626),
      isDense: true,
      onChanged: disabled || _isAiSending
          ? null
          : (value) {
              if (value == null) return;
              setState(() => _aiMode = value);
            },
      items: const [
        DropdownMenuItem(
          value: ChatMockupAiMode.director,
          child: Text('导演模式', style: TextStyle(color: Colors.white)),
        ),
        DropdownMenuItem(
          value: ChatMockupAiMode.role,
          child: Text('角色模式', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildAiComposer() {
    if (_isBrowseMode && !_isPlaybackComplete) {
      return const SizedBox.shrink();
    }
    final disabled = !_isDraftLoaded || _isPreviewing;
    final canSend = _canSendAi && !disabled;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: AndroidInputLock.lockedListenable,
                  builder: (context, locked, _) {
                    final requireConfirm =
                        AndroidInputLock.requiresExplicitConfirm &&
                            locked &&
                            _aiInputFocusNode.hasFocus;
                    return TextField(
                      controller: _aiInputController,
                      focusNode: _aiInputFocusNode,
                      enabled: !disabled && !_isAiSending,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: _aiMode == ChatMockupAiMode.director
                            ? '输入剧情走向（不会直接作为消息插入）'
                            : '输入要发送的消息（换行会拆分）',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xff202020),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xff2a2a2a)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xff2a2a2a)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        suffixIcon: requireConfirm
                            ? IconButton(
                                tooltip: '确认输入',
                                icon: const Icon(Icons.check_rounded, size: 18),
                                onPressed: () {
                                  AndroidInputLock.unlock();
                                  _aiInputFocusNode.unfocus();
                                },
                              )
                            : null,
                      ),
                      onTap: AndroidInputLock.lock,
                      onTapOutside: (_) {
                        if (AndroidInputLock.isLocked) {
                          _aiInputFocusNode.requestFocus();
                          return;
                        }
                        _aiInputFocusNode.unfocus();
                      },
                      onSubmitted: (_) async {
                        if (!_canSendAi) return;
                        AndroidInputLock.unlock();
                        await _sendAiRequest();
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isAiSending && _aiSettings.enableStreaming)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orangeAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _stopAiStreamGeneration,
                    child: const Text('停止生成', style: TextStyle(fontSize: 12)),
                  ),
                ),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: canSend
                      ? () async {
                          AndroidInputLock.unlock();
                          await _sendAiRequest();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff2a2a2a),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(
                    _isAiSending
                        ? (_aiSettings.enableStreaming ? '流式生成中' : '发送中')
                        : '发送',
                  ),
                ),
              ),
            ],
          ),
          if (!_aiSettings.isConfigured)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Tooltip(
                message: '请先在 AI 设置中补全接口/模型/API key',
                child: Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _sendAiRequest() async {
    if (widget.lockAiMode) {
      await _sendRoleAiRequest();
      return;
    }
    if (_aiMode == ChatMockupAiMode.director) {
      await _sendDirectorAiRequest();
      return;
    }
    await _sendRoleAiRequest();
  }

  String _buildAiChatHistory() {
    return _buildAiChatHistoryFromItems(_items);
  }

  String _buildAiChatHistoryUpToIndex(int inclusiveIndex) {
    if (_items.isEmpty || inclusiveIndex < 0) return '';
    final safeEnd =
        inclusiveIndex < _items.length ? inclusiveIndex : _items.length - 1;
    return _buildAiChatHistoryFromItems(_items.take(safeEnd + 1));
  }

  String _buildAiChatHistoryFromItems(Iterable<ChatMockupItem> items) {
    final lines = <String>[];
    for (final item in items) {
      switch (item.type) {
        case ChatMockupItemType.message:
          final text = (item.text ?? '').trim();
          if (text.isEmpty) continue;
          final prefix = item.side == ChatMockupItemSide.left
              ? '角色'
              : item.side == ChatMockupItemSide.right
                  ? '用户'
                  : '消息';
          lines.add('$prefix: $text');
        case ChatMockupItemType.action:
          final text = (item.text ?? '').trim();
          if (text.isEmpty) continue;
          lines.add('动作: $text');
        case ChatMockupItemType.emoji:
          lines.add('[emoji: ${item.emoji ?? '🙂'}]');
        case ChatMockupItemType.sticker:
          lines.add('[sticker]');
        case ChatMockupItemType.customImage:
          lines.add('[image]');
        case ChatMockupItemType.replyOptions:
          lines.add('[replyOptions]');
        case ChatMockupItemType.commission:
          lines.add('[commission]');
      }
    }
    return lines.join('\n');
  }

  String _buildContinueAiSystemPrompt({required String chatHistory}) {
    final parts = <String>[];

    void addSection(String title, String content) {
      final trimmed = content.trim();
      if (trimmed.isEmpty) return;
      parts.add('【$title】\n$trimmed');
    }

    addSection(
      'Main',
      [
        '你需要输出严格 XML（不要带 Markdown 代码块）：',
        '<chat>',
        '  <action><![CDATA[动作/旁白，可为空]]></action>',
        '  <character><![CDATA[角色消息1',
        '角色消息2]]></character>',
        '</chat>',
        '约束：',
        '- 这是“续写”任务，只能从现有历史最后一条之后继续，不得改写、复述或重排已有内容。',
        '- action 可为空；character 为 1~5 条角色消息，每条用换行分隔。',
        '- 字段值放在 CDATA 中（可为空字符串）。',
        '- 换行规则：一个换行=一条新消息，空行丢弃，trim()。',
      ].join('\n'),
    );
    addSection('用户身份', _aiSettings.userPrompt);
    addSection('角色卡', _aiSettings.rolePrompt);
    addSection('聊天历史（截止锚点）', chatHistory);

    return parts.join('\n\n');
  }

  String _buildAiSystemPrompt({
    required ChatMockupAiMode mode,
    required String scenarioOrUserInput,
  }) {
    final preset = _promptPreset;
    final parts = <String>[];

    String buildMainConstraintsForDirector() {
      return [
        '你需要输出严格 XML（不要带 Markdown 代码块）：',
        '<chat>',
        '  <turn>',
        '    <action><![CDATA[动作/旁白，可为空]]></action>',
        '    <user><![CDATA[用户发言，可为空]]></user>',
        '    <character><![CDATA[角色发言，可为空]]></character>',
        '  </turn>',
        '</chat>',
        '约束：turn 数量 5~7。每个 turn 都必须包含 action/user/character 三个子元素（CDATA 可为空）。',
        '身份映射：',
        '- 【用户身份】描述的是 user 的说话者；user 会显示为右侧气泡；聊天历史中的「用户:」也对应 user。',
        '- 【角色卡】描述的是 character 的说话者；character 会显示为左侧气泡；聊天历史中的「角色:」也对应 character。',
        '- 不得因为角色卡或用户身份使用第一人称「我」而改变字段归属。',
        '字段归属：user 仅写用户发言；character 仅写角色发言；action 仅写动作/旁白/状态，禁止写台词归属。',
        '禁止跨写：不得交换 user 与 character 的语义，不得把 user 内容写入 character，也不得反向写入。',
        '禁止冒充：不得让任一方冒充另一方发言；禁止把角色卡/设定内容复述进 user，禁止把用户设定写进 character。',
        '剧情走向仅为导演指令，不视为用户聊天消息。',
        '示例仅展示 XML 结构，实际输出的 turn 数量必须是 5~7。',
        '换行规则：一个换行=一条新消息，空行丢弃，trim()。',
        '输出前自检：检查每个 turn 的字段归属与 CDATA 内容均正确；若任一方本轮不发言必须输出空 CDATA。',
      ].join('\n');
    }

    String buildDirectorFinalSelfCheck() {
      return [
        '最终自检（必须在输出前完成）：',
        '1) 输出仅为 XML（<chat> 根元素），不含解释文本和 Markdown 代码块。',
        '2) turn 数量为 5~7，且每个 turn 都有 action/user/character 三个子元素。',
        '3) user 仅用户发言，character 仅角色发言，action 仅动作/旁白/状态，不得跨写或互换语义。',
        '4) 任一方本轮不发言时，CDATA 内容可为空。',
      ].join('\n');
    }

    String buildMainConstraintsForRole() {
      return [
        '你需要输出严格 XML（不要带 Markdown 代码块）：',
        '<chat>',
        '  <action><![CDATA[动作/旁白，可为空]]></action>',
        '  <character><![CDATA[角色消息1',
        '角色消息2',
        '角色消息3]]></character>',
        '</chat>',
        '约束：character 生成 3~5 条消息，每条用换行分隔。',
        '换行规则：一个换行=一条新消息，空行丢弃，trim()。',
      ].join('\n');
    }

    String buildSendPromptForMode() {
      return mode == ChatMockupAiMode.director
          ? _aiSettings.directorSendPrompt
          : _aiSettings.roleSendPrompt;
    }

    void addSection(String title, String content) {
      final trimmed = content.trim();
      if (trimmed.isEmpty) return;
      parts.add('【$title】\n$trimmed');
    }

    String finalizePrompt() {
      var prompt = parts.join('\n\n');
      if (mode == ChatMockupAiMode.director) {
        final finalCheckSection = '【输出前自检】\n${buildDirectorFinalSelfCheck()}';
        prompt = prompt.trim().isEmpty
            ? finalCheckSection
            : '$prompt\n\n$finalCheckSection';
      }
      return prompt;
    }

    if (preset == null || preset.order.isEmpty) {
      addSection(
        'Main',
        mode == ChatMockupAiMode.director
            ? buildMainConstraintsForDirector()
            : buildMainConstraintsForRole(),
      );
      addSection('发送时提示词', buildSendPromptForMode());
      addSection('用户身份', _aiSettings.userPrompt);
      addSection('角色卡', _aiSettings.rolePrompt);
      if (mode == ChatMockupAiMode.director) {
        addSection('剧情走向', scenarioOrUserInput);
      }
      addSection('聊天历史', _buildAiChatHistory());
      return finalizePrompt();
    }

    for (final id in preset.order) {
      final enabled = preset.enabledById[id] ?? false;
      if (!enabled) continue;
      switch (id) {
        case 'main':
          final base = preset.promptsById[id] ?? '';
          addSection(
            'Main',
            mode == ChatMockupAiMode.director
                ? buildMainConstraintsForDirector()
                : [base, buildMainConstraintsForRole()]
                    .where((e) => e.trim().isNotEmpty)
                    .join('\n'),
          );
        case 'personaDescription':
          addSection('用户身份', _aiSettings.userPrompt);
        case 'charDescription':
          addSection('角色卡', _aiSettings.rolePrompt);
        case 'scenario':
          if (mode == ChatMockupAiMode.director) {
            addSection('剧情走向', scenarioOrUserInput);
          }
        case 'chatHistory':
          addSection('聊天历史', _buildAiChatHistory());
        default:
          continue;
      }
    }

    if (parts.isEmpty) {
      addSection(
        'Main',
        mode == ChatMockupAiMode.director
            ? buildMainConstraintsForDirector()
            : buildMainConstraintsForRole(),
      );
    }
    addSection('发送时提示词', buildSendPromptForMode());
    return finalizePrompt();
  }

  void _beginAiStreamSession({
    required _AiStreamSessionKind kind,
    String? insertAfterItemId,
  }) {
    final pos = insertAfterItemId == null
        ? _items.length
        : () {
            final idx = _items.indexWhere((e) => e.id == insertAfterItemId);
            return idx < 0 ? _items.length : idx + 1;
          }();
    final session = _AiStreamSession(
      kind: kind,
      baseInsertPos: pos,
      xmlParser: ChatMockupAiXmlStreamFieldParser(
        directorMode: kind == _AiStreamSessionKind.director,
      ),
    );
    _aiStreamSession = session;
    final insertAt = pos.clamp(0, _items.length);
    final placeholder = _createItem(
      type: ChatMockupItemType.message,
      side: ChatMockupItemSide.left,
      text: _aiStreamingPlaceholderText,
    );
    _items.insert(insertAt, placeholder);
    session.placeholderItemId = placeholder.id;
    _visibleItemCount = _items.length;
    _markUnexportedChanges();
  }

  void _removeSessionPlaceholder(_AiStreamSession session) {
    final pid = session.placeholderItemId;
    if (pid == null) return;
    _items.removeWhere((it) => it.id == pid);
    session.placeholderItemId = null;
  }

  void _rollbackAiStreamSession() {
    final session = _aiStreamSession;
    if (session == null) return;
    final ids = session.keyToItemId.values.toSet();
    final ph = session.placeholderItemId;
    if (ph != null) {
      ids.add(ph);
    }
    _items.removeWhere((it) => ids.contains(it.id));
    session.keyToItemId.clear();
    session.placeholderItemId = null;
    _aiStreamSession = null;
  }

  /// Ends streaming session without removing projected chat rows (only drops placeholder).
  void _detachAiStreamSessionKeepingProjectedItems() {
    final session = _aiStreamSession;
    if (session == null) return;
    final ph = session.placeholderItemId;
    if (ph != null) {
      _items.removeWhere((it) => it.id == ph);
      session.placeholderItemId = null;
    }
    session.keyToItemId.clear();
    _aiStreamSession = null;
  }

  void _rollbackStreamingAiParseFailureSnack() {
    final session = _aiStreamSession;
    final keepProjection = session != null && session.keyToItemId.isNotEmpty;
    setState(() {
      if (keepProjection) {
        _detachAiStreamSessionKeepingProjectedItems();
      } else {
        _rollbackAiStreamSession();
      }
      _visibleItemCount = _items.length;
      _markUnexportedChanges();
    });
    _flushDraftAutoSaveNow();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          keepProjection ? '最终校验失败，已保留当前可见内容' : 'AI 失败: 无法解析或校验输出',
        ),
      ),
    );
  }

  void _handleAiStreamAccumulated(String accumulated) {
    if (!mounted || _aiStreamSession == null) return;
    final session = _aiStreamSession!;
    final newEvents = session.xmlParser.feed(accumulated);
    if (newEvents.isEmpty) return;
    setState(() {
      _applyCompletedXmlFieldEvents(session, newEvents);
      _markUnexportedChanges();
    });
    _flushDraftAutoSaveNow();
    _setFollowingLatest(true);
    _scrollToLatest(animated: true);
  }

  void _applyCompletedXmlFieldEvents(
    _AiStreamSession session,
    List<ChatMockupAiFieldEvent> newEvents,
  ) {
    if (newEvents.isEmpty) return;

    final continueMode = session.kind == _AiStreamSessionKind.continueFollowUp;
    final descriptors = streamItemDescriptorsFromFieldEvents(
      newEvents,
      startFieldIndex: session.completedFieldIndex,
      directorMode: session.kind == _AiStreamSessionKind.director,
      continueMode: continueMode,
      totalItemQuotaRemaining: 40 - session.appendedItemCount,
      continueLeftQuotaRemaining:
          continueMode ? 5 - session.continueLeftMessageCount : null,
    );
    session.completedFieldIndex += newEvents.length;
    session.appendedItemCount += descriptors.length;
    for (final d in descriptors) {
      if (d.side == ChatMockupAiStreamItemSide.left && !d.isAction) {
        session.continueLeftMessageCount++;
      }
    }

    if (descriptors.isNotEmpty) {
      _removeSessionPlaceholder(session);
    }

    final newLines = <_AiProjectedLine>[];
    var insertPos = _streamAppendInsertPos(session);
    for (final d in descriptors) {
      final line = _AiProjectedLine(
        lineKey: d.lineKey,
        isAction: d.isAction,
        side: _canvasSideFromStream(d.side),
        text: d.text,
      );
      newLines.add(line);
      final item = _createProjectedItem(line);
      session.keyToItemId[d.lineKey] = item.id;
      final clamped = insertPos.clamp(0, _items.length);
      _items.insert(clamped, item);
      insertPos = clamped + 1;
    }

    if (newLines.isNotEmpty) {
      final snap = session.lastProjectedLinesSnapshot ?? <_AiProjectedLine>[];
      session.lastProjectedLinesSnapshot = [...snap, ...newLines];
      _visibleItemCount = _items.length;
    }
  }

  int _streamAppendInsertPos(_AiStreamSession session) {
    var insertPos = session.baseInsertPos;
    for (final id in session.keyToItemId.values) {
      final idx = _items.indexWhere((it) => it.id == id);
      if (idx >= 0 && idx + 1 > insertPos) {
        insertPos = idx + 1;
      }
    }
    return insertPos;
  }

  void _flushAiStreamXmlAppend(String accumulated) {
    final session = _aiStreamSession;
    if (session == null) return;
    final newEvents = session.xmlParser.feed(accumulated);
    if (newEvents.isEmpty) return;
    _applyCompletedXmlFieldEvents(session, newEvents);
  }

  ChatMockupItemSide _canvasSideFromStream(ChatMockupAiStreamItemSide side) {
    return switch (side) {
      ChatMockupAiStreamItemSide.left => ChatMockupItemSide.left,
      ChatMockupAiStreamItemSide.right => ChatMockupItemSide.right,
      ChatMockupAiStreamItemSide.center => ChatMockupItemSide.center,
    };
  }

  ChatMockupItem _createProjectedItem(_AiProjectedLine line) {
    if (line.isAction) {
      return _createItem(
        type: ChatMockupItemType.action,
        side: ChatMockupItemSide.center,
        text: line.text,
      );
    }
    return _createItem(
      type: ChatMockupItemType.message,
      side: line.side,
      text: line.text,
    );
  }

  /// Removes streamed placeholders and inserts validated items at the same block.
  void _replaceStreamingBlockWithItems(List<ChatMockupItem> newItems) {
    final session = _aiStreamSession;
    if (session == null) return;
    final ids = session.keyToItemId.values.toSet();
    final ph = session.placeholderItemId;
    if (ph != null) {
      ids.add(ph);
    }
    var minIdx = session.baseInsertPos;
    if (ids.isNotEmpty) {
      for (final id in ids) {
        final i = _items.indexWhere((e) => e.id == id);
        if (i >= 0) {
          minIdx = math.min(minIdx, i);
        }
      }
    }
    _items.removeWhere((it) => ids.contains(it.id));
    if (newItems.isNotEmpty) {
      final insertAt = minIdx.clamp(0, _items.length);
      _items.insertAll(insertAt, newItems);
      for (final it in newItems) {
        _newlyAddedItemIds.add(it.id);
      }
    }
    _visibleItemCount = _items.length;
    session.keyToItemId.clear();
    session.placeholderItemId = null;
    _aiStreamSession = null;
  }

  _DirectorItemsBuild _buildDirectorItemsFromDecodedImpl(
    Map<String, dynamic> decoded, {
    required bool streamingFinalize,
  }) {
    final turns = decoded['turns'];
    if (turns is! List) {
      throw const FormatException(
        'AI 输出缺少 turns 数组；字段需为 action/user/character 字符串',
      );
    }
    if (turns.isEmpty) {
      throw const FormatException(
        'AI 输出 turns 为空；字段需为 action/user/character 字符串',
      );
    }
    String? qualityWarning;
    if (turns.length < 5 || turns.length > 7) {
      if (!streamingFinalize) {
        throw FormatException(
          'AI 输出 turns 数量错误（${turns.length}）；需要 5~7 条； '
          '字段需为 action/user/character 字符串',
        );
      }
      qualityWarning = 'turns 数量为 ${turns.length}（建议 5~7 条），请检查剧情节奏';
    }

    final pending = <ChatMockupItem>[];
    for (var i = 0; i < turns.length; i++) {
      final t = turns[i];
      if (pending.length >= 40) break;
      if (t is! Map<String, dynamic>) {
        throw FormatException(
          'AI 输出 turns[$i] 不是对象；字段需为 action/user/character 字符串',
        );
      }
      final action = t['action'];
      final user = t['user'];
      final character = t['character'];
      if (action is! String || user is! String || character is! String) {
        throw FormatException(
          'AI 输出 turns[$i] 字段类型错误；字段需为 action/user/character 字符串',
        );
      }

      _addActionLines(pending, action);

      for (final line in _splitAiMessageLines(user)) {
        if (pending.length >= 40) break;
        pending.add(_createItem(
          type: ChatMockupItemType.message,
          side: ChatMockupItemSide.right,
          text: line,
        ));
      }
      for (final line in _splitAiMessageLines(character)) {
        if (pending.length >= 40) break;
        pending.add(_createItem(
          type: ChatMockupItemType.message,
          side: ChatMockupItemSide.left,
          text: line,
        ));
      }
    }
    return _DirectorItemsBuild(
      items: pending,
      qualityWarning: qualityWarning,
    );
  }

  List<ChatMockupItem> _buildRoleContinueItemsFromDecoded(
    Map<String, dynamic> decoded,
  ) {
    final action = _readAnyString(decoded, ['action', '动作']) ?? '';
    final character =
        _readAnyString(decoded, ['character', 'assistant', 'left', '消息左']) ??
            '';

    final pending = <ChatMockupItem>[];
    _addActionLines(pending, action);
    for (final line in _splitAiMessageLines(character)) {
      if (pending.length >= 40) break;
      pending.add(
        _createItem(
          type: ChatMockupItemType.message,
          side: ChatMockupItemSide.left,
          text: line,
        ),
      );
    }
    return pending;
  }

  List<ChatMockupItem> _buildContinueItemsFromDecoded(
    Map<String, dynamic> decoded,
  ) {
    final action = _readAnyString(decoded, ['action', '动作']) ?? '';
    final character =
        _readAnyString(decoded, ['character', 'assistant', 'left', '消息左']) ??
            '';

    final pending = <ChatMockupItem>[];
    _addActionLines(pending, action);
    for (final line in _splitAiMessageLines(character).take(5)) {
      if (pending.length >= 40) break;
      pending.add(
        _createItem(
          type: ChatMockupItemType.message,
          side: ChatMockupItemSide.left,
          text: line,
        ),
      );
    }
    return pending;
  }

  _DirectorItemsBuild _buildDirectorItemsFromFieldEvents(
    List<ChatMockupAiFieldEvent> events,
  ) {
    final pending = <ChatMockupItem>[];
    var sawUser = false;
    for (final e in events) {
      if (pending.length >= 40) break;
      switch (e.kind) {
        case ChatMockupAiFieldKind.action:
          _addActionLines(pending, e.rawValue);
        case ChatMockupAiFieldKind.user:
          sawUser = true;
          for (final line in _splitAiMessageLines(e.rawValue)) {
            if (pending.length >= 40) break;
            pending.add(_createItem(
              type: ChatMockupItemType.message,
              side: ChatMockupItemSide.right,
              text: line,
            ));
          }
        case ChatMockupAiFieldKind.character:
          for (final line in _splitAiMessageLines(e.rawValue)) {
            if (pending.length >= 40) break;
            pending.add(_createItem(
              type: ChatMockupItemType.message,
              side: ChatMockupItemSide.left,
              text: line,
            ));
          }
      }
    }
    String? qualityWarning;
    if (!sawUser && pending.isNotEmpty) {
      qualityWarning = '未识别到 user 字段，请检查对话结构';
    }
    return _DirectorItemsBuild(
      items: pending,
      qualityWarning: qualityWarning,
    );
  }

  List<ChatMockupItem> _buildRoleItemsFromFieldEvents(
    List<ChatMockupAiFieldEvent> events,
  ) {
    final pending = <ChatMockupItem>[];
    for (final e in events) {
      if (pending.length >= 40) break;
      switch (e.kind) {
        case ChatMockupAiFieldKind.action:
          _addActionLines(pending, e.rawValue);
        case ChatMockupAiFieldKind.user:
          break;
        case ChatMockupAiFieldKind.character:
          for (final line in _splitAiMessageLines(e.rawValue)) {
            if (pending.length >= 40) break;
            pending.add(
              _createItem(
                type: ChatMockupItemType.message,
                side: ChatMockupItemSide.left,
                text: line,
              ),
            );
          }
      }
    }
    return pending;
  }

  List<ChatMockupItem> _buildContinueItemsFromFieldEvents(
    List<ChatMockupAiFieldEvent> events,
  ) {
    final pending = <ChatMockupItem>[];
    var leftCount = 0;
    for (final e in events) {
      if (pending.length >= 40) break;
      switch (e.kind) {
        case ChatMockupAiFieldKind.action:
          _addActionLines(pending, e.rawValue);
        case ChatMockupAiFieldKind.user:
          break;
        case ChatMockupAiFieldKind.character:
          for (final line in _splitAiMessageLines(e.rawValue)) {
            if (pending.length >= 40 || leftCount >= 5) break;
            pending.add(
              _createItem(
                type: ChatMockupItemType.message,
                side: ChatMockupItemSide.left,
                text: line,
              ),
            );
            leftCount++;
          }
      }
    }
    return pending;
  }

  List<ChatMockupItem> _itemsFromProjectedLines(List<_AiProjectedLine> lines) {
    return [for (final line in lines) _createProjectedItem(line)];
  }

  Map<String, dynamic> _decodeAiJsonObject(String content) {
    var text = content.trim();
    if (text.startsWith('```')) {
      final fenceIndex = text.indexOf('\n');
      if (fenceIndex >= 0) {
        text = text.substring(fenceIndex + 1);
      }
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3);
      }
      text = text.trim();
    }
    final first = text.indexOf('{');
    final last = text.lastIndexOf('}');
    if (first >= 0 && last > first) {
      text = text.substring(first, last + 1);
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('AI 输出不是 JSON 对象');
    }
    return decoded;
  }

  Map<String, dynamic>? _tryDecodeAiJsonStrict(String content) {
    try {
      return _decodeAiJsonObject(content);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _tryDecodeAiXmlStrict(
    String content,
    _AiStreamSessionKind kind,
  ) {
    return switch (kind) {
      _AiStreamSessionKind.director =>
        ChatMockupAiStreamPreview.tryParseStrictXmlDirector(content),
      _AiStreamSessionKind.role ||
      _AiStreamSessionKind.continueFollowUp =>
        ChatMockupAiStreamPreview.tryParseStrictXmlRoleOrContinue(content),
    };
  }

  /// Bracket-repaired buffer then [jsonDecode] to a map, or `null`.
  Map<String, dynamic>? _tryDecodeAiJsonRepaired(String content) {
    final repaired = ChatMockupAiStreamPreview.repairForProjection(content);
    return ChatMockupAiStreamPreview.tryParseProjectedObject(repaired);
  }

  /// Builds insertable items from a decoded root object; returns `null` if empty
  /// or if builders throw ([FormatException] from director strict shape, etc.).
  ({List<ChatMockupItem> items, String? qualityWarning})?
      _tryBuildAiItemsFromDecodedMap(
    Map<String, dynamic> decoded,
    _AiStreamSessionKind kind, {
    required bool streamingFinalize,
  }) {
    try {
      if (kind == _AiStreamSessionKind.director) {
        final b = _buildDirectorItemsFromDecodedImpl(
          decoded,
          streamingFinalize: streamingFinalize,
        );
        if (b.items.isEmpty) return null;
        return (items: b.items, qualityWarning: b.qualityWarning);
      }
      if (kind == _AiStreamSessionKind.role) {
        final r = _buildRoleContinueItemsFromDecoded(decoded);
        if (r.isEmpty) return null;
        return (items: r, qualityWarning: null);
      }
      final c = _buildContinueItemsFromDecoded(decoded);
      if (c.isEmpty) return null;
      return (items: c, qualityWarning: null);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ChatMockup AI: build from decoded map failed: $e\n$st');
      }
      return null;
    }
  }

  /// Same resolution order as [_finalizeStreamingAiContent] passes 1–4 (no snapshot).
  ///
  /// 1. Strict XML parse + map builders.
  /// 2. Ordered field scan (XML-first) + field builders.
  /// 3. Strict [jsonDecode] + map builders.
  /// 4. [ChatMockupAiStreamPreview.repairForProjection] + [tryParseProjectedObject] + builders.
  ///
  /// [resolutionNote] is set when legacy JSON repair succeeds (SnackBar parity).
  ({
    List<ChatMockupItem> items,
    String? qualityWarning,
    String? resolutionNote
  })? _tryResolveAiItemsNonStreaming(
    String content,
    _AiStreamSessionKind kind,
  ) {
    final xmlStrict = _tryDecodeAiXmlStrict(content, kind);
    if (xmlStrict != null) {
      final fromXml = _tryBuildAiItemsFromDecodedMap(
        xmlStrict,
        kind,
        streamingFinalize: false,
      );
      if (fromXml != null) {
        return (
          items: fromXml.items,
          qualityWarning: fromXml.qualityWarning,
          resolutionNote: null,
        );
      }
    }

    final events = switch (kind) {
      _AiStreamSessionKind.director =>
        ChatMockupAiStreamPreview.scanDirectorFields(content),
      _AiStreamSessionKind.role =>
        ChatMockupAiStreamPreview.scanRoleOrContinueFields(content),
      _AiStreamSessionKind.continueFollowUp =>
        ChatMockupAiStreamPreview.scanRoleOrContinueFields(content),
    };
    if (kind == _AiStreamSessionKind.director) {
      final b = _buildDirectorItemsFromFieldEvents(events);
      if (b.items.isNotEmpty) {
        return (
          items: b.items,
          qualityWarning: b.qualityWarning,
          resolutionNote: null,
        );
      }
    } else if (kind == _AiStreamSessionKind.role) {
      final r = _buildRoleItemsFromFieldEvents(events);
      if (r.isNotEmpty) {
        return (items: r, qualityWarning: null, resolutionNote: null);
      }
    } else {
      final c = _buildContinueItemsFromFieldEvents(events);
      if (c.isNotEmpty) {
        return (items: c, qualityWarning: null, resolutionNote: null);
      }
    }

    final strict = _tryDecodeAiJsonStrict(content);
    if (strict != null) {
      final fromStrict = _tryBuildAiItemsFromDecodedMap(
        strict,
        kind,
        streamingFinalize: false,
      );
      if (fromStrict != null) {
        return (
          items: fromStrict.items,
          qualityWarning: fromStrict.qualityWarning,
          resolutionNote: null,
        );
      }
    }

    final repaired = _tryDecodeAiJsonRepaired(content);
    if (repaired != null) {
      final fromRepaired = _tryBuildAiItemsFromDecodedMap(
        repaired,
        kind,
        streamingFinalize: false,
      );
      if (fromRepaired != null) {
        return (
          items: fromRepaired.items,
          qualityWarning: fromRepaired.qualityWarning,
          resolutionNote: _aiRepairedStructureUserNote,
        );
      }
    }

    return null;
  }

  void _maybeShowNonStreamingAiResolveNotes({
    String? resolutionNote,
    String? qualityWarning,
  }) {
    if (!mounted) return;
    final parts = <String>[];
    if (resolutionNote != null) parts.add(resolutionNote);
    if (qualityWarning != null) parts.add(qualityWarning);
    if (parts.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(parts.join('\n'))),
    );
  }

  /// Resolves streaming finalize in five passes:
  /// 1. Strict XML parse on `<chat>`… slice.
  /// 2. Ordered field scan (XML-first, JSON fallback).
  /// 3. Strict [jsonDecode] on trimmed `{`…`}` slice.
  /// 4. [ChatMockupAiStreamPreview.repairForProjection] then
  ///    [ChatMockupAiStreamPreview.tryParseProjectedObject].
  /// 5. Last successful stream projection snapshot.
  _StreamingAiFinalize? _finalizeStreamingAiContent(
    String content,
    _AiStreamSessionKind sessionKind,
  ) {
    _StreamingAiFinalize? out;

    void tryDecoded(Map<String, dynamic> decoded, _AiStreamDecodeKind k) {
      if (out != null) return;
      final built = _tryBuildAiItemsFromDecodedMap(
        decoded,
        sessionKind,
        streamingFinalize: true,
      );
      if (built == null) {
        if (kDebugMode) {
          debugPrint(
            'ChatMockup AI finalize: decoded map produced empty or invalid ($k)',
          );
        }
        return;
      }
      out = _StreamingAiFinalize(
        items: built.items,
        decodeKind: k,
        qualityWarning: built.qualityWarning,
      );
    }

    void tryFieldScan() {
      if (out != null) return;
      final events = switch (sessionKind) {
        _AiStreamSessionKind.director =>
          ChatMockupAiStreamPreview.scanDirectorFields(content),
        _AiStreamSessionKind.role =>
          ChatMockupAiStreamPreview.scanRoleOrContinueFields(content),
        _AiStreamSessionKind.continueFollowUp =>
          ChatMockupAiStreamPreview.scanRoleOrContinueFields(content),
      };
      try {
        if (sessionKind == _AiStreamSessionKind.director) {
          final b = _buildDirectorItemsFromFieldEvents(events);
          if (b.items.isEmpty) return;
          out = _StreamingAiFinalize(
            items: b.items,
            decodeKind: _AiStreamDecodeKind.orderedFieldExtraction,
            qualityWarning: b.qualityWarning,
          );
        } else if (sessionKind == _AiStreamSessionKind.role) {
          final r = _buildRoleItemsFromFieldEvents(events);
          if (r.isEmpty) return;
          out = _StreamingAiFinalize(
            items: r,
            decodeKind: _AiStreamDecodeKind.orderedFieldExtraction,
          );
        } else {
          final c = _buildContinueItemsFromFieldEvents(events);
          if (c.isEmpty) return;
          out = _StreamingAiFinalize(
            items: c,
            decodeKind: _AiStreamDecodeKind.orderedFieldExtraction,
          );
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint(
              'ChatMockup AI finalize: field scan build failed: $e\n$st');
        }
      }
    }

    void tryCachedProjection() {
      if (out != null) return;
      final snap = _aiStreamSession?.lastProjectedLinesSnapshot;
      if (snap == null || snap.isEmpty) return;
      final items = _itemsFromProjectedLines(snap);
      if (items.isEmpty) return;
      out = _StreamingAiFinalize(
        items: items,
        decodeKind: _AiStreamDecodeKind.cachedProjection,
      );
    }

    final xmlStrict = _tryDecodeAiXmlStrict(content, sessionKind);
    if (xmlStrict != null) {
      tryDecoded(xmlStrict, _AiStreamDecodeKind.strictXml);
    }

    if (out == null) {
      tryFieldScan();
    }

    if (out == null) {
      final strict = _tryDecodeAiJsonStrict(content);
      if (strict != null) {
        tryDecoded(strict, _AiStreamDecodeKind.legacyJson);
      }
    }

    if (out == null) {
      final obj = _tryDecodeAiJsonRepaired(content);
      if (obj != null) {
        tryDecoded(obj, _AiStreamDecodeKind.legacyRepairedJson);
      }
    }

    if (out == null) {
      tryCachedProjection();
    }

    return out;
  }

  void _showStreamingAiFinalizeFeedback({
    required _AiStreamDecodeKind decodeKind,
    String? qualityWarning,
  }) {
    if (!mounted) return;
    final parts = <String>[];
    if (decodeKind == _AiStreamDecodeKind.legacyRepairedJson) {
      parts.add(_aiRepairedStructureUserNote);
    } else if (decodeKind == _AiStreamDecodeKind.orderedFieldExtraction) {
      parts.add('已按字段提取结果完成插入，建议核对语义与顺序');
    } else if (decodeKind == _AiStreamDecodeKind.cachedProjection) {
      parts.add(
        '最终校验未通过，已保留可用内容（可能与模型原始输出存在差异）',
      );
    }
    if (qualityWarning != null) {
      parts.add(qualityWarning);
    }
    if (parts.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(parts.join('\n'))),
    );
  }

  /// User-initiated stop (button). [dispose] uses the same cancel hook with
  /// [_aiStreamAbortRequested] set there when a stream is active.
  void _stopAiStreamGeneration() {
    if (!_isAiSending || !_aiSettings.enableStreaming) return;
    if (_cancelActiveAiStream == null) return;
    setState(() => _aiStreamAbortRequested = true);
    _cancelActiveAiStream?.call();
  }

  /// Loads AI reply text. Streaming errors propagate to callers.
  ///
  /// **Abort vs failure:** If [_aiStreamAbortRequested] is set to `true`
  /// before [http.Client.close] (停止生成 or [dispose]), the stream throws;
  /// callers should treat that as user cancellation (“已停止生成”), not
  /// “AI 失败”. Other exceptions are real failures.
  Future<String> _consumeAiCompletion({
    required List<Map<String, String>> messages,
    required int mutationGen,
    double temperature = 0.8,
    void Function(String accumulated)? onStreamingAccumulated,
  }) async {
    if (!_aiSettings.enableStreaming) {
      return _aiApi.createChatCompletion(
        endpoint: _aiSettings.endpoint,
        apiKey: _aiSettings.apiKey,
        model: _aiSettings.model,
        messages: messages,
        temperature: temperature,
      );
    }

    final buf = StringBuffer();
    final streamClient = http.Client();
    _cancelActiveAiStream = streamClient.close;
    try {
      await for (final delta in _aiApi.createChatCompletionStream(
        endpoint: _aiSettings.endpoint,
        apiKey: _aiSettings.apiKey,
        model: _aiSettings.model,
        messages: messages,
        temperature: temperature,
        httpClient: streamClient,
      )) {
        buf.write(delta);
        onStreamingAccumulated?.call(buf.toString());
      }
    } finally {
      _cancelActiveAiStream = null;
      streamClient.close();
    }
    if (mutationGen != _canvasMutationGeneration) {
      return buf.toString();
    }
    if (mounted && onStreamingAccumulated != null && _aiStreamSession != null) {
      setState(() {
        _flushAiStreamXmlAppend(buf.toString());
        _markUnexportedChanges();
      });
      _flushDraftAutoSaveNow();
      _setFollowingLatest(true);
      _scrollToLatest(animated: true);
    } else if (mounted) {
      setState(() {});
    }
    return buf.toString();
  }

  List<String> _splitAiMessageLines(String value) {
    return value
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _addActionLines(List<ChatMockupItem> pending, String value) {
    for (final line in _splitAiMessageLines(value)) {
      if (pending.length >= 40) return;
      pending.add(
        _createItem(
          type: ChatMockupItemType.action,
          side: ChatMockupItemSide.center,
          text: line,
        ),
      );
    }
  }

  String? _readAnyString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v is String) return v;
    }
    return null;
  }

  void _appendNewItems(List<ChatMockupItem> items) {
    if (items.isEmpty) return;
    setState(() {
      _items.addAll(items);
      for (final it in items) {
        _newlyAddedItemIds.add(it.id);
      }
      _visibleItemCount = _items.length;
      _markUnexportedChanges();
    });
    _flushDraftAutoSaveNow();
    _setFollowingLatest(true);
    _scrollToLatest(animated: true);
  }

  void _insertNewItemsAfter(
    String anchorItemId,
    List<ChatMockupItem> items, {
    bool followLatest = false,
  }) {
    if (items.isEmpty) return;
    final anchorIndex = _items.indexWhere((item) => item.id == anchorItemId);
    if (anchorIndex < 0) {
      _appendNewItems(items);
      return;
    }
    final insertAt = anchorIndex + 1;
    setState(() {
      _items.insertAll(insertAt, items);
      for (final it in items) {
        _newlyAddedItemIds.add(it.id);
      }
      _visibleItemCount = _items.length;
      _markUnexportedChanges();
    });
    _flushDraftAutoSaveNow();
    if (followLatest) {
      _setFollowingLatest(true);
      _scrollToLatest(animated: true);
    }
  }

  Future<void> _continueFromSelectedItem(String itemId) async {
    if (_selectedItemIds.length != 1) return;
    if (!_isDraftLoaded ||
        !_isAiInitialized ||
        !_aiSettings.isConfigured ||
        _isPreviewing ||
        _isAiSending ||
        (_isBrowseMode && !_isPlaybackComplete) ||
        _editingItemId != null) {
      return;
    }

    final selectedIndex = _items.indexWhere((item) => item.id == itemId);
    if (selectedIndex < 0) return;
    final selectedItem = _items[selectedIndex];
    if (selectedItem.type != ChatMockupItemType.message &&
        selectedItem.type != ChatMockupItemType.action) {
      return;
    }

    _aiStreamAbortRequested = false;
    final mutationGen = _canvasMutationGeneration;
    setState(() {
      _isAiSending = true;
      if (_aiSettings.enableStreaming) {
        _beginAiStreamSession(
          kind: _AiStreamSessionKind.continueFollowUp,
          insertAfterItemId: itemId,
        );
      }
    });
    if (_aiSettings.enableStreaming) {
      _flushDraftAutoSaveNow();
    }
    try {
      final chatHistory = _buildAiChatHistoryUpToIndex(selectedIndex);
      final systemPrompt =
          _buildContinueAiSystemPrompt(chatHistory: chatHistory);
      final content = await _consumeAiCompletion(
        mutationGen: mutationGen,
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content': '请只输出 XML，不要解释文字、不要 Markdown 代码块。格式： '
                '<chat>'
                '<action><![CDATA[]]></action>'
                '<character><![CDATA[]]></character>'
                '</chat>',
          },
        ],
        onStreamingAccumulated:
            _aiSettings.enableStreaming ? _handleAiStreamAccumulated : null,
      );

      if (!mounted || mutationGen != _canvasMutationGeneration) {
        return;
      }
      late final List<ChatMockupItem> pending;
      if (_aiSettings.enableStreaming) {
        final fin = _finalizeStreamingAiContent(
          content,
          _AiStreamSessionKind.continueFollowUp,
        );
        if (!mounted || mutationGen != _canvasMutationGeneration) {
          return;
        }
        if (fin == null) {
          _rollbackStreamingAiParseFailureSnack();
          return;
        }
        pending = fin.items;
        _showStreamingAiFinalizeFeedback(
          decodeKind: fin.decodeKind,
          qualityWarning: fin.qualityWarning,
        );
      } else {
        final resolved = _tryResolveAiItemsNonStreaming(
          content,
          _AiStreamSessionKind.continueFollowUp,
        );
        if (resolved == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('AI 输出无法解析为可用内容')),
            );
          }
          return;
        }
        pending = resolved.items;
        _maybeShowNonStreamingAiResolveNotes(
          resolutionNote: resolved.resolutionNote,
          qualityWarning: resolved.qualityWarning,
        );
      }

      if (!mounted || pending.isEmpty) {
        if (_aiSettings.enableStreaming && mounted && pending.isEmpty) {
          setState(() {
            _rollbackAiStreamSession();
            _markUnexportedChanges();
          });
          _flushDraftAutoSaveNow();
        }
        return;
      }
      if (_aiSettings.enableStreaming) {
        setState(() {
          _replaceStreamingBlockWithItems(pending);
          _markUnexportedChanges();
        });
        _flushDraftAutoSaveNow();
        _setFollowingLatest(true);
        _scrollToLatest(animated: true);
      } else {
        _insertNewItemsAfter(itemId, pending);
      }
    } catch (error) {
      if (!mounted || mutationGen != _canvasMutationGeneration) {
        _aiStreamAbortRequested = false;
        return;
      }
      final aborted = _aiStreamAbortRequested;
      _aiStreamAbortRequested = false;
      if (aborted) {
        setState(() {
          _rollbackAiStreamSession();
          _markUnexportedChanges();
        });
        _flushDraftAutoSaveNow();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已停止生成')),
        );
        return;
      }
      setState(() {
        _rollbackAiStreamSession();
        _markUnexportedChanges();
      });
      _flushDraftAutoSaveNow();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('AI 失败: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isAiSending = false;
        });
      }
    }
  }

  Future<void> _sendDirectorAiRequest() async {
    final input = _aiInputController.text.trim();
    if (input.isEmpty) return;
    if (!_aiSettings.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先补全 AI 设置')));
      return;
    }
    if (_editingItemId != null || _isPreviewing || _isAiSending) return;

    _aiStreamAbortRequested = false;
    final mutationGen = _canvasMutationGeneration;
    setState(() {
      _isAiSending = true;
      if (_aiSettings.enableStreaming) {
        _beginAiStreamSession(kind: _AiStreamSessionKind.director);
      }
    });
    if (_aiSettings.enableStreaming) {
      _flushDraftAutoSaveNow();
    }
    try {
      final systemPrompt = _buildAiSystemPrompt(
        mode: ChatMockupAiMode.director,
        scenarioOrUserInput: input,
      );
      final content = await _consumeAiCompletion(
        mutationGen: mutationGen,
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content': '请只输出 XML，不要解释文字、不要 Markdown 代码块。格式： '
                '<chat>'
                '<turn>'
                '<action><![CDATA[]]></action>'
                '<user><![CDATA[]]></user>'
                '<character><![CDATA[]]></character>'
                '</turn>'
                '</chat>'
                ' turn 数量必须为 5~7，每个 turn 都必须包含 action/user/character 三个子元素（CDATA 可为空）。'
                ' user 只能写用户发言，character 只能写角色发言，action 只能写动作/旁白/状态；'
                ' 不得互换 user 与 character 语义，任一方本轮不发言时必须输出空 CDATA。',
          },
        ],
        onStreamingAccumulated:
            _aiSettings.enableStreaming ? _handleAiStreamAccumulated : null,
      );

      if (!mounted || mutationGen != _canvasMutationGeneration) {
        return;
      }
      late final List<ChatMockupItem> pending;
      if (_aiSettings.enableStreaming) {
        final fin = _finalizeStreamingAiContent(
          content,
          _AiStreamSessionKind.director,
        );
        if (!mounted || mutationGen != _canvasMutationGeneration) {
          return;
        }
        if (fin == null) {
          _rollbackStreamingAiParseFailureSnack();
          return;
        }
        pending = fin.items;
        _showStreamingAiFinalizeFeedback(
          decodeKind: fin.decodeKind,
          qualityWarning: fin.qualityWarning,
        );
      } else {
        final resolved = _tryResolveAiItemsNonStreaming(
          content,
          _AiStreamSessionKind.director,
        );
        if (resolved == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('AI 输出无法解析为可用内容')),
            );
          }
          return;
        }
        pending = resolved.items;
        _maybeShowNonStreamingAiResolveNotes(
          resolutionNote: resolved.resolutionNote,
          qualityWarning: resolved.qualityWarning,
        );
      }

      if (!mounted) return;
      _aiInputController.clear();
      if (_aiSettings.enableStreaming) {
        setState(() {
          _replaceStreamingBlockWithItems(pending);
          _markUnexportedChanges();
        });
        _flushDraftAutoSaveNow();
        _setFollowingLatest(true);
        _scrollToLatest(animated: true);
      } else {
        _appendNewItems(pending);
      }
    } catch (error) {
      if (!mounted || mutationGen != _canvasMutationGeneration) {
        _aiStreamAbortRequested = false;
        return;
      }
      final aborted = _aiStreamAbortRequested;
      _aiStreamAbortRequested = false;
      if (aborted) {
        setState(() {
          _rollbackAiStreamSession();
          _markUnexportedChanges();
        });
        _flushDraftAutoSaveNow();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已停止生成')),
        );
        return;
      }
      setState(() {
        _rollbackAiStreamSession();
        _markUnexportedChanges();
      });
      _flushDraftAutoSaveNow();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('AI 失败: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isAiSending = false;
        });
      }
    }
  }

  Future<void> _sendRoleAiRequest() async {
    final input = _aiInputController.text.trim();
    if (input.isEmpty) return;
    if (!_aiSettings.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先补全 AI 设置')));
      return;
    }
    if (_editingItemId != null || _isPreviewing || _isAiSending) return;

    final userLines = _splitAiMessageLines(input);
    if (userLines.isEmpty) return;

    final insertedUserItems = <ChatMockupItem>[
      for (final line in userLines.take(40))
        _createItem(
          type: ChatMockupItemType.message,
          side: ChatMockupItemSide.right,
          text: line,
        ),
    ];

    _aiInputController.clear();
    _appendNewItems(insertedUserItems);

    _aiStreamAbortRequested = false;
    final mutationGen = _canvasMutationGeneration;
    setState(() {
      _isAiSending = true;
      if (_aiSettings.enableStreaming) {
        _beginAiStreamSession(
          kind: _AiStreamSessionKind.role,
          insertAfterItemId: insertedUserItems.last.id,
        );
      }
    });
    if (_aiSettings.enableStreaming) {
      _flushDraftAutoSaveNow();
    }
    try {
      final systemPrompt = _buildAiSystemPrompt(
        mode: ChatMockupAiMode.role,
        scenarioOrUserInput: input,
      );
      final content = await _consumeAiCompletion(
        mutationGen: mutationGen,
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content': '请只输出 XML，不要解释文字、不要 Markdown 代码块。格式： '
                '<chat>'
                '<action><![CDATA[]]></action>'
                '<character><![CDATA[]]></character>'
                '</chat>',
          },
        ],
        onStreamingAccumulated:
            _aiSettings.enableStreaming ? _handleAiStreamAccumulated : null,
      );

      if (!mounted || mutationGen != _canvasMutationGeneration) {
        return;
      }
      late final List<ChatMockupItem> pending;
      if (_aiSettings.enableStreaming) {
        final fin = _finalizeStreamingAiContent(
          content,
          _AiStreamSessionKind.role,
        );
        if (!mounted || mutationGen != _canvasMutationGeneration) {
          return;
        }
        if (fin == null) {
          _rollbackStreamingAiParseFailureSnack();
          return;
        }
        pending = fin.items;
        _showStreamingAiFinalizeFeedback(
          decodeKind: fin.decodeKind,
          qualityWarning: fin.qualityWarning,
        );
      } else {
        final resolved = _tryResolveAiItemsNonStreaming(
          content,
          _AiStreamSessionKind.role,
        );
        if (resolved == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('AI 输出无法解析为可用内容')),
            );
          }
          return;
        }
        pending = resolved.items;
        _maybeShowNonStreamingAiResolveNotes(
          resolutionNote: resolved.resolutionNote,
          qualityWarning: resolved.qualityWarning,
        );
      }

      if (!mounted) return;
      if (_aiSettings.enableStreaming) {
        setState(() {
          _replaceStreamingBlockWithItems(pending);
          _markUnexportedChanges();
        });
        _flushDraftAutoSaveNow();
        _setFollowingLatest(true);
        _scrollToLatest(animated: true);
      } else {
        _appendNewItems(pending);
      }
    } catch (error) {
      if (!mounted || mutationGen != _canvasMutationGeneration) {
        _aiStreamAbortRequested = false;
        return;
      }
      final aborted = _aiStreamAbortRequested;
      _aiStreamAbortRequested = false;
      if (aborted) {
        setState(() {
          _rollbackAiStreamSession();
          _markUnexportedChanges();
        });
        _flushDraftAutoSaveNow();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已停止生成')),
        );
        return;
      }
      setState(() {
        _rollbackAiStreamSession();
        _markUnexportedChanges();
      });
      _flushDraftAutoSaveNow();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('AI 失败: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isAiSending = false;
        });
      }
    }
  }

  Widget _buildAddControls() {
    final isEditing = _editingItemId != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xff161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff2a2a2a)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTypeAddButtons(disabled: isEditing),
          if (_pendingAddType != null) ...[
            const SizedBox(height: 8),
            _buildSidePicker(_pendingAddType!, disabled: isEditing),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeAddButtons({required bool disabled}) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _addTypeButton('消息', ChatMockupItemType.message, disabled: disabled),
        _addTypeButton('表情', ChatMockupItemType.emoji, disabled: disabled),
        _addTypeButton('贴纸', ChatMockupItemType.sticker, disabled: disabled),
        _addTypeButton('图片', ChatMockupItemType.customImage,
            disabled: disabled),
        _addTypeButton('回复选项', ChatMockupItemType.replyOptions,
            disabled: disabled),
        _addTypeButton('动作', ChatMockupItemType.action, disabled: disabled),
        _addTypeButton('委托', ChatMockupItemType.commission, disabled: disabled),
        _buildMusicToolbarButton(disabled: disabled),
      ],
    );
  }

  Widget _buildMusicToolbarButton({required bool disabled}) {
    ChatMockupItem? selected;
    if (_selectedItemIds.length == 1) {
      final id = _selectedItemIds.first;
      for (final it in _items) {
        if (it.id == id) {
          selected = it;
          break;
        }
      }
    }
    final canUse = !disabled &&
        !_isReadOnlyCanvas &&
        !_isPreviewing &&
        selected != null &&
        selected.type == ChatMockupItemType.message;
    return ElevatedButton(
      onPressed: canUse ? _openMusicDirectiveEditor : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xff2a2a2a),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        disabledBackgroundColor: const Color(0xff222222),
        disabledForegroundColor: const Color(0xff666666),
      ),
      child: const Text('音乐', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Future<void> _openMusicDirectiveEditor() async {
    if (_editingItemId != null || _isReadOnlyCanvas || _isPreviewing) return;
    if (_selectedItemIds.length != 1) return;
    final id = _selectedItemIds.first;
    final index = _items.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final item = _items[index];
    if (item.type != ChatMockupItemType.message) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('消息音乐'),
          content: const Text(
            '预览或录像带播放时，当这条消息刚显示出来会应用所选指令。「停止」会结束背景音乐（非暂停）。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                AndroidInputLock.unlock();
                Navigator.of(ctx).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                AndroidInputLock.unlock();
                Navigator.of(ctx).pop();
                setState(() {
                  _items[index] = item.copyWith(music: null);
                  _markUnexportedChanges();
                });
              },
              child: const Text('清除'),
            ),
            TextButton(
              onPressed: () async {
                AndroidInputLock.unlock();
                Navigator.of(ctx).pop();
                await _promptAndApplyMusicPlay(item: item, index: index);
              },
              child: const Text('播放…'),
            ),
            TextButton(
              onPressed: () {
                AndroidInputLock.unlock();
                Navigator.of(ctx).pop();
                setState(() {
                  _items[index] =
                      item.copyWith(music: ChatMockupMusicDirective.stop);
                  _markUnexportedChanges();
                });
              },
              child: const Text('停止'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _promptAndApplyMusicPlay({
    required ChatMockupItem item,
    required int index,
  }) async {
    final existing = item.music;
    final initialKind = existing?.action == ChatMockupMusicAction.play
        ? existing!.kind
        : ChatMockupMusicSourceKind.audioUrl;
    final initial = existing?.action == ChatMockupMusicAction.play
        ? existing!.url ?? ''
        : '';
    final initialLoop =
        existing?.action == ChatMockupMusicAction.play && existing!.loop;
    final controller = TextEditingController(text: initial);
    ChatMockupMusicSourceKind? dialogMusicKind;
    try {
      final result = await showDialog<
          ({
            ChatMockupMusicSourceKind kind,
            String url,
            bool loop,
          })?>(
        context: context,
        builder: (ctx) {
          var loop = initialLoop;
          var kind = initialKind;
          return StatefulBuilder(
            builder: (context, setInner) {
              return AlertDialog(
                title: const Text('消息触发音乐'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<ChatMockupMusicSourceKind>(
                        segments: const [
                          ButtonSegment<ChatMockupMusicSourceKind>(
                            value: ChatMockupMusicSourceKind.audioUrl,
                            label: Text('音频 URL'),
                          ),
                          ButtonSegment<ChatMockupMusicSourceKind>(
                            value: ChatMockupMusicSourceKind.iframe,
                            label: Text('iframe'),
                          ),
                        ],
                        selected: <ChatMockupMusicSourceKind>{kind},
                        onSelectionChanged: (s) {
                          if (s.isEmpty) return;
                          setInner(() => kind = s.first);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        onTap: AndroidInputLock.lock,
                        onTapOutside: (_) {
                          if (AndroidInputLock.isLocked) return;
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                        decoration: InputDecoration(
                          hintText: kind == ChatMockupMusicSourceKind.audioUrl
                              ? 'HTTPS 音频 URL，路径须以支持的扩展名结尾（如 .mp3、.m4a、.ogg 等）'
                              : '可粘贴官方整段 <iframe …>，或只粘贴 https:// 或 // 开头的嵌入 URL（网易云 outchain、B 站 player、YouTube /embed/…）',
                        ),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: loop,
                        onChanged: (v) => setInner(() => loop = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('循环播放'),
                        subtitle: Text(
                          kind == ChatMockupMusicSourceKind.audioUrl
                              ? '开启后单曲循环，直到下一条音乐指令；关闭则播完或切歌为止。'
                              : '支持整段 iframe 或纯 URL；循环是否生效取决于站点（含网易云 outchain），必要时在地址中带 loop/autoplay 等参数。',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      AndroidInputLock.unlock();
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('取消'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      AndroidInputLock.unlock();
                      Navigator.of(ctx).pop((
                        kind: kind,
                        url: controller.text,
                        loop: loop,
                      ));
                    },
                    child: const Text('确定'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (result == null) return;
      dialogMusicKind = result.kind;
      final trimmed = result.url.trim();
      if (trimmed.isEmpty) return;
      final ChatMockupMusicDirective directive;
      switch (result.kind) {
        case ChatMockupMusicSourceKind.audioUrl:
          ChatMockupAudioUrlValidator.assertPlayableUrlShape(trimmed);
          directive =
              ChatMockupMusicDirective.playAudioUrl(trimmed, loop: result.loop);
        case ChatMockupMusicSourceKind.iframe:
          directive =
              ChatMockupMusicDirective.playIframe(trimmed, loop: result.loop);
      }
      if (result.kind == ChatMockupMusicSourceKind.iframe &&
          _isNeteaseOutchainOnWindows(directive.url)) {
        final ok = await _confirmNeteaseOutchainWindowsRisk();
        if (!ok || !mounted) return;
      }
      if (!mounted) return;
      setState(() {
        _items[index] = item.copyWith(music: directive);
        _markUnexportedChanges();
      });
    } catch (e) {
      if (!mounted) return;
      final detail = e is FormatException ? e.message : e.toString();
      final prefix = dialogMusicKind == ChatMockupMusicSourceKind.iframe
          ? 'iframe 输入无效'
          : 'URL 无效';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$prefix：$detail')),
      );
    } finally {
      AndroidInputLock.unlock();
      controller.dispose();
    }
  }

  Widget _buildSidePicker(ChatMockupItemType type, {required bool disabled}) {
    final sides = _allowedSidesForType(type);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (sides.contains(ChatMockupItemSide.left))
          _addSideButton('添加到左侧', type, ChatMockupItemSide.left,
              disabled: disabled),
        if (sides.contains(ChatMockupItemSide.right))
          _addSideButton('添加到右侧', type, ChatMockupItemSide.right,
              disabled: disabled),
        if (sides.contains(ChatMockupItemSide.center))
          _addSideButton('添加到中间', type, ChatMockupItemSide.center,
              disabled: disabled),
        TextButton(
          onPressed:
              disabled ? null : () => setState(() => _pendingAddType = null),
          child: const Text('取消'),
        ),
      ],
    );
  }

  Widget _addTypeButton(String label, ChatMockupItemType type,
      {required bool disabled}) {
    final isPending = _pendingAddType == type;
    final allowedSides = _allowedSidesForType(type);
    final requiresSideSelection = allowedSides.length > 1;
    return ElevatedButton(
      onPressed: disabled
          ? null
          : () {
              if (requiresSideSelection) {
                setState(() => _pendingAddType = type);
                return;
              }
              _addItem(type);
            },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isPending ? const Color(0xff3a3a3a) : const Color(0xff2a2a2a),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _addSideButton(
    String label,
    ChatMockupItemType type,
    ChatMockupItemSide side, {
    required bool disabled,
  }) {
    return OutlinedButton(
      onPressed: disabled
          ? null
          : () {
              _addItem(type, side: side);
              setState(() => _pendingAddType = null);
            },
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xff4a4a4a)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: Text(label),
    );
  }

  Widget _buildItem(ChatMockupItem item, int index) {
    final isSelected = _selectedItemIds.contains(item.id);
    final isEditingThisItem = _editingItemId == item.id;
    final isMultiSelecting = _selectedItemIds.length > 1;
    final shouldShowBatchControls =
        isMultiSelecting && item.id == _primarySelectedItemId;
    final side = _toMessageSide(item.side);
    final avatar = item.side == ChatMockupItemSide.center
        ? null
        : ChatMockupAvatar(
            image: _resolveImageProvider(
                item.avatarSource ?? _defaultAvatarForSide(item.side)),
          );
    final entranceEnabled =
        _isPreviewing || _newlyAddedItemIds.contains(item.id);
    final entranceKey =
        _isPreviewing ? 'preview_$_previewRunId:${item.id}' : 'edit:${item.id}';
    return Column(
      key: ValueKey(item.id),
      children: [
        _ChatMockupItemEntrance(
          enabled: entranceEnabled,
          animationKey: entranceKey,
          onCompleted: () {
            if (!_newlyAddedItemIds.contains(item.id)) return;
            setState(() => _newlyAddedItemIds.remove(item.id));
          },
          child: GestureDetector(
            behavior: isEditingThisItem
                ? HitTestBehavior.deferToChild
                : HitTestBehavior.translucent,
            onTap: isEditingThisItem || _isReadOnlyCanvas
                ? null
                : () => _onItemTap(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? ChatMockupTheme.infoBlue
                      : Colors.transparent,
                  width: 1.4,
                ),
              ),
              child: ChatMockupMessage(
                side: side,
                avatar: avatar,
                margin: EdgeInsets.zero,
                child: _buildItemContent(item),
              ),
            ),
          ),
        ),
        if (!_isReadOnlyCanvas &&
            !isMultiSelecting &&
            (isSelected || isEditingThisItem))
          _buildSelectionControls(item, index),
        if (!_isReadOnlyCanvas && shouldShowBatchControls)
          _buildBatchSelectionControls(item, index),
        const SizedBox(height: 8),
      ],
    );
  }

  CrossAxisAlignment _messageItemCrossAxisAlignment(ChatMockupItem item) {
    return switch (item.side) {
      ChatMockupItemSide.right => CrossAxisAlignment.end,
      ChatMockupItemSide.center => CrossAxisAlignment.center,
      ChatMockupItemSide.left => CrossAxisAlignment.start,
    };
  }

  Widget _buildItemContent(ChatMockupItem item) {
    final isMe = item.side == ChatMockupItemSide.right;
    final isEditingThisItem = _editingItemId == item.id;
    final waitLabel = item.waitMode == ChatMockupWaitMode.manual
        ? '点击继续'
        : item.waitSeconds > 0
            ? '等待 ${item.waitSeconds.toStringAsFixed(1)}s'
            : null;
    late final Widget content;
    switch (item.type) {
      case ChatMockupItemType.message:
        if (isEditingThisItem &&
            _editingField == ChatMockupEditableField.text) {
          content = ChatMockupEditableTextBubble(
            controller: _editingController,
            focusNode: _editingFocusNode,
            isMe: isMe,
            hintText: 'Click here to edit',
            retainKnockEditFocusOnTapOutside: () => isEditingText,
          );
        } else {
          final textBubble = ChatMockupTextBubble(
            text: item.text ?? 'Click here to edit',
            isMe: isMe,
          );
          final rowCross = _messageItemCrossAxisAlignment(item);
          // Keep the embed in the tree while iframe teardown runs, even after
          // `_isPreviewing` is cleared in `_stopPreview` / `_finishPlayback`.
          final showPreviewIframe = (_isPreviewing ||
                  _previewMusicIframeTearingDown) &&
              (_previewMusicIframeActive || _previewMusicIframeTearingDown) &&
              item.id == _previewMusicIframeSourceItemId &&
              item.music?.action == ChatMockupMusicAction.play &&
              item.music?.kind == ChatMockupMusicSourceKind.iframe &&
              (_previewMusicIframeUrl ?? '').trim().isNotEmpty;
          content = showPreviewIframe
              ? Column(
                  crossAxisAlignment: rowCross,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    textBubble,
                    ChatMockupIframeMusicEmbed(
                      url: _previewMusicIframeUrl,
                      active: _previewMusicIframeActive,
                      isMe: isMe,
                      teardownAckToken: _pendingIframeTeardownToken,
                      onMainDocumentLoadFailed:
                          _onPreviewIframeMusicMainDocumentLoadFailed,
                      onTeardownComplete: _onPreviewMusicIframeTeardownComplete,
                    ),
                  ],
                )
              : textBubble;
        }
      case ChatMockupItemType.emoji:
        content = ChatMockupEmojiBubble(emoji: item.emoji ?? '🙂', isMe: isMe);
      case ChatMockupItemType.sticker:
        content = ChatMockupImageBubble(
          image:
              _resolveImageProvider(item.imageSource ?? _defaultStickerSource),
          isMe: isMe,
          width: 88,
          height: 88,
        );
      case ChatMockupItemType.customImage:
        content = ChatMockupImageBubble(
          image: _resolveImageProvider(item.imageSource ?? _defaultCoverSource),
          isMe: isMe,
          frameColor: isMe ? null : Colors.white,
          width: 210,
          height: 132,
        );
      case ChatMockupItemType.action:
        if (isEditingThisItem &&
            _editingField == ChatMockupEditableField.text) {
          content = ChatMockupDividerText(
            child: _buildEditingTextField(
              style: const TextStyle(
                color: Color(0xff5b5b5b),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
              hintText: '-- Click here to edit --',
              textAlign: TextAlign.center,
            ),
          );
        } else {
          content = ChatMockupDividerText(
              text: item.text ?? '-- Click here to edit --');
        }
      case ChatMockupItemType.replyOptions:
        final editingFirst = isEditingThisItem &&
            _editingField == ChatMockupEditableField.firstReply;
        final editingSecond = isEditingThisItem &&
            _editingField == ChatMockupEditableField.secondReply;
        final canStartFieldEdit = _canStartCardFieldEditing(item.id);
        content = ChatMockupReplyCard(
          firstText: item.firstText ?? 'Click here to edit',
          secondText: item.secondText ?? 'Click here to edit',
          firstTextChild: editingFirst
              ? _buildEditingTextField(
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                  hintText: 'Click here to edit',
                  textAlign: TextAlign.center,
                )
              : null,
          secondTextChild: editingSecond
              ? _buildEditingTextField(
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                  hintText: 'Click here to edit',
                  textAlign: TextAlign.center,
                )
              : null,
          onFirstTextTap: editingFirst || !canStartFieldEdit
              ? null
              : () => _startEditing(
                    item.id,
                    ChatMockupEditableField.firstReply,
                    initialValue: item.firstText ?? '',
                  ),
          onSecondTextTap: editingSecond || !canStartFieldEdit
              ? null
              : () => _startEditing(
                    item.id,
                    ChatMockupEditableField.secondReply,
                    initialValue: item.secondText ?? '',
                  ),
        );
      case ChatMockupItemType.commission:
        final editingTitle =
            isEditingThisItem && _editingField == ChatMockupEditableField.title;
        final editingSubtitle = isEditingThisItem &&
            _editingField == ChatMockupEditableField.subtitle;
        final canStartFieldEdit = _canStartCardFieldEditing(item.id);
        content = ChatMockupActionCard(
          icon: Icons.info_outline_rounded,
          iconColor: ChatMockupTheme.infoBlue,
          title: item.title ?? 'Click here to edit',
          actionText: item.subtitle ?? 'Commission',
          titleChild: editingTitle
              ? _buildEditingTextField(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                  hintText: 'Click here to edit',
                  textAlign: TextAlign.left,
                )
              : null,
          onTitleTap: editingTitle || !canStartFieldEdit
              ? null
              : () => _startEditing(
                    item.id,
                    ChatMockupEditableField.title,
                    initialValue: item.title ?? '',
                  ),
          actionTextChild: editingSubtitle
              ? _buildEditingTextField(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                  hintText: 'Commission',
                  textAlign: TextAlign.center,
                )
              : null,
          onActionTextTap: editingSubtitle || !canStartFieldEdit
              ? null
              : () => _startEditing(
                    item.id,
                    ChatMockupEditableField.subtitle,
                    initialValue: item.subtitle ?? '',
                  ),
        );
    }

    if (waitLabel == null) {
      return content;
    }
    return Column(
      crossAxisAlignment: item.type == ChatMockupItemType.message
          ? _messageItemCrossAxisAlignment(item)
          : CrossAxisAlignment.start,
      children: [
        content,
        _buildWaitHint(waitLabel),
      ],
    );
  }

  Future<void> _triggerSingleItemAction(String itemId) async {
    if (_editingItemId != null || _isPreviewing) return;
    final index = _items.indexWhere((element) => element.id == itemId);
    if (index < 0) return;
    final item = _items[index];
    setState(() {
      _selectedItemIds
        ..clear()
        ..add(item.id);
      _primarySelectedItemId = item.id;
    });
    if (item.type == ChatMockupItemType.replyOptions ||
        item.type == ChatMockupItemType.commission) {
      await _showCardFieldEditorPicker(item);
      return;
    }
    await _handleItemTap(item);
  }

  bool _canStartCardFieldEditing(String itemId) {
    return _editingItemId == itemId && _selectedItemIds.length == 1;
  }

  Future<void> _showCardFieldEditorPicker(ChatMockupItem item) async {
    final field = await showModalBottomSheet<ChatMockupEditableField>(
      context: context,
      backgroundColor: const Color(0xff161616),
      builder: (ctx) {
        final options = switch (item.type) {
          ChatMockupItemType.replyOptions =>
            <MapEntry<String, ChatMockupEditableField>>[
              const MapEntry('编辑第一个回复', ChatMockupEditableField.firstReply),
              const MapEntry('编辑第二个回复', ChatMockupEditableField.secondReply),
            ],
          ChatMockupItemType.commission =>
            <MapEntry<String, ChatMockupEditableField>>[
              const MapEntry('编辑标题', ChatMockupEditableField.title),
              const MapEntry('编辑副标题', ChatMockupEditableField.subtitle),
            ],
          _ => const <MapEntry<String, ChatMockupEditableField>>[],
        };
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map(
                  (entry) => ListTile(
                    title: Text(entry.key,
                        style: const TextStyle(color: Colors.white)),
                    onTap: () => Navigator.pop(ctx, entry.value),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
    if (field == null) return;
    switch (field) {
      case ChatMockupEditableField.chatTitle:
        return;
      case ChatMockupEditableField.firstReply:
        _startEditing(item.id, field, initialValue: item.firstText ?? '');
        return;
      case ChatMockupEditableField.secondReply:
        _startEditing(item.id, field, initialValue: item.secondText ?? '');
        return;
      case ChatMockupEditableField.title:
        _startEditing(item.id, field, initialValue: item.title ?? '');
        return;
      case ChatMockupEditableField.subtitle:
        _startEditing(item.id, field, initialValue: item.subtitle ?? '');
        return;
      case ChatMockupEditableField.text:
        _startEditing(item.id, field, initialValue: item.text ?? '');
        return;
    }
  }

  Widget _buildWaitHint(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _handleItemTap(ChatMockupItem item) async {
    if (_selectedItemIds.length != 1) return;
    if (_editingItemId != null &&
        (_editingItemId != item.id ||
            _editingField != ChatMockupEditableField.text)) {
      return;
    }
    switch (item.type) {
      case ChatMockupItemType.message:
      case ChatMockupItemType.action:
        _startEditing(item.id, ChatMockupEditableField.text,
            initialValue: item.text ?? '');
        return;
      case ChatMockupItemType.emoji:
        await _showEmojiPicker(item);
        return;
      case ChatMockupItemType.sticker:
        await _showStickerPicker(item.id);
        return;
      case ChatMockupItemType.customImage:
        await _setCustomImageByUrl(item.id);
        return;
      case ChatMockupItemType.replyOptions:
      case ChatMockupItemType.commission:
        return;
    }
  }

  Future<void> _setCustomImageByUrl(String itemId) async {
    if (_editingItemId != null) return;
    final index = _items.indexWhere((element) => element.id == itemId);
    if (index < 0) return;
    final current = _items[index].imageSource;
    final initialUrl = current?.type == ChatMockupImageSourceType.network
        ? current?.value
        : '';
    final source = await _promptForNetworkImageSource(
      title: '使用图片 URL',
      initialUrl: initialUrl,
    );
    if (!mounted) return;
    if (source == null) return;
    setState(() {
      _items[index] = _items[index].copyWith(imageSource: source, image: null);
      _markUnexportedChanges();
    });
  }

  Future<ChatMockupImageSource?> _promptForNetworkImageSource({
    required String title,
    String? initialUrl,
  }) async {
    final controller = TextEditingController(text: initialUrl ?? '');
    try {
      final url = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              onTap: AndroidInputLock.lock,
              onTapOutside: (_) {
                if (AndroidInputLock.isLocked) return;
                FocusManager.instance.primaryFocus?.unfocus();
              },
              decoration: const InputDecoration(
                hintText: '请输入图片 URL（https://...）',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  AndroidInputLock.unlock();
                  Navigator.of(ctx).pop();
                },
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  AndroidInputLock.unlock();
                  Navigator.of(ctx).pop(controller.text);
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
      final trimmed = (url ?? '').trim();
      if (trimmed.isEmpty) return null;
      return ChatMockupImageSource.network(trimmed);
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('URL 无效: $e')));
      return null;
    } finally {
      AndroidInputLock.unlock();
      controller.dispose();
    }
  }

  void _startEditing(
    String itemId,
    ChatMockupEditableField field, {
    required String initialValue,
    bool shouldSelectItem = true,
  }) {
    final isEditingSameField =
        _editingItemId == itemId && _editingField == field;
    if (isEditingSameField) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _editingFocusNode.requestFocus();
      });
      return;
    }
    if (_editingItemId != null &&
        (_editingItemId != itemId || _editingField != field)) {
      return;
    }
    _editingController.text = initialValue;
    setState(() {
      _editingItemId = itemId;
      _editingField = field;
      if (shouldSelectItem) {
        _selectedItemIds
          ..clear()
          ..add(itemId);
        _primarySelectedItemId = itemId;
      }
    });
    AndroidInputLock.lock();
    _notifyEditingChangedIfNeeded();
    final end = _editingController.text.length;
    _editingController.selection = TextSelection.collapsed(offset: end);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _editingFocusNode.requestFocus();
    });
  }

  void _commitEditing() {
    if (_isCommittingEditing) return;
    final itemId = _editingItemId;
    final field = _editingField;
    if (itemId == null || field == null) return;
    _isCommittingEditing = true;
    try {
      if (field == ChatMockupEditableField.chatTitle &&
          itemId == _chatTitleEditingId) {
        final input = _editingController.text.trim();
        setState(() {
          _chatTitle = input;
          _editingItemId = null;
          _editingField = null;
          _markUnexportedChanges();
        });
        _notifyEditingChangedIfNeeded();
        return;
      }
      final index = _items.indexWhere((element) => element.id == itemId);
      final input = _editingController.text.trim();
      final updated = index >= 0 ? _items[index] : null;
      if (index >= 0 && updated != null) {
        final nextItem = switch (field) {
          ChatMockupEditableField.chatTitle => updated,
          ChatMockupEditableField.text =>
            updated.copyWith(text: input.isEmpty ? null : input),
          ChatMockupEditableField.title =>
            updated.copyWith(title: input.isEmpty ? null : input),
          ChatMockupEditableField.subtitle =>
            updated.copyWith(subtitle: input.isEmpty ? null : input),
          ChatMockupEditableField.firstReply =>
            updated.copyWith(firstText: input.isEmpty ? null : input),
          ChatMockupEditableField.secondReply =>
            updated.copyWith(secondText: input.isEmpty ? null : input),
        };
        setState(() {
          _items[index] = nextItem;
          _editingItemId = null;
          _editingField = null;
          _markUnexportedChanges();
        });
        _notifyEditingChangedIfNeeded();
      } else {
        setState(() {
          _editingItemId = null;
          _editingField = null;
        });
        _notifyEditingChangedIfNeeded();
      }
    } finally {
      AndroidInputLock.unlock();
      _editingFocusNode.unfocus();
      _isCommittingEditing = false;
    }
  }

  Widget _buildEditingTextField({
    required TextStyle style,
    required String hintText,
    required TextAlign textAlign,
    Color cursorColor = const Color(0xff111111),
  }) {
    final hintColor = style.color?.withValues(alpha: 0.55);
    return ValueListenableBuilder<bool>(
      valueListenable: AndroidInputLock.lockedListenable,
      builder: (context, locked, _) {
        final requireConfirm = AndroidInputLock.requiresExplicitConfirm &&
            locked &&
            isEditingText &&
            _editingFocusNode.hasFocus;
        return TextField(
          controller: _editingController,
          focusNode: _editingFocusNode,
          textAlign: textAlign,
          style: style,
          cursorColor: cursorColor,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: hintText,
            hintStyle:
                hintColor == null ? null : style.copyWith(color: hintColor),
            contentPadding: EdgeInsets.zero,
            suffixIcon: requireConfirm
                ? IconButton(
                    tooltip: '确认',
                    icon: const Icon(Icons.check_rounded, size: 18),
                    onPressed: _commitEditing,
                  )
                : null,
          ),
          onTap: AndroidInputLock.lock,
          onEditingComplete: () {
            if (!isEditingText) return;
            if (requireConfirm) return;
            _editingFocusNode.requestFocus();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (!isEditingText) return;
              if (_editingFocusNode.canRequestFocus) {
                _editingFocusNode.requestFocus();
              }
            });
          },
          onTapOutside: (event) {
            if (isEditingText || AndroidInputLock.isLocked) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (!isEditingText) return;
                if (_editingFocusNode.canRequestFocus) {
                  _editingFocusNode.requestFocus();
                }
              });
            } else {
              _editingFocusNode.unfocus();
            }
          },
        );
      },
    );
  }

  Future<void> _showEmojiPicker(ChatMockupItem item) async {
    if (_editingItemId != null) return;
    const emojis = <String>[
      '🙂',
      '😂',
      '😭',
      '😍',
      '😎',
      '😡',
      '🤔',
      '👍',
      '👎',
      '❤️',
      '🔥',
      '🎉'
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xff161616),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: emojis.map((emoji) {
                  return SizedBox(
                    width: 48,
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, emoji),
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    final index = _items.indexWhere((element) => element.id == item.id);
    if (index < 0) return;
    setState(() {
      _items[index] = _items[index].copyWith(emoji: selected);
      _markUnexportedChanges();
    });
  }

  Future<List<ChatMockupImageSource>> _loadSystemStickerSources() async {
    final cached = _cachedStickerSources;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    const zzzWebpPath = _stickerPath;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final stickerPngPaths = manifest
          .listAssets()
          .where(
            (k) =>
                k.startsWith('assets/images/ZZZ-2.1-flat/') &&
                k.toLowerCase().endsWith('.png'),
          )
          .toList()
        ..sort();
      final orderedPaths = <String>[zzzWebpPath];
      for (final path in stickerPngPaths) {
        if (path == zzzWebpPath) continue;
        orderedPaths.add(path);
      }
      final sources = orderedPaths
          .map((path) => ChatMockupImageSource(
              type: ChatMockupImageSourceType.asset, value: path))
          .toList();
      _cachedStickerSources = sources;
      return sources;
    } catch (_) {
      const fallback = [_defaultStickerSource];
      _cachedStickerSources = fallback;
      return fallback;
    }
  }

  Future<void> _showStickerPicker(String itemId) async {
    if (_editingItemId != null) return;
    final loadFuture = _loadSystemStickerSources();
    final gridController = ScrollController();
    int visibleStart = 1;
    int visibleEnd = 1;
    final selected = await showModalBottomSheet<ChatMockupImageSource>(
      context: context,
      backgroundColor: const Color(0xff161616),
      builder: (ctx) {
        final height = MediaQuery.of(ctx).size.height * 0.65;
        return Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: height,
            child: FutureBuilder<List<ChatMockupImageSource>>(
              future: loadFuture,
              builder: (ctx, snapshot) {
                final stickers = snapshot.data ?? const [_defaultStickerSource];
                unawaited(_precacheStickerThumbs(stickers));
                return StatefulBuilder(
                  builder: (context, setSheetState) {
                    void updateRange() {
                      const crossAxisCount = 4;
                      final maxWidth = MediaQuery.of(ctx).size.width - 24;
                      const totalSpacing = 8.0 * (crossAxisCount - 1);
                      final tileExtent =
                          (maxWidth - totalSpacing) / crossAxisCount;
                      final rowExtent = tileExtent + 8.0;
                      final scrollOffset = gridController.hasClients
                          ? gridController.offset
                          : 0.0;
                      final viewport = gridController.hasClients
                          ? gridController.position.viewportDimension
                          : height;
                      final firstRow = (scrollOffset / rowExtent).floor();
                      final viewportRows =
                          math.max(1, (viewport / rowExtent).ceil());
                      final start = firstRow * crossAxisCount + 1;
                      final end = (firstRow + viewportRows) * crossAxisCount;
                      final normalizedStart = math.min(
                        stickers.length,
                        math.max(1, start),
                      );
                      final normalizedEnd = math.min(
                        stickers.length,
                        math.max(normalizedStart, end),
                      );
                      setSheetState(() {
                        visibleStart = normalizedStart;
                        visibleEnd = normalizedEnd;
                      });
                    }

                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => updateRange());

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '选择贴纸',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$visibleStart-$visibleEnd / ${stickers.length}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              updateRange();
                              return false;
                            },
                            child: GridView.builder(
                              controller: gridController,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                              itemCount: stickers.length,
                              itemBuilder: (ctx, index) {
                                final sticker = stickers[index];
                                return TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(ctx, sticker),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image(
                                      image: _resolveImageProvider(
                                        sticker,
                                        cacheWidth: 160,
                                        cacheHeight: 160,
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              if (!gridController.hasClients) return;
                              gridController.animateTo(
                                0,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                              );
                            },
                            icon: const Icon(Icons.vertical_align_top_rounded),
                            label: const Text('回到顶部'),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
    gridController.dispose();
    if (selected == null || !mounted) return;
    final index = _items.indexWhere((element) => element.id == itemId);
    if (index < 0) return;
    setState(() {
      _items[index] =
          _items[index].copyWith(imageSource: selected, image: null);
      _markUnexportedChanges();
    });
  }

  Widget _buildPlacementSlider({
    required _ChatMockupMessagePlacement placement,
    required ValueChanged<double>? onChanged,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Slider(
          max: 2,
          divisions: 2,
          value: _sliderValueByPlacement[placement]!,
          onChanged: onChanged,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '左 消息左',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
              Expanded(
                child: Text(
                  '中 动作',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
              Expanded(
                child: Text(
                  '右 消息右',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        if (hintText != null) ...[
          const SizedBox(height: 6),
          Text(
            hintText,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectionControls(ChatMockupItem item, int index) {
    final canOperate = !isEditingText;
    final enabled = _items.length > 1 && canOperate;
    final isAiContinueTarget = item.type == ChatMockupItemType.message ||
        item.type == ChatMockupItemType.action;
    final canContinue = canOperate &&
        _isDraftLoaded &&
        !_isPreviewing &&
        !_isAiSending &&
        _isAiInitialized &&
        _aiSettings.isConfigured &&
        !(_isBrowseMode && !_isPlaybackComplete) &&
        isAiContinueTarget;
    final canRewind = canOperate &&
        _isDraftLoaded &&
        !_isPreviewing &&
        !_isAiSending &&
        !_plannerAiInFlight &&
        !(_isBrowseMode && !_isPlaybackComplete) &&
        index < _items.length - 1;
    final isEditingThisItem = _editingItemId == item.id;
    final placement = _placementForItem(item);
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xff181818),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _buildDragHandle(index, enabled: enabled),
              const SizedBox(width: 6),
              IconButton(
                onPressed: canOperate ? () => _showItemSettings(item.id) : null,
                icon: const Icon(Icons.settings_rounded, color: Colors.white70),
              ),
              if (isAiContinueTarget)
                IconButton(
                  onPressed: canContinue
                      ? () => _continueFromSelectedItem(item.id)
                      : null,
                  tooltip: 'AI 续写',
                  icon: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white70),
                ),
              IconButton(
                onPressed: canRewind
                    ? () => _requestRewindToSelectedItem(item.id)
                    : null,
                tooltip: '回溯到此（删除下方全部）',
                icon: const Icon(Icons.restart_alt_rounded,
                    color: Colors.white70),
              ),
              IconButton(
                onPressed:
                    canOperate ? () => _triggerSingleItemAction(item.id) : null,
                icon: const Icon(Icons.edit_rounded, color: Colors.white70),
              ),
              IconButton(
                onPressed: canOperate ? () => _removeItem(item.id) : null,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white70),
              ),
              if (isEditingThisItem)
                IconButton(
                  onPressed: _commitEditing,
                  icon: const Icon(Icons.check_rounded, color: Colors.white),
                ),
            ],
          ),
          if (placement != null) ...[
            const SizedBox(height: 2),
            _buildPlacementSlider(
              placement: placement,
              onChanged: canOperate
                  ? (value) {
                      final nextPlacement = _placementFromSliderValue(value);
                      if (nextPlacement == null) return;
                      _applyMessagePlacement(nextPlacement, <String>{item.id});
                    }
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBatchSelectionControls(ChatMockupItem item, int index) {
    final canOperate = !isEditingText;
    final enabled = _items.length > 1 && canOperate;
    final convertibleIds = _selectedConvertibleIds();
    final currentSelectionId = _primaryOrFirstConvertibleSelection();
    _ChatMockupMessagePlacement? placement;
    if (currentSelectionId != null) {
      final itemIndex =
          _items.indexWhere((element) => element.id == currentSelectionId);
      if (itemIndex >= 0) {
        placement = _placementForItem(_items[itemIndex]);
      }
    }
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xff181818),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _buildDragHandle(index, enabled: enabled),
              const SizedBox(width: 6),
              IconButton(
                onPressed: canOperate ? () => _showItemSettings(item.id) : null,
                icon: const Icon(Icons.settings_rounded, color: Colors.white70),
              ),
              IconButton(
                onPressed: canOperate ? () => _removeItem(item.id) : null,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white70),
              ),
            ],
          ),
          if (convertibleIds.isNotEmpty && placement != null) ...[
            const SizedBox(height: 2),
            _buildPlacementSlider(
              placement: placement,
              onChanged: canOperate
                  ? (value) {
                      final nextPlacement = _placementFromSliderValue(value);
                      if (nextPlacement == null) return;
                      _applyMessagePlacement(nextPlacement, convertibleIds);
                    }
                  : null,
              hintText: '仅作用于已选文字消息/动作',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDragHandle(int index, {required bool enabled}) {
    final handle = Semantics(
      button: true,
      label: '按住拖动排序',
      child: Opacity(
        opacity: enabled ? 1.0 : 0.38,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xff2a2a2a),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child:
              const Icon(Icons.drag_indicator_rounded, color: Colors.white70),
        ),
      ),
    );
    final decorated = MouseRegion(
      cursor: enabled ? SystemMouseCursors.grab : SystemMouseCursors.basic,
      child: enabled ? Tooltip(message: '按住拖动排序', child: handle) : handle,
    );
    return ReorderableDragStartListener(
        index: index, enabled: enabled, child: decorated);
  }

  ChatMockupItem _createItem({
    required ChatMockupItemType type,
    required ChatMockupItemSide side,
    String? text,
    String? emoji,
    ImageProvider? image,
    ChatMockupImageSource? imageSource,
    ChatMockupImageSource? avatarSource,
    ChatMockupWaitMode waitMode = ChatMockupWaitMode.auto,
    double waitSeconds = 0,
  }) {
    return ChatMockupItem(
      id: 'item_${_nextId++}',
      type: type,
      side: side,
      text: text,
      emoji: emoji,
      image: image,
      imageSource: imageSource,
      avatarSource: avatarSource,
      waitMode: waitMode,
      waitSeconds: waitSeconds,
    );
  }

  ChatMockupItemSide _defaultSideForType(ChatMockupItemType type) {
    switch (type) {
      case ChatMockupItemType.action:
        return ChatMockupItemSide.center;
      case ChatMockupItemType.replyOptions:
      case ChatMockupItemType.commission:
        return ChatMockupItemSide.right;
      case ChatMockupItemType.message:
      case ChatMockupItemType.emoji:
      case ChatMockupItemType.sticker:
      case ChatMockupItemType.customImage:
        return ChatMockupItemSide.left;
    }
  }

  Set<ChatMockupItemSide> _allowedSidesForType(ChatMockupItemType type) {
    switch (type) {
      case ChatMockupItemType.message:
      case ChatMockupItemType.emoji:
      case ChatMockupItemType.sticker:
      case ChatMockupItemType.customImage:
        return {ChatMockupItemSide.left, ChatMockupItemSide.right};
      case ChatMockupItemType.replyOptions:
      case ChatMockupItemType.commission:
        return {ChatMockupItemSide.right};
      case ChatMockupItemType.action:
        return {ChatMockupItemSide.center};
    }
  }

  bool _isPlacementConvertible(ChatMockupItem item) {
    return _placementForItem(item) != null;
  }

  _ChatMockupMessagePlacement? _placementForItem(ChatMockupItem item) {
    if (item.type == ChatMockupItemType.message &&
        item.side == ChatMockupItemSide.left) {
      return _ChatMockupMessagePlacement.left;
    }
    if (item.type == ChatMockupItemType.action &&
        item.side == ChatMockupItemSide.center) {
      return _ChatMockupMessagePlacement.action;
    }
    if (item.type == ChatMockupItemType.message &&
        item.side == ChatMockupItemSide.right) {
      return _ChatMockupMessagePlacement.right;
    }
    return null;
  }

  ChatMockupItem _copyItemWithPlacement(
    ChatMockupItem item,
    _ChatMockupMessagePlacement placement,
  ) {
    switch (placement) {
      case _ChatMockupMessagePlacement.left:
        return item.copyWith(
          type: ChatMockupItemType.message,
          side: ChatMockupItemSide.left,
        );
      case _ChatMockupMessagePlacement.action:
        return item.copyWith(
          type: ChatMockupItemType.action,
          side: ChatMockupItemSide.center,
        );
      case _ChatMockupMessagePlacement.right:
        return item.copyWith(
          type: ChatMockupItemType.message,
          side: ChatMockupItemSide.right,
        );
    }
  }

  Set<String> _selectedConvertibleIds() {
    final ids = <String>{};
    for (final selectedId in _selectedItemIds) {
      final index = _items.indexWhere((element) => element.id == selectedId);
      if (index < 0) continue;
      if (_isPlacementConvertible(_items[index])) {
        ids.add(selectedId);
      }
    }
    return ids;
  }

  String? _primaryOrFirstConvertibleSelection() {
    final primaryId = _primarySelectedItemId;
    if (primaryId != null) {
      final primaryIndex =
          _items.indexWhere((element) => element.id == primaryId);
      if (primaryIndex >= 0 && _isPlacementConvertible(_items[primaryIndex])) {
        return primaryId;
      }
    }
    for (final selectedId in _selectedItemIds) {
      final index = _items.indexWhere((element) => element.id == selectedId);
      if (index < 0) continue;
      if (_isPlacementConvertible(_items[index])) {
        return selectedId;
      }
    }
    return null;
  }

  void _applyMessagePlacement(
    _ChatMockupMessagePlacement placement,
    Set<String> targetIds,
  ) {
    if (targetIds.isEmpty) return;
    final updates = <int, ChatMockupItem>{};
    for (var index = 0; index < _items.length; index++) {
      final oldItem = _items[index];
      if (!targetIds.contains(oldItem.id) ||
          !_isPlacementConvertible(oldItem)) {
        continue;
      }
      final nextItem = _copyItemWithPlacement(oldItem, placement);
      final changedPlacement =
          oldItem.type != nextItem.type || oldItem.side != nextItem.side;
      if (!changedPlacement) continue;
      updates[index] = nextItem;
    }
    if (updates.isEmpty) return;
    setState(() {
      updates.forEach((index, item) => _items[index] = item);
      _markUnexportedChanges();
    });
  }

  _ChatMockupMessagePlacement? _placementFromSliderValue(double value) {
    final snapped = value.round().clamp(0, 2);
    return _placementBySliderValue[snapped];
  }

  /// Index for [List.insert] when adding via toolbar/side buttons: after the
  /// bottom-most selected row in [_items], or the list end when nothing is selected.
  int _resolveManualInsertIndex() {
    if (_selectedItemIds.isEmpty) {
      return _items.length;
    }
    var maxIndex = -1;
    for (var i = 0; i < _items.length; i++) {
      if (_selectedItemIds.contains(_items[i].id) && i > maxIndex) {
        maxIndex = i;
      }
    }
    if (maxIndex < 0) {
      return _items.length;
    }
    return maxIndex + 1;
  }

  void _addItem(ChatMockupItemType type, {ChatMockupItemSide? side}) {
    if (_editingItemId != null || _isReadOnlyCanvas) return;
    final allowed = _allowedSidesForType(type);
    final chosenSide = side ?? _defaultSideForType(type);
    if (!allowed.contains(chosenSide)) return;
    final item = _createItem(type: type, side: chosenSide);
    final insertAt = _resolveManualInsertIndex();
    final insertedAtTail = insertAt == _items.length;
    setState(() {
      _items.insert(insertAt, item);
      _newlyAddedItemIds.add(item.id);
      _selectedItemIds
        ..clear()
        ..add(item.id);
      _primarySelectedItemId = item.id;
      _pendingAddType = null;
      _visibleItemCount = _items.length;
      _markUnexportedChanges();
    });
    if (insertedAtTail) {
      _scrollToLatestIfFollowing();
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (_isReadOnlyCanvas) return;
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    final dragged = _items[oldIndex];
    final selectedDragged = _selectedItemIds.contains(dragged.id);
    if (!selectedDragged || _selectedItemIds.length <= 1) {
      var adjustedIndex = newIndex;
      if (oldIndex < adjustedIndex) adjustedIndex -= 1;
      adjustedIndex = adjustedIndex.clamp(0, _items.length - 1);
      if (oldIndex == adjustedIndex) return;
      setState(() {
        final item = _items.removeAt(oldIndex);
        _items.insert(adjustedIndex, item);
        _markUnexportedChanges();
      });
      return;
    }
    final selectedIndexes = <int>[];
    for (var i = 0; i < _items.length; i++) {
      if (_selectedItemIds.contains(_items[i].id)) selectedIndexes.add(i);
    }
    if (selectedIndexes.length <= 1) return;
    setState(() {
      final selectedItems = selectedIndexes.map((i) => _items[i]).toList();
      var insertIndex = newIndex;
      for (final i in selectedIndexes) {
        if (i < newIndex) {
          insertIndex -= 1;
        }
      }
      _items.removeWhere((element) => _selectedItemIds.contains(element.id));
      insertIndex = insertIndex.clamp(0, _items.length);
      _items.insertAll(insertIndex, selectedItems);
      _primarySelectedItemId = dragged.id;
      _markUnexportedChanges();
    });
  }

  void _removeItem(String id) {
    if (_isReadOnlyCanvas) return;
    final targets =
        _selectedItemIds.contains(id) ? _selectedItemIds.toSet() : <String>{id};
    setState(() {
      _items.removeWhere((item) => targets.contains(item.id));
      _newlyAddedItemIds.removeWhere(targets.contains);
      _selectedItemIds.removeWhere(targets.contains);
      if (_primarySelectedItemId != null &&
          targets.contains(_primarySelectedItemId)) {
        _primarySelectedItemId = null;
      }
      if (_editingItemId != null && targets.contains(_editingItemId)) {
        _editingItemId = null;
        _editingField = null;
      }
      _visibleItemCount = _items.length;
      _markUnexportedChanges();
    });
    _notifyEditingChangedIfNeeded();
  }

  Future<void> _requestRewindToSelectedItem(String itemId) async {
    if (_isReadOnlyCanvas) return;
    if (_selectedItemIds.length != 1 || !_selectedItemIds.contains(itemId)) {
      return;
    }
    if (!_isDraftLoaded ||
        _isPreviewing ||
        _isAiSending ||
        _plannerAiInFlight ||
        (_isBrowseMode && !_isPlaybackComplete) ||
        isEditingText) {
      return;
    }
    final selectedIndex = _items.indexWhere((e) => e.id == itemId);
    if (selectedIndex < 0 || selectedIndex >= _items.length - 1) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('回溯到此处'),
          content: const Text(
            '将保留当前选中的这一条，并删除其下方的全部内容（含消息、动作、表情、贴纸、选项、委托等）。'
            '此操作会影响后续预览、AI 续写与草稿保存；剧情构思对话也会被清空。是否继续？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('回溯'),
            ),
          ],
        );
      },
    );
    if (!mounted || confirmed != true) return;

    _canvasMutationGeneration++;

    final trimmed =
        List<ChatMockupItem>.from(_items.sublist(0, selectedIndex + 1));
    final keptIds = trimmed.map((e) => e.id).toSet();
    var revalidated =
        revalidateStoryPlanner(items: trimmed, planner: _storyPlanner);
    final hadPlannerChat = revalidated.chat.isNotEmpty;
    revalidated = revalidated.copyWith(
      chat: <PlannerChatTurn>[],
      outlineDirty: revalidated.outlineDirty || hadPlannerChat,
    );

    setState(() {
      _items
        ..clear()
        ..addAll(trimmed);
      _storyPlanner = revalidated;
      _selectedItemIds
        ..clear()
        ..add(itemId);
      _primarySelectedItemId = itemId;
      if (_editingItemId != null && !keptIds.contains(_editingItemId)) {
        _editingItemId = null;
        _editingField = null;
      }
      _newlyAddedItemIds.removeWhere((id) => !keptIds.contains(id));
      _visibleItemCount = _items.length;
      _isWaitingManual = false;
      _markUnexportedChanges();
    });
    _notifyEditingChangedIfNeeded();
    _flushDraftAutoSaveNow();
  }

  void _onItemTap(ChatMockupItem item) {
    if (_isPreviewing || _editingItemId != null || _isReadOnlyCanvas) return;
    setState(() {
      if (_selectedItemIds.contains(item.id)) {
        _selectedItemIds.remove(item.id);
        if (_primarySelectedItemId == item.id) {
          _primarySelectedItemId =
              _selectedItemIds.isEmpty ? null : _selectedItemIds.last;
        }
      } else {
        _selectedItemIds.add(item.id);
        _primarySelectedItemId = item.id;
      }
    });
  }

  List<ChatMockupItem> _visibleItems() {
    if (!_isPreviewing) return _items;
    final safeCount = _visibleItemCount.clamp(0, _items.length);
    return _items.take(safeCount).toList();
  }

  void _applyMusicForRevealAtIndex(int index) {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    if (item.type != ChatMockupItemType.message) return;
    final music = item.music;
    if (music == null) return;
    final iframeSourceItemId = music.action == ChatMockupMusicAction.play &&
            music.kind == ChatMockupMusicSourceKind.iframe &&
            (music.url ?? '').isNotEmpty
        ? item.id
        : null;
    _enqueueMusicDirective(
      music,
      iframeSourceItemId: iframeSourceItemId,
    );
  }

  Future<void> _ensurePreviewAudioSession() async {
    if (_previewAudioSessionConfigured) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _previewAudioSessionConfigured = true;
    } catch (e) {
      debugPrint('AudioSession configure failed: $e');
    }
  }

  Future<AudioPlayer> _ensurePreviewMusicPlayerWithSubscriptions() async {
    await _ensurePreviewAudioSession();
    if (_previewMusicPlayer != null) return _previewMusicPlayer!;
    final p = AudioPlayer();
    _previewMusicPlayer = p;
    _musicProcessingSub = p.processingStateStream.listen((state) {
      if (kDebugMode) {
        debugPrint('chat_mockup preview music processing: $state');
      }
    });
    _musicPlayerStateSub = p.playerStateStream.listen((playerState) {
      if (kDebugMode &&
          playerState.processingState == ProcessingState.completed &&
          !playerState.playing) {
        debugPrint('chat_mockup preview music playback completed');
      }
    });
    return p;
  }

  bool _isWindowsDesktopRuntime() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  bool _isNeteaseOutchainOnWindows(String? url) {
    if (url == null || url.isEmpty) return false;
    final normalized = normalizeChatMockupMusicIframeInput(url);
    return _isWindowsDesktopRuntime() &&
        isNeteaseOutchainMusicIframeEmbedUrl(normalized);
  }

  Future<bool> _confirmNeteaseOutchainWindowsRisk() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('可能存在播放风险'),
          content: const Text(kChatMockupNeteaseOutchainWindowsRiskMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('继续保存'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  /// Unified post-restore warning surface for [_ChatMockupRestoreOutcome].
  /// Defers to next frame so启动期 / 构建期入口 (browse 初始载入、草稿恢复) 也安全。
  void _maybeShowRestoreOutcomeWarnings(_ChatMockupRestoreOutcome outcome) {
    if (outcome.neteaseOutchainOnWindowsCount <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(kChatMockupNeteaseOutchainWindowsRiskShortLabel),
        ),
      );
    });
  }

  void _invalidateMusicPlaybackSession() {
    _neteaseOutchainWindowsWarningShownThisSession = false;
    _musicSessionId++;
    if (mounted) {
      _beginPreviewMusicIframeTeardownIfNeeded();
    }
    _musicQueueTail =
        _musicQueueTail.catchError((_) {}).then((_) => _silencePreviewMusic());
  }

  void _enqueueMusicDirective(
    ChatMockupMusicDirective music, {
    String? iframeSourceItemId,
  }) {
    final opId = _musicSessionId;
    _musicQueueTail = _musicQueueTail.catchError((_) {}).then(
          (_) => _runMusicDirectiveSerial(
            opId,
            music,
            iframeSourceItemId: iframeSourceItemId,
          ),
        );
  }

  void _onPreviewIframeMusicMainDocumentLoadFailed(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('iframe 音乐加载失败：$message')),
    );
  }

  void _onPreviewMusicIframeTeardownComplete(int token) {
    if (token == 0 || token != _pendingIframeTeardownToken) {
      logger.d(
        'chat_mockup_canvas iframe teardownComplete stale token=$token '
        'pending=$_pendingIframeTeardownToken session=$_musicSessionId',
      );
      return;
    }
    logger.d(
      'chat_mockup_canvas iframe teardownComplete token=$token '
      'source=$_previewMusicIframeSourceItemId session=$_musicSessionId',
    );
    final c = _previewMusicIframeTeardownCompleter;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
    _previewMusicIframeTeardownCompleter = null;
    _pendingIframeTeardownToken = 0;
    if (!mounted) {
      logger.d(
        'chat_mockup_canvas iframe teardownComplete skip setState unmounted '
        'session=$_musicSessionId',
      );
      return;
    }
    setState(() {
      _previewMusicIframeUrl = null;
      _previewMusicIframeSourceItemId = null;
      _previewMusicIframeTearingDown = false;
      _previewMusicIframeActive = false;
    });
  }

  /// Starts iframe teardown (inactive + completer) if a URL is loaded and no cycle is in flight.
  /// Returns whether this call began a new teardown cycle.
  bool _beginPreviewMusicIframeTeardownIfNeeded() {
    if (!mounted) return false;
    final url = (_previewMusicIframeUrl ?? '').trim();
    if (url.isEmpty || _previewMusicIframeTeardownCompleter != null) {
      return false;
    }
    _iframeTeardownSeq++;
    _pendingIframeTeardownToken = _iframeTeardownSeq;
    logger.d(
      'chat_mockup_canvas iframe teardown begin '
      'token=$_pendingIframeTeardownToken '
      'source=$_previewMusicIframeSourceItemId session=$_musicSessionId',
    );
    final completer = Completer<void>();
    _previewMusicIframeTeardownCompleter = completer;
    setState(() {
      _previewMusicIframeActive = false;
      _previewMusicIframeTearingDown = true;
    });
    return true;
  }

  void _forcePreviewMusicIframeTeardownClear() {
    logger.d(
      'chat_mockup_canvas iframe teardown force clear '
      'source=$_previewMusicIframeSourceItemId session=$_musicSessionId',
    );
    _pendingIframeTeardownToken = 0;
    final c = _previewMusicIframeTeardownCompleter;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
    _previewMusicIframeTeardownCompleter = null;
    if (!mounted) return;
    setState(() {
      _previewMusicIframeUrl = null;
      _previewMusicIframeSourceItemId = null;
      _previewMusicIframeTearingDown = false;
      _previewMusicIframeActive = false;
    });
  }

  Future<void> _awaitPreviewMusicIframeTeardown() async {
    if (_previewMusicIframeTeardownCompleter != null) {
      logger.d(
        'chat_mockup_canvas iframe teardown await in-flight '
        'session=$_musicSessionId',
      );
      try {
        await _previewMusicIframeTeardownCompleter!.future.timeout(
          _previewIframeTeardownTimeout,
          onTimeout: _forcePreviewMusicIframeTeardownClear,
        );
      } catch (_) {}
      return;
    }

    if (!_beginPreviewMusicIframeTeardownIfNeeded()) {
      return;
    }

    try {
      await _previewMusicIframeTeardownCompleter!.future.timeout(
        _previewIframeTeardownTimeout,
        onTimeout: _forcePreviewMusicIframeTeardownClear,
      );
    } catch (_) {}
  }

  Future<void> _runMusicDirectiveSerial(
    int opId,
    ChatMockupMusicDirective music, {
    String? iframeSourceItemId,
  }) async {
    if (!mounted || opId != _musicSessionId) return;
    try {
      if (music.action == ChatMockupMusicAction.play) {
        final url = music.url;
        if (url == null || url.isEmpty) return;
        if (music.kind == ChatMockupMusicSourceKind.iframe) {
          logger.d(
            'chat_mockup_canvas music directive iframe play '
            'session=$opId source=$iframeSourceItemId url=$url',
          );
          try {
            await _previewMusicPlayer?.stop();
          } catch (_) {}
          if (!mounted || opId != _musicSessionId) return;
          final prevSource = _previewMusicIframeSourceItemId;
          final prevUrl = (_previewMusicIframeUrl ?? '').trim();
          final switchingEmbedHost =
              prevUrl.isNotEmpty && iframeSourceItemId != prevSource;
          if (switchingEmbedHost) {
            logger.d(
              'chat_mockup_canvas iframe play switching host; await teardown '
              'session=$opId prev=$prevSource next=$iframeSourceItemId',
            );
            await _awaitPreviewMusicIframeTeardown();
            if (!mounted || opId != _musicSessionId) return;
          }
          setState(() {
            _previewMusicIframeUrl = url;
            _previewMusicIframeActive = true;
            _previewMusicIframeSourceItemId = iframeSourceItemId;
            _previewMusicIframeTearingDown = false;
          });
          logger.d(
            'chat_mockup_canvas music directive iframe play applied '
            'session=$opId source=$iframeSourceItemId',
          );
          if (!mounted || opId != _musicSessionId) return;
          if (!_neteaseOutchainWindowsWarningShownThisSession &&
              _isNeteaseOutchainOnWindows(url)) {
            _neteaseOutchainWindowsWarningShownThisSession = true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(kChatMockupNeteaseOutchainWindowsRiskShortLabel),
              ),
            );
          }
        } else {
          logger.d(
            'chat_mockup_canvas music directive non-iframe; await iframe teardown '
            'session=$opId',
          );
          await _awaitPreviewMusicIframeTeardown();
          if (!mounted || opId != _musicSessionId) return;
          final player = await _ensurePreviewMusicPlayerWithSubscriptions();
          if (!mounted || opId != _musicSessionId) return;
          await player.stop();
          if (!mounted || opId != _musicSessionId) return;
          final handle = _resourceCache.audioPlaybackHandle(url);
          if (handle == null || handle.isEmpty) {
            if (!mounted || opId != _musicSessionId) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('音乐资源未准备，请先完成预览前的资源下载。')),
            );
            return;
          }
          if (kIsWeb) {
            await player.setUrl(handle);
          } else {
            await player.setFilePath(handle);
          }
          if (!mounted || opId != _musicSessionId) return;
          await player.setLoopMode(
            music.loop ? LoopMode.all : LoopMode.off,
          );
          if (!mounted || opId != _musicSessionId) return;
          await player.play();
        }
      } else {
        await _silencePreviewMusic();
      }
    } catch (e, st) {
      debugPrint('preview music failed: $e\n$st');
      if (!mounted || opId != _musicSessionId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('音乐播放失败: $e')),
      );
    }
  }

  Future<void> _silencePreviewMusic() async {
    logger.d(
      'chat_mockup_canvas silencePreviewMusic session=$_musicSessionId',
    );
    await _awaitPreviewMusicIframeTeardown();
    try {
      await _previewMusicPlayer?.stop();
    } catch (_) {}
  }

  Future<void> _disposePreviewMusicPlayer() async {
    await _musicProcessingSub?.cancel();
    await _musicPlayerStateSub?.cancel();
    _musicProcessingSub = null;
    _musicPlayerStateSub = null;
    final player = _previewMusicPlayer;
    _previewMusicPlayer = null;
    if (player == null) return;
    try {
      await player.stop();
      await player.dispose();
    } catch (_) {}
  }

  void _startPreview() {
    if (_items.isEmpty) return;
    _playbackTimer?.cancel();
    _invalidateMusicPlaybackSession();
    setState(() {
      _previewRunId += 1;
      _isPreviewing = true;
      _visibleItemCount = 1;
      _isWaitingManual = false;
      _isPlaybackComplete = false;
    });
    _setFollowingLatest(true);
    _scrollToLatest(animated: false);
    _applyMusicForRevealAtIndex(0);
    _queueNextPreviewStep();
  }

  void _resumePreviewFromVisibleCount() {
    if (_items.isEmpty) return;
    final normalized = normalizeBrowsePlaybackState(
      visibleItemCount: _visibleItemCount,
      itemLength: _items.length,
      playbackComplete: _isPlaybackComplete,
    );
    if (normalized.playbackComplete) {
      setState(() {
        _visibleItemCount = _items.length;
        _isPlaybackComplete = true;
        _isPreviewing = false;
        _isWaitingManual = false;
        if (widget.lockAiMode) {
          _aiMode = ChatMockupAiMode.role;
        }
      });
      _setFollowingLatest(true);
      _scrollToLatest(animated: false);
      return;
    }
    final count = normalized.visibleItemCount;
    _playbackTimer?.cancel();
    _invalidateMusicPlaybackSession();
    setState(() {
      _previewRunId += 1;
      _isPreviewing = true;
      _visibleItemCount = count;
      _isWaitingManual = false;
      _isPlaybackComplete = false;
    });
    _setFollowingLatest(true);
    for (var i = 0; i < count; i++) {
      _applyMusicForRevealAtIndex(i);
    }
    _scrollToLatest(animated: false);
    _queueNextPreviewStep();
  }

  /// Stops browse-mode audio/teardown without expanding visible items (unlike [_stopPreview]).
  Future<void> shutdownBrowsePlaybackForRouteExit() async {
    _playbackTimer?.cancel();
    _invalidateMusicPlaybackSession();
    await _awaitPreviewMusicIframeTeardown();
    await _silencePreviewMusic();
    await _disposePreviewMusicPlayer();
  }

  void _stopPreview() {
    _invalidateMusicPlaybackSession();
    _playbackTimer?.cancel();
    setState(() {
      _isPreviewing = false;
      _visibleItemCount = _items.length;
      _isWaitingManual = false;
      _isPlaybackComplete = true;
    });
    _scrollToLatestIfFollowing();
  }

  void _continuePreviewManually() {
    if (!_isPreviewing || !_isWaitingManual) return;
    setState(() {
      _isWaitingManual = false;
      _visibleItemCount += 1;
    });
    _applyMusicForRevealAtIndex(_visibleItemCount - 1);
    _scrollToLatestIfFollowing();
    _queueNextPreviewStep();
  }

  void _queueNextPreviewStep() {
    _playbackTimer?.cancel();
    if (!_isPreviewing) return;
    if (_visibleItemCount >= _items.length) {
      _finishPlayback();
      return;
    }
    final current = _items[_visibleItemCount - 1];
    if (current.waitMode == ChatMockupWaitMode.manual && !_isBrowseMode) {
      setState(() => _isWaitingManual = true);
      return;
    }
    final waitSeconds = current.waitMode == ChatMockupWaitMode.manual
        ? 0.8
        : current.waitSeconds;
    final milliseconds = (waitSeconds * 1000).round();
    _playbackTimer = Timer(Duration(milliseconds: milliseconds), () {
      if (!mounted || !_isPreviewing) return;
      final nextCount = _visibleItemCount + 1;
      setState(() => _visibleItemCount = nextCount);
      _applyMusicForRevealAtIndex(nextCount - 1);
      _scrollToLatestIfFollowing();
      if (nextCount >= _items.length) {
        _finishPlayback();
        return;
      }
      _queueNextPreviewStep();
    });
  }

  void _finishPlayback() {
    if (!mounted) return;
    _invalidateMusicPlaybackSession();
    setState(() {
      _isPreviewing = false;
      _isWaitingManual = false;
      _visibleItemCount = _items.length;
      _isPlaybackComplete = true;
      if (widget.lockAiMode) {
        _aiMode = ChatMockupAiMode.role;
      }
    });
    widget.onPlaybackCompleted?.call();
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= _bottomFollowTolerance;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    final isUserDriven = (notification is ScrollUpdateNotification &&
            notification.dragDetails != null) ||
        (notification is OverscrollNotification &&
            notification.dragDetails != null) ||
        notification is UserScrollNotification;

    final isNearBottom = _isNearBottom();
    if (isNearBottom) {
      _setFollowingLatest(true);
      return false;
    }

    if (isUserDriven) {
      _followLatestScrollToken += 1;
      _setFollowingLatest(false);
    }
    return false;
  }

  void _setFollowingLatest(bool value) {
    final shouldShowButton = !value;
    if (_isFollowingLatest == value &&
        _showJumpToLatestButton == shouldShowButton) {
      return;
    }
    setState(() {
      _isFollowingLatest = value;
      _showJumpToLatestButton = shouldShowButton;
    });
  }

  void _scrollToLatestIfFollowing() {
    if (!_isFollowingLatest) return;
    _scrollToLatest(animated: true);
  }

  void _scrollToLatest({required bool animated}) {
    _followLatestScrollToken += 1;
    final token = _followLatestScrollToken;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || token != _followLatestScrollToken) return;
      if (!_scrollController.hasClients) return;

      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        await _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }

      if (!mounted || token != _followLatestScrollToken) return;
      if (!_isNearBottom()) return;
      _setFollowingLatest(true);
    });
  }

  Widget _buildJumpToLatestButton() {
    return FloatingActionButton.small(
      heroTag: 'chat_mockup_jump_to_latest',
      tooltip: '向下',
      onPressed: () {
        _setFollowingLatest(true);
        _scrollToLatest(animated: true);
      },
      child: const Icon(Icons.keyboard_arrow_down),
    );
  }

  ChatMockupImageSource _defaultAvatarForSide(ChatMockupItemSide side) {
    switch (side) {
      case ChatMockupItemSide.left:
        return _leftAvatarSource;
      case ChatMockupItemSide.right:
        return _rightAvatarSource;
      case ChatMockupItemSide.center:
        return _leftAvatarSource;
    }
  }

  Future<void> _precacheStickerThumbs(
    List<ChatMockupImageSource> stickers, {
    int start = 0,
    int count = 24,
  }) async {
    if (!mounted || stickers.isEmpty) return;
    final end = math.min(stickers.length, start + count);
    for (var i = start; i < end; i++) {
      await precacheImage(
        _resolveImageProvider(
          stickers[i],
          cacheWidth: 160,
          cacheHeight: 160,
        ),
        context,
      );
    }
  }

  ImageProvider _resolveImageProvider(
    ChatMockupImageSource source, {
    int? cacheWidth,
    int? cacheHeight,
  }) {
    final base = switch (source.type) {
      ChatMockupImageSourceType.asset => AssetImage(source.value),
      ChatMockupImageSourceType.network =>
        _resourceCache.tryCachedImageProvider(source.value) ??
            NetworkImage(source.value),
    };
    return ResizeImage.resizeIfNeeded(
      cacheWidth,
      cacheHeight,
      base,
    );
  }

  void _invalidateResourceCacheSession() {
    _resourcePrefetchSession++;
    _resourceCache.bumpGeneration();
    _resourceCache.clear();
    _resourcePrefetchRunning = false;
    _resourcePrefetchDone = 0;
    _resourcePrefetchTotal = 0;
  }

  Future<ChatMockupPrefetchResult?> _prepareResourcesForPlayback() async {
    final capturedSession = _resourcePrefetchSession;
    final urls = ChatMockupResourcePrefetcher.collectNetworkUrls(_items);
    if (urls.isEmpty) {
      return const ChatMockupPrefetchResult(
        total: 0,
        readyCount: 0,
        failedUrls: [],
      );
    }
    if (!mounted || capturedSession != _resourcePrefetchSession) return null;
    _resourcePrefetchRunning = true;
    _resourcePrefetchDone = 0;
    _resourcePrefetchTotal = urls.length;
    setState(() {});
    try {
      final gen = _resourceCache.generation;
      final result = await _resourceCache.prefetchUrls(
        urls,
        gen: gen,
        onProgress: (done, total) {
          if (!mounted || capturedSession != _resourcePrefetchSession) return;
          setState(() {
            _resourcePrefetchDone = done;
            _resourcePrefetchTotal = total;
          });
        },
      );
      if (!mounted || capturedSession != _resourcePrefetchSession) return null;
      return result;
    } finally {
      if (capturedSession == _resourcePrefetchSession) {
        _resourcePrefetchRunning = false;
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _showPrefetchFailureDialog(
    List<String> failedUrls, {
    Map<String, String> failureDetails = const {},
  }) async {
    if (!mounted) return;
    final show = failedUrls.length > 8
        ? failedUrls.take(8).toList()
        : List<String>.from(failedUrls);
    final buf = StringBuffer();
    for (final u in show) {
      buf.writeln(u);
      final d = failureDetails[u];
      if (d != null && d.isNotEmpty) {
        buf.writeln(d);
      }
      buf.writeln();
    }
    if (failedUrls.length > 8) {
      buf.writeln('…共 ${failedUrls.length} 条');
    }
    final preview = buf.toString().trimRight();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('资源下载失败'),
        content: SingleChildScrollView(
          child: SelectableText(
            '下列资源无法下载到本地，已阻止自动预览。含具体错误信息便于排查（如代理 502、连接超时、写入失败等）：\n\n$preview',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _startPreviewAfterPrefetch() async {
    if (_items.isEmpty) return;
    if (_resourcePrefetchRunning) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在准备资源…')),
        );
      }
      return;
    }
    final result = await _prepareResourcesForPlayback();
    if (!mounted) return;
    if (result == null) return;
    if (!result.allSucceeded) {
      await _showPrefetchFailureDialog(
        result.failedUrls,
        failureDetails: result.failureDetails,
      );
      return;
    }
    _startPreview();
  }

  Widget _buildResourcePrefetchBanner() {
    final t = _resourcePrefetchTotal;
    final d = _resourcePrefetchDone;
    final v = t > 0 ? d / t : null;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: v),
          const SizedBox(height: 4),
          Text(
            t > 0 ? '正在准备资源 ($d / $t)' : '正在准备资源…',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Iterable<String> _resolveScopeIds(_ChatMockupSettingTargetScope scope) {
    switch (scope) {
      case _ChatMockupSettingTargetScope.selected:
      case _ChatMockupSettingTargetScope.selectedMultiple:
        return _selectedItemIds;
      case _ChatMockupSettingTargetScope.allLeft:
        return _items
            .where((item) => item.side == ChatMockupItemSide.left)
            .map((item) => item.id);
      case _ChatMockupSettingTargetScope.allRight:
        return _items
            .where((item) => item.side == ChatMockupItemSide.right)
            .map((item) => item.id);
    }
  }

  void _applyAvatarSource(
      ChatMockupImageSource source, _ChatMockupSettingTargetScope scope) {
    final ids = _resolveScopeIds(scope).toSet();
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        final item = _items[i];
        if (!ids.contains(item.id) || item.side == ChatMockupItemSide.center) {
          continue;
        }
        _items[i] = item.copyWith(avatarSource: source);
      }
      _markUnexportedChanges();
    });
  }

  void _applyWaitSetting(
    ChatMockupWaitMode mode,
    double seconds,
    _ChatMockupSettingTargetScope scope,
  ) {
    final ids = _resolveScopeIds(scope).toSet();
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        if (!ids.contains(_items[i].id)) {
          continue;
        }
        _items[i] = _items[i].copyWith(
          waitMode: mode,
          waitSeconds: mode == ChatMockupWaitMode.auto ? seconds : 0,
        );
      }
      _markUnexportedChanges();
    });
  }

  Future<void> _showItemSettings(String itemId) async {
    if (_selectedItemIds.isEmpty) {
      setState(() {
        _selectedItemIds.add(itemId);
        _primarySelectedItemId = itemId;
      });
    }
    final baseId = _primarySelectedItemId ?? itemId;
    final baseIndex = _items.indexWhere((element) => element.id == baseId);
    final baseItem = baseIndex >= 0 ? _items[baseIndex] : null;
    final selectedCount = _selectedItemIds.length;
    ChatMockupWaitMode mode = baseItem?.waitMode ?? ChatMockupWaitMode.auto;
    double seconds = baseItem?.waitSeconds ?? 1.0;
    if (seconds <= 0) {
      seconds = 1.0;
    }
    _ChatMockupSettingTargetScope scope = selectedCount <= 1
        ? _ChatMockupSettingTargetScope.selected
        : _ChatMockupSettingTargetScope.selectedMultiple;
    final scopeItems = <DropdownMenuItem<_ChatMockupSettingTargetScope>>[
      if (selectedCount <= 1)
        const DropdownMenuItem(
          value: _ChatMockupSettingTargetScope.selected,
          child: Text('当前选中项'),
        ),
      if (selectedCount > 1)
        DropdownMenuItem(
          value: _ChatMockupSettingTargetScope.selectedMultiple,
          child: Text('已选中的 $selectedCount 项'),
        ),
      const DropdownMenuItem(
        value: _ChatMockupSettingTargetScope.allLeft,
        child: Text('全部左侧'),
      ),
      const DropdownMenuItem(
        value: _ChatMockupSettingTargetScope.allRight,
        child: Text('全部右侧'),
      ),
    ];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff161616),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  12, 12, 12, 12 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '设置',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<_ChatMockupSettingTargetScope>(
                    value: scope,
                    dropdownColor: const Color(0xff262626),
                    items: scopeItems,
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => scope = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          final source = await _pickStickerSource();
                          if (source == null || !mounted) return;
                          _applyAvatarSource(source, scope);
                        },
                        child: const Text('使用贴纸作为头像'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final source = await _promptForNetworkImageSource(
                            title: '使用头像 URL',
                          );
                          if (source == null || !mounted) return;
                          _applyAvatarSource(source, scope);
                        },
                        child: const Text('使用头像 URL'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('自动等待'),
                        selected: mode == ChatMockupWaitMode.auto,
                        onSelected: (_) =>
                            setSheetState(() => mode = ChatMockupWaitMode.auto),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('手动点击显示下一个'),
                        selected: mode == ChatMockupWaitMode.manual,
                        onSelected: (_) => setSheetState(
                            () => mode = ChatMockupWaitMode.manual),
                      ),
                    ],
                  ),
                  if (mode == ChatMockupWaitMode.auto) ...[
                    const SizedBox(height: 10),
                    Slider(
                      max: 10,
                      divisions: 100,
                      value: seconds,
                      label: seconds.toStringAsFixed(1),
                      onChanged: (value) =>
                          setSheetState(() => seconds = value),
                    ),
                    Text(
                      '等待 ${seconds.toStringAsFixed(1)}s',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => _applyWaitSetting(
                      mode,
                      mode == ChatMockupWaitMode.auto ? seconds : 0,
                      scope,
                    ),
                    child: const Text('应用等待设置'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<ChatMockupImageSource?> _pickStickerSource() async {
    final stickers = await _loadSystemStickerSources();
    if (!mounted) return null;
    await _precacheStickerThumbs(stickers);
    if (!mounted) return null;
    final gridController = ScrollController();
    int visibleStart = 1;
    int visibleEnd = 1;
    return showModalBottomSheet<ChatMockupImageSource>(
      context: context,
      backgroundColor: const Color(0xff161616),
      builder: (ctx) {
        final height = MediaQuery.of(ctx).size.height * 0.65;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void updateRange() {
              const crossAxisCount = 4;
              final maxWidth = MediaQuery.of(ctx).size.width - 24;
              const totalSpacing = 8.0 * (crossAxisCount - 1);
              final tileExtent = (maxWidth - totalSpacing) / crossAxisCount;
              final rowExtent = tileExtent + 8.0;
              final scrollOffset =
                  gridController.hasClients ? gridController.offset : 0.0;
              final viewport = gridController.hasClients
                  ? gridController.position.viewportDimension
                  : height;
              final firstRow = (scrollOffset / rowExtent).floor();
              final viewportRows = math.max(1, (viewport / rowExtent).ceil());
              final start = firstRow * crossAxisCount + 1;
              final end = (firstRow + viewportRows) * crossAxisCount;
              final normalizedStart = math.min(
                stickers.length,
                math.max(1, start),
              );
              final normalizedEnd = math.min(
                stickers.length,
                math.max(normalizedStart, end),
              );
              setSheetState(() {
                visibleStart = normalizedStart;
                visibleEnd = normalizedEnd;
              });
            }

            WidgetsBinding.instance.addPostFrameCallback((_) => updateRange());

            return Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: height,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$visibleStart-$visibleEnd / ${stickers.length}',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          updateRange();
                          return false;
                        },
                        child: GridView.builder(
                          controller: gridController,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: stickers.length,
                          itemBuilder: (ctx, index) {
                            final source = stickers[index];
                            return InkWell(
                              onTap: () => Navigator.pop(ctx, source),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image(
                                  image: _resolveImageProvider(
                                    source,
                                    cacheWidth: 160,
                                    cacheHeight: 160,
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          if (!gridController.hasClients) return;
                          gridController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        icon: const Icon(Icons.vertical_align_top_rounded),
                        label: const Text('回到顶部'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => gridController.dispose());
  }

  Future<bool> _exportTextFile({
    required String content,
    required String fileName,
    required String mimeType,
    required List<XTypeGroup> acceptedTypeGroups,
    required String successMessage,
    required String cancelledMessage,
  }) async {
    try {
      final shouldUseShareSheet = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      if (shouldUseShareSheet) {
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                utf8.encode(content),
                mimeType: mimeType,
                name: fileName,
              ),
            ],
            text: fileName,
          ),
        );
        if (!mounted) return false;
        if (result.status == ShareResultStatus.success) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(successMessage)));
          return true;
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(cancelledMessage)));
        return false;
      }

      final location = await getSaveLocation(
        acceptedTypeGroups: acceptedTypeGroups,
        suggestedName: fileName,
        confirmButtonText: '导出',
      );
      if (location == null) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(cancelledMessage)));
        return false;
      }
      final file = XFile.fromData(
        utf8.encode(content),
        mimeType: mimeType,
        name: fileName,
      );
      await file.saveTo(location.path);
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出失败: $error')));
      return false;
    }
  }

  bool _isCleanExportPlaceholder(String? raw) {
    final s = raw?.trim() ?? '';
    if (s.isEmpty) return true;
    return s == _cleanExportHintMessage ||
        s == _cleanExportHintAction ||
        s == _cleanExportHintChatTitle;
  }

  String? _networkImageUrlForCleanExport(ChatMockupImageSource? source) {
    if (source == null) return null;
    if (source.type != ChatMockupImageSourceType.network) return null;
    final v = source.value.trim();
    return v.isEmpty ? null : v;
  }

  String _buildCleanExportText() {
    final sections = <String>[];
    final title = _chatTitle.trim();
    if (title.isNotEmpty && !_isCleanExportPlaceholder(title)) {
      sections.add(title);
    }
    for (final item in _items) {
      final block = <String>[];
      switch (item.type) {
        case ChatMockupItemType.message:
          final text = (item.text ?? '').trim();
          if (_isCleanExportPlaceholder(text)) break;
          final prefix = item.side == ChatMockupItemSide.left
              ? '角色'
              : item.side == ChatMockupItemSide.right
                  ? '用户'
                  : '消息';
          block.add('$prefix：$text');
        case ChatMockupItemType.action:
          final text = (item.text ?? '').trim();
          if (_isCleanExportPlaceholder(text)) break;
          block.add('【动作】$text');
        case ChatMockupItemType.replyOptions:
          final a = (item.firstText ?? '').trim();
          final b = (item.secondText ?? '').trim();
          if (!_isCleanExportPlaceholder(a)) block.add(a);
          if (!_isCleanExportPlaceholder(b)) block.add(b);
        case ChatMockupItemType.commission:
          final t = (item.title ?? '').trim();
          final st = (item.subtitle ?? '').trim();
          if (!_isCleanExportPlaceholder(t)) block.add('标题：$t');
          if (!_isCleanExportPlaceholder(st)) block.add('副标题：$st');
        case ChatMockupItemType.emoji:
          final e = (item.emoji ?? '').trim();
          if (e.isEmpty) break;
          block.add(e);
        case ChatMockupItemType.sticker:
        case ChatMockupItemType.customImage:
          final url = _networkImageUrlForCleanExport(item.imageSource);
          if (url != null) block.add(url);
      }
      if (block.isNotEmpty) {
        sections.add(block.join('\n'));
      }
    }
    return sections.join('\n\n');
  }

  /// Plain-text export for transcription; does not clear [hasUnexportedChanges].
  Future<bool> exportCleanText() async {
    if (!_isDraftLoaded) {
      return false;
    }
    final body = _buildCleanExportText();
    return _exportTextFile(
      content: body.isEmpty ? '' : '$body\n',
      fileName: 'chat_mockup.txt',
      mimeType: 'text/plain',
      acceptedTypeGroups: const [_txtTypeGroup],
      successMessage: '已导出纯文本',
      cancelledMessage: '已取消纯文本导出',
    );
  }

  Future<bool> exportJson() async {
    if (!_isDraftLoaded) {
      return false;
    }
    if (mounted) {
      _revalidatePlannerForPersistIfNeeded();
    }
    final payload = _buildJsonPayload(includeDraftMetadata: false);
    final jsonText = _encodeJsonPayload(payload);
    final exported = await _exportTextFile(
      content: jsonText,
      fileName: 'chat_mockup.json',
      mimeType: 'application/json',
      acceptedTypeGroups: const [_jsonTypeGroup],
      successMessage: '已导出 JSON',
      cancelledMessage: '已取消导出',
    );
    if (!exported) return false;
    if (!mounted) return false;
    setState(() {
      _lastExportedSnapshot =
          _encodeJsonPayload(_buildJsonPayload(includeDraftMetadata: false));
      _hasUnexportedChanges = false;
    });
    return true;
  }

  Future<void> importJson() async {
    try {
      final file = await openFile(
          acceptedTypeGroups: const [_jsonTypeGroup], confirmButtonText: '导入');
      if (file == null) return;
      final decoded = await _decodeJsonFileAsMap(file);
      final restoreOutcome =
          await _restoreFromJsonPayload(decoded, preserveDraftMetadata: false);
      if (!mounted) return;
      setState(() {
        _lastExportedSnapshot =
            _encodeJsonPayload(_buildJsonPayload(includeDraftMetadata: false));
        _hasUnexportedChanges = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('导入成功')));
      _maybeShowRestoreOutcomeWarnings(restoreOutcome);
    } catch (error) {
      if (!mounted) return;
      final message = _mapImportErrorMessage(error);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Map<String, dynamic> _itemToJson(ChatMockupItem item) {
    return {
      'id': item.id,
      'type': item.type.name,
      'side': item.side.name,
      'text': item.text,
      'emoji': item.emoji,
      'image': item.imageSource?.toJson(),
      'avatar': item.avatarSource?.toJson(),
      'title': item.title,
      'subtitle': item.subtitle,
      'firstText': item.firstText,
      'secondText': item.secondText,
      'wait': {'mode': item.waitMode.name, 'seconds': item.waitSeconds},
      if (item.music != null) 'music': item.music!.toJson(),
    };
  }

  void _markUnexportedChanges() {
    _hasUnexportedChanges = hasUnexportedChanges;
    _scheduleDraftAutoSave();
  }

  void _scheduleDraftAutoSave() {
    if (!mounted ||
        !_isDraftLoaded ||
        _isBrowseMode ||
        hasPendingInvalidDraft) {
      return;
    }
    _hasPendingDraftAutoSave = true;
    _draftAutoSaveTimer?.cancel();
    _draftAutoSaveTimer = Timer(_draftAutoSaveDelay, () {
      unawaited(_flushDraftAutoSave());
    });
  }

  void _flushDraftAutoSaveNow() {
    _draftAutoSaveTimer?.cancel();
    unawaited(_flushDraftAutoSave());
  }

  Future<void> _flushDraftAutoSave() async {
    if (!mounted ||
        !_isDraftLoaded ||
        _isBrowseMode ||
        hasPendingInvalidDraft) {
      return;
    }
    if (_isSavingDraftCache) {
      _hasPendingDraftAutoSave = true;
      _scheduleDraftAutoSave();
      return;
    }
    if (!_hasPendingDraftAutoSave) {
      return;
    }

    _hasPendingDraftAutoSave = false;
    try {
      await _writeDraftCache(
        ignorePendingInvalid: false,
        clearInvalidOnSuccess: false,
      );
    } finally {
      if (_hasPendingDraftAutoSave) {
        _scheduleDraftAutoSave();
      }
    }
  }

  /// Serializes canvas state. [storyPlanner] in JSON is always a **revalidated** view of
  /// current items; it does **not** update [_storyPlanner] — use [_revalidatePlannerForPersistIfNeeded] first when persisting.
  Map<String, dynamic> _buildJsonPayload({
    required bool includeDraftMetadata,
    bool includeStoryPlanner = true,
  }) {
    final payload = <String, dynamic>{
      'version': 1,
      'chatTitle': _chatTitle,
      'items': _items.map(_itemToJson).toList(),
    };
    if (includeStoryPlanner) {
      payload['storyPlanner'] = revalidateStoryPlanner(
        items: _items,
        planner: _storyPlanner,
      ).toJson();
    }
    if (includeDraftMetadata) {
      payload['lastExportedSnapshot'] = _lastExportedSnapshot;
      payload['hasUnexportedChanges'] = _hasUnexportedChanges;
    }
    return payload;
  }

  String _encodeJsonPayload(Map<String, dynamic> payload) {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String _decodeJsonTextBytes(List<int> bytes) {
    final view = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final utf8Bytes = view.length >= 3 &&
            view[0] == 0xEF &&
            view[1] == 0xBB &&
            view[2] == 0xBF
        ? view.sublist(3)
        : view;
    try {
      return utf8.decode(utf8Bytes);
    } on FormatException {
      throw const FormatException(_importErrEncoding);
    }
  }

  Future<Map<String, dynamic>> _decodeJsonFileAsMap(XFile file) async {
    final text = _decodeJsonTextBytes(await file.readAsBytes());
    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException(_importErrJsonSyntax);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(_importErrRootNotObject);
    }
    return decoded;
  }

  String _mapImportErrorMessage(Object error) {
    final raw = error.toString();
    if (raw.contains(_importErrEncoding)) {
      return '导入失败：文件编码错误，请使用 UTF-8 编码';
    }
    if (raw.contains(_importErrRootNotObject)) {
      return '导入失败：JSON 根节点必须是对象';
    }
    if (raw.contains(_importErrJsonSyntax)) {
      return '导入失败：JSON 格式不合法';
    }
    if (error is FormatException && _isMusicImportFormatException(error)) {
      return '导入失败：背景音乐（music）字段不合法，请检查 kind（须为字符串）、url、action 等是否与最新保存格式一致';
    }
    if (_isBusinessFieldError(raw)) {
      return '导入失败：业务字段不合法';
    }
    return '导入失败: $raw';
  }

  /// [FormatException] messages from [ChatMockupMusicDirective.fromJson] and
  /// related music parsing (import / restore).
  bool _isMusicImportFormatException(FormatException e) {
    final m = e.message;
    return m.contains('Music kind must be a string') ||
        m.contains('Unknown music kind') ||
        m.contains('Invalid music directive') ||
        m.contains('Unsupported music action') ||
        m.contains('music.play requires');
  }

  bool _isBusinessFieldError(String raw) {
    return raw.contains('不支持的预设版本') ||
        raw.contains('重复 id') ||
        raw.contains('类型错误') ||
        raw.contains('不能为空') ||
        raw.contains('不存在于') ||
        raw.contains('Invalid item entry') ||
        raw.contains('Unsupported') ||
        raw.contains('Missing') ||
        raw.contains('mismatch');
  }

  String _currentExportSnapshot() {
    return _encodeJsonPayload(_buildJsonPayload(includeDraftMetadata: false));
  }

  Future<void> _initializeDraft() async {
    if (_isBrowseMode) {
      _ChatMockupRestoreOutcome? browseRestoreOutcome;
      try {
        final payload = widget.initialPayload;
        if (payload != null) {
          final chatMockup = payload['chatMockup'];
          if (chatMockup is Map<String, dynamic>) {
            browseRestoreOutcome = await _restoreFromJsonPayload(
              chatMockup,
              preserveDraftMetadata: false,
            );
          } else {
            final defaults = _initialItems();
            setState(() {
              _items
                ..clear()
                ..addAll(defaults);
              _chatTitle = '';
              _storyPlanner = ChatMockupStoryPlanner.empty();
              _nextId = _computeNextId(defaults);
              _visibleItemCount = defaults.length;
            });
          }
          _seedVideoAiPromptsFromPayload(payload);
          if (_browsePayloadIncludesAi) {
            _aiSettings = _aiSettings.copyWith(
              rolePrompt: _videoRolePrompt ?? '',
              userPrompt: _videoUserPrompt ?? '',
            );
          }
        } else {
          final defaults = _initialItems();
          setState(() {
            _items
              ..clear()
              ..addAll(defaults);
            _chatTitle = '';
            _storyPlanner = ChatMockupStoryPlanner.empty();
            _nextId = _computeNextId(defaults);
            _visibleItemCount = defaults.length;
          });
        }
        if (!mounted) return;
        final playbackState = widget.initialPlaybackState;
        setState(() {
          _isDraftLoaded = true;
          _loadError = null;
          if (widget.lockAiMode) {
            _aiMode = ChatMockupAiMode.role;
          }
          if (playbackState != null) {
            final normalized = normalizeBrowsePlaybackState(
              visibleItemCount: playbackState.visibleItemCount,
              itemLength: _items.length,
              playbackComplete: playbackState.playbackComplete,
            );
            if (normalized.playbackComplete) {
              _visibleItemCount = _items.length;
              _isPlaybackComplete = true;
              _isPreviewing = false;
            } else {
              _visibleItemCount = normalized.visibleItemCount;
              _isPlaybackComplete = false;
            }
          } else if (widget.autoStartPlayback) {
            _visibleItemCount = 0;
            _isPlaybackComplete = false;
          } else {
            _isPlaybackComplete = false;
          }
        });
        _setFollowingLatest(true);
        _scrollToLatest(animated: false);
        widget.onDraftLoadedChanged?.call(true);
        if (browseRestoreOutcome != null) {
          _maybeShowRestoreOutcomeWarnings(browseRestoreOutcome);
        }
        if (widget.autoStartPlayback) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted || _items.isEmpty || _loadError != null) return;
            if (_isPlaybackComplete) {
              return;
            }
            final result = await _prepareResourcesForPlayback();
            if (!mounted) return;
            if (result == null) return;
            if (!result.allSucceeded) {
              await _showPrefetchFailureDialog(
                result.failedUrls,
                failureDetails: result.failureDetails,
              );
              return;
            }
            if (widget.initialPlaybackState != null) {
              _resumePreviewFromVisibleCount();
            } else {
              _startPreview();
            }
          });
        }
        return;
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _isDraftLoaded = true;
          _isPlaybackComplete = false;
          _loadError = '$error';
        });
        widget.onDraftLoadedChanged?.call(true);
        return;
      }
    }
    final restored = await loadDraftCache();
    if (!mounted) return;
    if (!restored) {
      final defaults = _initialItems();
      setState(() {
        _items
          ..clear()
          ..addAll(defaults);
        _chatTitle = '';
        _storyPlanner = ChatMockupStoryPlanner.empty();
        _newlyAddedItemIds.clear();
        _nextId = _computeNextId(defaults);
        _selectedItemIds.clear();
        _primarySelectedItemId = null;
        _editingItemId = null;
        _editingField = null;
        _isPreviewing = false;
        _visibleItemCount = defaults.length;
        _isWaitingManual = false;
        _lastExportedSnapshot = _currentExportSnapshot();
        _hasUnexportedChanges = false;
        _isDraftLoaded = true;
      });
      _notifyEditingChangedIfNeeded();
      _setFollowingLatest(true);
      _scrollToLatest(animated: false);
      widget.onDraftLoadedChanged?.call(true);
      if (_draftLoadErrorMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showInvalidDraftDialog();
        });
      }
      return;
    }
    setState(() {
      _visibleItemCount = _items.length;
      _isDraftLoaded = true;
      _hasUnexportedChanges = hasUnexportedChanges;
    });
    _setFollowingLatest(true);
    _scrollToLatest(animated: false);
    widget.onDraftLoadedChanged?.call(true);
  }

  Future<_ChatMockupRestoreOutcome> _restoreFromJsonPayload(
    Map<String, dynamic> payload, {
    required bool preserveDraftMetadata,
  }) async {
    final version = payload['version'];
    final itemsJson = payload['items'];
    final importedChatTitle =
        payload['chatTitle'] is String ? payload['chatTitle'] as String : '';
    if (version != 1 || itemsJson is! List) {
      throw const FormatException('Unsupported JSON format.');
    }
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final availableAssets = manifest.listAssets().toSet();
    final imported = <ChatMockupItem>[];
    for (final item in itemsJson) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid item entry.');
      }
      imported.add(_itemFromJson(item, availableAssets: availableAssets));
    }
    final normalizedImported = _normalizeImportedItemIds(imported);
    final parsedPlanner =
        ChatMockupStoryPlanner.fromJson(payload['storyPlanner']);
    final importedPlanner = revalidateStoryPlanner(
      items: normalizedImported,
      planner: parsedPlanner,
    );
    var neteaseOutchainOnWindowsCount = 0;
    for (final item in normalizedImported) {
      if (item.type != ChatMockupItemType.message) continue;
      final m = item.music;
      if (m != null &&
          m.action == ChatMockupMusicAction.play &&
          (m.url ?? '').isNotEmpty) {
        if (m.kind == ChatMockupMusicSourceKind.audioUrl) {
          ChatMockupAudioUrlValidator.assertPlayableUrlShape(m.url!);
        } else if (m.kind == ChatMockupMusicSourceKind.iframe) {
          await validateChatMockupMusicIframeForSaveOrImport(m.url!);
          if (_isNeteaseOutchainOnWindows(m.url)) {
            neteaseOutchainOnWindowsCount++;
          }
        }
      }
    }
    _invalidateResourceCacheSession();
    _playbackTimer?.cancel();
    _invalidateMusicPlaybackSession();
    if (!mounted) {
      return _ChatMockupRestoreOutcome(
        neteaseOutchainOnWindowsCount: neteaseOutchainOnWindowsCount,
      );
    }
    setState(() {
      _items
        ..clear()
        ..addAll(normalizedImported);
      _chatTitle = importedChatTitle;
      _storyPlanner = importedPlanner;
      _newlyAddedItemIds.clear();
      _nextId = _computeNextId(normalizedImported);
      _selectedItemIds.clear();
      _primarySelectedItemId = null;
      _editingItemId = null;
      _editingField = null;
      _isPreviewing = false;
      _visibleItemCount = normalizedImported.length;
      _isWaitingManual = false;
      if (preserveDraftMetadata) {
        final cachedSnapshot = payload['lastExportedSnapshot'];
        final cachedHasUnexportedChanges =
            payload['hasUnexportedChanges'] == true;
        if (cachedSnapshot is String && cachedSnapshot.isNotEmpty) {
          _lastExportedSnapshot = cachedSnapshot;
          _hasUnexportedChanges =
              _currentExportSnapshot() != _lastExportedSnapshot;
        } else {
          if (cachedHasUnexportedChanges) {
            _lastExportedSnapshot = null;
            _hasUnexportedChanges = true;
          } else {
            _lastExportedSnapshot = _currentExportSnapshot();
            _hasUnexportedChanges = false;
          }
        }
      }
    });
    _notifyEditingChangedIfNeeded();
    return _ChatMockupRestoreOutcome(
      neteaseOutchainOnWindowsCount: neteaseOutchainOnWindowsCount,
    );
  }

  Future<bool> loadDraftCache() async {
    final cached = box.read(_draftCacheKey);
    if (cached is! String || cached.isEmpty) return false;
    try {
      final decoded = jsonDecode(cached);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid cache root.');
      }
      final outcome = await _restoreFromJsonPayload(
        decoded,
        preserveDraftMetadata: true,
      );
      _draftLoadErrorMessage = null;
      _invalidDraftRaw = null;
      _maybeShowRestoreOutcomeWarnings(outcome);
      return true;
    } catch (error) {
      _draftLoadErrorMessage = '$error';
      _invalidDraftRaw = cached;
      return false;
    }
  }

  Future<void> _showInvalidDraftDialog() async {
    final message = _draftLoadErrorMessage;
    final raw = _invalidDraftRaw;
    if (message == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('旧草稿兼容提示'),
          content: SelectableText(
            '旧草稿包含不再支持的内嵌图片，已回退到默认内容。\n'
            '请导出备份后手动改为图片 URL。\n\n'
            '详情：$message',
          ),
          actions: [
            TextButton(
              onPressed: raw == null
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: raw));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('旧草稿文本已复制到剪贴板')),
                      );
                    },
              child: const Text('导出旧草稿文本'),
            ),
            TextButton(
              onPressed: () async {
                await clearInvalidDraftCache();
                _draftLoadErrorMessage = null;
                _invalidDraftRaw = null;
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
              },
              child: const Text('丢弃旧草稿'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('稍后处理'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> saveDraftCache() {
    return _writeDraftCache(
      ignorePendingInvalid: false,
      clearInvalidOnSuccess: false,
    );
  }

  Future<void> discardPendingInvalidDraft() async {
    _draftLoadErrorMessage = null;
    _invalidDraftRaw = null;
    await clearInvalidDraftCache();
  }

  Future<bool> forceSaveDraftCache() {
    return _writeDraftCache(
      ignorePendingInvalid: true,
      clearInvalidOnSuccess: true,
    );
  }

  /// Snapshot of the current canvas for local archiving (not the GitHub upload JSON).
  Future<Map<String, dynamic>?> buildCurrentStorySnapshot() async {
    if (!_isDraftLoaded || _isBrowseMode) return null;
    _revalidatePlannerForPersistIfNeeded();
    return <String, dynamic>{
      'version': 1,
      'chatTitle': _chatTitle,
      'items': _items.map(_itemToJson).toList(),
      'storyPlanner': _storyPlanner.toJson(),
      'capturedAtMs': DateTime.now().millisecondsSinceEpoch,
      'templateRevision': kChatMockupStoryTemplateRevision,
    };
  }

  /// Read-only export for 录像带 browse mode: title + items for per-work session persistence.
  /// Does not touch [chat_mockup_draft]; returns null when not in browse mode or not loaded.
  Map<String, dynamic>? buildCurrentSessionSnapshotForBrowse() {
    if (!_isDraftLoaded || !_isBrowseMode) {
      return null;
    }
    final normalized = normalizeBrowsePlaybackState(
      visibleItemCount: _visibleItemCount,
      itemLength: _items.length,
      playbackComplete: _isPlaybackComplete,
    );
    return <String, dynamic>{
      'version': 1,
      'chatTitle': _chatTitle,
      'items': _items.map(_itemToJson).toList(),
      'storyPlanner': _storyPlanner.toJson(),
      'visibleItemCount': normalized.visibleItemCount,
      'playbackComplete': normalized.playbackComplete,
      'templateRevision': kChatMockupStoryTemplateRevision,
    };
  }

  /// Whether [snapshot] has nothing worth archiving (empty title and no items, or still
  /// the legacy demo layout from [_initialItems]).
  bool isSnapshotEquivalentToFreshTemplate(Map<String, dynamic> snapshot) {
    if (!_isDraftLoaded || _isBrowseMode) return false;
    final title = snapshot['chatTitle'];
    final t = title is String ? title.trim() : '';
    if (t.isNotEmpty) return false;
    final snapItems = snapshot['items'];
    if (snapItems is! List) return false;
    if (snapItems.isEmpty) return true;
    final rev = snapshot['templateRevision'];
    if (rev is int && rev != kChatMockupStoryTemplateRevision) {
      return false;
    }
    final defaults = _initialItems();
    final ref = _encodeJsonPayload(<String, dynamic>{
      'version': 1,
      'chatTitle': '',
      'items': defaults.map(_itemToJson).toList(),
    });
    final candidate = _encodeJsonPayload(<String, dynamic>{
      'version': 1,
      'chatTitle': '',
      'items': snapItems,
    });
    if (ref != candidate) {
      return false;
    }
    final sp = snapshot['storyPlanner'];
    if (sp != null &&
        ChatMockupStoryPlanner.fromJson(sp).hasLocalArchiveSignal) {
      return false;
    }
    return true;
  }

  /// Restores a snapshot from [buildCurrentStorySnapshot] into the canvas and persists draft.
  Future<ChatMockupStoryRestoreResult> restoreStoryFromSnapshot(
    Map<String, dynamic> snapshot,
  ) async {
    if (!_isDraftLoaded || _isBrowseMode) {
      return ChatMockupStoryRestoreResult.failed;
    }
    if (_isPreviewing) {
      return ChatMockupStoryRestoreResult.failedPreviewActive;
    }
    if (_isAiSending) {
      return ChatMockupStoryRestoreResult.failedAiBusy;
    }
    if (isEditingText) {
      return ChatMockupStoryRestoreResult.failedEditingText;
    }
    try {
      final payload = Map<String, dynamic>.from(snapshot);
      payload.remove('capturedAtMs');
      final outcome = await _restoreFromJsonPayload(
        payload,
        preserveDraftMetadata: false,
      );
      if (!mounted) return ChatMockupStoryRestoreResult.failedUnmounted;
      setState(() {
        _lastExportedSnapshot = _currentExportSnapshot();
        _hasUnexportedChanges = false;
      });
      _maybeShowRestoreOutcomeWarnings(outcome);
      _notifyEditingChangedIfNeeded();
      AndroidInputLock.unlock();
      FocusManager.instance.primaryFocus?.unfocus();
      _setFollowingLatest(true);
      _scrollToLatest(animated: false);
      if (await saveDraftCache()) {
        return ChatMockupStoryRestoreResult.restoredPersisted;
      }
      if (await forceSaveDraftCache()) {
        return ChatMockupStoryRestoreResult.restoredPersisted;
      }
      return ChatMockupStoryRestoreResult.restoredPersistFailed;
    } catch (_) {
      return ChatMockupStoryRestoreResult.failed;
    }
  }

  /// Stops preview / AI streaming placeholders, optionally persists the fresh draft, then resets
  /// to [initialItems] template with an empty title.
  Future<bool> startNewStory({bool saveDraft = true}) async {
    if (!_isDraftLoaded || _isBrowseMode) return false;

    _canvasMutationGeneration++;

    if (_isAiSending && _aiSettings.enableStreaming) {
      _aiStreamAbortRequested = true;
      _cancelActiveAiStream?.call();
    }
    // Client.close() stops the stream promptly; [_consumeAiCompletion] also
    // clears this in finally when the stream ends—both paths are safe.
    _cancelActiveAiStream = null;

    _rollbackAiStreamSession();

    _playbackTimer?.cancel();
    if (_isPreviewing) {
      _stopPreview();
    } else {
      _invalidateMusicPlaybackSession();
    }
    _invalidateResourceCacheSession();

    _draftAutoSaveTimer?.cancel();
    _draftAutoSaveTimer = null;
    _hasPendingDraftAutoSave = false;

    if (!mounted) return false;

    // Empty session: no placeholder/demo rows — user builds from add controls.
    const emptySession = <ChatMockupItem>[];
    setState(() {
      _isAiSending = false;
      _aiStreamAbortRequested = false;
      _items.clear();
      _chatTitle = '';
      _storyPlanner = ChatMockupStoryPlanner.empty();
      _newlyAddedItemIds.clear();
      _nextId = _computeNextId(emptySession);
      _selectedItemIds.clear();
      _primarySelectedItemId = null;
      _editingItemId = null;
      _editingField = null;
      _visibleItemCount = 0;
      _isWaitingManual = false;
      _isPlaybackComplete = false;
      _lastExportedSnapshot = _currentExportSnapshot();
      _hasUnexportedChanges = false;
    });
    _notifyEditingChangedIfNeeded();
    AndroidInputLock.unlock();
    FocusManager.instance.primaryFocus?.unfocus();
    _setFollowingLatest(true);
    _scrollToLatest(animated: false);

    if (!saveDraft) {
      return true;
    }
    if (await saveDraftCache()) {
      return true;
    }
    return forceSaveDraftCache();
  }

  Future<void> clearInvalidDraftCache() async {
    await box.remove(_draftCacheKey);
  }

  Future<bool> _writeDraftCache({
    required bool ignorePendingInvalid,
    required bool clearInvalidOnSuccess,
  }) async {
    if (!_isDraftLoaded || _isBrowseMode) {
      return false;
    }
    if (!ignorePendingInvalid && hasPendingInvalidDraft) {
      return false;
    }

    while (_isSavingDraftCache) {
      final pendingWrite = _draftCacheWriteCompleter;
      if (pendingWrite == null) {
        break;
      }
      await pendingWrite.future;
      if (!_isDraftLoaded || _isBrowseMode) {
        return false;
      }
      if (!ignorePendingInvalid && hasPendingInvalidDraft) {
        return false;
      }
    }

    final writeCompleter = Completer<void>();
    _draftCacheWriteCompleter = writeCompleter;
    _isSavingDraftCache = true;
    try {
      if (mounted) {
        _revalidatePlannerForPersistIfNeeded();
      }
      final payload = _buildJsonPayload(includeDraftMetadata: true);
      final encoded = _encodeJsonPayload(payload);
      await box.write(_draftCacheKey, encoded);
      if (clearInvalidOnSuccess) {
        _draftLoadErrorMessage = null;
        _invalidDraftRaw = null;
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      _isSavingDraftCache = false;
      if (identical(_draftCacheWriteCompleter, writeCompleter)) {
        _draftCacheWriteCompleter = null;
      }
      writeCompleter.complete();
    }
  }

  ChatMockupItem _itemFromJson(
    Map<String, dynamic> json, {
    required Set<String> availableAssets,
  }) {
    final typeName = json['type'];
    final sideName = json['side'];
    if (typeName is! String || sideName is! String) {
      throw const FormatException('Missing type/side.');
    }
    final type = ChatMockupItemType.values.firstWhere(
      (element) => element.name == typeName,
      orElse: () => throw const FormatException('Unsupported item type.'),
    );
    final side = ChatMockupItemSide.values.firstWhere(
      (element) => element.name == sideName,
      orElse: () => throw const FormatException('Unsupported item side.'),
    );
    if (!_allowedSidesForType(type).contains(side)) {
      throw const FormatException('Type/side mismatch.');
    }
    final wait = json['wait'];
    ChatMockupWaitMode waitMode = ChatMockupWaitMode.auto;
    double waitSeconds = 0;
    if (wait is Map<String, dynamic>) {
      final mode = wait['mode'];
      final seconds = wait['seconds'];
      if (mode is String) {
        waitMode = ChatMockupWaitMode.values.firstWhere(
          (element) => element.name == mode,
          orElse: () => throw const FormatException('Unsupported wait mode.'),
        );
      }
      if (seconds is num) {
        waitSeconds = seconds.toDouble().clamp(0, 10).toDouble();
      }
    }
    final imageSource = json['image'] is Map<String, dynamic>
        ? ChatMockupImageSource.fromJson(json['image'] as Map<String, dynamic>)
        : null;
    final avatarSource = json['avatar'] is Map<String, dynamic>
        ? ChatMockupImageSource.fromJson(json['avatar'] as Map<String, dynamic>)
        : null;
    _validateAssetSource(imageSource, availableAssets);
    _validateAssetSource(avatarSource, availableAssets);
    ChatMockupMusicDirective? music;
    final musicJson = json['music'];
    if (musicJson != null) {
      if (musicJson is! Map<String, dynamic>) {
        throw const FormatException('Invalid music field.');
      }
      music = ChatMockupMusicDirective.fromJson(musicJson);
    }
    return ChatMockupItem(
      id: (json['id'] as String?) ?? 'item_${_nextId++}',
      type: type,
      side: side,
      text: json['text'] as String?,
      emoji: json['emoji'] as String?,
      imageSource: imageSource,
      avatarSource: avatarSource,
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      firstText: json['firstText'] as String?,
      secondText: json['secondText'] as String?,
      waitMode: waitMode,
      waitSeconds: waitMode == ChatMockupWaitMode.auto ? waitSeconds : 0,
      music: music,
    );
  }

  void _validateAssetSource(
    ChatMockupImageSource? source,
    Set<String> availableAssets,
  ) {
    if (source == null || source.type != ChatMockupImageSourceType.asset) {
      return;
    }
    if (!availableAssets.contains(source.value)) {
      throw FormatException('Missing asset: ${source.value}');
    }
  }

  List<ChatMockupItem> _normalizeImportedItemIds(List<ChatMockupItem> items) {
    final normalized = <ChatMockupItem>[];
    final seen = <String>{};
    var nextId = _computeNextId(items);
    for (final item in items) {
      final id = item.id.trim();
      if (id.isNotEmpty && !seen.contains(id)) {
        seen.add(id);
        normalized.add(item.copyWith(id: id));
        continue;
      }
      var generated = 'item_$nextId';
      while (seen.contains(generated)) {
        nextId += 1;
        generated = 'item_$nextId';
      }
      seen.add(generated);
      normalized.add(item.copyWith(id: generated));
      nextId += 1;
    }
    return normalized;
  }

  int _computeNextId(List<ChatMockupItem> items) {
    var maxId = -1;
    for (final item in items) {
      if (!item.id.startsWith('item_')) continue;
      final parsed = int.tryParse(item.id.substring(5));
      if (parsed != null && parsed > maxId) maxId = parsed;
    }
    return maxId + 1;
  }

  ChatMockupMessageSide _toMessageSide(ChatMockupItemSide side) {
    switch (side) {
      case ChatMockupItemSide.left:
        return ChatMockupMessageSide.left;
      case ChatMockupItemSide.right:
        return ChatMockupMessageSide.right;
      case ChatMockupItemSide.center:
        return ChatMockupMessageSide.center;
    }
  }

  Future<VideoUploadPrepareResult?> prepareVideoUpload() async {
    if (!_isDraftLoaded) return null;
    try {
      if (!_isAiInitialized) {
        await _aiInitCompleter.future.timeout(const Duration(seconds: 5));
      }
      final chatMockup = _buildJsonPayload(
        includeDraftMetadata: false,
        includeStoryPlanner: false,
      );
      final payload = buildVideoUploadPayload(
        chatMockup: chatMockup,
        rolePrompt: _aiSettings.rolePrompt,
        userPrompt: _aiSettings.userPrompt,
      );
      void scanForLegacyMemory(dynamic node) {
        if (node is Map) {
          final type = node['type'];
          if (type is String && type.trim() == 'memory') {
            throw const FormatException(
              '影片上传不支持内嵌图片，请将图片改为 URL 或使用内置贴纸。',
            );
          }
          for (final v in node.values) {
            scanForLegacyMemory(v);
          }
          return;
        }
        if (node is List) {
          for (final v in node) {
            scanForLegacyMemory(v);
          }
        }
      }

      scanForLegacyMemory(payload);
      final encodedResult = encodeVideoPayloadWithStats(payload);
      final wrapped = wrapEncodedPayload(encodedResult.encoded);
      final mode = encodedResult.base64Chars > maxInlinePayloadChars
          ? VideoUploadPublishMode.gistRequired
          : VideoUploadPublishMode.inline;
      final recommendedBodySnippet = mode == VideoUploadPublishMode.inline
          ? '【影片简介】\n（在这里写简介）\n\n$wrapped'
          : '【影片简介】\n（在这里写简介）\n\n'
              'https://gist.githubusercontent.com/<user>/<gist-id>/raw';
      await Clipboard.setData(ClipboardData(text: wrapped));
      if (!mounted) return null;
      final warning = mode == VideoUploadPublishMode.gistRequired
          ? '；数据超过内联建议阈值，请改用 gist raw 链接发布'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '影片数据已压缩并复制到剪贴板：原始 ${encodedResult.jsonChars} 字符，压缩后 ${encodedResult.base64Chars} 字符$warning',
          ),
        ),
      );
      return VideoUploadPrepareResult(
        mode: mode,
        wrappedPayload: wrapped,
        encodedChars: encodedResult.base64Chars,
        jsonChars: encodedResult.jsonChars,
        recommendedBodySnippet: recommendedBodySnippet,
      );
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('上传数据准备失败: $e')));
      return null;
    }
  }
}

class _ChatMockupItemEntrance extends StatefulWidget {
  const _ChatMockupItemEntrance({
    required this.child,
    required this.enabled,
    required this.animationKey,
    this.onCompleted,
  });

  final Widget child;
  final bool enabled;
  final String animationKey;
  final VoidCallback? onCompleted;

  @override
  State<_ChatMockupItemEntrance> createState() =>
      _ChatMockupItemEntranceState();
}

class _ChatMockupItemEntranceState extends State<_ChatMockupItemEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    final curve =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(curve);
    _fade = Tween<double>(begin: 0, end: 1).animate(curve);
    _runIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _ChatMockupItemEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationKey != widget.animationKey ||
        (!oldWidget.enabled && widget.enabled)) {
      _runIfNeeded();
    }
  }

  void _runIfNeeded() {
    if (!widget.enabled) {
      _controller.value = 1;
      return;
    }
    _controller
      ..value = 0
      ..forward().whenComplete(() {
        if (!mounted) return;
        widget.onCompleted?.call();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
