import 'package:cloud_firestore/cloud_firestore.dart';

// ── Single caption entry ─────────────────────────────────────────────
class CaptionEntry {
  final String userId;
  final String userName;
  final String text;
  final DateTime timestamp;

  CaptionEntry({
    required this.userId,
    required this.userName,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userName': userName,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
  };

  factory CaptionEntry.fromMap(Map<String, dynamic> map) => CaptionEntry(
    userId: map['userId'] ?? '',
    userName: map['userName'] ?? '',
    text: map['text'] ?? '',
    timestamp: map['timestamp'] != null
        ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
        : DateTime.now(),
  );
}

// ── Full transcription model matching Firestore schema ───────────────
// Collection: captionsFileTranscription
// Fields: meetingId, transcriptionFilePath, createdAt, translatedSign,
//         captionsBuffer, isCompleted, updatedAt, format
class CaptionsAndTranscriptionModel {
  final String meetingId;
  final String transcriptionFilePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<dynamic> translatedSign;
  final List<CaptionEntry> captionsBuffer;
  final bool isCompleted;
  final String format;
  final List<String> attendees;

  CaptionsAndTranscriptionModel({
    required this.meetingId,
    this.transcriptionFilePath = '',
    required this.createdAt,
    required this.updatedAt,
    this.translatedSign = const [],
    this.captionsBuffer = const [],
    this.isCompleted = false,
    this.format = 'pdf',
    this.attendees = const [],
  });

  factory CaptionsAndTranscriptionModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return CaptionsAndTranscriptionModel(
      meetingId: map['meetingId'] ?? '',
      transcriptionFilePath: map['transcriptionFilePath'] ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      translatedSign: map['translatedSign'] ?? [],
      captionsBuffer: (map['captionsBuffer'] as List<dynamic>? ?? [])
          .map((e) => CaptionEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      isCompleted: map['isCompleted'] ?? false,
      format: map['format'] ?? 'pdf',
      attendees: List<String>.from(map['attendees'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'meetingId': meetingId,
    'transcriptionFilePath': transcriptionFilePath,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'translatedSign': translatedSign,
    'captionsBuffer': captionsBuffer.map((e) => e.toMap()).toList(),
    'isCompleted': isCompleted,
    'format': format,
    'attendees': attendees,
  };
}