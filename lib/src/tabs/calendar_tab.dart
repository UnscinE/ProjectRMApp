// lib/src/tabs/calendar_tab.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_calendar/device_calendar.dart' as devcal;
import 'package:timezone/timezone.dart' as tz;

// ฟังก์ชันจาก helper (คุณมีอยู่แล้ว)
import '../widgets/calendar_helper.dart'
    show pickCalendarIdDialog, loadSelectedCalendarId, saveSelectedCalendarId;

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});
  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  final _plugin = devcal.DeviceCalendarPlugin();

  late DateTime _visibleMonth;                // วันที่ 1 ของเดือนที่กำลังแสดง
  String? _calendarId;                        // id เล่มที่เลือก
  String? _calendarTitle;                     // ชื่อเล่มไว้โชว์
  bool _loading = true;
  String? _error;

  /// เก็บอีเวนต์แยกตาม “วันในเดือน” -> events
  final Map<int, List<devcal.Event>> _eventsByDay = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) โหลด calendarId ที่เคยเลือก (ถ้าไม่มีให้เปิด dialog)
      String? calId = await loadSelectedCalendarId();
      if (calId == null && mounted) {
        final picked = await pickCalendarIdDialog(context);
        if (picked != null) {
          calId = picked;
          await saveSelectedCalendarId(picked);
        }
      }
      if (calId == null) {
        setState(() {
          _calendarId = null;
          _calendarTitle = null;
          _eventsByDay.clear();
          _loading = false;
        });
        return;
      }
      _calendarId = calId;

      // 2) ตั้งชื่อเล่มไว้โชว์ใต้หัวข้อ
      final calsRes = await _plugin.retrieveCalendars();
      final cal = (calsRes.data ?? <devcal.Calendar>[])
          .firstWhere((c) => c.id == _calendarId, orElse: () => devcal.Calendar());
      _calendarTitle = [
        (cal.name ?? 'Calendar'),
        if ((cal.accountName ?? '').isNotEmpty) '• ${cal.accountName}',
      ].join(' ');

      // 3) โหลดอีเวนต์ของเดือนที่กำลังแสดง
      await _loadMonthEvents();
    } catch (e) {
      setState(() {
        _error = '$e';
        _eventsByDay.clear();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMonthEvents() async {
    if (_calendarId == null) return;
    _eventsByDay.clear();

    final start = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final end = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1)
        .subtract(const Duration(seconds: 1));
    final tzStart = tz.TZDateTime.from(start, tz.local);
    final tzEnd = tz.TZDateTime.from(end, tz.local);

    final res = await _plugin.retrieveEvents(
      _calendarId!,
      devcal.RetrieveEventsParams(startDate: tzStart, endDate: tzEnd),
    );
    final events = res.data ?? <devcal.Event>[];

    for (final e in events) {
      final dt = (e.start?.toLocal() ?? start);
      if (dt.month != _visibleMonth.month || dt.year != _visibleMonth.year) continue;
      final d = dt.day;
      (_eventsByDay[d] ??= <devcal.Event>[]).add(e);
    }
    for (final list in _eventsByDay.values) {
      list.sort((a, b) {
        final ta = a.start?.toLocal() ?? start;
        final tb = b.start?.toLocal() ?? start;
        return ta.compareTo(tb);
      });
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickMonth() async {
  final picked = await showDatePicker(
    context: context,
    initialDate: _visibleMonth,
    firstDate: DateTime(2015, 1, 1),
    lastDate: DateTime(2100, 12, 31),
    helpText: 'เลือกเดือน',
    // 👇 แต่งปอปอัพตรงนี้
    builder: (ctx, child) {
      final base = Theme.of(ctx);
      return Theme(
        data: base.copyWith(
          colorScheme: base.colorScheme.copyWith(
            primary: const Color(0xFFFF6F00),   // สีไฮไลต์/ปุ่ม OK
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: const Color(0xFF212121),
          ),
          datePickerTheme: const DatePickerThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
            headerBackgroundColor: Color(0xFFFF8F00),
            headerForegroundColor: Colors.white,
            dayStyle: TextStyle(fontWeight: FontWeight.w700),
            todayForegroundColor: WidgetStatePropertyAll(Color(0xFFFF6F00)),
            todayBackgroundColor: WidgetStatePropertyAll(Color(0x1AFF6F00)),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF6F00), // ปุ่ม Cancel
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        child: child!,
      );
    },
  );
  if (picked != null) {
    setState(() => _visibleMonth = DateTime(picked.year, picked.month, 1));
    setState(() => _loading = true);
    await _loadMonthEvents();
    if (mounted) setState(() => _loading = false);
  }
}


  Future<void> _changeCalendar() async {
    final picked = await pickCalendarIdDialog(context);
    if (picked == null) return;
    await saveSelectedCalendarId(picked);
    await _bootstrap();
  }

  Future<void> _prevMonth() async {
    setState(() => _visibleMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1));
    setState(() => _loading = true);
    await _loadMonthEvents();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _nextMonth() async {
    setState(() => _visibleMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1));
    setState(() => _loading = true);
    await _loadMonthEvents();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysInMonth =
        DateUtils.getDaysInMonth(_visibleMonth.year, _visibleMonth.month);
    final firstWeekday =
        DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday; // Mon=1..Sun=7
    final leadingEmpty = (firstWeekday - 1) % 7;
    final totalCells = leadingEmpty + daysInMonth;
    final trailingEmpty = (totalCells % 7 == 0) ? 0 : (7 - (totalCells % 7));
    final gridCount = totalCells + trailingEmpty;

    final now = DateTime.now();
    final isThisMonth =
        now.year == _visibleMonth.year && now.month == _visibleMonth.month;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFFFAFAFA), Color(0xFFF5F5F5)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // หัวเรื่อง
              Text(
                'ปฏิทินการฝึก',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: const Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 10),

              // เดือน + ปุ่มเปลี่ยนเล่ม/รีเฟรช
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundIconButton(icon: Icons.chevron_left, onTap: _prevMonth),
                  const SizedBox(width: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: _pickMonth,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
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
                      child: Row(
                        children: [
                          Text(
                            '${_thaiMonth(_visibleMonth.month)} ${_visibleMonth.year + 543}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.expand_more, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RoundIconButton(
                    icon: Icons.chevron_right,
                    onTap: _nextMonth,
                  ),
                  const SizedBox(width: 10),
                  // ปุ่มเลือกเล่ม
                  _RoundIconButton(
                    icon: Icons.refresh, // หรือ Icons.event_note
                    onTap: _changeCalendar,
                  ),
                ],
              ),

              if (_calendarTitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  _calendarTitle!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF757575),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // แถบชื่อวัน
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
                  children: const ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา']
                      .map((d) => Expanded(
                            child: Center(
                              child: Text(
                                d,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF757575),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),

              const SizedBox(height: 16),

              // ตารางวัน (ข้อมูลจริง)
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
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Text(
                                'ผิดพลาด: $_error',
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : GridView.builder(
                              physics: const BouncingScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.82,
                              ),
                              itemCount: gridCount,
                              itemBuilder: (context, index) {
                                if (index < leadingEmpty) return const SizedBox.shrink();
                                final day = index - leadingEmpty + 1;
                                if (day > daysInMonth) return const SizedBox.shrink();

                                final isToday = isThisMonth && day == now.day;
                                final events = _eventsByDay[day] ?? const <devcal.Event>[];
                                final hasEvent = events.isNotEmpty;

                                return _DayCell(
                                  day: day,
                                  isToday: isToday,
                                  hasEvent: hasEvent,
                                  eventCount: events.length,
                                  onTap: hasEvent
                                      ? () => _showDayEvents(context, day, events)
                                      : null,
                                );
                              },
                            ),
                ),
              ),

              const SizedBox(height: 20),

              // สรุป (นับจากอีเวนต์จริง)
              _SummaryBar(visibleMonth: _visibleMonth, eventsByDay: _eventsByDay),
            ],
          ),
        ),
      ),
    );
  }

  void _showDayEvents(BuildContext context, int day, List<devcal.Event> events) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'กิจกรรมวันที่ $day ${_thaiMonth(_visibleMonth.month)} ${_visibleMonth.year + 543}',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const Divider(height: 10),
                    itemBuilder: (_, i) {
                      final e = events[i];
                      final st = e.start?.toLocal();
                      final et = e.end?.toLocal();
                      final time = (st != null && et != null)
                          ? '${_hhmm(st)} – ${_hhmm(et)}'
                          : (st != null ? _hhmm(st) : '-');

                      return ListTile(
                        leading: const Icon(Icons.event_note, color: Color(0xFFFF6F00)),
                        title: Text((e.title ?? '').isEmpty ? '(ไม่มีชื่อเรื่อง)' : e.title!),
                        subtitle: Text(time),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool hasEvent;
  final int eventCount;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.hasEvent,
    required this.eventCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: isToday
                ? const LinearGradient(colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)])
                : null,
            color: isToday
                ? null
                : hasEvent
                    ? const Color(0xFFF5F5F5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isToday
                  ? Colors.transparent
                  : hasEvent
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isToday
                          ? Colors.white
                          : hasEvent
                              ? const Color(0xFF212121)
                              : const Color(0xFFBDBDBD),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isToday)
                    Container(
                      width: 5, height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    )
                  else if (hasEvent)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, size: 6, color: Color(0xFFFF6F00)),
                        const SizedBox(width: 4),
                        Text(
                          '$eventCount',
                          style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF757575)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final DateTime visibleMonth;
  final Map<int, List<devcal.Event>> eventsByDay;

  const _SummaryBar({required this.visibleMonth, required this.eventsByDay});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    int done = 0, doing = 0, todo = 0;

    eventsByDay.forEach((d, evs) {
      final date = DateTime(visibleMonth.year, visibleMonth.month, d);
      if (date.isBefore(DateTime(now.year, now.month, now.day))) {
        done += evs.length;
      } else if (date.year == now.year && date.month == now.month && date.day == now.day) {
        doing += evs.length;
      } else {
        todo += evs.length;
      }
    });

    Widget item(IconData icon, String label, String value, Color color) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(.12), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900, color: const Color(0xFF212121), letterSpacing: -0.5,
          )),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(
            color: Color(0xFF757575), fontWeight: FontWeight.w600, fontSize: 12,
          )),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(blurRadius: 12, offset: const Offset(0, 3), color: Colors.black.withOpacity(.05))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          item(Icons.check_circle, 'เสร็จแล้ว', '$done', const Color(0xFF10B981)),
          Container(width: 1, height: 40, color: const Color(0xFFE0E0E0)),
          item(Icons.trending_up, 'กำลังฝึก', '$doing', const Color(0xFFFF6F00)),
          Container(width: 1, height: 40, color: const Color(0xFFE0E0E0)),
          item(Icons.schedule, 'รอฝึก', '$todo', const Color(0xFF9E9E9E)),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: const Color(0xFF616161)),
        ),
      ),
    );
  }
}

String _thaiMonth(int m) {
  const months = ['มกราคม','กุมภาพันธ์','มีนาคม','เมษายน','พฤษภาคม','มิถุนายน',
    'กรกฎาคม','สิงหาคม','กันยายน','ตุลาคม','พฤศจิกายน','ธันวาคม'];
  return months[m - 1];
}
