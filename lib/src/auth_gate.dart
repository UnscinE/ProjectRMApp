// lib/src/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_page.dart';
import 'login_page.dart';
import 'distance_select_page.dart';
import 'program_repo.dart' as repo;

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<void> _ensureUserDoc(User user) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        if (user.displayName != null) 'displayName': user.displayName,
        if (user.email != null) 'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<bool> _hasProgramSelected(User user) async {
    // ย้าย current -> active ถ้ามีตกค้าง
    await repo.ProgramRepo.cleanupProgramDocs(user.uid);

    final data = await repo.ProgramRepo.fetchActive(user.uid);
    final hasDistance = (data?['distance'] as num?) != null;
    final hasDuration =
        (data?['duration_choice'] as num?) != null ||
        (data?['duration'] is List && (data?['duration'] as List).isNotEmpty);
    return hasDistance && hasDuration;
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

        return FutureBuilder<bool>(
          future: (() async {
            await _ensureUserDoc(user);
            return _hasProgramSelected(user);
          })(),
          builder: (context, prog) {
            if (prog.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final selected = prog.data == true;
            return selected ? const HomePage() : const DistanceSelectPage();
          },
        );
      },
    );
  }
}
