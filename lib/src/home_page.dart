import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rmapp/src/trainingtask_page.dart';
import 'tabs/home_tab.dart';
import 'tabs/schedule_tab.dart';
import 'tabs/calendar_tab.dart';
import 'tabs/trainning2_tab.dart';
import 'tabs/account_tab.dart';
import 'program_repo.dart' as repo;
import 'distance_select_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: repo.ProgramRepo.programStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData ||
            snapshot.data!['distance'] == null ||
            snapshot.data!['duration_choice'] == null) {
          return const DistanceSelectPage();
        }

        final targetKm = snapshot.data!['distance'] as int;
        final trainingWeeks = snapshot.data!['duration_choice'] as int;

        final tabs = <Widget>[
          DashboardTab(
            targetKm: targetKm,
            trainingWeeks: trainingWeeks,
            onContinue: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ScreenTwo()));
            },
            email: user.email ?? 'Runner',
          ),
          ScheduleTab(weeks: trainingWeeks, targetKm: targetKm),
          const CalendarTab(),
          const Trainning2Tab(),
          AccountTab(
            email: user.email ?? 'Runner',
            displayName: user.displayName,
            onSignOut: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ];

        return Scaffold(
          body: IndexedStack(index: _index, children: tabs),
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
      },
    );
  }
}
