import '../models/hand_model.dart';

/// Classifies tokens against the sign dictionary.
///
/// Multi-word signs are checked explicitly by [_multiWordPhrases] (longest
/// first). Everything else is a single-word lookup; unmatched words are
/// prefixed with `#fingerspell:` so [HandController] expands them letter
/// by letter.
class NamedEntityRecognition {
  final HandModel _handModel;

  const NamedEntityRecognition(this._handModel);

  // Known multi-word signs, sorted longest-first so the greedy check always
  // prefers the longest match.
  static const List<String> _multiWordPhrases = [
    'جامعه الملك سعود',
  ];

  List<String> identifyEntities(List<String> words) {
    final result = <String>[];
    int i = 0;

    while (i < words.length) {
      bool matched = false;

      // Check multi-word phrases (longest first).
      for (final phrase in _multiWordPhrases) {
        final parts = phrase.split(' ');
        final len = parts.length;
        if (i + len <= words.length &&
            words.sublist(i, i + len).join(' ') == phrase &&
            _handModel.hasGesture(phrase)) {
          result.add(phrase);
          i += len;
          matched = true;
          break;
        }
      }
      if (matched) continue;
      // Single-word lookup.
      if (_handModel.hasGesture(words[i])) {
        result.add(words[i]);
      } else {
        result.add('#fingerspell:${words[i]}');
      }
      i++;
    }

    return result;
  }
}
