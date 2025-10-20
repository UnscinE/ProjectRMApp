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

import 'distance_select_page.dart';
import 'duration_select_page.dart';
import 'program_repo.dart' as repo;

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  int targetKm = 5;
  int trainingWeeks = 4;

  bool isLoading = true;
  StreamSubscription? _userDocSub;
  bool _navigatingToSelect = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _userDocSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadLocalFallback();
    await _ensureProgramSelected();
    _listenUserPrefs();
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _loadLocalFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final km = prefs.getInt('program_distance');
      final weeks = prefs.getInt('program_duration');
      if (km != null && weeks != null && mounted) {
        setState(() {
          targetKm = km;
          trainingWeeks = weeks;
        });
      }
    } catch (_) {}
  }

  Future<void> _ensureProgramSelected() async {
    final prefs = await SharedPreferences.getInstance();
    final hasDistance = prefs.containsKey('program_distance');
    final hasDuration = prefs.containsKey('program_duration');
    if (hasDistance && hasDuration) {
      setState(() {
        targetKm = prefs.getInt('program_distance')!;
        trainingWeeks = prefs.getInt('program_duration')!;
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final data = await repo.ProgramRepo
            .fetchActive(user.uid)
            .timeout(const Duration(seconds: 6));

        if (data != null) {
          final dist = (data['distance'] as num?)?.toInt();
          final weeks = (data['duration_choice'] as num?)?.toInt() ??
              ((data['duration'] is List && (data['duration'] as List).isNotEmpty)
                  ? ((data['duration'] as List).first as num).toInt()
                  : null);

          if (dist != null && weeks != null) {
            await prefs.setInt('program_distance', dist);
            await prefs.setInt('program_duration', weeks);
            if (mounted) {
              setState(() {
                targetKm = dist;
                trainingWeeks = weeks;
              });
            }
            return;
          }
        }
      } catch (_) {}
    }

    if (!_navigatingToSelect && mounted) {
      _navigatingToSelect = true;

      final ok1 = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const DistanceSelectPage()),
      );
      if (ok1 != true || !mounted) {
        _navigatingToSelect = false;
        return;
      }

      final ok2 = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const DurationSelectPage()),
      );
      _navigatingToSelect = false;

      final km = prefs.getInt('program_distance') ?? targetKm;
      final w  = prefs.getInt('program_duration') ?? trainingWeeks;
      if (mounted) {
        setState(() {
          targetKm = km;
          trainingWeeks = w;
        });
      }
    }
  }

  void _listenUserPrefs() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userDocSub?.cancel();
    _userDocSub = repo.ProgramRepo.basicStream(user.uid).listen((data) async {
      if (data == null) return;

      final dist = (data['distance'] as num?)?.toInt();
      final weeks = (data['duration_choice'] as num?)?.toInt() ??
          ((data['duration'] is List && (data['duration'] as List).isNotEmpty)
              ? ((data['duration'] as List).first as num).toInt()
              : null);

      if (dist == null || weeks == null) return;

      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('program_distance')) {
        await prefs.setInt('program_distance', dist);
      }
      if (!prefs.containsKey('program_duration')) {
        await prefs.setInt('program_duration', weeks);
      }

      if (!mounted) return;
      setState(() {
        targetKm = dist;
        trainingWeeks = weeks;
      });
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final tabs = <Widget>[
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
          if (mounted) setState(() => _index = 0);
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
