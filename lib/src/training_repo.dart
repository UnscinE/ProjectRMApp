// lib/src/training_repo.dart
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
        if (displayName != null && displayName.isNotEmpty)
          'displayName': displayName,
        if (email != null && email.isNotEmpty) 'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// (เลิกใช้) เดิมเราเคยเก็บ target_km / training_weeks ใน users/{uid}
  /// ตอนนี้ย้ายไปเก็บใน collection: program แล้ว
  static Future<Map<String, dynamic>?> fetchPrefs(String uid) async {
    final doc = await _col.doc(uid).get();
    return doc.data();
  }

  // ---------- โปรไฟล์ร่างกาย ----------
  static Stream<DocumentSnapshot<Map<String, dynamic>>> userDocStream(
    String uid,
  ) => _col.doc(uid).snapshots();

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
      return Future.value();
    }
    return _col.doc(uid).set(data, SetOptions(merge: true));
  }

  // สมมติ: Program ID ปัจจุบันถูกเก็บอยู่ใน Document 'config' ภายใต้ Sub-Collection 'Program_Config'
  static Future<List?> fetchCurrentProgramId(String uid) async {
    try {
      final userConfigDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('Program')
          .get();

      final programIds = userConfigDoc.docs.map((doc) => doc.id).toList();

      // ถ้าไม่พบการตั้งค่าปัจจุบัน
      return programIds;
    } catch (e) {
      print("❌ Error fetching current program ID for user $uid: $e");
      return null;
    }
  }
}

/// ====== Program Repo (ใหม่) ======
/// เก็บโปรแกรมฝึกลง collection: program (แยกจาก users)
class ProgramRepo {
  static final _programCol = FirebaseFirestore.instance.collection('program');

  /// สร้าง/บันทึกโปรแกรมที่ผู้ใช้เพิ่งกดลงปฏิทิน
  ///
  /// - แนะนำให้ใช้ autoId 1 เอกสารต่อ 1 ครั้งที่ผู้ใช้เริ่มโปรแกรม
  /// - field สำคัญ:
  ///   userId, startDate, totalWeeks, targetKm, calendarId, calendarTitle,
  ///   source('device_calendar'|'ics'), planSnapshot (เก็บ snapshot ของแผน)
  static Future<String> createProgram({
    required String userId,
    required DateTime startDate,
    required int totalWeeks,
    required int targetKm,
    String? calendarId,
    String? calendarTitle,
    required String source, // 'device_calendar' | 'ics'
    required List<List<Map<String, String>>> planSnapshot,
  }) async {
    final doc = _programCol.doc(); // auto id
    await doc.set({
      'userId': userId,
      'startDate': Timestamp.fromDate(startDate),
      'totalWeeks': totalWeeks,
      'targetKm': targetKm,
      'calendarId': calendarId,
      'calendarTitle': calendarTitle,
      'source': source,
      'status': 'active', // เผื่ออนาคตจะมี completed / cancelled
      'createdAt': FieldValue.serverTimestamp(),
      // เก็บ snapshot ของแผนแบบ lightweight (string ๆ)
      'planSnapshot': planSnapshot,
    });
    return doc.id;
  }

  /// ดึงโปรแกรมล่าสุดของผู้ใช้ (active ตัวล่าสุด)
  static Future<QueryDocumentSnapshot<Map<String, dynamic>>?> fetchLatestActive(
    String userId,
  ) async {
    final q = await _programCol
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    return q.docs.isEmpty ? null : q.docs.first;
  }
}
