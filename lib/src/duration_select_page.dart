import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'program_repo.dart';
import 'auth_gate.dart';

class DurationSelectPage extends StatelessWidget {
  const DurationSelectPage({super.key});

  Future<void> _chooseWeeks(BuildContext context, int weeks) async {
    final user = FirebaseAuth.instance.currentUser;

    // modal loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? error;
    try {
      // เก็บ local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('program_duration', weeks);

      // เขียน Firestore (ถ้ามี user)
      if (user != null) {
        await ProgramRepo.setDurationChoice(user.uid, weeks);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // ปิด loading
      }
    }

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('บันทึกค่าไม่ได้: $error')));
      return;
    }

    // กลับสู่ flow ปกติแบบล้างสแตก
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    }
  }

  Future<int?> _readDistance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('program_distance'); // แสดงสรุปด้านบน
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('เลือกเวลาที่ต้องการฝึก')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FutureBuilder<int?>(
                  future: _readDistance(),
                  builder: (context, snap) {
                    final km = snap.data;
                    return Column(
                      children: [
                        Text(
                          'เลือกระยะเวลาโปรแกรม',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          km != null
                              ? 'โปรแกรมระยะทาง: $km KM'
                              : 'โปรแกรมระยะทาง: -',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: _WeekCard(
                        weeks: 8,
                        onTap: () => _chooseWeeks(context, 8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _WeekCard(
                        weeks: 12,
                        onTap: () => _chooseWeeks(context, 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _WeekCard(
                        weeks: 16,
                        onTap: () => _chooseWeeks(context, 16),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Text(
                  'เลือก 8 / 12 / 16 สัปดาห์ เพื่อเริ่มโปรแกรม',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  final int weeks;
  final VoidCallback onTap;

  const _WeekCard({required this.weeks, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFFEDEDEF), Color(0xFFDCDCDF)],
          ),
        ),
        child: Column(
          children: [
            Text(
              '$weeks',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            const Text('สัปดาห์', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
