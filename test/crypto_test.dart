import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:classsync/core/crypto/crypto_service.dart';
import 'package:classsync/core/crypto/hash_chain.dart';
import 'package:classsync/core/crypto/deterministic_ids.dart';
import 'package:classsync/models/quiz.dart';
import 'package:classsync/models/question.dart';

void main() {
  late CryptoService cryptoService;

  setUp(() {
    cryptoService = CryptoService();
  });

  group('Ed25519 Digital Signatures', () {
    test('successfully signs and verifies a valid message', () async {
      final keyPair = await cryptoService.generateEd25519KeyPair();
      final pubKeyHex = await cryptoService.exportPublicKeyHex(keyPair);

      const message = 'ClassSync Exam Session Token: CS-2026-X89';
      final signatureHex = await cryptoService.signMessage(message, keyPair);

      final isValid = await cryptoService.verifySignature(
        message: message,
        signatureHex: signatureHex,
        publicKeyHex: pubKeyHex,
      );

      expect(isValid, isTrue);
    });

    test('tampered quiz package payload FAILS signature verification', () async {
      final teacherKeyPair = await cryptoService.generateEd25519KeyPair();
      final teacherPubKeyHex = await cryptoService.exportPublicKeyHex(teacherKeyPair);

      final originalQuiz = Quiz(
        quizId: 'quiz_midterm_101',
        teacherId: 'teacher_smith',
        title: 'Distributed Systems & Networking',
        timeLimitMinutes: 20,
        questions: [
          Question(
            questionId: 'q1',
            quizId: 'quiz_midterm_101',
            type: QuestionType.mcq,
            body: 'What is the primary role of an Ed25519 signature?',
            options: ['Encryption', 'Authentication & Integrity', 'Compression', 'Routing'],
            correctAnswer: '1',
            marks: 2,
          ),
        ],
      );

      final originalPayload = originalQuiz.getSignablePayload();
      final signatureHex = await cryptoService.signMessage(originalPayload, teacherKeyPair);

      // Verify legitimate quiz
      final initialValid = await cryptoService.verifySignature(
        message: originalPayload,
        signatureHex: signatureHex,
        publicKeyHex: teacherPubKeyHex,
      );
      expect(initialValid, isTrue);

      // Maliciously modify quiz question text
      final tamperedQuiz = originalQuiz.copyWith(
        title: 'Distributed Systems & Networking [TAMPERED]',
      );
      final tamperedPayload = tamperedQuiz.getSignablePayload();

      final isTamperedValid = await cryptoService.verifySignature(
        message: tamperedPayload,
        signatureHex: signatureHex,
        publicKeyHex: teacherPubKeyHex,
      );

      expect(isTamperedValid, isFalse, reason: 'Tampered quiz package payload must be rejected');
    });

    test('invalid signature string fails verification gracefully', () async {
      final keyPair = await cryptoService.generateEd25519KeyPair();
      final pubKeyHex = await cryptoService.exportPublicKeyHex(keyPair);

      final isValid = await cryptoService.verifySignature(
        message: 'Valid Message',
        signatureHex: 'deadbeef12345678', // Bad signature
        publicKeyHex: pubKeyHex,
      );

      expect(isValid, isFalse);
    });
  });

  group('AES-256-GCM Authenticated Encryption', () {
    test('encrypts and decrypts string payload correctly', () async {
      final aesKey = await cryptoService.generateAesKey();
      const secretQuizAnswers = '{"q1": 1, "q2": 0, "q3": 2}';

      final encrypted = await cryptoService.encryptPayload(secretQuizAnswers, aesKey);
      expect(encrypted['ciphertext'], isNotEmpty);
      expect(encrypted['nonce'], isNotEmpty);
      expect(encrypted['mac'], isNotEmpty);

      final decrypted = await cryptoService.decryptPayload(encrypted, aesKey);
      expect(decrypted, equals(secretQuizAnswers));
    });

    test('tampered ciphertext fails AES-GCM MAC validation', () async {
      final aesKey = await cryptoService.generateAesKey();
      const plaintext = 'Sensitive classroom assessment payload';

      final encrypted = await cryptoService.encryptPayload(plaintext, aesKey);

      // Tamper ciphertext
      final rawCipher = encrypted['ciphertext']!;
      final tamperedCipher = rawCipher.substring(0, rawCipher.length - 2) + 'ff';
      final tamperedMap = {
        'ciphertext': tamperedCipher,
        'nonce': encrypted['nonce']!,
        'mac': encrypted['mac']!,
      };

      expect(
        () async => await cryptoService.decryptPayload(tamperedMap, aesKey),
        throwsA(anything),
        reason: 'Tampered ciphertext must fail authenticated decryption',
      );
    });
  });

  group('Incremental Hash Chain Engine', () {
    test('valid answer chain passes verification', () async {
      const submissionId = 'sub_9a8b7c6d';
      const studentId = 'std_2026_01';

      final genesis = await HashChainEngine.computeGenesisHash(
        submissionId: submissionId,
        studentId: studentId,
        cryptoService: cryptoService,
      );

      final ts1 = DateTime.now().millisecondsSinceEpoch;
      final link1 = await HashChainEngine.computeLink(
        previousHash: genesis,
        questionId: 'q1',
        response: '1',
        timestampMs: ts1,
        cryptoService: cryptoService,
      );

      final ts2 = ts1 + 5000;
      final link2 = await HashChainEngine.computeLink(
        previousHash: link1,
        questionId: 'q2',
        response: '0',
        timestampMs: ts2,
        cryptoService: cryptoService,
      );

      final ts3 = ts2 + 6000;
      final link3 = await HashChainEngine.computeLink(
        previousHash: link2,
        questionId: 'q3',
        response: '3',
        timestampMs: ts3,
        cryptoService: cryptoService,
      );

      final answers = [
        AnswerChainItem(questionId: 'q1', response: '1', timestampMs: ts1, hashChainLink: link1),
        AnswerChainItem(questionId: 'q2', response: '0', timestampMs: ts2, hashChainLink: link2),
        AnswerChainItem(questionId: 'q3', response: '3', timestampMs: ts3, hashChainLink: link3),
      ];

      final isValid = await HashChainEngine.verifyChain(
        answers: answers,
        genesisHash: genesis,
        cryptoService: cryptoService,
      );

      expect(isValid, isTrue);
    });

    test('broken or tampered hash chain is DETECTED and REJECTED', () async {
      const submissionId = 'sub_9a8b7c6d';
      const studentId = 'std_2026_01';

      final genesis = await HashChainEngine.computeGenesisHash(
        submissionId: submissionId,
        studentId: studentId,
        cryptoService: cryptoService,
      );

      final ts1 = 100000;
      final link1 = await HashChainEngine.computeLink(
        previousHash: genesis,
        questionId: 'q1',
        response: '1',
        timestampMs: ts1,
        cryptoService: cryptoService,
      );

      final ts2 = 105000;
      final link2 = await HashChainEngine.computeLink(
        previousHash: link1,
        questionId: 'q2',
        response: '0',
        timestampMs: ts2,
        cryptoService: cryptoService,
      );

      // Student/Attacker tampers with answer 1 response after the fact (from '1' to '2')
      final tamperedAnswers = [
        AnswerChainItem(questionId: 'q1', response: '2', timestampMs: ts1, hashChainLink: link1),
        AnswerChainItem(questionId: 'q2', response: '0', timestampMs: ts2, hashChainLink: link2),
      ];

      final isChainValid = await HashChainEngine.verifyChain(
        answers: tamperedAnswers,
        genesisHash: genesis,
        cryptoService: cryptoService,
      );

      expect(isChainValid, isFalse, reason: 'Mid-quiz tampering must break the hash chain');
    });
  });

  group('Deterministic IDs', () {
    test('produces identical submission_id for identical tuple inputs', () {
      final subId1 = DeterministicIds.generateSubmissionId(
        studentId: 'std_fatima_18',
        sessionId: 'session_cs_4892',
        deviceId: 'dev_pixel7_a8',
      );

      final subId2 = DeterministicIds.generateSubmissionId(
        studentId: 'std_fatima_18',
        sessionId: 'session_cs_4892',
        deviceId: 'dev_pixel7_a8',
      );

      final subIdDiffDevice = DeterministicIds.generateSubmissionId(
        studentId: 'std_fatima_18',
        sessionId: 'session_cs_4892',
        deviceId: 'dev_pixel8_b9',
      );

      expect(subId1, equals(subId2));
      expect(subId1.startsWith('sub_'), isTrue);
      expect(subId1, isNot(equals(subIdDiffDevice)));
    });
  });
}
