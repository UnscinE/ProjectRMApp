// lib/src/program_repo.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ProgramRepo {
  static final _users = FirebaseFirestore.instance.collection('users');

  static DocumentReference<Map<String, dynamic>> _active(String uid) =>
      _users.doc(uid).collection('program').doc('active');

  static DocumentReference<Map<String, dynamic>> _current(String uid) =>
      _users.doc(uid).collection('program').doc('current');

  /// เรียกครั้งเดียวช่วง Auth: ย้าย current -> active (ถ้ามี) แล้วลบทิ้ง
  static Future<void> cleanupProgramDocs(String uid) async {
    final act = await _active(uid).get();
    final cur = await _current(uid).get();

    if (!act.exists && cur.exists) {
      final data = cur.data();
      if (data != null) {
        await _active(uid).set({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
    if (cur.exists) {
      await _current(uid).delete();
    }
  }

  /// --- เขียนค่า ---
  static Future<void> setDistance(String uid, int km) {
    return _active(uid).set({
      'distance': km,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> setDurationChoice(String uid, int weeks) {
    return _active(uid).set({
      'duration_choice': weeks,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> setProgramName(String uid, String name) {
    return _active(uid).set({
      'programname': name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// --- อ่านค่า ---
  static Future<Map<String, dynamic>?> fetchActive(String uid) async {
    final snap = await _active(uid).get();
    return snap.data();
  }

  static Stream<Map<String, dynamic>?> basicStream(String uid) {
    return _active(uid).snapshots().map((s) => s.data());
  }
}
