// lib/presentation/create_quiz/add_question_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/question_model.dart';
import '../../data/services/quiz_provider.dart';

class AddQuestionScreen extends ConsumerStatefulWidget {
  final QuestionModel? questionToEdit;
  final int? editIndex;
  const AddQuestionScreen({super.key, this.questionToEdit, this.editIndex});

  @override
  ConsumerState<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends ConsumerState<AddQuestionScreen> {
  final _questionController = TextEditingController();

  QuestionType _selectedType = QuestionType.mcq;
  int _timeLimit = 20;
  int _points = 1000;

  final List<TextEditingController> _optionControllers =
  List.generate(4, (_) => TextEditingController());
  int _correctIndex = 0;

  bool _trueFalseAnswer = true;

  bool get _isEditing => widget.questionToEdit != null;

  @override
  void initState() {
    super.initState();
    final q = widget.questionToEdit;
    if (q != null) {
      _questionController.text = q.question;
      _selectedType = q.type;
      _timeLimit = q.timeLimitSeconds;
      _points = _pointsToInt(q.points);
      for (int i = 0; i < q.options.length && i < _optionControllers.length; i++) {
        _optionControllers[i].text = q.options[i];
      }
      if (q.type == QuestionType.mcq && q.correctAnswers.isNotEmpty) {
        final idx = q.options.indexOf(q.correctAnswers.first);
        _correctIndex = idx >= 0 ? idx : 0;
      } else if (q.type == QuestionType.trueFalse) {
        _trueFalseAnswer = q.correctAnswers.isNotEmpty &&
            q.correctAnswers.first.toLowerCase() == 'true';
      }
    }
  }

  int _pointsToInt(PointsType p) {
    switch (p) {
      case PointsType.none:
        return 0;
      case PointsType.double:
        return 2000;
      case PointsType.standard:
        return 1000;
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _saveQuestion() {
    if (_questionController.text.trim().isEmpty) {
      _showSnack('Please enter a question');
      return;
    }

    List<String> allOptions = [];
    List<String> correctAnswers = [];

    switch (_selectedType) {
      case QuestionType.mcq:
        allOptions = _optionControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();
        if (allOptions.length < 2) {
          _showSnack('Please enter at least 2 options');
          return;
        }
        correctAnswers = [
          _correctIndex < allOptions.length
              ? allOptions[_correctIndex]
              : allOptions[0]
        ];
        break;

      case QuestionType.trueFalse:
        allOptions = ['True', 'False'];
        correctAnswers = [_trueFalseAnswer ? 'True' : 'False'];
        break;
    }

    final question = QuestionModel(
      id: widget.questionToEdit?.id ?? const Uuid().v4(),
      question: _questionController.text.trim(),
      type: _selectedType,
      options: allOptions,
      correctAnswers: correctAnswers,
      timeLimitSeconds: _timeLimit,
      points: _points == 0
          ? PointsType.none
          : _points == 2000
          ? PointsType.double
          : PointsType.standard,
    );

    final editor = ref.read(quizEditorProvider.notifier);
    if (widget.editIndex != null) {
      editor.updateQuestion(widget.editIndex!, question);
    } else {
      editor.addQuestion(question);
    }
    context.pop();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(_isEditing ? 'Edit Question' : 'Add Question',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saveQuestion,
            child: Text(_isEditing ? 'Save' : 'Add',
                style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _questionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Question',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.accent),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Question Type',
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: QuestionType.values.map((type) {
                final isSelected = _selectedType == type;
                return ChoiceChip(
                  label: Text(_typeLabel(type)),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedType = type),
                  selectedColor: AppTheme.accent,
                  backgroundColor: Colors.white10,
                  labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            _buildAnswerSection(),
            const SizedBox(height: 20),

            const Text('Time Limit',
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [5, 10, 20, 30, 60, 120].map((t) {
                final isSelected = _timeLimit == t;
                return ChoiceChip(
                  label: Text('${t}s'),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _timeLimit = t),
                  selectedColor: AppTheme.accent,
                  backgroundColor: Colors.white10,
                  labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            const Text('Points',
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [0, 1000, 2000].map((p) {
                final isSelected = _points == p;
                return ChoiceChip(
                  label: Text(p == 0 ? 'No Points' : '$p pts'),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _points = p),
                  selectedColor: AppTheme.accent,
                  backgroundColor: Colors.white10,
                  labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerSection() {
    switch (_selectedType) {
      case QuestionType.mcq:
        return _buildMcqSection();
      case QuestionType.trueFalse:
        return _buildTrueFalseSection();
    }
  }

  Widget _buildMcqSection() {
    final colors = [Colors.red, Colors.blue, Colors.yellow, Colors.green];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Answer Options (tap the colored box to mark the correct one)',
            style: TextStyle(
                color: Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...List.generate(4, (index) {
          final isCorrect = _correctIndex == index;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isCorrect ? colors[index].withOpacity(0.25) : Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isCorrect ? colors[index] : Colors.transparent),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _correctIndex = index),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors[index],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                    child: isCorrect
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _optionControllers[index],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Option ${index + 1}',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTrueFalseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Correct Answer',
            style: TextStyle(
                color: Colors.white70, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _trueFalseAnswer = true),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _trueFalseAnswer
                        ? Colors.green.withOpacity(0.25)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _trueFalseAnswer
                            ? Colors.green
                            : Colors.transparent),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          color: _trueFalseAnswer
                              ? Colors.green
                              : Colors.white54),
                      const SizedBox(width: 8),
                      const Text('True',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _trueFalseAnswer = false),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: !_trueFalseAnswer
                        ? Colors.red.withOpacity(0.25)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: !_trueFalseAnswer
                            ? Colors.red
                            : Colors.transparent),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cancel,
                          color: !_trueFalseAnswer
                              ? Colors.red
                              : Colors.white54),
                      const SizedBox(width: 8),
                      const Text('False',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _typeLabel(QuestionType type) {
    switch (type) {
      case QuestionType.mcq:
        return 'Multiple Choice';
      case QuestionType.trueFalse:
        return 'True / False';
    }
  }
}
