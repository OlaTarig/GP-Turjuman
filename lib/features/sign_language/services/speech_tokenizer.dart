import '../models/hand_model.dart';

/// Tokenizes Arabic words into sign language tokens for [HandController].
///
/// Multi-word signs are discovered dynamically from [HandModel] (any key that
/// contains a space), sorted longest-first so the greedy scan always prefers
/// the longest match. Single-word tokens that are not in the dictionary are
/// prefixed with `#fingerspell:` so [HandController] expands them letter by letter.
class SpeechTokenizer {
  final HandModel _handModel;

  /// Multi-word phrases extracted from the dictionary, sorted longest-first.
  late final List<List<String>> _multiWordPhrases;

  SpeechTokenizer(this._handModel) {
    _multiWordPhrases = _handModel
        .listGestures()
        .where((key) => key.contains(' '))
        .map((key) => key.split(' '))
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length)); // longest first
  }

  List<String> tokenize(List<String> words) {
    final result = <String>[];
    int i = 0;

    while (i < words.length) {
      bool matched = false;

      for (final parts in _multiWordPhrases) {
        final len = parts.length;
        if (i + len <= words.length &&
            words.sublist(i, i + len).join(' ') == parts.join(' ') &&
            _handModel.hasGesture(parts.join(' '))) {
          result.add(parts.join(' '));
          i += len;
          matched = true;
          break;
        }
      }
      if (matched) continue;

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
