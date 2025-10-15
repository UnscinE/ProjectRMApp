// lib/src/tabs/schedule_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/calendar_helper.dart' as cal;

class ScheduleTab extends StatefulWidget {
  final int weeks; // เช่น 4
  final int targetKm; // เช่น 5
  const ScheduleTab({super.key, required this.weeks, required this.targetKm});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  int _weekIndex = 0;

  String? _calendarId;
  String _calendarTitle = 'ยังไม่ได้เลือกเล่ม';

  @override
  void initState() {
    super.initState();
    _loadCalendarSelection();
  }

  Future<void> _loadCalendarSelection() async {
    final id = await cal.loadSelectedCalendarId();
    if (id == null) return;
    // หา title จาก device อีกที (ถ้าหาไม่ได้ก็ขึ้น id)
    try {
      final cals = await cal.getWritableCalendars();
      final matched = cals.where((c) => c.id == id).toList();
      if (mounted) {
        setState(() {
          _calendarId = id;
          _calendarTitle = matched.isNotEmpty
              ? '${matched.first.name ?? 'Calendar'}'
                    '${(matched.first.accountName ?? '').isNotEmpty ? ' • ${matched.first.accountName}' : ''}'
              : id;
        });
      }
    } catch (_) {}
  }

  List<Map<String, String>> _weekPlan(int week) {
    switch (week) {
      case 0:
        return const [
          {'day': 'Mon', 'dist': '3 KM', 'time': '21 Min', 'note': 'Long run'},
          {'day': 'Tue', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {
            'day': 'Wed',
            'dist': '400 m × 4',
            'time': '1:30 / 3:50 Min/Set',
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
            'time': '1:30 / 3:45 Min/Set',
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
            'time': '1:25 / 3:40 Min/Set',
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
            'time': '1:20 / 3:35 Min/Set',
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
      List.generate(widget.weeks, (w) => _weekPlan(w));

  /// ปุ่มขวา: เลือก/สร้างเล่ม
  Future<void> _chooseOrCreateCalendar() async {
    final id = await cal.pickCalendarIdDialog(context);
    if (id == null) {
      // ผู้ใช้ไปสร้างเล่มใหม่/เปิดหน้าเว็บแล้ว ยังไม่เลือก
      return;
    }
    await cal.saveSelectedCalendarId(id);
    if (!mounted) return;

    // อัปเดตชื่อเล่มไว้โชว์
    final cals = await cal.getWritableCalendars();
    final matched = cals.where((c) => c.id == id).toList();
    setState(() {
      _calendarId = id;
      _calendarTitle = matched.isNotEmpty
          ? '${matched.first.name ?? 'Calendar'}'
                '${(matched.first.accountName ?? '').isNotEmpty ? ' • ${matched.first.accountName}' : ''}'
          : id;
    });
  }

  DateTime _mondayOf(DateTime any) {
    final mon = any.subtract(Duration(days: (any.weekday - DateTime.monday)));
    return DateTime(mon.year, mon.month, mon.day);
  }

  Future<void> _addWholeProgramToCalendar(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'เลือก “วันเริ่มโปรแกรม”',
      confirmText: 'เพิ่มลงปฏิทิน',
      cancelText: 'ยกเลิก',
    );
    if (picked == null) return;

    // ใช้วันที่เลือกเป็นวันเริ่มจริง ๆ
    final startDate = picked.copyWith(hour: 8, minute: 0);

    try {
      // โหลด id เล่มที่ผู้ใช้เลือกไว้ (จากปุ่ม “เลือก/สร้างเล่ม” ข้างบน)
      final selectedId = _calendarId ?? await cal.loadSelectedCalendarId();

      // ลองดึงรายชื่อเล่มที่เขียนได้ดูว่ามีมั้ย
      final calendars = await cal.getWritableCalendars().catchError(
        (_) => <dynamic>[],
      );
      final hasWritable = calendars.isNotEmpty;

      if (hasWritable) {
        await cal.bulkInsertToDeviceCalendar(
          calendarId: selectedId, // <<<<<<<<<< สำคัญ
          week1StartDate: startDate,
          totalWeeks: widget.weeks,
          targetKm: widget.targetKm,
          planByWeeks: _allWeeks,
          startHour: 8,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'เพิ่มลงเล่ม: ${_calendarTitle.isEmpty ? (selectedId ?? "ไม่ระบุ") : _calendarTitle} เรียบร้อย',
            ),
          ),
        );
        return;
      }

      // ถ้าเขียนตรงไม่ได้ (อีมู/ไม่มีเล่ม) → สร้างไฟล์ .ics แทน
      await cal.exportTrainingPlanToICS(
        week1StartDate: startDate,
        totalWeeks: widget.weeks,
        targetKm: widget.targetKm,
        planByWeeks: _allWeeks,
        startHour: 8,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งออกไฟล์ .ics เรียบร้อย')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ล้มเหลว: $e')));
    }
  }

  Future<void> _addTodayOnly() async {
    final monday = _mondayOf(DateTime.now());
    try {
      final isMobile =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);

      if (isMobile) {
        final calId = _calendarId ?? await cal.loadSelectedCalendarId();
        if (calId != null) {
          await cal.addTodaysPlanToDeviceCalendar(
            week1StartDate: monday,
            totalWeeks: widget.weeks,
            targetKm: widget.targetKm,
            planByWeeks: _allWeeks,
            calendarId: calId,
            startHour: 6,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('บันทึกแผน “วันนี้” ลงเล่ม: $_calendarTitle'),
            ),
          );
          return;
        }
      }

      // เว็บ/ไม่มีเล่ม → เปิด template
      await cal.openGoogleCalendarImportPage();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ล้มเหลว: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _weekPlan(_weekIndex.clamp(0, widget.weeks - 1));

    return SafeArea(
      child: Column(
        children: [
          // แถบปุ่ม “เล่มที่เลือก / เลือก/สร้างเล่ม”
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.bookmark_added_outlined),
                    label: Text(
                      _calendarTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: _chooseOrCreateCalendar, // กดเพื่อเลือก/รีเฟรช
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _chooseOrCreateCalendar,
                  icon: const Icon(Icons.library_add),
                  label: const Text('เลือก/สร้างเล่ม'),
                ),
              ],
            ),
          ),

          // ปุ่มทำงานหลัก
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.event_available),
                    label: const Text('เพิ่มทั้งโปรแกรม (เลือกวันเริ่ม)'),
                    onPressed: () => _addWholeProgramToCalendar(context),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.today),
                    label: const Text('ส่งแผน “วันนี้” ไปปฏิทิน'),
                    onPressed: _addTodayOnly,
                  ),
                ),
              ],
            ),
          ),

          if (widget.weeks > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => setState(
                      () => _weekIndex = (_weekIndex - 1).clamp(
                        0,
                        widget.weeks - 1,
                      ),
                    ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'สัปดาห์ที่ ${_weekIndex + 1}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(
                      () => _weekIndex = (_weekIndex + 1).clamp(
                        0,
                        widget.weeks - 1,
                      ),
                    ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // ตารางโชว์รายการ
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: plan.length,
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final row = plan[index];
                final day = row['day'] ?? '';
                final note = row['note'] ?? '';
                final dist = row['dist'] ?? '-';
                final time = row['time'] ?? '-';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 54,
                      child: Text(
                        day,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.isEmpty ? '-' : note,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _MiniCell(
                                  headline: 'ระยะทาง',
                                  value: dist,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MiniCell(headline: 'เวลา', value: time),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
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
  const _MiniCell({required this.headline, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
