import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  final GlobalKey<NavigatorState> navigatorKey;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription? _sub;

  // ✅ Stores meeting ID from cold start — does NOT navigate yet
  String? pendingMeetingId;

  DeepLinkService(this.navigatorKey);

  Future<void> start() async {
    // 1. Cold start — store the ID only, do NOT navigate
    //    (navigator is not mounted yet at this point)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        pendingMeetingId = _extractMeetingId(initialUri);
        debugPrint('🔗 Cold start link stored: $pendingMeetingId');
      }
    } catch (e) {
      debugPrint('❌ DeepLinkService: error getting initial link: $e');
    }

    // 2. Warm start — app already running, navigate immediately
    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
          (Uri uri) => _handleUri(uri),
      onError: (e) => debugPrint('❌ DeepLinkService: stream error: $e'),
    );
  }

  /// ✅ Call this from HomePage.initState() after user is confirmed logged in.
  /// Navigates to the meeting and clears the pending link.
  void consumePendingLink() {
    if (pendingMeetingId != null) {
      final id = pendingMeetingId!;
      pendingMeetingId = null;
      debugPrint('✅ Consuming pending deep link for meeting: $id');
      _navigateToMeeting(id);
    }
  }

  void _handleUri(Uri uri) {
    debugPrint('🔗 DeepLinkService received: $uri');
    final id = _extractMeetingId(uri);
    if (id != null) _navigateToMeeting(id);
  }

  String? _extractMeetingId(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'meeting') {
      final id = segments[1];
      return id.isNotEmpty ? id : null;
    }
    return null;
  }

  void _navigateToMeeting(String meetingId) {
    debugPrint('✅ DeepLinkService: navigating to meeting $meetingId');
    navigatorKey.currentState?.pushNamed(
      '/joinMeeting',
      arguments: meetingId,
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}