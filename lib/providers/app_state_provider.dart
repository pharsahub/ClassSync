import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/id_generator.dart';
import '../models/answer.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import '../models/session.dart';
import '../models/student.dart';
import '../models/submission.dart';

enum UserRole {
  teacher,
  student,
}

class AppStateProvider extends ChangeNotifier {
  UserRole _currentRole = UserRole.teacher;
  UserRole get currentRole => _currentRole;

  // Quizzes list
  final List<Quiz> _quizzes = [];
  List<Quiz> get quizzes => List.unmodifiable(_quizzes);

  // Active session
  Session? _activeSession;
  Session? get activeSession => _activeSession;

  // Completed sessions history
  final List<Session> _completedSessions = [];
  List<Session> get completedSessions => List.unmodifiable(_completedSessions);

  // Current student session state
  Student? _currentStudent;
  Student? get currentStudent => _currentStudent;

  // Student active answers map: questionId -> optionIndex
  final Map<String, int> _studentAnswers = {};
  Map<String, int> get studentAnswers => Map.unmodifiable(_studentAnswers);

  // Latest student submission
  Submission? _latestSubmission;
  Submission? get latestSubmission => _latestSubmission;

  AppStateProvider() {
    _seedSampleData();
  }

  void setRole(UserRole role) {
    _currentRole = role;
    notifyListeners();
  }

