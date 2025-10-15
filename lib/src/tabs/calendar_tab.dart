import 'package:flutter/material.dart';


class CalendarTab extends StatelessWidget {
  const CalendarTab({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);

    // mock เปอร์เซ็นต์ 0.0..1.0 ในแต่ละวัน
    final percents = List<double>.generate(daysInMonth, (i) => ((i+3) % 10) / 10);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('ปฏิทินการฝึก', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${firstDay.day} ${_thaiMonth(now.month)} ${now.year + 543}', style: Theme.of(context).textTheme.bodyMedium),

          const SizedBox(height: 12),

          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: daysInMonth,
              itemBuilder: (context, i) {
                final pct = percents[i];
                final day = i + 1;
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD5D5DA)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 30, height: 30,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(value: pct, strokeWidth: 5),
                          Text('$day', style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _thaiMonth(int m) {
    const months = ['มกราคม','กุมภาพันธ์','มีนาคม','เมษายน','พฤษภาคม','มิถุนายน','กรกฎาคม','สิงหาคม','กันยายน','ตุลาคม','พฤศจิกายน','ธันวาคม'];
    return months[m-1];
  }
}
