import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'program_repo.dart';
import 'duration_select_page.dart';

class DistanceSelectPage extends StatelessWidget {
  const DistanceSelectPage({super.key});

  Future<void> _chooseDistance(BuildContext context, int km) async {
    final user = FirebaseAuth.instance.currentUser;

    // modal loading กันผู้ใช้กดซ้ำ
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? error;
    try {
      // เก็บ local (กัน offline)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('program_distance', km);
      await prefs.setString('program_name', '$km km');

      // ถ้ามี user → Firestore (/users/{uid}/program/active)
      if (user != null) {
        await ProgramRepo.setDistance(user.uid, km);
        await ProgramRepo.setProgramName(user.uid, '$km km');
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // ปิด loading
      }
    }

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกค่าไม่ได้: $error')),
      );
      return;
    }

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DurationSelectPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('เลือกระยะทางที่ต้องการฝึก')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'เลือกโปรแกรมระยะทาง',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ระบบจะใช้ระยะทางนี้เพื่อสร้างตารางฝึกที่เหมาะสม',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                _DistanceCard(
                  label: '5 KM',
                  subtitle: 'เริ่มต้นสำหรับผู้ฝึกพื้นฐาน',
                  icon: Icons.directions_run,
                  onTap: () => _chooseDistance(context, 5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DistanceCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _DistanceCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8C3B), Color(0xFFFF6A00)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orangeAccent.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_run, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('5 KM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 2),
                  Text('เริ่มต้นสำหรับผู้ฝึกพื้นฐาน',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      )),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 28),
          ],
        ),
      ),
    );
  }
}
