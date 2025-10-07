import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'training_repo.dart';
import 'home_page.dart';

class DurationSelectPage extends StatelessWidget {
  const DurationSelectPage({super.key});

  Future<void> _choose4Weeks(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await TrainingRepo.setTrainingWeeks(uid, 4);

    // อ่าน km เพื่อส่งให้ Home แสดง (ถ้าเพิ่งเลือกมาก่อนหน้านี้จะมีแน่นอน)
    final data = await TrainingRepo.fetchPrefs(uid);
    final km = (data?['target_km'] as int?) ?? 5;

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomePage(targetKm: km, trainingWeeks: 4)),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('เลือกเวลาที่ต้องการฝึก')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _choose4Weeks(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDEDEF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('4 สัปดาห์',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('เลือก 4 สัปดาห์เพื่อเริ่มโปรแกรม', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
