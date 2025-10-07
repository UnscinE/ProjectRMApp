import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingRepo {
  static final _users = FirebaseFirestore.instance.collection('users');

  // อ่านค่าการตั้งค่า ของผู้ใช้คนนี้
  static Future<Map<String, dynamic>?> fetchPrefs(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.data();
  }

  // เซตระยะทาง (km)
  static Future<void> setTargetKm(String uid, int km) {
    return _users.doc(uid).set({'target_km': km}, SetOptions(merge: true));
  }

  // เซตจำนวนสัปดาห์
  static Future<void> setTrainingWeeks(String uid, int weeks) {
    return _users.doc(uid).set({'training_weeks': weeks}, SetOptions(merge: true));
  }
}

