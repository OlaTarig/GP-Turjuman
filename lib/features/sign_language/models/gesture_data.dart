/// Data container for a single sign language gesture.
class GestureData {
  final String videoPath;  // Flutter asset path, e.g. 'assets/signs/مرحبا.glb'
  final int durationMs;    // animation duration in ms — used to advance the playback queue
  final String word;       // original Arabic word / letter this gesture represents

  const GestureData({
    required this.videoPath,
    required this.durationMs,
    required this.word,
  });

  factory GestureData.fromJson(Map<String, dynamic> json) => GestureData(
        videoPath: json['videoPath'] as String,
        durationMs: (json['durationMs'] as num).toInt(),
        word: json['word'] as String,
      );

  Map<String, dynamic> toJson() => {
        'videoPath': videoPath,
        'durationMs': durationMs,
        'word': word,
      };

  @override
  String toString() => 'GestureData(word: $word, videoPath: $videoPath)';
}
