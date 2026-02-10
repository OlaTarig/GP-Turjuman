import 'package:cloud_firestore/cloud_firestore.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> updateUserFields(String userId, Map<String, dynamic> data) async {
    await _firestore
        .collection('User')
        .doc(userId)
        .set(data, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserDoc(String userId) async {
    final doc = await _firestore.collection('User').doc(userId).get();
    return doc.data();
  }
}