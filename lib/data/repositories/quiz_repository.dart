import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quiz_model.dart';

class QuizRepository {
  final _firestore = FirebaseFirestore.instance;

  // Save quiz to Firestore
  Future<void> saveQuiz(QuizModel quiz) async {
    await _firestore
        .collection('quizzes')
        .doc(quiz.id)
        .set(quiz.toMap());
  }

  // Get all quizzes by creator
  Future<List<QuizModel>> getMyQuizzes(String creatorId) async {
    final snapshot = await _firestore
        .collection('quizzes')
        .where('creatorId', isEqualTo: creatorId)
        .get();
    return snapshot.docs
        .map((doc) => QuizModel.fromMap(doc.data()))
        .toList();
  }

  // Delete quiz
  Future<void> deleteQuiz(String id) async {
    await _firestore.collection('quizzes').doc(id).delete();
  }

  Stream<List<QuizModel>> watchMyQuizzes(String uid) {
    return _firestore
        .collection('quizzes')
        .where('creatorId', isEqualTo: uid)  // ✅ also fixed: creatorId not createdBy
        .snapshots()
        .map((s) => s.docs
        .map((d) => QuizModel.fromMap(d.data()))  // ✅ removed d.id
        .toList());
  }
}