import 'dart:convert';
import 'package:crypto/crypto.dart' as standard_crypto;

/// Utility for generating deterministic identifiers required by ClassSync DTN logic.
class DeterministicIds {
  /// Generates a deterministic submission ID from student_id, session_id, and device_id.
  ///
  /// Format: `sub_<16-char-sha256-hex>`
  static String generateSubmissionId({
    required String studentId,
    required String sessionId,
    required String deviceId,
  }) {
    final rawInput = 'sub:$studentId:$sessionId:$deviceId';
    final bytes = utf8.encode(rawInput);
    final digest = standard_crypto.sha256.convert(bytes);
    final hexPrefix = digest.toString().substring(0, 16);
    return 'sub_$hexPrefix';
  }

  /// Generates a deterministic device ID from student_id and platform identifier.
  static String generateDeviceId({
    required String studentId,
    required String platformName,
  }) {
    final rawInput = 'dev:$studentId:$platformName';
    final bytes = utf8.encode(rawInput);
    final digest = standard_crypto.sha256.convert(bytes);
    final hexPrefix = digest.toString().substring(0, 12);
    return 'dev_$hexPrefix';
  }

  /// Generates a deterministic attendance ID.
  static String generateAttendanceId({
    required String sessionId,
    required String studentId,
  }) {
    final rawInput = 'att:$sessionId:$studentId';
    final bytes = utf8.encode(rawInput);
    final digest = standard_crypto.sha256.convert(bytes);
    final hexPrefix = digest.toString().substring(0, 16);
    return 'att_$hexPrefix';
  }

  /// Generates a deterministic answer ID.
  static String generateAnswerId({
    required String submissionId,
    required String questionId,
  }) {
    final rawInput = 'ans:$submissionId:$questionId';
    final bytes = utf8.encode(rawInput);
    final digest = standard_crypto.sha256.convert(bytes);
    final hexPrefix = digest.toString().substring(0, 16);
    return 'ans_$hexPrefix';
  }
}
