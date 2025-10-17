// lib/training_repo.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingRepo {
  static final _col = FirebaseFirestore.instance.collection('users');

  /// เรียกครั้งแรกหลังล็อกอิน เพื่อสร้างเอกสาร users/{uid} ถ้ายังไม่มี
  static Future<void> ensureUserDocExists({
    required String uid,
    String? displayName,
    String? email,
  }) async {
    final ref = _col.doc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
        if (email != null && email.isNotEmpty) 'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // ---------- อ่าน/เขียน KM & Weeks ----------
  static Future<void> setTargetKm(String uid, int km) =>
      _col.doc(uid).set(
        {'target_km': km, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

  static Future<void> setTrainingWeeks(String uid, int weeks) =>
      _col.doc(uid).set(
        {'training_weeks': weeks, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

  static Future<Map<String, dynamic>?> fetchPrefs(String uid) async {
    final doc = await _col.doc(uid).get();
    return doc.data();
  }

  // ---------- โปรไฟล์ร่างกาย ----------
  static Stream<DocumentSnapshot<Map<String, dynamic>>> userDocStream(String uid) =>
      _col.doc(uid).snapshots();

  static Future<void> updateProfile(
    String uid, {
    String? displayName,
    double? weightKg,
    double? heightCm,
    int? age,
    String? sex, // 'male'|'female'|'other'
    double? bmi,
  }) {
    final data = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (weightKg != null) 'weight_kg': weightKg,
      if (heightCm != null) 'height_cm': heightCm,
      if (age != null) 'age': age,
      if (sex != null) 'sex': sex,
      if (bmi != null) 'bmi': bmi,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (data.length == 1) {
      // มีแค่ updatedAt แปลว่าไม่มีอะไรจะอัปเดต ก็ไม่ต้องยิง
      return Future.value();
    }
    return _col.doc(uid).set(data, SetOptions(merge: true));
  }
}
