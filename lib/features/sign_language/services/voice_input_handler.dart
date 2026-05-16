import 'package:flutter/foundation.dart';
import '../../../controllers/CaptionController.dart';
import '../controllers/hand_controller.dart';
import 'named_entity_recognition.dart';

/// Bridges the live caption stream to the sign language animation pipeline.
///
/// Listens to [CaptionController.liveCaptions] updates, normalises each new
/// Arabic caption entry, tokenises it, runs NER, and forwards the resulting
/// token list to [HandController].
///
/// Arabic normalisation applied before dictionary lookup:
///   • Strip diacritics (tashkeel): U+064B – U+0652 and related marks
///   • Normalise alef variants (أ إ آ ٱ) → ا
///   • Normalise taa marbuta (ة) → ه  [set [normalizeTaaMarbuta] to disable]
///   • Strip punctuation and extra whitespace
class VoiceInputHandler {
  final HandController _handController;
  final NamedEntityRecognition _ner;

  /// Whether to normalise ة → ه before dictionary lookup.
  final bool normalizeTaaMarbuta;

  CaptionController? _captionController;

  /// How many entries from [liveCaptions] have already been processed.
  int _processedCount = 0;

  /// Keys ("userId|text") of captions already forwarded via pendingCaption,
  /// used to skip the duplicate when Firestore later confirms them in liveCaptions.
  /// A set (not a single entry) handles the case where caption B arrives before
  /// Firestore confirms caption A — both are tracked independently.
  final Set<String> _pendingProcessed = {};

  VoiceInputHandler({
    required HandController handController,
    required NamedEntityRecognition ner,
    this.normalizeTaaMarbuta = false,
  })  : _handController = handController,
        _ner = ner;

  // ── Attach / detach ────────────────────────────────────────────────

  /// Start listening to [captionController]'s caption updates.
  void attach(CaptionController captionController) {
    if (_captionController == captionController) return;
    detach(_captionController);
    _captionController = captionController;
    _processedCount = captionController.liveCaptions.length; // skip history
    // Skip any caption already pending at attach time so we don't play
    // something that was spoken before the avatar was opened.
    final pending = captionController.pendingCaption;
    if (pending != null && pending.text.trim().isNotEmpty) {
      _pendingProcessed.add('${pending.userId}|${pending.text}');
    }
    captionController.addListener(_onCaptionsUpdated);
    debugPrint('🔗 VoiceInputHandler: attached to CaptionController');
  }

  /// Stop listening.
  void detach(CaptionController? captionController) {
    captionController?.removeListener(_onCaptionsUpdated);
    if (_captionController == captionController) {
      _captionController = null;
      _processedCount = 0;
      _pendingProcessed.clear();
    }
  }

  void dispose() {
    detach(_captionController);
  }

  // ── Caption listener ───────────────────────────────────────────────

  void _onCaptionsUpdated() {
    final cc = _captionController;
    if (cc == null) return;

    // ── Fix 1: process pendingCaption immediately (before Firestore confirms) ──
    // pendingCaption is set the moment speech is recognized, before the Firestore
    // round-trip, so forwarding it here eliminates the 200-600ms Firestore delay.
    final pending = cc.pendingCaption;
    if (pending != null && pending.text.trim().isNotEmpty) {
      final key = '${pending.userId}|${pending.text}';
      if (!_pendingProcessed.contains(key)) {
        _pendingProcessed.add(key);
        startTracking(pending.text);
      }
    }

    // ── Process newly arrived liveCaptions entries from Firestore ──
    final captions = cc.liveCaptions;
    if (captions.length <= _processedCount) {
      // List was cleared (e.g. meeting ended) — reset counter
      _processedCount = captions.length;
      return;
    }

    final newEntries = captions.sublist(_processedCount);
    _processedCount = captions.length;

    for (final entry in newEntries) {
      if (entry.text.trim().isEmpty) continue;
      // Skip the Firestore confirmation of a caption already queued via pendingCaption.
      // Use remove() so the same phrase can be queued again if said a second time.
      final key = '${entry.userId}|${entry.text}';
      if (_pendingProcessed.remove(key)) continue;
      startTracking(entry.text);
    }
  }

  // ── Processing pipeline ────────────────────────────────────────────

  /// Normalise, tokenise, run NER and queue tokens in HandController.
  ///
  /// This is the primary entry point; call it directly when text arrives
  /// from any source (CaptionController or tests).
  void startTracking(String rawText) {
    final normalised = processInput(rawText);
    if (normalised.isEmpty) return;

    final tokens = tokenizeText(normalised);
    if (tokens.isEmpty) return;

    final annotated = _ner.identifyEntities(tokens);
    debugPrint('🔤 VoiceInputHandler: queueing ${annotated.length} tokens for "$normalised"');

    _handController.setText(annotated);
  }

  /// Normalises raw Arabic text for dictionary lookup.
  String processInput(String rawText) {
    var text = rawText.trim();

    // 1. Strip tashkeel (diacritics): U+064B–U+0652, plus U+0610–U+061A, U+0670
    text = text.replaceAll(
      RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670]'),
      '',
    );

    // 2. Normalise alef variants → bare alef ا
    text = text
        .replaceAll('\u0623', '\u0627') // أ → ا
        .replaceAll('\u0625', '\u0627') // إ → ا
        .replaceAll('\u0622', '\u0627') // آ → ا
        .replaceAll('\u0671', '\u0627') // ٱ → ا
        .replaceAll('\u0673', '\u0627') // ٳ → ا
        .replaceAll('\u0672', '\u0627'); // ٲ → ا

    // 3. (Optional) Normalise taa marbuta ة → ه
    if (normalizeTaaMarbuta) {
      text = text.replaceAll('\u0629', '\u0647');
    }

    // 4. Normalise waw variants → و
    text = text.replaceAll('\u0624', '\u0648'); // ؤ → و

    // 5. Normalise yaa variants → ي
    text = text
        .replaceAll('\u0626', '\u064A') // ئ → ي
        .replaceAll('\u0649', '\u064A'); // ى → ي

    // 6. Strip punctuation and non-Arabic/non-space characters
    text = text.replaceAll(
      RegExp(r'[^\u0600-\u06FF\s]'),
      '',
    );

    // 7. Collapse whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  /// Splits normalised Arabic text into individual word tokens.
  List<String> tokenizeText(String text) {
    return text
        .split(' ')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();
  }
}
