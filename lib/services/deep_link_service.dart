import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

class DeepLinkService {
  DeepLinkService(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  Future<void> start() async {
    // 1) لو التطبيق انفتح من لينك وهو مقفّل
    final initial = await _appLinks.getInitialLink();
    if (initial != null) _handleUri(initial);

    // 2) لو التطبيق شغال وجاه لينك
    _sub = _appLinks.uriLinkStream.listen(_handleUri);
  }

  void dispose() {
    _sub?.cancel();
  }

  void _handleUri(Uri uri) {
    // نتوقع: /meeting/<id>
    final seg = uri.pathSegments;
    if (seg.length >= 2 && seg[0] == 'meeting') {
      final meetingId = seg[1];

      // هنا حولي لصفحة Join/Meeting (انتِ اختاري اسم الراوت)
      navigatorKey.currentState?.pushNamed(
        '/joinMeeting',
        arguments: meetingId,
      );
    }
  }
}
