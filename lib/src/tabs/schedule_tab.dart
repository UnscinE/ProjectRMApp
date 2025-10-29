import 'package:flutter/material.dart';
import '../widgets/calendar_helper.dart' as cal;
import 'package:firebase_auth/firebase_auth.dart';
import '../training_repo.dart'; // ProgramRepo.createProgram(...)

class ScheduleTab extends StatefulWidget {
  final int weeks;
  final int targetKm;
  const ScheduleTab({super.key, required this.weeks, required this.targetKm});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  int _selectedWeeks = 8;
  int _weekIndex = 0;

  String? _calendarId;
  String _calendarTitle = 'ยังไม่ได้เลือกเล่ม';

  @override
  void initState() {
    super.initState();
    _selectedWeeks = widget.weeks;
    _loadCalendarSelection();
  }

  Future<void> _loadCalendarSelection() async {
    final id = await cal.loadSelectedCalendarId();
    if (id == null) return;
    try {
      final cals = await cal.getWritableCalendars();
      final m = cals.where((c) => c.id == id).toList();
      if (!mounted) return;
      setState(() {
        _calendarId = id;
        _calendarTitle = m.isNotEmpty
            ? '${m.first.name ?? 'Calendar'}${(m.first.accountName ?? '').isNotEmpty ? ' • ${m.first.accountName}' : ''}'
            : id;
      });
    } catch (_) {}
  }

