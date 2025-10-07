import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'run_page.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/schedule_tab.dart';
import 'tabs/calendar_tab.dart';

class HomePage extends StatefulWidget {
  final int targetKm;
  final int trainingWeeks;
  const HomePage({super.key, required this.targetKm, required this.trainingWeeks});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final tabs = [
      DashboardTab(
        targetKm: widget.targetKm,
        trainingWeeks: widget.trainingWeeks,
        onContinue: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RunPage()),
          );
        },
        email: user?.email ?? 'Runner',
      ),
      ScheduleTab(weeks: widget.trainingWeeks, targetKm: widget.targetKm),
      const CalendarTab(), // mock %
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: tabs)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.card_travel_outlined), selectedIcon: Icon(Icons.card_travel), label: 'Plans'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendar'),
        ],
      ),
    );
  }
}
