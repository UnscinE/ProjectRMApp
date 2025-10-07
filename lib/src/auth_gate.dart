import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'distance_select_page.dart';
import 'duration_select_page.dart';
import 'training_repo.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<(int?, int?)> _loadUserPrefs(String uid) async {
    try {
      final data = await TrainingRepo.fetchPrefs(uid);
      final km = data?['target_km'] as int?;
      final weeks = data?['training_weeks'] as int?;
      return (km, weeks);
    } on FirebaseException catch (_) {
      // ถ้าอ่านไม่ได้ ก็ให้เลือกใหม่
      return (null, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return const LoginPage();

        return FutureBuilder<(int?, int?)>(
          future: _loadUserPrefs(user.uid),
          builder: (context, prefSnap) {
            if (prefSnap.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final (km, weeks) = prefSnap.data!;
            if (km == null) return const DistanceSelectPage();       // ยังไม่เลือกระยะทาง
            if (weeks == null) return const DurationSelectPage();     // ยังไม่เลือกสัปดาห์
            return HomePage(targetKm: km, trainingWeeks: weeks);      // ครบ → Home
          },
        );
      },
    );
  }
}
