import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // ต้องเพิ่ม package intl ใน pubspec.yaml

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

// ----------------------------------------------------------------------
/// ====== Program Repo (ใหม่ - ปรับปรุงโครงสร้าง) ======
/// เก็บโปรแกรมฝึกลง Subcollection: users/{userId}/Program/{programId}
class ProgramRepo {
  // เปลี่ยนไปใช้ reference จาก _col ของ TrainingRepo
  static final _userCol = FirebaseFirestore.instance.collection('users');

  /// สร้าง/บันทึกโปรแกรมที่ผู้ใช้เพิ่งกดลงปฏิทิน
  ///
  /// **บันทึกที่ Path: `users/{userId}/Program/{autoId}`**
  /// **บันทึก Training รายวันใน Subcollection: `users/{userId}/Program/{programId}/Training/{dateString}`**
  static Future<String> createProgram({
    required String userId,
    required DateTime startDate,
    required int totalWeeks,
    required int targetKm,
    String? calendarId,
    String? calendarTitle,
    required String source, // 'device_calendar' | 'ics'
    required List<List<Map<String, String>>> planSnapshot,
    required List<Map<String, dynamic>>
    dailyTrainings, // <-- ข้อมูล Training รายวัน
  }) async {
    // 1. กำหนด Reference สำหรับ Program Subcollection
    final programColRef = _userCol.doc(userId).collection('Program');

    // 2. สร้างเอกสาร Program หลัก (ใช้ auto id)
    final programDocRef = programColRef.doc(); // auto id
    final programId = programDocRef.id;

    // 3. สร้าง Firestore Batch สำหรับบันทึกหลายรายการ
    final batch = FirebaseFirestore.instance.batch();

    // **แก้ไขข้อผิดพลาด Nested arrays are not supported**
    // 4. สร้าง List ของ Map ที่เป็นรายการฝึกซ้อมทั้งหมดแบบเรียบ (Flat List)
    final List<Map<String, dynamic>> flatPlanSnapshot = dailyTrainings.map((
      data,
    ) {
      return {
        'week': data['week'],
        'dayOfWeek': data['dayOfWeek'],
        'type': data['type'],
        'distance': data['distance'],
        'time': data['time'],
      };
    }).toList();

    // 5. ตั้งค่าเอกสาร Program
    batch.set(programDocRef, {
      'userId': userId,
      'startDate': Timestamp.fromDate(startDate),
      'totalWeeks': totalWeeks,
      'targetKm': targetKm,
      'calendarId': calendarId,
      'calendarTitle': calendarTitle,
      'source': source,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'planSnapshot': flatPlanSnapshot, // ใช้ Flat List
    });

    // 6. เตรียม Subcollection สำหรับ Training
    final trainingColRef = programDocRef.collection('Training');
    final dateFormatter = DateFormat('dd-MM-yyyy'); // Format สำหรับ Document ID

    // 7. เพิ่มรายการ Training รายวันทั้งหมดลงใน Batch
    for (final trainingData in dailyTrainings) {
      final DateTime date = trainingData['date'];
      final String dateId = dateFormatter.format(
        date,
      ); // แปลงวันที่เป็น String ID (YYYY-MM-DD)

      // กำหนด Document ID เป็นวันที่
      final trainingDocRef = trainingColRef.doc(dateId);

      // สร้างข้อมูลสำหรับบันทึก
      final data = Map<String, dynamic>.from(trainingData);
      data['date'] = Timestamp.fromDate(date); // เก็บวันที่จริงเป็น Timestamp
      data['loggedAt'] = FieldValue.serverTimestamp();

      batch.set(trainingDocRef, data);
    }

    // 8. ดำเนินการบันทึก Batch
    await batch.commit();

    return programId;
  }

  /// ดึงโปรแกรมล่าสุดของผู้ใช้ (active ตัวล่าสุด)
  static Future<DocumentSnapshot<Map<String, dynamic>>?> fetchLatestActive(
    String userId,
  ) async {
    final programColRef = _userCol.doc(userId).collection('Program');

    final q = await programColRef
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    return q.docs.isEmpty ? null : q.docs.first;
  }
}
