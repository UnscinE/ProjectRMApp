import 'package:flutter/material.dart';

class CalendarTab extends StatelessWidget {
  const CalendarTab({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final theme = Theme.of(context);

    // mock เปอร์เซ็นต์ 0.0..1.0 ในแต่ละวัน
    final percents = List<double>.generate(daysInMonth, (i) => ((i + 3) % 10) / 10);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFAFAFA),
            Color(0xFFF5F5F5),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // หัวข้อ
              Text(
                'ปฏิทินการฝึก',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: const Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF6F00),
                      Color(0xFFFF8F00),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6F00).withOpacity(.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '${_thaiMonth(now.month)} ${now.year + 543}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // หัววัน
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                      color: Colors.black.withOpacity(.04),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'].map((day) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF757575),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // ตารางวัน
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
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
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: daysInMonth,
                    itemBuilder: (context, i) {
                      final pct = percents[i];
                      final day = i + 1;
                      final isToday = day == now.day;
                      final hasActivity = pct > 0.1;

                      return Container(
                        decoration: BoxDecoration(
                          gradient: isToday
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFFF6F00),
                                    Color(0xFFFF8F00),
                                  ],
                                )
                              : null,
                          color: isToday
                              ? null
                              : hasActivity
                                  ? const Color(0xFFF5F5F5)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isToday
                                ? Colors.transparent
                                : hasActivity
                                    ? const Color(0xFFE0E0E0)
                                    : const Color(0xFFEEEEEE),
                            width: 1.5,
                          ),
                          boxShadow: isToday
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFF6F00).withOpacity(.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isToday
                                    ? Colors.white
                                    : hasActivity
                                        ? const Color(0xFF212121)
                                        : const Color(0xFFBDBDBD),
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (hasActivity && !isToday) ...[
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: pct,
                                      strokeWidth: 3,
                                      backgroundColor:
                                          const Color(0xFFEEEEEE),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        Color(0xFFFF6F00),
                                      ),
                                    ),
                                    Text(
                                      '${(pct * 100).toInt()}%',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF757575),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (isToday) ...[
                              const SizedBox(height: 4),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // สรุปสถิติ
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                      color: Colors.black.withOpacity(.05),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      icon: Icons.check_circle,
                      label: 'เสร็จแล้ว',
                      value: '${percents.where((p) => p > 0.8).length}',
                      color: const Color(0xFF10B981),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: const Color(0xFFE0E0E0),
                    ),
                    _StatItem(
                      icon: Icons.trending_up,
                      label: 'กำลังฝึก',
                      value: '${percents.where((p) => p > 0.1 && p <= 0.8).length}',
                      color: const Color(0xFFFF6F00),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: const Color(0xFFE0E0E0),
                    ),
                    _StatItem(
                      icon: Icons.schedule,
                      label: 'รอฝึก',
                      value: '${percents.where((p) => p <= 0.1).length}',
                      color: const Color(0xFF9E9E9E),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _thaiMonth(int m) {
    const months = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    return months[m - 1];
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: const Color(0xFF212121),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: const Color(0xFF757575),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}