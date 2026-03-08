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
    // Cold start — store ID, do NOT navigate yet
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        pendingMeetingId = _extractMeetingId(initialUri);
        debugPrint('🔗 Cold start link stored: $pendingMeetingId');
      }
    } catch (e) {
      debugPrint('❌ DeepLinkService: error getting initial link: $e');
    }

    // Warm start — app already open, navigate immediately
    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
          (Uri uri) => _handleUri(uri),
      onError: (e) => debugPrint('❌ DeepLinkService: stream error: $e'),
    );
  }

  /// Called from HomePage.initState() ONCE.
  /// Returns the pending meeting ID and clears it — caller handles navigation.
  String? consumePendingLink() {
    if (pendingMeetingId != null) {
      final id = pendingMeetingId!;
      pendingMeetingId = null;
      debugPrint('✅ Consuming pending deep link: $id');
      return id;
    }
    return null;
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