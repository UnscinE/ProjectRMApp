import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'run_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tabs/home_tab.dart';
import 'tabs/schedule_tab.dart';
import 'tabs/calendar_tab.dart';
import 'tabs/trainning_tab.dart';
import 'tabs/account_tab.dart';

import 'training_repo.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // กรณี user ปกติ
      final uid = user.uid;
      final data = await TrainingRepo.fetchPrefs(uid);
      final km = (data?['target_km'] as int?) ?? 5;
      final weeks = (data?['training_weeks'] as int?) ?? 4;

      setState(() {
        targetKm = km;
        trainingWeeks = weeks;
      });
    } else {
      // กรณี guest
      final prefs = await SharedPreferences.getInstance();
      final km = prefs.getInt('target_km') ?? 5;
      final weeks = prefs.getInt('training_weeks') ?? 4;

      setState(() {
        targetKm = km;
        trainingWeeks = weeks;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final tabs = [
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

      const CalendarTab(), // mock %

      const TrainningTab(),
      
      AccountTab(email: user?.email ?? 'Runner', onSignOut: () {
        FirebaseAuth.instance.signOut();
      }),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: tabs),
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
          )
        ],
      ),
    );
  }
}