  void _seedSampleData() {
    final sampleQuiz1 = Quiz(
      id: 'quiz_dsa_101',
      title: 'Data Structures & Algorithms Basics',
      description: 'Covers Big-O notation, binary search trees, hashing, and arrays.',
      timeLimitMinutes: 10,
      questions: [
        Question(
          id: 'q1_dsa',
          quizId: 'quiz_dsa_101',
          text: 'What is the average time complexity of searching an element in a Balanced Binary Search Tree (BST)?',
          type: QuestionType.mcq,
          options: ['O(1)', 'O(log n)', 'O(n)', 'O(n log n)'],
          correctOptionIndex: 1,
          marks: 2,
          explanation: 'A balanced BST divides search space in half at each step, resulting in O(log n) time.',
        ),
        Question(
          id: 'q2_dsa',
          quizId: 'quiz_dsa_101',
          text: 'Which data structure operates on a First-In, First-Out (FIFO) principle?',
          type: QuestionType.mcq,
          options: ['Stack', 'Queue', 'Priority Queue', 'Deque'],
          correctOptionIndex: 1,
          marks: 2,
          explanation: 'Queues process elements in the order they arrive (FIFO).',
        ),
        Question(
          id: 'q3_dsa',
          quizId: 'quiz_dsa_101',
          text: 'In Python and Dart, hash table lookups have an average time complexity of O(1).',
          type: QuestionType.trueFalse,
          options: ['True', 'False'],
          correctOptionIndex: 0,
          marks: 1,
          explanation: 'Hash maps provide constant average-time O(1) key lookups with a good hash distribution.',
        ),
        Question(
          id: 'q4_dsa',
          quizId: 'quiz_dsa_101',
          text: 'What happens when two distinct keys produce the same hash value in a hash table?',
          type: QuestionType.mcq,
          options: ['Stack Overflow', 'Hash Collision', 'Segmentation Fault', 'Deadlock'],
          correctOptionIndex: 1,
          marks: 2,
          explanation: 'When two keys map to the same bucket index, it is called a Hash Collision.',
        ),
        Question(
          id: 'q5_dsa',
          quizId: 'quiz_dsa_101',
          text: 'Which sorting algorithm has the worst-case time complexity of O(n²)?',
          type: QuestionType.mcq,
          options: ['Merge Sort', 'Heap Sort', 'Quick Sort', 'Counting Sort'],
          correctOptionIndex: 2,
          marks: 2,
          explanation: 'Standard Quick Sort degrades to O(n²) when the pivot selection is unbalanced.',
        ),
      ],
    );

    final sampleQuiz2 = Quiz(
      id: 'quiz_net_201',
      title: 'Computer Networks & Protocols',
      description: 'Fundamental quiz on OSI model, TCP/IP, DNS, and HTTP/HTTPS protocols.',
      timeLimitMinutes: 15,
      questions: [
        Question(
          id: 'q1_net',
          quizId: 'quiz_net_201',
          text: 'Which OSI layer is responsible for end-to-end reliable communication and flow control?',
          type: QuestionType.mcq,
          options: ['Network Layer', 'Transport Layer', 'Data Link Layer', 'Session Layer'],
          correctOptionIndex: 1,
          marks: 2,
          explanation: 'The Transport Layer (Layer 4) handles reliable data transfer (e.g., TCP) and flow control.',
        ),
        Question(
          id: 'q2_net',
          quizId: 'quiz_net_201',
          text: 'UDP provides guaranteed packet delivery and ordered sequencing.',
          type: QuestionType.trueFalse,
          options: ['True', 'False'],
          correctOptionIndex: 1,
          marks: 1,
          explanation: 'UDP is connectionless and does not guarantee delivery or packet ordering.',
        ),
        Question(
          id: 'q3_net',
          quizId: 'quiz_net_201',
          text: 'What is the default port for HTTPS traffic?',
          type: QuestionType.mcq,
          options: ['80', '8080', '443', '22'],
          correctOptionIndex: 2,
          marks: 2,
          explanation: 'Port 443 is reserved for secure HTTPS traffic.',
        ),
      ],
    );

    _quizzes.add(sampleQuiz1);
    _quizzes.add(sampleQuiz2);

    // Seed a sample completed session for review
    final sampleCompletedSession = Session(
      id: 'session_demo_past',
      quizId: sampleQuiz1.id,
      quiz: sampleQuiz1,
      sessionCode: 'CS-1092',
      teacherId: 'teacher_alex',
      teacherName: AppConstants.defaultTeacherName,
      status: SessionStatus.completed,
      startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      connectedStudents: [
        Student(
          id: 'std_01',
          name: 'Amina Al-Mansoor',
          rollNumber: 'CS23-014',
          status: StudentStatus.submitted,
          score: 9,
          currentQuestionIndex: 5,
        ),
        Student(
          id: 'std_02',
          name: 'Devon Vance',
          rollNumber: 'CS23-029',
          status: StudentStatus.submitted,
          score: 7,
          currentQuestionIndex: 5,
        ),
        Student(
          id: 'std_03',
          name: 'Elena Rostova',
          rollNumber: 'CS23-041',
          status: StudentStatus.submitted,
          score: 9,
          currentQuestionIndex: 5,
        ),
      ],
      submissions: [
        Submission(
          id: 'sub_01',
          sessionId: 'session_demo_past',
          quizId: sampleQuiz1.id,
          studentId: 'std_01',
          studentName: 'Amina Al-Mansoor',
          studentRollNumber: 'CS23-014',
          score: 9,
          totalPossibleMarks: sampleQuiz1.totalMarks,
          answers: {
            'q1_dsa': Answer(questionId: 'q1_dsa', selectedOptionIndex: 1, isCorrect: true, marksAwarded: 2),
            'q2_dsa': Answer(questionId: 'q2_dsa', selectedOptionIndex: 1, isCorrect: true, marksAwarded: 2),
            'q3_dsa': Answer(questionId: 'q3_dsa', selectedOptionIndex: 0, isCorrect: true, marksAwarded: 1),
            'q4_dsa': Answer(questionId: 'q4_dsa', selectedOptionIndex: 1, isCorrect: true, marksAwarded: 2),
            'q5_dsa': Answer(questionId: 'q5_dsa', selectedOptionIndex: 2, isCorrect: true, marksAwarded: 2),
          },
          status: SubmissionStatus.graded,
        ),
        Submission(
          id: 'sub_02',
          sessionId: 'session_demo_past',
          quizId: sampleQuiz1.id,
          studentId: 'std_02',
          studentName: 'Devon Vance',
          studentRollNumber: 'CS23-029',
          score: 7,
          totalPossibleMarks: sampleQuiz1.totalMarks,
          answers: {
            'q1_dsa': Answer(questionId: 'q1_dsa', selectedOptionIndex: 1, isCorrect: true, marksAwarded: 2),
            'q2_dsa': Answer(questionId: 'q2_dsa', selectedOptionIndex: 1, isCorrect: true, marksAwarded: 2),
            'q3_dsa': Answer(questionId: 'q3_dsa', selectedOptionIndex: 0, isCorrect: true, marksAwarded: 1),
            'q4_dsa': Answer(questionId: 'q4_dsa', selectedOptionIndex: 0, isCorrect: false, marksAwarded: 0),
            'q5_dsa': Answer(questionId: 'q5_dsa', selectedOptionIndex: 2, isCorrect: true, marksAwarded: 2),
          },
          status: SubmissionStatus.graded,
        ),
      ],
    );

    _completedSessions.add(sampleCompletedSession);
  }

  // -------------------------------------------------------------
  // TEACHER ACTIONS
  // -------------------------------------------------------------

  void createQuiz(Quiz quiz) {
    _quizzes.add(quiz);
    notifyListeners();
  }

  void deleteQuiz(String quizId) {
    _quizzes.removeWhere((q) => q.id == quizId);
    if (_activeSession?.quizId == quizId) {
      _activeSession = null;
    }
    notifyListeners();
  }

  Session startSession(String quizId) {
    final quiz = _quizzes.firstWhere(
      (q) => q.id == quizId,
      orElse: () => _quizzes.first,
    );

    final sessionCode = IdGenerator.generateSessionCode();
    final newSession = Session(
      id: IdGenerator.generate('session'),
      quizId: quiz.id,
      quiz: quiz,
      sessionCode: sessionCode,
      teacherId: 'teacher_1',
      teacherName: AppConstants.defaultTeacherName,
      status: SessionStatus.waiting,
      connectedStudents: [],
      submissions: [],
    );

    _activeSession = newSession;
    notifyListeners();
    return newSession;
  }

