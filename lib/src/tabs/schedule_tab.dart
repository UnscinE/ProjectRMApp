// lib/src/tabs/schedule_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../widgets/calendar_helper.dart' as cal;

class ScheduleTab extends StatefulWidget {
  final int weeks;    // จำนวนสัปดาห์ เช่น 4
  final int targetKm; // เป้าหมายระยะทาง เช่น 5
  const ScheduleTab({super.key, required this.weeks, required this.targetKm});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  int _weekIndex = 0;

  String? _calendarId;
  String  _calendarTitle = 'ยังไม่ได้เลือกเล่ม';

  @override
  void initState() {
    super.initState();
    _loadCalendarSelection();
  }

  Future<void> _loadCalendarSelection() async {
    final id = await cal.loadSelectedCalendarId();
    if (id == null) return;
    try {
      final cals = await cal.getWritableCalendars();
      final matched = cals.where((c) => c.id == id).toList();
      if (!mounted) return;
      setState(() {
        _calendarId = id;
        _calendarTitle = matched.isNotEmpty
            ? '${matched.first.name ?? 'Calendar'}'
              '${(matched.first.accountName ?? '').isNotEmpty ? ' • ${matched.first.accountName}' : ''}'
            : id;
      });
    } catch (_) {}
  }

  // ---------- แผนฝึกแต่ละสัปดาห์ ----------
  List<Map<String, String>> _weekPlan(int week) {
    switch (week) {
      case 0:
        return const [
          {'day': 'Mon', 'dist': '3 KM', 'time': '21 Min', 'note': 'Long run'},
          {'day': 'Tue', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Wed', 'dist': '400 m × 4', 'time': '1:30 / 3:50 Min/Set', 'note': 'Interval'},
          {'day': 'Thu', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Fri', 'dist': '2 KM', 'time': '14 Min', 'note': 'Recovery'},
          {'day': 'Sat', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Sun', 'dist': '2 KM', 'time': '13 Min', 'note': 'Tempo'},
        ];
      case 1:
        return const [
          {'day': 'Mon', 'dist': '3.5 KM', 'time': '24 Min', 'note': 'Long run'},
          {'day': 'Tue', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Wed', 'dist': '400 m × 5', 'time': '1:30 / 3:45 Min/Set', 'note': 'Interval'},
          {'day': 'Thu', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Fri', 'dist': '2.5 KM', 'time': '16 Min', 'note': 'Recovery'},
          {'day': 'Sat', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Sun', 'dist': '2.5 KM', 'time': '15 Min', 'note': 'Tempo'},
        ];
      case 2:
        return const [
          {'day': 'Mon', 'dist': '4 KM', 'time': '27 Min', 'note': 'Long run'},
          {'day': 'Tue', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Wed', 'dist': '400 m × 6', 'time': '1:25 / 3:40 Min/Set', 'note': 'Interval'},
          {'day': 'Thu', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Fri', 'dist': '3 KM', 'time': '19 Min', 'note': 'Recovery'},
          {'day': 'Sat', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Sun', 'dist': '3 KM', 'time': '18 Min', 'note': 'Tempo'},
        ];
      default:
        return const [
          {'day': 'Mon', 'dist': '4.5 KM', 'time': '30 Min', 'note': 'Long run'},
          {'day': 'Tue', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Wed', 'dist': '400 m × 6', 'time': '1:20 / 3:35 Min/Set', 'note': 'Interval'},
          {'day': 'Thu', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Fri', 'dist': '3.5 KM', 'time': '22 Min', 'note': 'Recovery'},
          {'day': 'Sat', 'dist': '-', 'time': '-', 'note': 'Rest'},
          {'day': 'Sun', 'dist': '3.5 KM', 'time': '21 Min', 'note': 'Tempo'},
        ];
    }
  }

  List<List<Map<String, String>>> get _allWeeks =>
      List.generate(widget.weeks, (w) => _weekPlan(w));

  // ---------- ปุ่มเลือก/สร้างเล่ม ----------
  Future<void> _chooseOrCreateCalendar() async {
    final id = await cal.pickCalendarIdDialog(context);
    if (id == null) return; // ผู้ใช้ไปสร้างเล่มใหม่/เปิดเว็บแล้วยังไม่เลือก

    await cal.saveSelectedCalendarId(id);

    // อัปเดตชื่อโชว์
    final cals = await cal.getWritableCalendars();
    final matched = cals.where((c) => c.id == id).toList();
    if (!mounted) return;
    setState(() {
      _calendarId = id;
      _calendarTitle = matched.isNotEmpty
          ? '${matched.first.name ?? 'Calendar'}'
            '${(matched.first.accountName ?? '').isNotEmpty ? ' • ${matched.first.accountName}' : ''}'
          : id;
    });
  }

  // ---------- เครื่องมือวันที่ ----------
  DateTime _mondayOf(DateTime any) {
    final mon = any.subtract(Duration(days: (any.weekday - DateTime.monday)));
    return DateTime(mon.year, mon.month, mon.day);
  }

  // ---------- เพิ่มทั้งโปรแกรม (เริ่มจากวันที่ผู้ใช้เลือก) ----------
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

    final startDate = picked.copyWith(hour: 8, minute: 0); // วันเริ่มจริง

    try {
      final selectedId = _calendarId ?? await cal.loadSelectedCalendarId();
      final calendars = await cal.getWritableCalendars().catchError((_) => <dynamic>[]);
      final hasWritable = calendars.isNotEmpty;

      if (hasWritable) {
        await cal.bulkInsertToDeviceCalendar(
          calendarId: selectedId,            // << ใส่ลงเล่มที่เลือก
          week1StartDate: startDate,
          totalWeeks: widget.weeks,
          targetKm: widget.targetKm,
          planByWeeks: _allWeeks,
          startHour: 8,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เพิ่มลงเล่ม: ${_calendarTitle.isEmpty ? (selectedId ?? "ไม่ระบุ") : _calendarTitle} เรียบร้อย')),
        );
        return;
      }

      // เขียนตรงไม่ได้ → สร้างไฟล์ .ics
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ล้มเหลว: $e')),
      );
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final plan = _weekPlan(_weekIndex.clamp(0, widget.weeks - 1));
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          // Header card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ป้ายชื่อเล่ม (อ่านอย่างเดียว)
                    _ReadonlyPill(
                      icon: Icons.bookmark_added_outlined,
                      text: _calendarTitle,
                    ),
                    const SizedBox(height: 12),
                    // ปุ่มแอคชัน
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _chooseOrCreateCalendar,
                            icon: const Icon(Icons.library_add),
                            label: const Text('เลือก/สร้างเล่ม'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(fontWeight: FontWeight.w600),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _addWholeProgramToCalendar(context),
                            icon: const Icon(Icons.event_available),
                            label: const Text('เพิ่มทั้งโปรแกรม'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(fontWeight: FontWeight.w700),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // สลับสัปดาห์
          if (widget.weeks > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _weekIndex = (_weekIndex - 1).clamp(0, widget.weeks - 1)),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('สัปดาห์ที่ ${_weekIndex + 1}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _weekIndex = (_weekIndex + 1).clamp(0, widget.weeks - 1)),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // ตารางรายการ
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: plan.length,
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final row = plan[index];
                final day  = row['day'] ?? '';
                final note = row['note'] ?? '';
                final dist = row['dist'] ?? '-';
                final time = row['time'] ?? '-';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 54,
                      child: Text(day,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(note.isEmpty ? '-' : note,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(child: _MiniCell(headline: 'ระยะทาง', value: dist)),
                              const SizedBox(width: 12),
                              Expanded(child: _MiniCell(headline: 'เวลา', value: time)),
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

// ---------- Widgets ย่อย ----------

class _ReadonlyPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ReadonlyPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
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
  const _MiniCell({required this.headline, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  )),
          const SizedBox(height: 4),
          Text(value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
        ],
      ),
    );
  }
}
