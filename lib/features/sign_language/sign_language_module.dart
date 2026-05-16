// Sign Language Feature — public API
// Import this single file to access all sign language classes:
//   import 'features/sign_language/sign_language_module.dart';
export 'models/gesture_data.dart';
export 'models/hand_model.dart';
export 'services/named_entity_recognition.dart';
export 'services/voice_input_handler.dart';
export 'controllers/hand_controller.dart';
export 'views/hand_view.dart';
export 'views/sign_overlay_widget.dart';

import 'package:flutter/foundation.dart';
import '../../controllers/CaptionController.dart';
import 'models/hand_model.dart';
import 'services/named_entity_recognition.dart';
import 'services/voice_input_handler.dart';
import 'controllers/hand_controller.dart';

/// Singleton that owns every component of the sign language pipeline.
///
/// Usage in MeetingView:
/// ```dart
/// // 1. In initState (once per app launch)
/// await SignLanguageModule.instance.initialize();
///
/// // 2. After joining a meeting
/// SignLanguageModule.instance.attachToCaption(CaptionController.instance);
///
/// // 3. In dispose / on leave
/// SignLanguageModule.instance.detachFromCaption(CaptionController.instance);
/// ```
class SignLanguageModule {
  SignLanguageModule._();
  static final SignLanguageModule instance = SignLanguageModule._();

  late final HandModel _handModel;
  late final NamedEntityRecognition _ner;
  late final HandController _handController;
  late final VoiceInputHandler _voiceInputHandler;

  bool _initialized = false;

  // ── Accessors ──────────────────────────────────────────────────────

  HandController get handController {
    assert(_initialized, 'Call initialize() before accessing handController');
    return _handController;
  }

  VoiceInputHandler get voiceInputHandler {
    assert(_initialized, 'Call initialize() before accessing voiceInputHandler');
    return _voiceInputHandler;
  }

  HandModel get handModel {
    assert(_initialized, 'Call initialize() before accessing handModel');
    return _handModel;
  }

  bool get isInitialized => _initialized;

  // ── Lifecycle ──────────────────────────────────────────────────────

  /// Loads the gesture dictionary and wires up all components.
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_initialized) return;

    _handModel = HandModel();
    await _handModel.loadFromAsset();

    _ner = NamedEntityRecognition(_handModel);
    _handController = HandController(_handModel);
    _voiceInputHandler = VoiceInputHandler(
      handController: _handController,
      ner: _ner,
      normalizeTaaMarbuta: true,
    );

    _initialized = true;
    debugPrint('✅ SignLanguageModule initialized '
        '(${_handModel.listGestures().length} gestures loaded)');
  }

  /// Begins forwarding captions from [captionController] to the sign pipeline.
  void attachToCaption(CaptionController captionController) {
    if (!_initialized) {
      debugPrint('⚠️ SignLanguageModule: not initialized — skipping attach');
      return;
    }
    _handController.stopAnimation(); // clear any stale queue from a prior session
    _voiceInputHandler.attach(captionController);
  }

  /// Stops forwarding captions.
  void detachFromCaption(CaptionController captionController) {
    if (!_initialized) return;
    _voiceInputHandler.detach(captionController);
  }

  /// Stops the current animation and clears the queue.
  void stopPlayback() {
    if (!_initialized) return;
    _handController.stopAnimation();
  }

  /// Releases resources. After this call [initialize] must be called again.
  void dispose() {
    if (!_initialized) return;
    _voiceInputHandler.dispose();
    _handController.dispose();
    _initialized = false;
    debugPrint('🛑 SignLanguageModule disposed');
  }
}
