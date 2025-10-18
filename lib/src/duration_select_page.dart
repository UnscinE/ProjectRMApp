import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'program_repo.dart';
import 'auth_gate.dart'; // กลับไปให้ AuthGate ตัดสินใจแล้วพาเข้า Home

class DurationSelectPage extends StatelessWidget {
  const DurationSelectPage({super.key});

  Future<void> _chooseWeeks(BuildContext context, int weeks) async {
    final user = FirebaseAuth.instance.currentUser;

    // เก็บ local
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('program_duration', weeks);

    // ถ้ามี user → เขียน Firestore
    if (user != null) {
      await ProgramRepo.setDurationChoice(user.uid, weeks);
    }

    // กลับสู่ flow ปกติแบบ "ล้างสแตก" เพื่อกันจอดำ/ค้าง
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
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
                _Item(weeks: 4,  onTap: () => _chooseWeeks(context, 4)),
                const SizedBox(height: 10),
                _Item(weeks: 8,  onTap: () => _chooseWeeks(context, 8)),
                const SizedBox(height: 10),
                _Item(weeks: 12, onTap: () => _chooseWeeks(context, 12)),
                const SizedBox(height: 14),
                Text('เลือก 4 / 8 / 12 สัปดาห์ เพื่อเริ่มโปรแกรม', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final int weeks;
  final VoidCallback onTap;
  const _Item({required this.weeks, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEDEDEF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text('$weeks สัปดาห์',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
