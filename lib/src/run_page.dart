import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RunPage extends StatefulWidget {
  const RunPage({super.key});

  @override
  State<RunPage> createState() => _RunPageState();
}

class _RunPageState extends State<RunPage> {
  Timer? _timer;
  final int _secs = 0;
  final double _distance = 0; // km
  final bool _running = false;

  // ... (existing _start, _stop, _reset methods) ...

  Future<void> _saveRun() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // สมมติว่าเรารู้ programId และข้อมูลการวิ่งอื่นๆ
    // ในโค้ดจริง ส่วนนี้อาจจะต้องส่งค่ามาจากหน้าก่อนหน้า
    const programId =
        "Zetrhi2jhUYQGpXCGfDB"; // Placeholder, replace with actual ID
    final today = DateTime.now();
    final dateKey = DateFormat('dd-MM-yyyy').format(today);

    final trainingDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Program')
        .doc(programId)
        .collection('Training')
        .doc(dateKey);

    final plannedDoc = await trainingDocRef.get();
    double plannedDistance = 0;
    if (plannedDoc.exists) {
      plannedDistance = (plannedDoc.data()!['distance_km'] as num).toDouble();
    }

    // คำนวณ progress
    final performancePercent = (plannedDistance > 0)
        ? ((_distance / plannedDistance) * 100).toInt()
        : 100;

    final runData = {
      'duration_s': _secs,
      'distance_km': _distance,
      'progress_bar_percent': performancePercent,
      'status': 'Completed',
      'loggedAt': FieldValue.serverTimestamp(),
      // ... other fields
    };

    await trainingDocRef.set(runData, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกการวิ่งเรียบร้อย และปรับโปรแกรมวันถัดไปแล้ว'),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  // ... (build method and other UI code) ...

  @override
  Widget build(BuildContext context) {
    // ... (Your existing build method with the UI)
    // For demonstration, I'll add a save button.
    return Scaffold(
      appBar: AppBar(title: const Text('Running')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ... your timer and stats UI ...
            ElevatedButton(onPressed: _saveRun, child: const Text('Save Run')),
          ],
        ),
      ),
    );
  }
}
