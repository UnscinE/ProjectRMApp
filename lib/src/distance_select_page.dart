import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'program_repo.dart';
import 'duration_select_page.dart';

class DistanceSelectPage extends StatelessWidget {
  const DistanceSelectPage({super.key});

  Future<void> _choose5km(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    // เก็บ local (กัน offline)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('program_distance', 5);

    // ถ้ามี user → Firestore (เขียนที่ /users/{uid}/program/active)
    if (user != null) {
      await ProgramRepo.setDistance(user.uid, 5);
      await ProgramRepo.setProgramName(user.uid, '5 km');
    }

    // ไปต่อหน้า "เลือกสัปดาห์" ด้วย push (ไม่ pop กลับ)
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DurationSelectPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เลือกระยะทางที่ต้องการฝึก')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: InkWell(
            onTap: () => _choose5km(context),
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEDEDEF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_run),
                  SizedBox(width: 10),
                  Text('5 Km', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  SizedBox(width: 6),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
