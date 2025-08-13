import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codecraft_project/models/user_progress.dart';

class DatabaseService {
  final String uid;
  DatabaseService({required this.uid});

  Stream<UserProgress> get userProgress {
    return FirebaseFirestore.instance
        .collection('user_progress')
        .doc(uid)
        .snapshots()
        .map((doc) {
      final data = doc.data()!;
      return UserProgress.fromMap(data);
    });
  }
}
