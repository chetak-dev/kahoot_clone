import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/question_model.dart';
import 'file_saver_io.dart' if (dart.library.html) 'file_saver_web.dart';

/// Imports quiz questions from an Excel (.xlsx) file, and generates a sample
/// template. Column order is flexible — everything is resolved by header name.
class ExcelImportService {
  static const String _xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static const List<String> _headers = [
    'type', 'time_limit', 'points', 'question',
    'option_a', 'option_b', 'option_c', 'option_d', 'correct_answers',
  ];

  static const List<List<String>> _sampleRows = [
    ['mcq', '30', '1000', 'What is the capital of France?', 'Paris', 'London',
      'Berlin', 'Madrid', 'A'],
    ['truefalse', '20', '100', 'Is the Earth flat?', '', '', '', '', 'False'],
    ['mcq', '15', '10', 'Which planet is known as the Red Planet?', 'Venus',
      'Mars', 'Jupiter', 'Saturn', 'B'],
  ];

  // ── Generate & download a sample .xlsx ───────────────────────────────────────
  static Future<void> downloadSampleExcel() async {
    try {
      final excel = Excel.createExcel();
      final sheetName = excel.getDefaultSheet() ?? 'Sheet1';

      excel.appendRow(
          sheetName, _headers.map<CellValue?>((h) => TextCellValue(h)).toList());
      for (final row in _sampleRows) {
        excel.appendRow(
            sheetName, row.map<CellValue?>((c) => TextCellValue(c)).toList());
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to build the Excel file.');
      await saveBytesFile(
        'sample_quiz.xlsx',
        Uint8List.fromList(bytes),
        mimeType: _xlsxMime,
        extensions: const ['xlsx'],
      );
    } catch (e) {
      debugPrint('Error generating sample Excel: $e');
      rethrow;
    }
  }

  // ── Import from an Excel file ─────────────────────────────────────────────────
  static Future<List<QuestionModel>?> importQuestions() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;
      final bytes = result.files.first.bytes;
      if (bytes == null) return null;
      return parseExcelToQuestions(bytes);
    } catch (e) {
      debugPrint('Error importing questions: $e');
      rethrow;
    }
  }

  static List<QuestionModel> parseExcelToQuestions(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) return [];

    final table = <List<String>>[];
    for (final row in sheet.rows) {
      final cells = row.map((cell) => _cellToString(cell?.value)).toList();
      if (cells.every((c) => c.trim().isEmpty)) continue;
      table.add(cells);
    }
    if (table.length < 2) return [];
    return _tableToQuestions(table);
  }

  static List<QuestionModel> _tableToQuestions(List<List<String>> table) {
    final headers = table.first.map((h) => h.trim().toLowerCase()).toList();
    int col(String name) => headers.indexOf(name);

    final List<QuestionModel> questions = [];
    for (int i = 1; i < table.length; i++) {
      try {
        final row = table[i];
        if (row.isEmpty) continue;

        String get(String name) {
          final idx = col(name);
          if (idx < 0 || idx >= row.length) return '';
          return row[idx].trim();
        }

        final questionText = get('question');
        if (questionText.isEmpty) continue;

        final type = _parseType(get('type').toLowerCase());
        final optionA = get('option_a');
        final optionB = get('option_b');
        final optionC = get('option_c');
        final optionD = get('option_d');

        final options = [optionA, optionB, optionC, optionD]
            .where((o) => o.isNotEmpty)
            .toList();

        final correctRaw = get('correct_answers');
        final correctAnswers = correctRaw.isNotEmpty
            ? correctRaw.split(',').map((s) => s.trim())
            .where((s) => s.isNotEmpty).toList()
            : <String>[];

        final resolvedCorrect = type == QuestionType.mcq
            ? correctAnswers.map((letter) {
          switch (letter.toUpperCase()) {
            case 'A': return optionA;
            case 'B': return optionB;
            case 'C': return optionC;
            case 'D': return optionD;
            default: return letter;
          }
        }).where((o) => o.isNotEmpty).toList()
            : correctAnswers;

        questions.add(QuestionModel(
          id: 'import_${i}_${DateTime.now().millisecondsSinceEpoch}',
          question: questionText,
          type: type,
          options: options,
          correctAnswers: resolvedCorrect,
          timeLimitSeconds: _toInt(get('time_limit'), 30),
          points: _parsePoints(get('points')),
        ));
      } catch (e) {
        debugPrint('Skipping row ${i + 1}: $e');
        continue;
      }
    }
    return questions;
  }

  static String _cellToString(CellValue? value) {
    if (value == null) return '';
    if (value is TextCellValue) return value.value.toString();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is BoolCellValue) return value.value.toString();
    if (value is FormulaCellValue) return value.formula.toString();
    return value.toString();
  }

  static QuestionType _parseType(String raw) {
    switch (raw) {
      case 'truefalse':
      case 'true_false':
      case 'tf':
        return QuestionType.trueFalse;
      default:
        return QuestionType.mcq;
    }
  }

  static int _toInt(String raw, int fallback) {
    final n = int.tryParse(raw.trim());
    if (n != null) return n;
    final d = double.tryParse(raw.trim());
    if (d != null) return d.toInt();
    return fallback;
  }

  static int _parsePoints(String raw) {
    final n = int.tryParse(raw.trim());
    if (n != null) return n;
    final d = double.tryParse(raw.trim());
    if (d != null) return d.toInt();
    switch (raw.toLowerCase()) {
      case 'double': return 2000;
      case 'none': return 0;
      default: return 1000;
    }
  }
}