  // ---------------- plan ----------------
  List<Map<String, String>> _weekPlan(int w) {
    switch (w % 4) {
      case 0:
        return const [
          {'day': 'Mon', 'dist': '3 KM', 'time': '21 Min', 'note': 'Long run'},
          {'day': 'Tue', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {
            'day': 'Wed',
            'dist': '400 m × 4',
            'time': '1:30 / 3:50',
            'note': 'Interval',
          },
          {'day': 'Thu', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Fri', 'dist': '2 KM', 'time': '14 Min', 'note': 'Recovery'},
          {'day': 'Sat', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Sun', 'dist': '2 KM', 'time': '13 Min', 'note': 'Tempo'},
        ];
      case 1:
        return const [
          {
            'day': 'Mon',
            'dist': '3.5 KM',
            'time': '24 Min',
            'note': 'Long run',
          },
          {'day': 'Tue', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {
            'day': 'Wed',
            'dist': '400 m × 5',
            'time': '1:30 / 3:45',
            'note': 'Interval',
          },
          {'day': 'Thu', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {
            'day': 'Fri',
            'dist': '2.5 KM',
            'time': '16 Min',
            'note': 'Recovery',
          },
          {'day': 'Sat', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Sun', 'dist': '2.5 KM', 'time': '15 Min', 'note': 'Tempo'},
        ];
      case 2:
        return const [
          {'day': 'Mon', 'dist': '4 KM', 'time': '27 Min', 'note': 'Long run'},
          {'day': 'Tue', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {
            'day': 'Wed',
            'dist': '400 m × 6',
            'time': '1:25 / 3:40',
            'note': 'Interval',
          },
          {'day': 'Thu', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Fri', 'dist': '3 KM', 'time': '19 Min', 'note': 'Recovery'},
          {'day': 'Sat', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Sun', 'dist': '3 KM', 'time': '18 Min', 'note': 'Tempo'},
        ];
      default:
        return const [
          {
            'day': 'Mon',
            'dist': '4.5 KM',
            'time': '30 Min',
            'note': 'Long run',
          },
          {'day': 'Tue', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {
            'day': 'Wed',
            'dist': '400 m × 6',
            'time': '1:20 / 3:35',
            'note': 'Interval',
          },
          {'day': 'Thu', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {
            'day': 'Fri',
            'dist': '3.5 KM',
            'time': '22 Min',
            'note': 'Recovery',
          },
          {'day': 'Sat', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Sun', 'dist': '3.5 KM', 'time': '21 Min', 'note': 'Tempo'},
        ];
    }
  }

  List<List<Map<String, String>>> get _allWeeks =>
      List.generate(_selectedWeeks, (w) => _weekPlan(w));

  // ---------------- choose/create calendar ----------------
  Future<void> _chooseOrCreateCalendar() async {
    final id = await cal.pickCalendarIdDialog(context);
    if (id == null) return;
    await cal.saveSelectedCalendarId(id);

    final cals = await cal.getWritableCalendars();
    final m = cals.where((c) => c.id == id).toList();
    if (!mounted) return;
    setState(() {
      _calendarId = id;
      _calendarTitle = m.isNotEmpty
          ? '${m.first.name ?? 'Calendar'}${(m.first.accountName ?? '').isNotEmpty ? ' • ${m.first.accountName}' : ''}'
          : id;
    });
  }

  // ---------------- add whole program ----------------
  Future<void> _addWholeProgramToCalendar(BuildContext context) async {
    final now = DateTime.now();

    const orange = Color(0xFFFF6F00);
    const orange2 = Color(0xFFFF8F00);

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'เลือกวันเริ่มโปรแกรม',
      confirmText: 'เพิ่มลงปฏิทิน',
      cancelText: 'ยกเลิก',
      builder: (ctx, child) {
        final base = Theme.of(ctx);
        return Theme(
          data: base.copyWith(
            colorScheme: base.colorScheme.copyWith(
              primary: orange,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF212121),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: orange,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              headerBackgroundColor: orange,
              headerForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return const Color(0xFF212121);
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return orange;
                return null;
              }),
              todayForegroundColor: WidgetStateProperty.all(Colors.white),
              todayBackgroundColor: WidgetStateProperty.all(orange2),
              dayOverlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return orange.withOpacity(.12);
                }
                return null;
              }),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;
    final startDate = DateTime(picked.year, picked.month, picked.day, 8);

    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'anonymous';

    // snapshot รายวัน (เก็บลง Firestore)
    final daily = <Map<String, dynamic>>[];
    var cur = startDate;
    for (int w = 0; w < _selectedWeeks; w++) {
      final week = _weekPlan(w);
      for (final d in week) {
        daily.add({
          'date': cur,
          'week': w + 1,
          'dayOfWeek': d['day'],
          'type': d['note'],
          'distance': d['dist'],
          'time': d['time'],
          'status': (d['dist'] == '-') ? 'Rest' : 'Planned',
        });
        cur = cur.add(const Duration(days: 1));
      }
    }

    try {
      final cals = await cal.getWritableCalendars().catchError(
        (_) => <dynamic>[],
      );
      String source = 'device_calendar';
      String? calId;
      String? calTitle;

      if (cals.isNotEmpty) {
        final selected = await cal.loadSelectedCalendarId();
        calId = selected ?? cals.first.id;
        final m = cals.where((c) => c.id == calId).toList();
        if (m.isNotEmpty) {
          calTitle =
              '${m.first.name ?? 'Calendar'}${(m.first.accountName ?? '').isNotEmpty ? ' • ${m.first.accountName}' : ''}';
        }

        await cal.bulkInsertToDeviceCalendar(
          calendarId: calId,
          week1StartDate: startDate,
          totalWeeks: _selectedWeeks,
          targetKm: widget.targetKm,
          planByWeeks: _allWeeks,
          startHour: 8,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เพิ่มลงปฏิทินเครื่องเรียบร้อย')),
        );
      } else {
        // ถ้าไม่มี provider -> สร้างไฟล์ .ics ให้ผู้ใช้ import เอง
        source = 'ics';
        await cal.exportTrainingPlanToICS(
          week1StartDate: startDate,
          totalWeeks: _selectedWeeks,
          targetKm: widget.targetKm,
          planByWeeks: _allWeeks,
          startHour: 8,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งออกไฟล์ .ics เรียบร้อย')),
        );
      }

      await ProgramRepo.createProgram(
        userId: userId,
        startDate: startDate,
        totalWeeks: _selectedWeeks,
        targetKm: widget.targetKm,
        calendarId: calId,
        calendarTitle: calTitle,
        source: source,
        planSnapshot: _allWeeks,
        dailyTrainings: daily,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ล้มเหลว: $e')));
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final plan = _weekPlan(_weekIndex.clamp(0, _selectedWeeks - 1));
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFAFAFA), Color(0xFFF5F5F5)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                      color: Colors.black.withOpacity(.06),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ReadonlyPill(
                      icon: Icons.bookmark_border,
                      text: _calendarTitle,
                    ),
                    const SizedBox(height: 16),

                    // week chips
                    Row(
                      children: [8, 12, 16].map((w) {
                        final sel = _selectedWeeks == w;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedWeeks = w;
                                  _weekIndex = _weekIndex.clamp(
                                    0,
                                    _selectedWeeks - 1,
                                  );
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: sel
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFFFF6F00),
                                            Color(0xFFFF8F00),
                                          ],
                                        )
                                      : null,
                                  color: sel ? null : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: sel
                                      ? null
                                      : Border.all(
                                          color: const Color(0xFFE0E0E0),
                                          width: 1.5,
                                        ),
                                  boxShadow: sel
                                      ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFFFF6F00,
                                            ).withOpacity(.25),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    '$w สัปดาห์',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: sel
                                          ? Colors.white
                                          : const Color(0xFF757575),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFF6F00),
                                width: 2,
                              ),
                            ),
                            child: OutlinedButton.icon(
                              onPressed: _chooseOrCreateCalendar,
                              icon: const Icon(Icons.calendar_today, size: 20),
                              label: const Text('เลือกเล่ม'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFF6F00),
                                backgroundColor: Colors.transparent,
                                side: BorderSide.none,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFFF6F00).withOpacity(.3),
                                  blurRadius: 16,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: FilledButton.icon(
                              onPressed: () =>
                                  _addWholeProgramToCalendar(context),
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 20,
                              ),
                              label: const Text('เพิ่มโปรแกรม'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // switch week
            if (_selectedWeeks > 1)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                        color: Colors.black.withOpacity(.04),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => setState(
                          () => _weekIndex = (_weekIndex - 1).clamp(
                            0,
                            _selectedWeeks - 1,
                          ),
                        ),
                        icon: const Icon(
                          Icons.chevron_left,
                          color: Color(0xFFFF6F00),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'สัปดาห์ที่ ${_weekIndex + 1}/$_selectedWeeks',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF212121),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(
                          () => _weekIndex = (_weekIndex + 1).clamp(
                            0,
                            _selectedWeeks - 1,
                          ),
                        ),
                        icon: const Icon(
                          Icons.chevron_right,
                          color: Color(0xFFFF6F00),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                itemCount: plan.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final row = plan[i];
                  final day = row['day'] ?? '';
                  final note = row['note'] ?? '';
                  final dist = row['dist'] ?? '-';
                  final time = row['time'] ?? '-';
                  final isRest = note.toLowerCase() == 'rest';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: isRest
                          ? Border.all(
                              color: const Color(0xFFE0E0E0),
                              width: 1.5,
                            )
                          : null,
                      boxShadow: isRest
                          ? null
                          : [
                              BoxShadow(
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                                color: Colors.black.withOpacity(.05),
                              ),
                            ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: isRest
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFFFF6F00),
                                      Color(0xFFFF8F00),
                                    ],
                                  ),
                            color: isRest ? const Color(0xFFF5F5F5) : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              day,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isRest
                                    ? const Color(0xFF9E9E9E)
                                    : Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.isEmpty ? '-' : note,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isRest
                                      ? const Color(0xFF9E9E9E)
                                      : const Color(0xFF212121),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _MiniCell(
                                      headline: 'ระยะทาง',
                                      value: dist,
                                      isRest: isRest,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _MiniCell(
                                      headline: 'เวลา',
                                      value: time,
                                      isRest: isRest,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- widgets ----------
class _ReadonlyPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ReadonlyPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.bookmark_border, size: 20, color: Color(0xFFFF6F00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF616161),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCell extends StatelessWidget {
  final String headline;
  final String value;
  final bool isRest;
  const _MiniCell({
    required this.headline,
    required this.value,
    this.isRest = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: isRest
            ? const Color(0xFFFAFAFA)
            : const Color(0xFFFF6F00).withOpacity(.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isRest
              ? const Color(0xFFEEEEEE)
              : const Color(0xFFFF6F00).withOpacity(.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isRest ? const Color(0xFF9E9E9E) : const Color(0xFF757575),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: isRest ? const Color(0xFFBDBDBD) : const Color(0xFF212121),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