  void startQuizForSession() {
    if (_activeSession == null) return;
    _activeSession = _activeSession!.copyWith(status: SessionStatus.inProgress);
    // Update any connected students to inProgress
    final updatedStudents = _activeSession!.connectedStudents.map((s) {
      return s.copyWith(status: StudentStatus.inProgress);
    }).toList();

    _activeSession = _activeSession!.copyWith(connectedStudents: updatedStudents);
    notifyListeners();
  }

  void endSession() {
    if (_activeSession == null) return;
    final finalized = _activeSession!.copyWith(status: SessionStatus.completed);
    _completedSessions.insert(0, finalized);
    _activeSession = null;
    notifyListeners();
  }

  // -------------------------------------------------------------
  // STUDENT ACTIONS
  // -------------------------------------------------------------

  bool joinSession({
    required String sessionCode,
    required String studentName,
    required String rollNumber,
  }) {
    if (_activeSession == null) return false;
    if (_activeSession!.sessionCode.toUpperCase().trim() !=
        sessionCode.toUpperCase().trim()) {
      return false;
    }

    // Check if student already in session
    final existingIndex = _activeSession!.connectedStudents.indexWhere(
      (s) => s.rollNumber.toLowerCase() == rollNumber.toLowerCase(),
    );

    Student student;
    if (existingIndex >= 0) {
      student = _activeSession!.connectedStudents[existingIndex];
    } else {
      student = Student(
        id: IdGenerator.generate('std'),
        name: studentName,
        rollNumber: rollNumber,
        status: _activeSession!.status == SessionStatus.inProgress
            ? StudentStatus.inProgress
            : StudentStatus.notStarted,
      );

      final updatedList = List<Student>.from(_activeSession!.connectedStudents)..add(student);
      _activeSession = _activeSession!.copyWith(connectedStudents: updatedList);
    }

    _currentStudent = student;
    _studentAnswers.clear();
    _latestSubmission = null;
    notifyListeners();
    return true;
  }

  void recordAnswer(String questionId, int selectedOptionIndex) {
    _studentAnswers[questionId] = selectedOptionIndex;
    if (_currentStudent != null && _activeSession != null) {
      final updatedList = _activeSession!.connectedStudents.map((s) {
        if (s.id == _currentStudent!.id) {
          return s.copyWith(
            currentQuestionIndex: _studentAnswers.length,
            status: StudentStatus.inProgress,
          );
        }
        return s;
      }).toList();
      _activeSession = _activeSession!.copyWith(connectedStudents: updatedList);
    }
    notifyListeners();
  }

  Submission submitQuiz() {
    if (_activeSession == null || _currentStudent == null || _activeSession!.quiz == null) {
      throw Exception('No active session or student found.');
    }

    final quiz = _activeSession!.quiz!;
    int totalScore = 0;
    final Map<String, Answer> answerRecords = {};

    for (final q in quiz.questions) {
      final selected = _studentAnswers[q.id];
      final isCorrect = selected != null && selected == q.correctOptionIndex;
      final marks = isCorrect ? q.marks : 0;
      totalScore += marks;

      answerRecords[q.id] = Answer(
        questionId: q.id,
        selectedOptionIndex: selected,
        isCorrect: isCorrect,
        marksAwarded: marks,
      );
    }

    final submission = Submission(
      id: IdGenerator.generate('sub'),
      sessionId: _activeSession!.id,
      quizId: quiz.id,
      studentId: _currentStudent!.id,
      studentName: _currentStudent!.name,
      studentRollNumber: _currentStudent!.rollNumber,
      score: totalScore,
      totalPossibleMarks: quiz.totalMarks,
      answers: answerRecords,
      status: SubmissionStatus.graded,
      submittedAt: DateTime.now(),
    );

    _latestSubmission = submission;

    // Update student in active session
    final updatedStudents = _activeSession!.connectedStudents.map((s) {
      if (s.id == _currentStudent!.id) {
        return s.copyWith(
          status: StudentStatus.submitted,
          score: totalScore,
          submittedAt: DateTime.now(),
        );
      }
      return s;
    }).toList();

    // Add submission to active session
    final updatedSubmissions = List<Submission>.from(_activeSession!.submissions)
      ..removeWhere((sub) => sub.studentId == _currentStudent!.id)
      ..add(submission);

    _activeSession = _activeSession!.copyWith(
      connectedStudents: updatedStudents,
      submissions: updatedSubmissions,
    );

    notifyListeners();
    return submission;
  }

  void resetStudentSession() {
    _currentStudent = null;
    _studentAnswers.clear();
    _latestSubmission = null;
    notifyListeners();
  }
}
