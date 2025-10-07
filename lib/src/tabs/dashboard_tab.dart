import 'package:flutter/material.dart';

class DashboardTab extends StatelessWidget {
  final int targetKm;
  final int trainingWeeks;
  final VoidCallback onContinue;
  final String email;

  const DashboardTab({
    super.key,
    required this.targetKm,
    required this.trainingWeeks,
    required this.onContinue,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    // ---------- MOCK DATA ----------
    final distance = 5.0;             // km
    final pace = '6:11 / Km';         // mock
    final totalTime = '30:59 นาที';   // mock
    final successPercent = 94;         // mock 0..100
    final today = DateTime.now();
    // --------------------------------

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('การวิ่ง', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          // วันที่
          Text('${today.day} ${_thaiMonth(today.month)} ${today.year + 543}', style: Theme.of(context).textTheme.bodyMedium),

          const SizedBox(height: 12),

          // สรุป 3 ช่อง
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatBox(title: 'ระยะทาง', value: '${distance.toStringAsFixed(2)} กม.'),
              _StatBox(title: 'เพซเฉลี่ย', value: pace),
              _StatBox(title: 'เวลารวม', value: totalTime),
            ],
          ),

          const SizedBox(height: 20),

          // วงกลมเปอร์เซ็นต์ (mock 50)
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200, height: 200,
                  child: CircularProgressIndicator(
                    value: 0.50, // 50%
                    strokeWidth: 14,
                  ),
                ),
                Text('50', style: Theme.of(context).textTheme.displaySmall),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // สัปดาห์ 1..N ไฮไลต์อันแรก (mock)
          _WeekStrip(current: 1, total: trainingWeeks),

          const SizedBox(height: 16),
          Text('อัตราความสำเร็จของคุณ', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('$successPercent / 100 %', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),

          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              child: const Text('Continue Training'),
            ),
          ),

          const SizedBox(height: 8),
          Text('สวัสดี $email • โปรแกรม ${targetKm} กม. • ${trainingWeeks} สัปดาห์',
              style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _thaiMonth(int m) {
    const months = ['มกราคม','กุมภาพันธ์','มีนาคม','เมษายน','พฤษภาคม','มิถุนายน','กรกฎาคม','สิงหาคม','กันยายน','ตุลาคม','พฤศจิกายน','ธันวาคม'];
    return months[m-1];
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  const _StatBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6E6EA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.black54)),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  final int current;
  final int total;
  const _WeekStrip({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final idx = i + 1;
        final selected = idx == current;
        return Expanded(
          child: Container(
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: selected ? Colors.lightGreenAccent.shade100 : const Color(0xFFE0E0E2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(child: Text('$idx')),
          ),
        );
      }),
    );
  }
}
