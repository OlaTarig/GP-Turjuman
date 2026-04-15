import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../controllers/hand_controller.dart';

/// Renders sign language video clips driven by [HandController].
///
/// Playback model
/// ──────────────
/// • Two [VideoPlayerController] slots (front / back) enable a 200 ms
///   cross-fade between consecutive signs.
/// • When the front video is ~200 ms from its end, [HandController.onVideoFinished]
///   is called so the controller can dequeue the next token and update
///   [currentVideoPath].  [HandView] then starts loading the back slot and
///   begins the cross-fade, so both clips overlap for ~200 ms.
/// • After the fade the back slot becomes the front and the old front is
///   disposed.
/// • Videos are displayed with BoxFit.cover so landscape clips fill the
///   portrait panel without black bars.
class HandView extends StatefulWidget {
  final HandController controller;
  final double width;
  final double height;

  const HandView({
    super.key,
    required this.controller,
    this.width = 220,
    this.height = 220,
  });

  @override
  State<HandView> createState() => _HandViewState();
}

class _HandViewState extends State<HandView>
    with SingleTickerProviderStateMixin {
  // ── Video controller slots ─────────────────────────────────────────
  VideoPlayerController? _frontCtrl;
  VideoPlayerController? _backCtrl;

  // ── Cross-fade animation ───────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim; // 0 = front fully visible, 1 = back fully visible

  // ── State tracking ─────────────────────────────────────────────────
  String? _frontPath;       // asset path currently in the front slot
  String? _pendingPath;     // path being loaded into the back slot
  bool _transitioning = false;
  bool _endNotified = false; // guard against duplicate onVideoFinished calls
  Timer? _endTimer;

  // ── Lifecycle ──────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    widget.controller.addListener(_onHandControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onHandControllerChanged);
    _endTimer?.cancel();
    _frontCtrl?.dispose();
    _backCtrl?.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── HandController listener ────────────────────────────────────────

  void _onHandControllerChanged() {
    final newPath = widget.controller.currentVideoPath;

    if (newPath == null) {
      _endTimer?.cancel();
      setState(() {});
      return;
    }

    // Only react to a genuinely new path
    if (newPath != _frontPath && newPath != _pendingPath) {
      _loadAndCrossFade(newPath);
    }
  }

  // ── Asset → VideoPlayerController (handles Unicode filenames) ────────

  /// Creates and initialises a [VideoPlayerController] for [assetPath].
  ///
  /// Strategy:
  /// 1. Try `VideoPlayerController.asset()` directly.
  /// 2. If that fails (common on Android with Arabic/Unicode filenames),
  ///    copy the asset bytes to a temp file with an ASCII name and use
  ///    `VideoPlayerController.file()` instead.
  Future<VideoPlayerController> _makeController(String assetPath) async {
    // ── Attempt 1: asset path directly ──────────────────────────────
    final direct = VideoPlayerController.asset(assetPath);
    try {
      await direct.initialize();
      debugPrint('✅ HandView: loaded via asset path "$assetPath"');
      return direct;
    } catch (e) {
      direct.dispose();
      debugPrint('⚠️ HandView: asset() failed for "$assetPath" — falling back to temp file ($e)');
    }

    // ── Attempt 2: extract to temp file with ASCII name ──────────────
    final ext = assetPath.contains('.') ? assetPath.split('.').last : 'mp4';
    final hash = assetPath.hashCode.abs();
    try {
      final tmpDir = await getTemporaryDirectory();
      final tmpFile = File('${tmpDir.path}/sign_$hash.$ext');

      final data = await rootBundle.load(assetPath);
      await tmpFile.writeAsBytes(data.buffer.asUint8List(), flush: true);

      final fileCtrl = VideoPlayerController.file(tmpFile);
      await fileCtrl.initialize();
      debugPrint('✅ HandView: loaded via temp file for "$assetPath"');
      return fileCtrl;
    } catch (e2) {
      throw Exception('HandView: could not load "$assetPath": $e2');
    }
  }

  // ── Video transition ───────────────────────────────────────────────

  Future<void> _loadAndCrossFade(String assetPath) async {
    if (_transitioning) {
      _pendingPath = assetPath;
      return;
    }

    _transitioning = true;
    _pendingPath = assetPath;
    _endNotified = false;
    _endTimer?.cancel();

    VideoPlayerController newCtrl;
    try {
      newCtrl = await _makeController(assetPath);
    } catch (e) {
      debugPrint('❌ HandView: failed to init "$assetPath": $e');
      _transitioning = false;
      widget.controller.onVideoFinished();
      return;
    }

    if (!mounted) {
      newCtrl.dispose();
      _transitioning = false;
      return;
    }

    await _backCtrl?.dispose();
    _backCtrl = newCtrl;

    await _backCtrl!.setLooping(false);
    await _backCtrl!.play();

    final duration = _backCtrl!.value.duration;
    if (duration > Duration.zero) {
      final fireAt = duration > const Duration(milliseconds: 300)
          ? duration - const Duration(milliseconds: 200)
          : duration;
      _endTimer = Timer(fireAt, _onNearEnd);
    }

    _fadeCtrl.value = 0.0;
    if (mounted) setState(() {});

    await _fadeCtrl.forward();

    if (!mounted) {
      _transitioning = false;
      return;
    }

    await _frontCtrl?.dispose();
    _frontCtrl = _backCtrl;
    _frontPath = assetPath;
    _backCtrl = null;
    _fadeCtrl.value = 0.0;
    _transitioning = false;

    setState(() {});

    if (_pendingPath != null && _pendingPath != _frontPath) {
      final next = _pendingPath!;
      _pendingPath = null;
      _loadAndCrossFade(next);
    } else {
      _pendingPath = null;
    }
  }

  void _onNearEnd() {
    if (_endNotified) return;
    _endNotified = true;
    widget.controller.onVideoFinished();
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _fadeAnim,
        builder: (context, _) {
          final hasFront =
              _frontCtrl != null && _frontCtrl!.value.isInitialized;
          final hasBack = _backCtrl != null && _backCtrl!.value.isInitialized;
          final showPlaceholder = !hasFront && !hasBack;

          return Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black87),

              if (hasFront)
                Opacity(
                  opacity: (1.0 - _fadeAnim.value).clamp(0.0, 1.0),
                  child: _buildVideo(_frontCtrl!),
                ),

              if (hasBack)
                Opacity(
                  opacity: _fadeAnim.value.clamp(0.0, 1.0),
                  child: _buildVideo(_backCtrl!),
                ),

              if (showPlaceholder)
                const Center(
                  child: Icon(
                    Icons.sign_language,
                    color: Colors.white38,
                    size: 56,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideo(VideoPlayerController ctrl) {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: ctrl.value.size.width,
          height: ctrl.value.size.height,
          child: VideoPlayer(ctrl),
        ),
      ),
    );
  }
}
