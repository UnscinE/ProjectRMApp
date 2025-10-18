// lib/src/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'run_page.dart';

import 'tabs/home_tab.dart';
import 'tabs/schedule_tab.dart';
import 'tabs/calendar_tab.dart';
import 'tabs/trainning2_tab.dart';
import 'tabs/account_tab.dart';

import 'training_repo.dart' as repo;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  int targetKm = 0;
  int trainingWeeks = 0;
  bool isLoading = true;

  StreamSubscription? _userDocSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenUserPrefs(); // ✅ ถ้ามี user จะฟังค่า real-time
  }

  @override
  void dispose() {
    _userDocSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final uid = user.uid;

      // ✅ สร้างเอกสารครั้งแรกถ้ายังไม่มี (สำคัญ!)
      await repo.TrainingRepo.ensureUserDocExists(
        uid: uid,
        displayName: user.displayName,
        email: user.email,
      );

      // โหลดค่าเป้าหมายเบื้องต้นจาก Firestore (one-shot)
      final data = await repo.TrainingRepo.fetchPrefs(uid);
      final km = (data?['target_km'] as int?) ?? 5;
      final weeks = (data?['training_weeks'] as int?) ?? 4;

      if (!mounted) return;
      setState(() {
        targetKm = km;
        trainingWeeks = weeks;
        isLoading = false;
      });
    } else {
      // ยังไม่ล็อกอิน → ใช้ค่าที่เก็บในเครื่องไว้ก่อน
      final prefs = await SharedPreferences.getInstance();
      final km = prefs.getInt('target_km') ?? 5;
      final weeks = prefs.getInt('training_weeks') ?? 4;

      if (!mounted) return;
      setState(() {
        targetKm = km;
        trainingWeeks = weeks;
        isLoading = false;
      });
    }
  }

  void _listenUserPrefs() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userDocSub?.cancel();
    _userDocSub = repo.TrainingRepo.userDocStream(user.uid).listen((snap) {
      final data = snap.data();
      if (data == null) return;

      final km = (data['target_km'] as int?) ?? targetKm;
      final weeks = (data['training_weeks'] as int?) ?? trainingWeeks;

      if (!mounted) return;
      setState(() {
        targetKm = km;
        trainingWeeks = weeks;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final List<Widget> tabs = [
      DashboardTab(
        targetKm: targetKm,
        trainingWeeks: trainingWeeks,
        onContinue: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const RunPage()));
        },
        email: user?.email ?? 'Runner',
      ),
      ScheduleTab(weeks: trainingWeeks, targetKm: targetKm),
      const CalendarTab(),

      const Trainning2Tab(),

      AccountTab(
        email: user?.email ?? 'Runner',
        displayName: user?.displayName,
        onSignOut: () async {
          await FirebaseAuth.instance.signOut();
          _userDocSub?.cancel();
          if (mounted) {
            setState(() {
              _index = 0;
              // ค่าบนหน้า Home กลับมาใช้ของ local เผื่อยังอยู่ในแอป
            });
          }
        },
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(index: _index, children: tabs),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_travel_outlined),
            selectedIcon: Icon(Icons.card_travel),
            label: 'Plans',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.run_circle_outlined),
            selectedIcon: Icon(Icons.run_circle),
            label: 'Training',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
