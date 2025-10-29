import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgramRepo {
  static final _users = FirebaseFirestore.instance.collection('users');

  static DocumentReference<Map<String, dynamic>> _active(String uid) =>
      _users.doc(uid).collection('program').doc('active');

  static Future<void> cleanupProgramDocs(String uid) async {
    final cur = _users.doc(uid).collection('program').doc('current');
    final act = _active(uid);
    final actSnap = await act.get();
    final curSnap = await cur.get();

    if (!actSnap.exists && curSnap.exists) {
      final data = curSnap.data();
      if (data != null) {
        await act.set({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
    if (curSnap.exists) {
      await cur.delete();
    }
  }

  static Future<void> setDistance(String uid, int km) async {
    await _active(uid).set({
      'distance': km,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('program_distance', km);
  }

  static Future<void> setDurationChoice(String uid, int weeks) async {
    await _active(uid).set({
      'duration_choice': weeks,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('program_duration', weeks);
  }

  static Future<void> setProgramName(String uid, String name) {
    return _active(uid).set({
      'programname': name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<Map<String, dynamic>?> fetchProgram(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final distance = prefs.getInt('program_distance');
    final duration = prefs.getInt('program_duration');

    if (distance != null && duration != null) {
      return {'distance': distance, 'duration_choice': duration};
    }

    try {
      final snap = await _active(uid).get();
      final data = snap.data();
      if (data != null) {
        final dist = (data['distance'] as num?)?.toInt();
        final weeks = (data['duration_choice'] as num?)?.toInt();
        if (dist != null && weeks != null) {
          await prefs.setInt('program_distance', dist);
          await prefs.setInt('program_duration', weeks);
          return {'distance': dist, 'duration_choice': weeks};
        }
      }
    } catch (e) {
      // Silently ignore network errors, will fallback to program selection.
    }
    return null;
  }

  static Stream<Map<String, dynamic>> programStream(String uid) {
    final controller = StreamController<Map<String, dynamic>>();
    SharedPreferences.getInstance().then((prefs) {
      final distance = prefs.getInt('program_distance');
      final duration = prefs.getInt('program_duration');
      if (distance != null && duration != null) {
        controller.add({'distance': distance, 'duration_choice': duration});
      }

      _active(uid).snapshots().listen((snapshot) async {
        final data = snapshot.data();
        if (data != null) {
          final dist = (data['distance'] as num?)?.toInt();
          final weeks = (data['duration_choice'] as num?)?.toInt();

          if (dist != null && weeks != null) {
            final oldDist = prefs.getInt('program_distance');
            final oldWeeks = prefs.getInt('program_duration');
            if (dist != oldDist || weeks != oldWeeks) {
              await prefs.setInt('program_distance', dist);
              await prefs.setInt('program_duration', weeks);
              controller.add({'distance': dist, 'duration_choice': weeks});
            }
          }
        }
      });
    });
    return controller.stream;
  }
}
