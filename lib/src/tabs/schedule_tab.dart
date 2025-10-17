import 'package:flutter/material.dart';

class ScheduleTab extends StatefulWidget {
  final int weeks;
  final int targetKm; // เผื่ออนาคต
  const ScheduleTab({super.key, required this.weeks, required this.targetKm});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  int _week = 1;

  @override
  Widget build(BuildContext context) {
    final plan = _mockPlanForWeek(_week);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ตารางการฝึก', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(onPressed: _week>1 ? ()=> setState(()=>_week--) : null, icon: const Icon(Icons.chevron_left)),
              Text('สัปดาห์ : $_week', style: Theme.of(context).textTheme.titleMedium),
              IconButton(onPressed: _week<widget.weeks ? ()=> setState(()=>_week++) : null, icon: const Icon(Icons.chevron_right)),
            ],
          ),
          const SizedBox(height: 8),

          // Header
          Container(
            decoration: BoxDecoration(color: const Color(0xFFF2F2F4), borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text('กิจกรรม', style: TextStyle(fontWeight: FontWeight.w700))),
                Expanded(child: Text('ระยะทาง', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700))),
                Expanded(child: Text('เวลา', textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w700))),
              ],
            ),
          ),

          const SizedBox(height: 6),

          Expanded(
            child: ListView.separated(
              itemCount: plan.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = plan[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(r.dayName)),
                      Expanded(child: Text(r.distance, textAlign: TextAlign.center)),
                      Expanded(child: Text(r.time, textAlign: TextAlign.end)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- MOCK PLAN ----------
  List<_Row> _mockPlanForWeek(int week) {
    // สัปดาห์ 1..4 ใช้แพทเทิร์นใกล้เคียงกัน
    const rows = [
      _Row('Mon', 'Long run', '3 KM', '21 Min'),
      _Row('Tue', 'Rest', '-', '-'),
      _Row('Wed', 'Interval run', '400 M × 4', '1:30 / 3:50 Min/Set'),
      _Row('Thu', 'Rest', '-', '-'),
      _Row('Fri', 'Recovery run', '2 KM', '14 Min'),
      _Row('Sat', 'Rest', '-', '-'),
      _Row('Sun', 'Tempo run', '2 KM', '13 Min'),
    ];
    return rows.map((e) => e.copyWith(dayName: e.dayName)).toList();
  }
}

class _Row {
  final String dayName;
  final String activity;
  final String distance;
  final String time;
  const _Row(this.dayName, this.activity, this.distance, this.time);

  _Row copyWith({String? dayName, String? activity, String? distance, String? time}) =>
      _Row(dayName ?? this.dayName, activity ?? this.activity, distance ?? this.distance, time ?? this.time);
}
