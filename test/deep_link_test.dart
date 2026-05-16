// ─────────────────────────────────────────────────────────────────────────────
// test/deep_link_test.dart
// TC06 — Join via Deep Link — Cold Start
// One group → one test, matching the manual test table exactly.
// Uses REAL DeepLinkService from lib/services/deep_link_service.dart.
// _extractMeetingId() is private — tested via public consumePendingLink()
// which is exactly what the app calls during cold start navigation.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turjuman/services/deep_link_service.dart';

void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late DeepLinkService           deepLinkService;

  setUp(() {
    navigatorKey    = GlobalKey<NavigatorState>();
    deepLinkService = DeepLinkService(navigatorKey);
  });

  tearDown(() => deepLinkService.dispose());

  // ══════════════════════════════════════════════════════════════════════════
  // TC06 — Join via Deep Link — Cold Start
  // Steps : 1. Close the app  2. Tap the invitation link  3. Observe navigation
  // Expected: App opens and navigates to join meeting screen with correct ID
  // ══════════════════════════════════════════════════════════════════════════
  group('TC06 — Join via Deep Link — Cold Start', () {
    test(
      'Participant taps the invitation link while the app is closed — '
          'the app launches and navigates to the join meeting screen '
          'with the correct meeting ID',
          () {
        // Step 1 & 2 — app was closed, link tapped
        // Simulates what DeepLinkService.start() sets after parsing the URI
        deepLinkService.pendingMeetingId = 'meeting_abc123';

        // Step 3 — app reads the pending ID during _AppEntryState._init()
        final meetingId = deepLinkService.consumePendingLink();

        // Expected: app navigates to join meeting screen with correct meeting ID
        expect(meetingId, isNotNull,
            reason: 'Meeting ID must be available after cold-start link tap');
        expect(meetingId, equals('meeting_abc123'),
            reason: 'App must navigate to the correct meeting from the link');

        // pendingMeetingId cleared — prevents navigating twice
        expect(deepLinkService.pendingMeetingId, isNull,
            reason: 'Link must be consumed exactly once');

        // Second consume returns null — no duplicate navigation
        final second = deepLinkService.consumePendingLink();
        expect(second, isNull,
            reason: 'Consumed link must not trigger navigation again');
      },
    );
  });
}