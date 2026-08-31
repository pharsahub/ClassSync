import 'dart:math';

class IdGenerator {
  static final Random _random = Random();

  /// Generates a short unique ID with prefix e.g. "qz_948294"
  static String generate([String prefix = 'id']) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final randomPart = _random.nextInt(99999).toRadixString(36);
    return '${prefix}_$timestamp$randomPart';
  }

  /// Generates a human-friendly classroom session code e.g. "CS-8492"
  static String generateSessionCode() {
    final numbers = _random.nextInt(9000) + 1000;
    return 'CS-$numbers';
  }
}
