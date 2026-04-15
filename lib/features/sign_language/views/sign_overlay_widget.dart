import 'package:flutter/material.dart';
import '../controllers/hand_controller.dart';
import 'hand_view.dart';

/// A floating, draggable sign-language avatar overlay.
///
/// Designed to sit inside a [Stack] in the meeting screen, anchored to the
/// bottom-right corner by default and draggable by the user.
///
/// Embed example (inside the existing meeting Stack):
/// ```dart
/// if (_signAvatarEnabled)
///   SignOverlayWidget(
///     controller: SignLanguageModule.instance.handController,
///   ),
/// ```
class SignOverlayWidget extends StatefulWidget {
  final HandController controller;

  /// Initial width of the avatar panel.
  final double initialWidth;

  /// Initial height of the avatar panel.
  final double initialHeight;

  /// Right-margin offset from the screen edge.
  final double initialRight;

  /// Bottom-margin offset from the screen edge.
  final double initialBottom;

  const SignOverlayWidget({
    super.key,
    required this.controller,
    this.initialWidth = 160,
    this.initialHeight = 200,
    this.initialRight = 8,
    this.initialBottom = 8,
  });

  @override
  State<SignOverlayWidget> createState() => _SignOverlayWidgetState();
}

class _SignOverlayWidgetState extends State<SignOverlayWidget> {
  late double _right;
  late double _bottom;
  late double _width;
  late double _height;

  // Drag state
  Offset? _dragStartGlobal;
  double? _dragStartRight;
  double? _dragStartBottom;

  @override
  void initState() {
    super.initState();
    _right = widget.initialRight;
    _bottom = widget.initialBottom;
    _width = widget.initialWidth;
    _height = widget.initialHeight;
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: _right,
      bottom: _bottom,
      child: GestureDetector(
        onPanStart: _onDragStart,
        onPanUpdate: _onDragUpdate,
        child: _buildPanel(context),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final currentWord = widget.controller.currentWord;
    final isPlaying = widget.controller.isPlaying;

    return Container(
      width: _width,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlaying
              ? const Color(0xFFFFB382).withValues(alpha:0.8)
              : Colors.white24,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header bar ──────────────────────────────────────────
            _buildHeader(isPlaying),

            // ── Avatar video ────────────────────────────────────────
            HandView(
              controller: widget.controller,
              width: _width,
              height: _height,
            ),

            // ── Subtitle ────────────────────────────────────────────
            _buildSubtitle(currentWord),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isPlaying) {
    return Container(
      height: 28,
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          // Drag handle icon
          const Icon(Icons.drag_indicator, color: Colors.white38, size: 16),
          const SizedBox(width: 4),
          Text(
            'Sign',
            style: TextStyle(
              color: Colors.white.withValues(alpha:0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          // Live indicator dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPlaying ? const Color(0xFFFFB382) : Colors.white24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle(String? word) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: word != null && word.isNotEmpty
          ? Container(
              key: ValueKey(word),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              color: Colors.black54,
              child: Text(
                word,
                key: ValueKey(word),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: Color(0xFFFFB382),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : const SizedBox(
              key: ValueKey('empty'),
              height: 28,
            ),
    );
  }

  // ── Drag handling ──────────────────────────────────────────────────

  void _onDragStart(DragStartDetails details) {
    _dragStartGlobal = details.globalPosition;
    _dragStartRight = _right;
    _dragStartBottom = _bottom;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_dragStartGlobal == null) return;
    final delta = details.globalPosition - _dragStartGlobal!;
    setState(() {
      // Moving left/right flips sign because Positioned.right is from screen edge
      _right = (_dragStartRight! - delta.dx).clamp(0.0, double.infinity);
      _bottom = (_dragStartBottom! - delta.dy).clamp(0.0, double.infinity);
    });
  }
}
