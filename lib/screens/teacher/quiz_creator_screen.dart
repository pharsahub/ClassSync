import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/id_generator.dart';
import '../../models/question.dart';
import '../../models/quiz.dart';
import '../../providers/app_state_provider.dart';

class QuizCreatorScreen extends StatefulWidget {
  const QuizCreatorScreen({super.key});

  @override
  State<QuizCreatorScreen> createState() => _QuizCreatorScreenState();
}

class _QuizCreatorScreenState extends State<QuizCreatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _timeLimitMinutes = 10;

  final List<_QuestionDraft> _questions = [];

  @override
  void initState() {
    super.initState();
    // Add default initial question
    _addNewQuestion();
  }

  void _addNewQuestion() {
    setState(() {
      _questions.add(_QuestionDraft(
        id: IdGenerator.generate('q'),
        textController: TextEditingController(),
        explanationController: TextEditingController(),
        type: QuestionType.mcq,
        optionControllers: [
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
        ],
        correctOptionIndex: 0,
        marks: 2,
      ));
    });
  }

  void _fillSampleTemplate() {
    setState(() {
      _titleController.text = 'Cybersecurity & Cryptography Essentials';
      _descriptionController.text =
          'Assessment on symmetric/asymmetric encryption, hashing, and authentication protocols.';
      _timeLimitMinutes = 15;

      _questions.clear();
      _questions.addAll([
        _QuestionDraft(
          id: IdGenerator.generate('q'),
          textController: TextEditingController(
            text: 'Which encryption algorithm uses a pair of public and private keys?',
          ),
          explanationController: TextEditingController(
            text: 'Asymmetric cryptography (such as RSA or ECC) uses mathematically linked key pairs.',
          ),
          type: QuestionType.mcq,
          optionControllers: [
            TextEditingController(text: 'AES-256'),
            TextEditingController(text: 'RSA'),
            TextEditingController(text: 'DES'),
            TextEditingController(text: 'Blowfish'),
          ],
          correctOptionIndex: 1,
          marks: 2,
        ),
        _QuestionDraft(
          id: IdGenerator.generate('q'),
          textController: TextEditingController(
            text: 'Cryptographic hash functions are strictly one-way and cannot be easily reversed.',
          ),
          explanationController: TextEditingController(
            text: 'Hashes like SHA-256 are deterministic one-way mathematical functions.',
          ),
          type: QuestionType.trueFalse,
          optionControllers: [
            TextEditingController(text: 'True'),
            TextEditingController(text: 'False'),
          ],
          correctOptionIndex: 0,
          marks: 1,
        ),
        _QuestionDraft(
          id: IdGenerator.generate('q'),
          textController: TextEditingController(
            text: 'What type of attack involves an adversary intercepting and possibly altering communication between two parties?',
          ),
          explanationController: TextEditingController(
            text: 'A Man-in-the-Middle (MitM) attack intercepts messages between two endpoints without their consent.',
          ),
          type: QuestionType.mcq,
          optionControllers: [
            TextEditingController(text: 'SQL Injection'),
            TextEditingController(text: 'Cross-Site Scripting (XSS)'),
            TextEditingController(text: 'Man-in-the-Middle (MitM)'),
            TextEditingController(text: 'Denial of Service (DoS)'),
          ],
          correctOptionIndex: 2,
          marks: 2,
        ),
      ]);
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A quiz must have at least one question.')),
      );
      return;
    }
    setState(() {
      _questions.removeAt(index);
    });
  }

  void _saveQuiz() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all required fields.')),
      );
      return;
    }

    final quizId = IdGenerator.generate('quiz');
    final builtQuestions = _questions.map((draft) {
      final options = draft.type == QuestionType.trueFalse
          ? ['True', 'False']
          : draft.optionControllers.map((c) => c.text.trim()).toList();

      return Question(
        id: draft.id,
        quizId: quizId,
        text: draft.textController.text.trim(),
        type: draft.type,
        options: options,
        correctOptionIndex: draft.correctOptionIndex,
        marks: draft.marks,
        explanation: draft.explanationController.text.trim().isNotEmpty
            ? draft.explanationController.text.trim()
            : null,
      );
    }).toList();

    final newQuiz = Quiz(
      id: quizId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      timeLimitMinutes: _timeLimitMinutes,
      questions: builtQuestions,
      createdAt: DateTime.now(),
    );

    context.read<AppStateProvider>().createQuiz(newQuiz);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Quiz "${newQuiz.title}" created successfully!'),
        backgroundColor: Colors.green.shade700,
      ),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final q in _questions) {
      q.textController.dispose();
      q.explanationController.dispose();
      for (final opt in q.optionControllers) {
        opt.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final totalMarks = _questions.fold(0, (sum, q) => sum + q.marks);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Quiz', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: _fillSampleTemplate,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Quick Template'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _saveQuiz,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save Quiz'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quiz Details',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Quiz Title *',
                              hintText: 'e.g. Operating Systems: Process Synchronization',
                              prefixIcon: Icon(Icons.title),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty ? 'Title is required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description / Instructions (Optional)',
                              hintText: 'Brief instructions for students...',
                              prefixIcon: Icon(Icons.description_outlined),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Duration: $_timeLimitMinutes Minutes',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    Slider(
                                      value: _timeLimitMinutes.toDouble(),
                                      min: 2,
                                      max: 60,
                                      divisions: 29,
                                      label: '$_timeLimitMinutes mins',
                                      onChanged: (val) {
                                        setState(() => _timeLimitMinutes = val.toInt());
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '$totalMarks',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.secondary,
                                      ),
                                    ),
                                    Text(
                                      'Total Marks',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Questions Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Questions (${_questions.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _addNewQuestion,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Question'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Questions List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _questions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      return _buildQuestionCard(index, theme, colorScheme);
                    },
                  ),
                  const SizedBox(height: 32),

                  // Bottom Save Bar
                  Center(
                    child: SizedBox(
                      width: 260,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _saveQuiz,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Publish & Save Quiz', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, ThemeData theme, ColorScheme colorScheme) {
    final draft = _questions[index];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Card Header
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Text(
                  'Question ${index + 1}',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Type selector
                SegmentedButton<QuestionType>(
                  segments: const [
                    ButtonSegment(value: QuestionType.mcq, label: Text('MCQ')),
                    ButtonSegment(value: QuestionType.trueFalse, label: Text('T/F')),
                  ],
                  selected: {draft.type},
                  onSelectionChanged: (selection) {
                    setState(() {
                      draft.type = selection.first;
                      draft.correctOptionIndex = 0;
                    });
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Delete Question',
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => _removeQuestion(index),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Question Prompt
            TextFormField(
              controller: draft.textController,
              decoration: const InputDecoration(
                labelText: 'Question Statement *',
                hintText: 'Enter question text...',
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Question text is required' : null,
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Options Section
            Text(
              draft.type == QuestionType.mcq
                  ? 'Answer Options (Select the radio of the correct answer)'
                  : 'Select Correct Statement',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),

            if (draft.type == QuestionType.mcq) ...[
              for (int optIdx = 0; optIdx < 4; optIdx++) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Radio<int>(
                        value: optIdx,
                        groupValue: draft.correctOptionIndex,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => draft.correctOptionIndex = val);
                          }
                        },
                      ),
                      Text(
                        '${String.fromCharCode(65 + optIdx)}.',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: draft.optionControllers[optIdx],
                          decoration: InputDecoration(
                            hintText: 'Option ${String.fromCharCode(65 + optIdx)}',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? 'Option is required' : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<int>(
                      title: const Text('True'),
                      value: 0,
                      groupValue: draft.correctOptionIndex,
                      onChanged: (val) => setState(() => draft.correctOptionIndex = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<int>(
                      title: const Text('False'),
                      value: 1,
                      groupValue: draft.correctOptionIndex,
                      onChanged: (val) => setState(() => draft.correctOptionIndex = val!),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Marks Awarded'),
                    initialValue: draft.marks,
                    items: [1, 2, 3, 4, 5].map((m) {
                      return DropdownMenuItem(value: m, child: Text('$m Mark${m > 1 ? 's' : ''}'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => draft.marks = val);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: draft.explanationController,
                    decoration: const InputDecoration(
                      labelText: 'Explanation / Solution Note (Optional)',
                      hintText: 'Shown to students during post-test review',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionDraft {
  final String id;
  final TextEditingController textController;
  final TextEditingController explanationController;
  QuestionType type;
  final List<TextEditingController> optionControllers;
  int correctOptionIndex;
  int marks;

  _QuestionDraft({
    required this.id,
    required this.textController,
    required this.explanationController,
    required this.type,
    required this.optionControllers,
    required this.correctOptionIndex,
    required this.marks,
  });
}
