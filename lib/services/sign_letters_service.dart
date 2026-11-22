import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Arabic sign-letter images, stored in Firebase Storage under
/// `sign_letters/<name>.png`.
///
/// Images: AASL dataset (Al-Barham et al., 2023), CC BY-SA 4.0, backgrounds
/// removed. The attribution line lives in Settings.
class SignLettersService {
  SignLettersService._();
  static final SignLettersService instance = SignLettersService._();

  static const String _folder = 'sign_letters';

  /// Letter → file name in Storage. Order is the daily-letter rotation.
  static const List<MapEntry<String, String>> letters = [
    MapEntry('ا', 'alef'),
    MapEntry('ب', 'beh'),
    MapEntry('ت', 'teh'),
    MapEntry('ث', 'theh'),
    MapEntry('ج', 'jeem'),
    MapEntry('ح', 'hah'),
    MapEntry('خ', 'khah'),
    MapEntry('د', 'dal'),
    MapEntry('ذ', 'thal'),
    MapEntry('ر', 'reh'),
    MapEntry('ز', 'zain'),
    MapEntry('س', 'seen'),
    MapEntry('ش', 'sheen'),
    MapEntry('ص', 'sad'),
    MapEntry('ض', 'dad'),
    MapEntry('ط', 'tah'),
    MapEntry('ظ', 'zah'),
    MapEntry('ع', 'ain'),
    MapEntry('غ', 'ghain'),
    MapEntry('ف', 'feh'),
    MapEntry('ق', 'qaf'),
    MapEntry('ك', 'kaf'),
    MapEntry('ل', 'lam'),
    MapEntry('م', 'meem'),
    MapEntry('ن', 'noon'),
    MapEntry('ه', 'heh'),
    MapEntry('و', 'waw'),
    MapEntry('ي', 'yeh'),
    MapEntry('ة', 'teh_marbuta'),
  ];

  static final Map<String, String> _fileByLetter = Map.fromEntries(letters);

  /// Letter variants that share a hand shape.
  static const Map<String, String> _normalize = {
    'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا',
    'ى': 'ي', 'ئ': 'ي', 'ؤ': 'و',
  };

  final Map<String, Future<String?>> _urlCache = {};

  /// Storage file name for [char], or null when there is no sign image
  /// (Latin letters, digits, spaces, diacritics).
  String? fileFor(String char) {
    final c = _normalize[char] ?? char;
    return _fileByLetter[c];
  }

  /// Download URL for [char]'s image; cached for the app session.
  Future<String?> urlFor(String char) {
    final file = fileFor(char);
    if (file == null) return Future.value(null);
    return _urlCache.putIfAbsent(file, () async {
      try {
        return await FirebaseStorage.instance
            .ref('$_folder/$file.png')
            .getDownloadURL();
      } catch (e) {
        debugPrint('SignLetters: no image for $file ($e)');
        _urlCache.remove(file); // allow a retry later
        return null;
      }
    });
  }

  /// Splits a name into displayable letters (drops spaces), max [limit].
  List<String> lettersOf(String name, {int limit = 12}) => name.characters
      .where((c) => c.trim().isNotEmpty)
      .take(limit)
      .toList();

  /// Today's letter. Based on the UTC calendar day so every user sees the
  /// same letter, changing once a day.
  String letterOfTheDay([DateTime? now]) {
    final d = (now ?? DateTime.now()).toUtc();
    final day = DateTime.utc(d.year, d.month, d.day)
        .difference(DateTime.utc(2025, 1, 1))
        .inDays;
    return letters[day % letters.length].key;
  }
}

extension on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}
