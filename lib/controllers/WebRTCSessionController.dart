import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';


class WebRTCSessionController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Local media
  MediaStream? _localStream;
  RTCVideoRenderer localRenderer = RTCVideoRenderer();

  // Remote renderers per peer
  final Map<String, RTCVideoRenderer> remoteRenderers = {};

  // Peer connections per peer
  final Map<String, RTCPeerConnection> _pcs = {};

  // Signaling subscriptions
  final List<StreamSubscription> _subs = [];

  bool isMicOn = false;
  bool isCameraOn = false;

  bool isInitialized = false;

  Future<void> initialize() async {
    await localRenderer.initialize();
    isInitialized = true;
    notifyListeners();
  }


  Future<void> disposeSession() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();

    for (final pc in _pcs.values) {
      await pc.close();
    }
    _pcs.clear();

    for (final r in remoteRenderers.values) {
      await r.dispose();
    }
    remoteRenderers.clear();

    await _localStream?.dispose();
    _localStream = null;

    await localRenderer.dispose();
    isInitialized = false;
  }

  Future<void> _ensureLocalStream({required bool wantAudio, required bool wantVideo}) async {
    if (_localStream != null) return;

    final mediaConstraints = <String, dynamic>{
      'audio': wantAudio,
      'video': wantVideo
          ? {
        'facingMode': 'user',
        'width': {'ideal': 640},
        'height': {'ideal': 480},
        'frameRate': {'ideal': 24},
      }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    localRenderer.srcObject = _localStream;

    // افتراضيًا خليهم مطفيين حسب متطلباتكم
    for (final t in _localStream!.getAudioTracks()) {
      t.enabled = false;
    }
    for (final t in _localStream!.getVideoTracks()) {
      t.enabled = false;
    }
    isMicOn = false;
    isCameraOn = false;
    notifyListeners();
  }

  Future<RTCPeerConnection> _createPeerConnection({
    required String meetingId,
    required String selfId,
    required String peerId,
  }) async {
    final config = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    final pc = await createPeerConnection(config);

    // Add local tracks (audio/video) to this peer connection
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        pc.addTrack(track, _localStream!);
      }
    }

    // ICE candidates -> Firestore
    pc.onIceCandidate = (c) async {
      if (c.candidate == null) return;
      final candRef = _db
          .collection('Meetings')
          .doc(meetingId)
          .collection('signals')
          .doc(peerId)
          .collection('candidates')
          .doc();

      await candRef.set({
        'from': selfId,
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
        'ts': FieldValue.serverTimestamp(),
      });
    };

    // Remote track -> renderer
    pc.onTrack = (event) async {
      if (event.track.kind == 'video') {
        final r = remoteRenderers.putIfAbsent(peerId, () => RTCVideoRenderer());
        if (r.textureId == null) {
          await r.initialize();
        }
        r.srcObject = event.streams.isNotEmpty ? event.streams[0] : null;
        notifyListeners();
      }
    };

    return pc;
  }

  /// HOST: call this when meeting starts to listen for participants offers.
  Future<void> hostStartListening({
    required String meetingId,
    required String hostId,
  }) async {
    await _ensureLocalStream(wantAudio: true, wantVideo: true);

    // Listen to /signals/* docs changes (offers from participants)
    final sub = _db
        .collection('Meetings')
        .doc(meetingId)
        .collection('signals')
        .snapshots()
        .listen((snap) async {
      for (final doc in snap.docs) {
        final data = doc.data();
        final type = data['type'] as String?;
        final from = data['from'] as String?;
        if (type == 'offer' && from != null && from != hostId) {
          await _handleOfferAsHost(meetingId: meetingId, hostId: hostId, peerId: from, offerSdp: data['sdp']);
        }
      }
    });

    _subs.add(sub);
  }

  Future<void> _handleOfferAsHost({
    required String meetingId,
    required String hostId,
    required String peerId,
    required String offerSdp,
  }) async {
    if (_pcs.containsKey(peerId)) return;

    final pc = await _createPeerConnection(meetingId: meetingId, selfId: hostId, peerId: peerId);
    _pcs[peerId] = pc;

    await pc.setRemoteDescription(RTCSessionDescription(offerSdp, 'offer'));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    // Write answer to participant signal doc
    await _db.collection('Meetings').doc(meetingId).collection('signals').doc(peerId).set({
      'type': 'answer',
      'from': hostId,
      'to': peerId,
      'sdp': answer.sdp,
      'ts': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Listen for ICE candidates from participant -> host
    _listenCandidates(meetingId: meetingId, selfId: hostId, peerId: peerId, pc: pc);
  }

  /// PARTICIPANT: call this to join meeting (send offer to host).
  Future<void> participantJoin({
    required String meetingId,
    required String participantId,
    required String hostId,
  }) async {
    await _ensureLocalStream(wantAudio: true, wantVideo: true);

    final pc = await _createPeerConnection(meetingId: meetingId, selfId: participantId, peerId: participantId);
    _pcs[hostId] = pc;

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    // Send offer (store under participantId doc)
    await _db.collection('Meetings').doc(meetingId).collection('signals').doc(participantId).set({
      'type': 'offer',
      'from': participantId,
      'to': hostId,
      'sdp': offer.sdp,
      'ts': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Listen for answer
    final sub = _db
        .collection('Meetings')
        .doc(meetingId)
        .collection('signals')
        .doc(participantId)
        .snapshots()
        .listen((doc) async {
      final data = doc.data();
      if (data == null) return;
      if (data['type'] == 'answer' && data['sdp'] != null) {
        await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], 'answer'));
      }
    });
    _subs.add(sub);

    // Listen candidates host->participant (stored under participantId/candidates with from=hostId)
    _listenCandidates(meetingId: meetingId, selfId: participantId, peerId: participantId, pc: pc);
  }

  void _listenCandidates({
    required String meetingId,
    required String selfId,
    required String peerId,
    required RTCPeerConnection pc,
  }) {
    final sub = _db
        .collection('Meetings')
        .doc(meetingId)
        .collection('signals')
        .doc(peerId)
        .collection('candidates')
        .orderBy('ts')
        .snapshots()
        .listen((snap) async {
      for (final d in snap.docs) {
        final data = d.data();
        final from = data['from'] as String?;
        // Ignore own candidates
        if (from == selfId) continue;

        final cand = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        );
        await pc.addCandidate(cand);
      }
    });

    _subs.add(sub);
  }

  Future<void> setMicEnabled(bool enabled) async {
    if (_localStream == null) return;
    for (final t in _localStream!.getAudioTracks()) {
      t.enabled = enabled;
    }
    isMicOn = enabled;
    notifyListeners();
  }

  Future<void> setCameraEnabled(bool enabled) async {
    if (_localStream == null) return;
    for (final t in _localStream!.getVideoTracks()) {
      t.enabled = enabled;
    }
    isCameraOn = enabled;
    notifyListeners();
  }

  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final videoTrack = _localStream!.getVideoTracks().isNotEmpty ? _localStream!.getVideoTracks().first : null;
    if (videoTrack == null) return;
    await Helper.switchCamera(videoTrack);
  }
  Future<bool> ensurePermissions({
    required bool needMic,
    required bool needCamera,
  }) async {
    if (needMic) {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) return false;
    }
    if (needCamera) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) return false;
    }
    return true;
  }

  Future<bool> toggleMicWithPermission() async {
    // لو ما عندك stream (نادر لأنك تسوين join/start بعد initialize)
    // لكن نحمي الدالة
    if (_localStream == null) {
      await _ensureLocalStream(wantAudio: true, wantVideo: true);
    }

    if (!isMicOn) {
      final st = await Permission.microphone.status;
      if (!st.isGranted) {
        final req = await Permission.microphone.request();
        if (!req.isGranted) return false;
      }
    }

    await setMicEnabled(!isMicOn);
    return true;
  }

  Future<bool> toggleCameraWithPermission() async {
    if (_localStream == null) {
      await _ensureLocalStream(wantAudio: true, wantVideo: true);
    }

    if (!isCameraOn) {
      final st = await Permission.camera.status;
      if (!st.isGranted) {
        final req = await Permission.camera.request();
        if (!req.isGranted) return false;
      }
    }

    await setCameraEnabled(!isCameraOn);
    return true;
  }

}
