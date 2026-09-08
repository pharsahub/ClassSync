import 'dart:convert';
import 'crypto_service.dart';

/// Item representing an answer unit in a cryptographic hash chain.
class AnswerChainItem {
  final String questionId;
  final String response;
  final int timestampMs;
  final String hashChainLink;

  const AnswerChainItem({
    required this.questionId,
    required this.response,
    required this.timestampMs,
    required this.hashChainLink,
  });
}

/// Engine for computing and verifying incremental SHA-256 hash chains for quiz answers.
///
/// Formula:
/// link[0] = hash(genesis_hash + q_id[0] + response[0] + timestamp[0])
/// link[i] = hash(link[i-1] + q_id[i] + response[i] + timestamp[i])
class HashChainEngine {
  static const String defaultGenesisPrefix = 'CLASSSYNC_GENESIS_V1';

  /// Generates the deterministic genesis hash for a submission session.
  static Future<String> computeGenesisHash({
    required String submissionId,
    required String studentId,
    CryptoService? cryptoService,
  }) async {
    final crypto = cryptoService ?? CryptoService();
    final input = '$defaultGenesisPrefix:$submissionId:$studentId';
    return await crypto.hashString(input);
  }

  /// Calculates a single hash chain link given the previous hash, question ID, response, and timestamp.
  static Future<String> computeLink({
    required String previousHash,
    required String questionId,
    required String response,
    required int timestampMs,
    CryptoService? cryptoService,
  }) async {
    final crypto = cryptoService ?? CryptoService();
    final rawInput = '$previousHash|$questionId|$response|$timestampMs';
    return await crypto.hashString(rawInput);
  }

  /// Verifies an ordered sequence of answers against the initial genesis hash.
  /// Returns true only if every link in the chain is mathematically authentic.
  static Future<bool> verifyChain({
    required List<AnswerChainItem> answers,
    required String genesisHash,
    CryptoService? cryptoService,
  }) async {
    if (answers.isEmpty) return true;

    final crypto = cryptoService ?? CryptoService();
    String currentPreviousHash = genesisHash;

    for (int i = 0; i < answers.length; i++) {
      final item = answers[i];
      final expectedLink = await computeLink(
        previousHash: currentPreviousHash,
        questionId: item.questionId,
        response: item.response,
        timestampMs: item.timestampMs,
        cryptoService: crypto,
      );

      if (expectedLink.toLowerCase() != item.hashChainLink.toLowerCase()) {
        // Broken chain detected
        return false;
      }

      currentPreviousHash = item.hashChainLink;
    }

    return true;
  }
}
