// lib/presentation/create_quiz/create_quiz_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/question_model.dart';
import '../../data/models/quiz_model.dart';
import '../../data/repositories/quiz_repository.dart';
import '../../data/services/auth_provider.dart';
import '../../data/services/excel_import_service.dart';
import '../../data/services/quiz_provider.dart';

class CreateQuizScreen extends ConsumerStatefulWidget {
  final bool importCsvOnOpen;
  final QuizModel? quizToEdit;

  const CreateQuizScreen({
    super.key,
    this.importCsvOnOpen = false,
    this.quizToEdit,
  });

  @override
  ConsumerState<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends ConsumerState<CreateQuizScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isImporting = false;
  bool _isSaving = false;

  bool get _isEditing => widget.quizToEdit != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final editor = ref.read(quizEditorProvider.notifier);
      final existing = widget.quizToEdit;
      if (existing != null) {
        _titleController.text = existing.title;
        _descController.text = existing.description;
        editor.setQuestions(existing.questions);
      } else {
        editor.clearAll();
      }
      if (widget.importCsvOnOpen) {
        _importQuestions();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _downloadSample() async {
    try {
      await ExcelImportService.downloadSampleExcel();
    } catch (e) {
      _showError('Could not download sample: $e');
    }
  }

  Future<void> _importQuestions() async {
    setState(() => _isImporting = true);
    try {
      final questions = await ExcelImportService.importQuestions();
      if (questions == null) {
        setState(() => _isImporting = false);
        return;
      }
      if (questions.isEmpty) {
        _showError('No valid questions found in the file.');
        setState(() => _isImporting = false);
        return;
      }
      final editor = ref.read(quizEditorProvider.notifier);
      for (final q in questions) {
        editor.addQuestion(q);
      }
      setState(() => _isImporting = false);
      _showSuccess('${questions.length} question(s) imported!');
    } catch (e) {
      _showError('Failed to import file: $e');
      setState(() => _isImporting = false);
    }
  }


  Future<void> _saveQuiz() async {
    final questions = ref.read(quizEditorProvider);

    if (_titleController.text.trim().isEmpty) {
      _showError('Please enter a quiz title.');
      return;
    }
    if (questions.isEmpty) {
      _showError('Please add at least one question.');
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      _showError('Not logged in.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final existing = widget.quizToEdit;
      final quiz = QuizModel(
        id: existing?.id ?? const Uuid().v4(),
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        creatorId: existing?.creatorId ?? user.uid,
        questions: questions,
        createdAt: existing?.createdAt ?? DateTime.now(),
      );


      await QuizRepository().saveQuiz(quiz);
      ref.read(quizEditorProvider.notifier).clearAll();
      _showSuccess(_isEditing ? 'Quiz updated!' : 'Quiz saved!');
      if (mounted) context.go('/my-quizzes');
    } catch (e) {
      _showError('Failed to save quiz: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHost = ref.watch(isHostProvider);
    if (!isHost) {
      return const Scaffold(
        body: Center(
          child: Text('Access denied.',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final questions = ref.watch(quizEditorProvider);

    return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
        child: Scaffold(
          backgroundColor: AppTheme.background,

          appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(_isEditing ? 'Edit Quiz' : 'Create Quiz',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          _isSaving
              ? const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2),
            ),
          )
              : TextButton(
            onPressed: _saveQuiz,
            child: Text(_isEditing ? 'Update' : 'Save',
                style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader('Quiz Details'),
            const SizedBox(height: 12),
            _StyledTextField(
              controller: _titleController,
              label: 'Quiz Title',
              hint: 'e.g. Science Quiz 2024',
            ),
            const SizedBox(height: 12),
            _StyledTextField(
              controller: _descController,
              label: 'Description (optional)',
              hint: 'What is this quiz about?',
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            _SectionHeader('Import Questions from Excel'),

            const SizedBox(height: 6),
            Text(
              'Download the sample Excel file, fill in your questions, then upload it (.xlsx).',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 13),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _OutlineButton(
                    icon: Icons.download_rounded,
                    label: 'Sample Excel',
                    color: Colors.blueAccent,
                    onTap: _downloadSample,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OutlineButton(
                    icon: Icons.upload_file_rounded,
                    label: 'Upload Excel',
                    color: Colors.orangeAccent,
                    onTap: _isImporting ? null : _importQuestions,
                    isLoading: _isImporting,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionHeader('Questions (${questions.length})'),
                TextButton.icon(
                  onPressed: () => context.push('/add-question'),
                  icon: const Icon(Icons.add,
                      color: AppTheme.accent, size: 18),
                  label: const Text('Add Manually',
                      style: TextStyle(color: AppTheme.accent)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (questions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.list_alt_rounded,
                        color: Colors.white.withOpacity(0.3), size: 40),
                    const SizedBox(height: 8),
                    Text(
                      'No questions yet. Import a CSV or add manually.',
                    textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: questions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final q = questions[index];
                  return _QuestionTile(
                    index: index + 1,
                    question: q,
                    onEdit: () => context.push(
                      '/add-question',
                      extra: {'question': q, 'index': index},
                    ),
                    onDelete: () => ref
                        .read(quizEditorProvider.notifier)
                        .removeQuestion(index),
                  );
                },

              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16));
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  const _StyledTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  const _OutlineButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          color: color.withOpacity(0.08),
        ),
        child: isLoading
            ? Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
                color: color, strokeWidth: 2),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  final int index;
  final QuestionModel question;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionTile({
    required this.index,
    required this.question,
    required this.onEdit,
    required this.onDelete,
  });

  String get _typeLabel {
    switch (question.type) {
      case QuestionType.mcq:
        return 'MCQ';
      case QuestionType.trueFalse:
        return 'True/False';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.accent.withOpacity(0.2),
            child: Text('$index',
                style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question.question,
                    style:
                    const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                // Wrap (not Row) so chips never overflow on narrow screens.
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Chip(_typeLabel, Colors.blueAccent),
                    _Chip('${question.timeLimitSeconds}s',
                        Colors.orangeAccent),
                    _Chip('${question.points} pts', Colors.greenAccent),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Compact buttons so they take less horizontal space.
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.accent),
            tooltip: 'Edit question',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete question',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}



class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
