import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:classsync/core/crypto/crypto_service.dart';
import 'package:classsync/core/crypto/deterministic_ids.dart';
import 'package:classsync/core/crypto/hash_chain.dart';
import 'package:classsync/core/p2p/dtn_reconnect_manager.dart';
import 'package:classsync/core/p2p/p2p_transport.dart';
import 'package:classsync/core/p2p/simulated_p2p_transport.dart';
import 'package:classsync/core/storage/database_service.dart';
import 'package:classsync/models/answer.dart';
import 'package:classsync/models/question.dart';
import 'package:classsync/models/quiz.dart';
import 'package:classsync/models/session.dart';
import 'package:classsync/models/student.dart';
import 'package:classsync/models/submission.dart';
import 'package:classsync/providers/student_quiz_provider.dart';
import 'package:classsync/providers/teacher_session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late CryptoService cryptoService;
  late VirtualMeshHub meshHub;

  setUp(() async {
    cryptoService = CryptoService();
    meshHub = VirtualMeshHub()..clear();

    final dbService = DatabaseService();
    await dbService.init(inMemory: true);
  });

  tearDown(() async {
    meshHub.clear();
    final dbService = DatabaseService();
    await dbService.close();
  });

  group('Phase 6: Multi-Device DTN Resilience & Reconnect Test Harness', () {
    test('5-Device Classroom Scenario: Mid-Quiz Disconnects, Staggered Reconnects & Zero Data Loss', () async {
      // -------------------------------------------------------------
      // 1. SETUP TEACHER NODE & QUIZ
      // -------------------------------------------------------------
      final teacherTransport = SimulatedP2PTransport(nodeId: 'teacher_node');
      final teacherNotifier = TeacherSessionNotifier(cryptoService);
      await teacherTransport.startAdvertising(
        hostName: 'Prof. Anderson (ClassSync)',
        serviceId: 'classsync_exam_service',
      );

      final quiz = Quiz(
        quizId: 'quiz_comp_arch_401',
        teacherId: 'teacher_1',
        title: 'Computer Architecture & Pipelining',
        timeLimitMinutes: 15,
        questions: [
          Question(
            questionId: 'q1',
            quizId: 'quiz_comp_arch_401',
            type: QuestionType.mcq,
            body: 'Which pipeline hazard is resolved by data forwarding?',
            options: ['Structural Hazard', 'RAW Data Hazard', 'Control Hazard', 'WAR Hazard'],
            correctAnswer: '1',
            marks: 2,
          ),
          Question(
            questionId: 'q2',
            quizId: 'quiz_comp_arch_401',
            type: QuestionType.trueFalse,
            body: 'Branch prediction reduces stall penalties from control hazards.',
            options: ['True', 'False'],
            correctAnswer: '0',
            marks: 1,
          ),
          Question(
            questionId: 'q3',
            quizId: 'quiz_comp_arch_401',
            type: QuestionType.mcq,
            body: 'What is the theoretical maximum speedup in an ideal k-stage pipeline?',
            options: ['k / 2', 'k', '2^k', 'log(k)'],
            correctAnswer: '1',
            marks: 2,
          ),
        ],
      );

      await teacherNotifier.saveQuiz(quiz);
      final session = await teacherNotifier.startSession(quiz.quizId);

      // Set up teacher incoming payload handler
      teacherTransport.onPayloadReceived.listen((msg) async {
        if (msg.type == P2PMessageType.submissionPayload) {
          final sub = Submission.fromJson(msg.data);
          await teacherNotifier.processIncomingSubmission(sub);
        }
      });

      // -------------------------------------------------------------
      // 2. SETUP 5 STUDENT NODES WITH ED25519 KEYS & ROSTER BOOTSTRAP
      // -------------------------------------------------------------
      final List<Student> students = [];
      final List<SimulatedP2PTransport> studentTransports = [];
      final List<DtnReconnectManager> dtnManagers = [];
      final List<StudentQuizNotifier> studentNotifiers = [];
      final List<dynamic> keyPairs = [];

      for (int i = 1; i <= 5; i++) {
        final keyPair = await cryptoService.generateEd25519KeyPair();
        final pubKeyHex = await cryptoService.exportPublicKeyHex(keyPair);
        keyPairs.add(keyPair);

        final student = Student(
          studentId: 'std_00$i',
          name: 'Student 00$i',
          publicKey: pubKeyHex,
          classId: 'CS401',
          rollNumber: 'CS23-00$i',
        );
        students.add(student);

        final transport = SimulatedP2PTransport(nodeId: 'student_node_00$i');
        studentTransports.add(transport);

        final dtnManager = DtnReconnectManager(transport: transport);
        dtnManagers.add(dtnManager);

        final notifier = StudentQuizNotifier(cryptoService);
        studentNotifiers.add(notifier);

        // Connect each student transport to teacher
        await transport.startDiscovery(studentName: student.name, serviceId: 'classsync_exam_service');
        await transport.acceptConnection(teacherTransport.nodeId);
        await teacherTransport.acceptConnection(transport.nodeId);
      }

      // Teacher imports the full class roster ahead of time
      await teacherNotifier.importStudentRoster(students);
      expect(teacherNotifier.state.registeredRoster.length, equals(5));

      // -------------------------------------------------------------
      // 3. BROADCAST QUIZ & START QUIZ ON ALL 5 DEVICES
      // -------------------------------------------------------------
      for (int i = 0; i < 5; i++) {
        await studentNotifiers[i].startQuizSession(
          student: students[i],
          sessionId: session.sessionId,
          quiz: quiz,
          teacherPublicKeyHex: teacherNotifier.state.teacherPublicKeyHex,
        );
        expect(studentNotifiers[i].state.isQuizSignatureVerified, isTrue);
      }

      // -------------------------------------------------------------
      // 4. DISRUPT CONNECTIVITY (KILL P2P FOR STUDENTS 2 AND 4)
      // -------------------------------------------------------------
      // Simulate Students 2 & 4 losing connection (airplane mode / out of range)
      meshHub.simulateNetworkDrop(studentTransports[1].nodeId);
      meshHub.simulateNetworkDrop(studentTransports[3].nodeId);

      // -------------------------------------------------------------
      // 5. ALL 5 STUDENTS COMPLETE QUIZ & ANSWER WITH HASH CHAINS
      // -------------------------------------------------------------
      final List<Submission> generatedSubmissions = [];

      for (int i = 0; i < 5; i++) {
        // Answer questions with incremental hash chains
        await studentNotifiers[i].recordAnswer(questionId: 'q1', response: '1');
        await studentNotifiers[i].recordAnswer(questionId: 'q2', response: '0');
        await studentNotifiers[i].recordAnswer(questionId: 'q3', response: '1');

        final sub = await studentNotifiers[i].submitQuiz(studentKeyPair: keyPairs[i]);
        generatedSubmissions.add(sub);

        // Enqueue into DTN outbox
        await dtnManagers[i].enqueueSubmission(
          submission: sub,
          connectedTeacherEndpointId: teacherTransport.nodeId,
        );
      }

      // Allow event loop to process immediate transmissions for online students (0, 2, 4)
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify intermediate state: Online students delivered, dropped students held in outbox
      expect(dtnManagers[1].pendingOutbox.length, equals(1), reason: 'Student 2 outbox must hold pending submission');
      expect(dtnManagers[3].pendingOutbox.length, equals(1), reason: 'Student 4 outbox must hold pending submission');

      // -------------------------------------------------------------
      // 6. STAGGERED RECONNECT OF DROPPED NODES (DTN Opportunistic Sync)
      // -------------------------------------------------------------
      // Reconnect Student 2
      meshHub.simulateReconnect(studentTransports[1].nodeId);
      await dtnManagers[1].flushOutbox(teacherTransport.nodeId);
      await Future.delayed(const Duration(milliseconds: 50));

      // Reconnect Student 4
      meshHub.simulateReconnect(studentTransports[3].nodeId);
      await dtnManagers[3].flushOutbox(teacherTransport.nodeId);
      await Future.delayed(const Duration(milliseconds: 50));

      // Simulate a duplicate sync attempt from Student 2 (e.g. re-broadcast)
      await dtnManagers[1].enqueueSubmission(
        submission: generatedSubmissions[1],
        connectedTeacherEndpointId: teacherTransport.nodeId,
      );
      await Future.delayed(const Duration(milliseconds: 50));

      // -------------------------------------------------------------
      // 7. FINAL RESILIENCE ASSERTIONS
      // -------------------------------------------------------------
      final finalActiveSession = teacherNotifier.state.activeSession!;
      final submissions = finalActiveSession.submissions;

      // 1. Zero data loss: Exactly 5 submissions recorded
      expect(submissions.length, equals(5), reason: 'All 5 student submissions must be present');

      // 2. No duplicates: Unique submission IDs matching deterministic hashes
      final uniqueIds = submissions.map((s) => s.submissionId).toSet();
      expect(uniqueIds.length, equals(5), reason: 'Deterministic IDs must collapse duplicate sync attempts');

      // 3. 100% Cryptographic Verification: All signatures and hash chains are valid
      for (final sub in submissions) {
        expect(sub.isSignatureVerified, isTrue, reason: 'Student ${sub.studentId} signature must be verified');
        expect(sub.isHashChainVerified, isTrue, reason: 'Student ${sub.studentId} hash chain must be verified');
        expect(sub.status, equals(SubmissionStatus.graded));
        expect(sub.score, equals(5)); // Perfect score
      }

      // 4. CSV Export produces complete attendance & marks report
      final csvData = teacherNotifier.exportSessionToCsv(finalActiveSession);
      expect(csvData, contains('Student 001'));
      expect(csvData, contains('Student 002'));
      expect(csvData, contains('Student 003'));
      expect(csvData, contains('Student 004'));
      expect(csvData, contains('Student 005'));
      expect(csvData, contains('YES,YES,GRADED'));
    });
  });
}
