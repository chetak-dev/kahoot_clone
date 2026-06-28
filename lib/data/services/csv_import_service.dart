// lib/data/services/csv_import_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/question_model.dart';
import 'file_saver_io.dart' if (dart.library.html) 'file_saver_web.dart';


class CsvImportService {
  // ── Sample CSV ───────────────────────────────────────────────────────────────
  // Column order: type, time_limit, points, then the question content.
  // Points are numeric (10 / 100 / 1000).
  static const String sampleCsvContent =
  '''type,time_limit,points,question,option_a,option_b,option_c,option_d,correct_answers
mcq,30,1000,What is the capital of France?,Paris,London,Berlin,Madrid,A
truefalse,20,100,Is the Earth flat?,,,,,False
mcq,15,10,Which planet is known as the Red Planet?,Venus,Mars,Jupiter,Saturn,B''';


  /// Opens Android's "Save As" dialog (Storage Access Framework) so the user
  /// picks the location, then writes the sample CSV there.
  static Future<void> downloadSampleCsv() async {
    try {
      final Uint8List bytes =
      Uint8List.fromList(utf8.encode(sampleCsvContent));
      // Web -> browser download; mobile/desktop -> system "Save As".
      // (FilePicker.saveFile is unsupported on web.)
      await saveCsvFile('sample_quiz.csv', bytes);
    } catch (e) {
      debugPrint('Error saving sample CSV: $e');
      rethrow;
    }
  }


  // ── Import CSV ───────────────────────────────────────────────────────────────

  /// Opens file picker, reads the CSV, returns parsed QuestionModel list
  static Future<List<QuestionModel>?> importFromCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
        withData: true, // ensures bytes are available
      );

      if (result == null || result.files.isEmpty) return null;

      final bytes = result.files.first.bytes;
      if (bytes == null) return null;

      final csvContent = utf8.decode(bytes);
      return parseCsvToQuestions(csvContent);
    } catch (e) {
      debugPrint('Error importing CSV: $e');
      rethrow;
    }
  }

  /// Parses CSV string into a list of QuestionModel
  static List<QuestionModel> parseCsvToQuestions(String csvContent) {
    // One real line per question (independent of any eol setting).
        final lines = const LineSplitter()
        .convert(csvContent)
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.length < 2) return []; // need header + at least one data row


    final headers =
    _splitCsvLine(lines.first).map((h) => h.trim().toLowerCase()).toList();
    int col(String name) => headers.indexOf(name);

    final List<QuestionModel> questions = [];

    for (int i = 1; i < lines.length; i++) {
      try {
        final row = _splitCsvLine(lines[i]);
        if (row.isEmpty) continue;

        // Safe read: never throws even if the row is short.
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
            ? correctRaw
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
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
          id: 'csv_${i}_${DateTime.now().millisecondsSinceEpoch}',
          question: questionText,
          type: type,
          options: options,
          correctAnswers: resolvedCorrect,
          timeLimitSeconds: int.tryParse(get('time_limit')) ?? 30,
          points: _parsePoints(get('points')),
        ));
      } catch (e) {
        // Skip a malformed row instead of failing the whole import.
        debugPrint('Skipping CSV row ${i + 1}: $e');
        continue;
      }
    }

    return questions;
  }

  /// Splits one CSV line into fields, honoring "quoted, fields" and "" escapes.
  /// Never throws a RangeError.
  static List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"'); // escaped double-quote
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }



  static QuestionType _parseType(String raw) {
    switch (raw) {
      case 'truefalse':
      case 'true_false':
      case 'tf':
        return QuestionType.trueFalse;
      case 'mcq':
      case 'multiplechoice':
      case 'multiple_choice':
      default:
        return QuestionType.mcq;
    }
  }

  static int _parsePoints(String raw) {
    // New numeric format (10 / 100 / 1000).
    final n = int.tryParse(raw.trim());
    if (n != null) return n;
    // Backward compatibility with the old enum names.
    switch (raw.toLowerCase()) {
      case 'double':
        return 2000;
      case 'none':
        return 0;
      case 'standard':
      default:
        return 1000;
    }
  }

}
