// lib/src/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'training_repo.dart';

// <-- ถ้าไฟล์นี้อยู่ lib/ ให้ใส่ '../training_repo.dart' (จาก src/ ขึ้นไป 1 ระดับ)

import 'home_page.dart';        // หน้า main หลังล็อกอิน
import 'login_page.dart';       // หน้าเข้าสู่ระบบของคุณ

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snap.data;
        if (user == null) {
          return const LoginPage();
        }

        // ✅ สร้างเอกสาร users/{uid} ครั้งแรกถ้ายังไม่มี
        // ทำใน Future.microtask เพื่อไม่บล็อค build
        Future.microtask(() => TrainingRepo.ensureUserDocExists(
              uid: user.uid,
              displayName: user.displayName,
              email: user.email,
            ));

        return const HomePage(); // ไปหน้าโฮมของคุณ
      },
    );
  }
}
