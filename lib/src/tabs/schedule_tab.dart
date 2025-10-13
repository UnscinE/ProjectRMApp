import 'package:flutter/material.dart';
import '../calendar_helper.dart';

class ScheduleTab extends StatefulWidget {
  final int weeks;     // ปกติ 4
  final int targetKm;  // ปกติ 5

  const ScheduleTab({
    super.key,
    required this.weeks,
    required this.targetKm,
  });

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  int _weekIndex = 0;

  // ---------- ตารางฝึกตามจริงที่คุณให้มา ----------
  List<Map<String, String>> _weekPlan(int week) {
    switch (week) {
      case 0:
        return const [
          {'day': 'Mon', 'dist': '3 KM',       'time': '21 Min',     'note': 'Long run'},
          {'day': 'Tue', 'dist': '-',          'time': '-',          'note': 'Rest'},
          {'day': 'Wed', 'dist': '400 m × 4',  'time': '1:30 / 3:50 Min/Set', 'note': 'Interval'},
          {'day': 'Thu', 'dist': '-',          'time': '-',          'note': 'Rest'},
          {'day': 'Fri', 'dist': '2 KM',       'time': '14 Min',     'note': 'Recovery'},
          {'day': 'Sat', 'dist': '-',          'time': '-',          'note': 'Rest'},
          {'day': 'Sun', 'dist': '2 KM',       'time': '13 Min',     'note': 'Tempo'},
        ];
      case 1:
        return const [
          {'day': 'Mon', 'dist': '3.5 KM',     'time': '24 Min',     'note': 'Long run'},
          {'day': 'Tue', 'dist': '-',          'time': '-',          'note': 'Rest'},
          {'day': 'Wed', 'dist': '400 m × 5',  'time': '1:30 / 3:45 Min/Set', 'note': 'Interval'},
          {'day': 'Thu', 'dist': '-',          'time': '-',          'note': 'Rest'},
          {'day': 'Fri', 'dist': '2.5 KM',     'time': '16 Min',     'note': 'Recovery'},
          {'day': 'Sat', 'dist': '-',          'time': '-',          'note': 'Rest'},
          {'day': 'Sun', 'dist': '2.5 KM',     'time': '15 Min',     'note': 'Tempo'},
        ];
      case 2:
        return const [
          {'day': 'Mon', 'dist': '4 KM',       'time': '27 Min',     'note': 'Long run'},
          {'day': 'Tue', 'dist': '-',          'time': '-',          'note': 'Rest'},
          {'day': 'Wed', 'dist': '400 m × 6',  'time': '1:25 / 3:40 Min/Set', 'note': 'Interval'},
          {'day': 'Thu', 'dist': '-',          'time': '-',          'note': 'Rest'},
          {'day': 'Fri', 'dist': '3 KM',       'time': '19 Min',     'note': 'Recovery'},
          {'day': 'Sat', 'dist': '-',          'time': '-',          'note': 'Rest'},
          {'day': 'Sun', 'dist': '3 KM',       'time': '18 Min',     'note': 'Tempo'},
        ];
      default:
        return const [
          {'day': 'Mon', 'dist': '4.5 KM',     'time': '30 Min',     'note': 'Long run'},
          {'day': 'Tue', 'dist': '-',          'time': '-',          'note': 'Rest'},
          {'day': 'Wed', 'dist': '400 m × 6',  'time': '1:20 / 3:35 Min/Set', 'note': 'Interval'},
          {'day': 'Thu', 'dist': '-',          'time': '-',          'note': 'Rest'},
          {'day': 'Fri', 'dist': '3.5 KM',     'time': '22 Min',     'note': 'Recovery'},
          {'day': 'Sat', 'dist': '-',          'time': '-',          'note': 'Rest'},
          {'day': 'Sun', 'dist': '3.5 KM',     'time': '21 Min',     'note': 'Tempo'},
        ];
    }
  }

  List<List<Map<String, String>>> get _allWeeks =>
      List.generate(widget.weeks, (w) => _weekPlan(w));

  // ============ ปุ่มเดียว: เลือกวันเริ่ม แล้วส่งออก .ics ทั้งโปรแกรม ============
  Future<void> _addWholeProgramToCalendar(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'เลือก “วันจันทร์ของสัปดาห์ที่ 1”',
      confirmText: 'เพิ่มลงปฏิทิน',
      cancelText: 'ยกเลิก',
    );
    if (picked == null) return;

    // หากผู้ใช้ไม่ได้เลือกวันจันทร์ ให้ปรับเป็นวันจันทร์ของสัปดาห์นั้นอัตโนมัติ
    final monday = picked
        .subtract(Duration(days: (picked.weekday + 6) % 7))
        .copyWith(hour: 8, minute: 0, second: 0);

    await exportTrainingPlanToICS(
      week1StartDate: monday,
      totalWeeks: widget.weeks,
      targetKm: widget.targetKm,
      planByWeeks: _allWeeks,
      startHour: 8,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('เพิ่มลงปฏิทิน (ไฟล์ .ics) เรียบร้อย')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _weekPlan(_weekIndex.clamp(0, widget.weeks - 1));

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 80, // กันชนล่าง
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== ปุ่มเดียว =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.event_available),
                  label: const Text('เพิ่มทั้งโปรแกรมลงปฏิทิน'),
                  onPressed: () => _addWholeProgramToCalendar(context),
                ),
              ),
            ),

            // ===== ส่วนหัว + ตัวเปลี่ยนสัปดาห์ =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('ตารางการฝึก',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    onPressed: _weekIndex > 0 ? () => setState(() => _weekIndex--) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('สัปดาห์ : ${_weekIndex + 1}',
                      style: Theme.of(context).textTheme.titleMedium),
                  IconButton(
                    onPressed: _weekIndex < widget.weeks - 1 ? () => setState(() => _weekIndex++) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ===== ตารางแผน =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Material(
                color: Colors.transparent,
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.4),
                    1: FlexColumnWidth(1.0),
                    2: FlexColumnWidth(1.2),
                  },
                  children: [
                    // header
                    TableRow(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      children: const [
                        _HeaderCell('กิจกรรม'),
                        _HeaderCell('ระยะทาง'),
                        _HeaderCell('เวลา'),
                      ],
                    ),
                    // rows
                    ...plan.map((row) => TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                      ),
                      children: [
                        _RowCell('${row['day']}\n${row['note'] ?? ''}'),
                        _RowCell(row['dist'] ?? '-'),
                        _RowCell(row['time'] ?? '-'),
                      ],
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _RowCell extends StatelessWidget {
  final String text;
  const _RowCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Text(text),
    );
  }
}
