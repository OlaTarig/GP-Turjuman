import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  final GlobalKey<NavigatorState> navigatorKey;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription? _sub;

  String? pendingMeetingId;

  DeepLinkService(this.navigatorKey);

  Future<void> start() async {
    // Cold start — try to capture the link that launched the app
    try {
      final initialUri = await _appLinks.getInitialLink();
      debugPrint('🔗 Raw initial URI: $initialUri');
      if (initialUri != null) {
        pendingMeetingId = _extractMeetingId(initialUri);
        debugPrint('🔗 Cold start stored: $pendingMeetingId');
      } else {
        debugPrint('🔗 No initial URI found');
      }
    } catch (e) {
      debugPrint('❌ DeepLinkService.start error: $e');
    }

    // Warm start — app already running, navigate immediately
    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
          (Uri uri) => _handleUri(uri),
      onError: (e) => debugPrint('❌ DeepLinkService stream error: $e'),
    );
  }

  /// Second attempt at getInitialLink() for devices where it arrives late.
  /// Called from _AppEntryState._init() after start() already ran.
  Future<String?> retryInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      debugPrint('🔗 retryInitialLink URI: $uri');
      if (uri != null) {
        final id = _extractMeetingId(uri);
        if (id != null) {
          pendingMeetingId = id;
          return id;
        }
      }
    } catch (e) {
      debugPrint('❌ retryInitialLink error: $e');
    }
    return null;
  }

  /// Consume the pending link exactly once.
  String? consumePendingLink() {
    if (pendingMeetingId != null) {
      final id = pendingMeetingId!;
      pendingMeetingId = null;
      debugPrint('✅ consumePendingLink: $id');
      return id;
    }
    return null;
  }

  void _handleUri(Uri uri) {
    debugPrint('🔗 DeepLinkService received (warm): $uri');
    final id = _extractMeetingId(uri);
    if (id != null) _navigateToMeeting(id);
  }

  String? _extractMeetingId(Uri uri) {
    debugPrint('🔍 Extracting from: $uri | segments: ${uri.pathSegments}');
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'meeting') {
      final id = segments[1];
      debugPrint('✅ Extracted meetingId: $id');
      return id.isNotEmpty ? id : null;
    }
    debugPrint('❌ Could not extract meetingId');
    return null;
  }

  void _navigateToMeeting(String meetingId) {
    debugPrint('✅ DeepLinkService warm-start navigating to: $meetingId');
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/joinMeeting',
          (route) => route.isFirst,
      arguments: meetingId,
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}