import '../models/hand_model.dart';

/// Classifies tokens that are not in the sign dictionary as entities
/// that should be fingerspelled letter by letter.
///
/// Tokens found in [HandModel] are returned as-is.
/// Unknown tokens are prefixed with `#fingerspell:` so [HandController]
/// knows to expand them into individual letter tokens.
class NamedEntityRecognition {
  final HandModel _handModel;

  const NamedEntityRecognition(this._handModel);

  /// Annotates [tokens] with fingerspell markers where needed.
  ///
  /// Returns a new list where every token is either:
  /// - the original word (found in the sign dictionary), or
  /// - `#fingerspell:<word>` (not in dictionary → spell letter by letter)
  List<String> identifyEntities(List<String> tokens) {
    final result = <String>[];
    for (final token in tokens) {
      if (token.isEmpty) continue;

      if (_handModel.hasGesture(token)) {
        result.add(token);
      } else {
        // Mark for fingerspelling; HandController will expand this
        result.add('#fingerspell:$token');
      }
    }
    return result;
  }
}
