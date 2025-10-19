// lib/src/trainingtask_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'modelhandle_backend.dart';
import 'training_repo.dart';

class ScreenTwo extends StatefulWidget {
  const ScreenTwo({super.key});
  @override
  State<ScreenTwo> createState() => _ScreenTwoState();
}

class Vector3 {
  final double x;
  final double y;
  final double z;
  const Vector3(this.x, this.y, this.z);
}

class _ScreenTwoState extends State<ScreenTwo> {
  // -------- State หลัก --------
  final HarModelPredictor _predictor = HarModelPredictor();

  String? _currentProgramId;

  // แผนของวันนี้
  String _runningType = 'Long Run';
  String _runningTargetText = ''; // เช่น "3 KM"
  int _timeTargetMin = 0;         // นาที
  double _targetDistanceKm = 0.0; // กิโลเมตร (parse จาก _runningTargetText)

  // ค่าขณะฝึก
  bool _isTraining = false;
  String _activity = 'getting data';
  double _distanceKm = 0.0;       // ระยะทางที่ทำได้ (km)
  String _speedKmhText = '0.00';  // แสดงบน UI

  // Stopwatch
  Timer? _timer;
  int _secs = 0;
  bool _running = false;

  // Countdown overlay
  int _countdown = 0;
  bool _showOverlay = false;

  // GPS
  StreamSubscription<Position>? _locationSub;
  Position? _lastPosition;
  double _totalDistanceMeters = 0.0;
  double _currentSpeedMs = 0.0;

  // Sensors
  Vector3 _accelerometerData = const Vector3(0, 0, 0);
  Vector3 _gyroscopeData = const Vector3(0, 0, 0);

  final List<double> _accelMagnitudes = [];
  final List<double> _gyroMagnitudes = [];
  final int _maxDataPoints = 50;

  final List<Map<String, double>> _rawAccelData = [];
  final List<Map<String, double>> _rawGyroData = [];

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  @override
  void initState() {
    super.initState();
    _predictor.loadModel();
    _loadProgramId();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  // ---------------- Firestore / Program ----------------
  Future<void> _loadProgramId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final idList = await TrainingRepo.fetchCurrentProgramId(user.uid);
    setState(() => _currentProgramId = idList?.first);
    if (_currentProgramId != null) {
      await _loadTodayPlan();
    }
  }

  Future<void> _loadTodayPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentProgramId == null) return;

    // ใช้ฟอร์แมตเดียวกับฝั่งบันทึก: dd-MM-yyyy
    final todayId = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Program')
        .doc(_currentProgramId!)
        .collection('Training')
        .doc(todayId);

    try {
      final snap = await docRef.get();
      if (!snap.exists) {
        setState(() {
          _runningType = 'No Plan';
          _runningTargetText = 'N/A';
          _timeTargetMin = 0;
          _targetDistanceKm = 0.0;
        });
        return;
      }

      final data = snap.data()!;
      final distanceText = (data['distance']?.toString() ?? '').trim(); // เช่น "3 KM" หรือ "400 m × 4"
      final timeText = (data['time']?.toString() ?? '').trim();         // เช่น "21 Min"
      final typeText = (data['type']?.toString() ?? 'Rest').trim();

      // ดึงตัวเลขนาทีจาก timeText
      final minutesNum = int.tryParse(timeText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      // ดึงตัวเลขกิโลเมตรจาก distanceText
      final distanceNum = double.tryParse(distanceText.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

      setState(() {
        _runningType = typeText;
        _runningTargetText = distanceText;
        _timeTargetMin = minutesNum;
        _targetDistanceKm = distanceNum;
      });
    } catch (_) {
      setState(() {
        _runningType = 'Error';
        _runningTargetText = 'Error';
        _timeTargetMin = 0;
        _targetDistanceKm = 0.0;
      });
    }
  }

  Future<void> _recordData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentProgramId == null) return;

    final dateKey = DateFormat('dd-MM-yyyy').format(DateTime.now());

    final totalDistanceKm = _totalDistanceMeters / 1000.0;
    final avgSpeedKph = _secs == 0 ? 0.0 : (totalDistanceKm / (_secs / 3600)); // km/h
    String two(int n) => n.toString().padLeft(2, '0');
    final durationStr =
        '${two(Duration(seconds: _secs).inHours)}:'
        '${two(Duration(seconds: _secs).inMinutes.remainder(60))}:'
        '${two(_secs % 60)}';

    // คำนวณ progress 0..100 จากเวลา/ระยะทางแบบถัวเฉลี่ย
    final progress01 = _calculateOverallProgress();        // 0..1
    final progressBar = (progress01 * 100).round().clamp(0, 100);

    final ref = FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('Program').doc(_currentProgramId!)
        .collection('Training').doc(dateKey);

    final data = {
      'date': Timestamp.now(),
      'activity': _activity,
      'distance_km': totalDistanceKm,
      'duration_s': _secs,
      'duration_display': durationStr,
      'average_speed_kph': avgSpeedKph.toStringAsFixed(2),
      'progress_bar_percent': progressBar, // เก็บค่าเดียว ไม่ซ้ำคีย์
    };

    try {
      await ref.set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Record error: $e');
    }
  }

  // ---------------- GPS ----------------
  Future<void> _initLocationService() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
    }

    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((pos) {
      if (!mounted) return;

      setState(() {
        _currentSpeedMs = (pos.speed).abs();
        _speedKmhText = (_currentSpeedMs * 3.6).toStringAsFixed(2);

        if (_lastPosition != null) {
          final inc = Geolocator.distanceBetween(
            _lastPosition!.latitude, _lastPosition!.longitude,
            pos.latitude, pos.longitude,
          );
          _totalDistanceMeters += inc;
          _distanceKm = _totalDistanceMeters / 1000.0;
        }
        _lastPosition = pos;
      });
    });
  }

  // ---------------- Sensors ----------------
  void _startSensorStreams() {
    final int t0 = DateTime.now().millisecondsSinceEpoch;

    // ใช้สตรีมมาตรฐานของ sensors_plus (ไม่ใช่ *_EventStream)
    _accelSub = accelerometerEvents.listen((e) {
      if (!mounted) return;

      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      final time = (DateTime.now().millisecondsSinceEpoch - t0) / 1000.0;

      _rawAccelData.add({
        'Time (s)': time,
        'accelerometer_x': e.x,
        'accelerometer_y': e.y,
        'accelerometer_z': e.z,
      });

      setState(() {
        _accelerometerData = Vector3(e.x, e.y, e.z);
        _accelMagnitudes.add(mag);
        if (_accelMagnitudes.length > _maxDataPoints) {
          _accelMagnitudes.removeAt(0);
        }
      });
    });

    _gyroSub = gyroscopeEvents.listen((e) {
      if (!mounted) return;

      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      final time = (DateTime.now().millisecondsSinceEpoch - t0) / 1000.0;

      _rawGyroData.add({
        'Time (s)': time,
        'gyroscope_x': e.x,
        'gyroscope_y': e.y,
        'gyroscope_z': e.z,
      });

      setState(() {
        _gyroscopeData = Vector3(e.x, e.y, e.z);
        _gyroMagnitudes.add(mag);
        if (_gyroMagnitudes.length > _maxDataPoints) {
          _gyroMagnitudes.removeAt(0);
        }
      });
    });
  }

  // ---------------- Stopwatch / Progress ----------------
  void _startStopwatch() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _secs++;

        // จบอัตโนมัติถ้าบรรลุระยะทาง
        if (_targetDistanceKm > 0 && _distanceKm >= _targetDistanceKm) {
          t.cancel();
          _stopTraining();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🎉 Goal reached! Session ended.')),
          );
        }
      });
    });
  }

  void _stopStopwatch() {
    _running = false;
    _timer?.cancel();
  }

  /// รวมความคืบหน้าจาก "เวลา" + "ระยะทาง" (ถ้ามีแผน)
  double _calculateOverallProgress({double weightTime = 0.5, double weightDistance = 0.5}) {
    double pTime = 0.0;
    if (_timeTargetMin > 0) {
      final targetSecs = _timeTargetMin * 60;
      pTime = _secs / targetSecs;
    }

    double pDist = 0.0;
    if (_targetDistanceKm > 0) {
      pDist = _distanceKm / _targetDistanceKm;
    }

    final p = (pTime.clamp(0.0, 1.0) * weightTime) +
              (pDist.clamp(0.0, 1.0) * weightDistance);
    return p.clamp(0.0, 1.0);
  }

  String get _timeText {
    final m = (_secs ~/ 60).toString().padLeft(2, '0');
    final s = (_secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ---------------- Flow Start/Stop ----------------
  void _startCountdown() {
    if (_showOverlay) return;
    setState(() {
      _countdown = 3;
      _showOverlay = true;
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        setState(() => _showOverlay = false);
        _startTraining();
      }
    });
  }

  void _startTraining() {
    // reset
    _rawAccelData.clear();
    _rawGyroData.clear();
    _totalDistanceMeters = 0.0;
    _lastPosition = null;
    _distanceKm = 0.0;
    _secs = 0;

    _startSensorStreams();
    _isTraining = true;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Training started!')));

    _startStopwatch();
    _initLocationService();

    // loop ทำนายกิจกรรมทุก 0.5s
    Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (!_isTraining) {
        t.cancel();
        return;
      }
      final features = _extractFeatures(_rawAccelData, _rawGyroData);
      if (features.isNotEmpty) {
        final pred = _predictor.predict(features);
        setState(() => _activity = pred);
      }
    });
  }

  void _stopTraining() {
    _isTraining = false;
    _stopStopwatch();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _locationSub?.cancel();

    _recordData();
  }

  // ---------------- Feature Extraction ----------------
  Map<String, double> _extractFeatures(
    List<Map<String, double>> accelData,
    List<Map<String, double>> gyroData,
  ) {
    const window = 100;
    if (accelData.length < window || gyroData.length < window) return {};

    final ax = accelData.sublist(accelData.length - window);
    final gx = gyroData.sublist(gyroData.length - window);

    List<double> col(List<Map<String, double>> d, String k) =>
        d.map((m) => m[k]!).toList();

    final aX = col(ax, 'accelerometer_x');
    final aY = col(ax, 'accelerometer_y');
    final aZ = col(ax, 'accelerometer_z');

    final gX = col(gx, 'gyroscope_x');
    final gY = col(gx, 'gyroscope_y');
    final gZ = col(gx, 'gyroscope_z');

    List<double> mag(List<Map<String, double>> d, String x, String y, String z) =>
        d.map((m) => sqrt(pow(m[x]!, 2) + pow(m[y]!, 2) + pow(m[z]!, 2))).toList();

    final aMag = mag(ax, 'accelerometer_x', 'accelerometer_y', 'accelerometer_z');
    final gMag = mag(gx, 'gyroscope_x', 'gyroscope_y', 'gyroscope_z');

    double mean(List<double> v) =>
        v.isEmpty ? 0.0 : v.reduce((a, b) => a + b) / v.length;

    double std(List<double> v, double m) {
      if (v.length < 2) return 0.0;
      final varSum = v.map((x) => pow(x - m, 2)).reduce((a, b) => a + b);
      return sqrt(varSum / (v.length - 1));
    }

    double skew(List<double> v, double m, double s) {
      if (s == 0.0) return 0.0;
      double sum = 0.0;
      for (var x in v) sum += pow((x - m) / s, 3);
      return sum / v.length;
    }

    double kurt(List<double> v, double m, double s) {
      if (s == 0.0) return 0.0;
      double sum = 0.0;
      for (var x in v) sum += pow((x - m) / s, 4);
      return (sum / v.length) - 3.0;
    }

    Map<String, List<double>> streams = {
      'accelerometer_x': aX,
      'accelerometer_y': aY,
      'accelerometer_z': aZ,
      'gyroscope_x': gX,
      'gyroscope_y': gY,
      'gyroscope_z': gZ,
    };

    final f = <String, double>{};
    for (final e in streams.entries) {
      final m = mean(e.value);
      final s = std(e.value, m);
      f['${e.key}_mean'] = m;
      f['${e.key}_std'] = s;
      f['${e.key}_max'] = e.value.reduce(max);
      f['${e.key}_min'] = e.value.reduce(min);
      f['${e.key}_skew'] = skew(e.value, m, s);
      f['${e.key}_kurtosis'] = kurt(e.value, m, s);
    }
    f['acceleration_magnitude_mean'] = mean(aMag);
    f['gyroscope_magnitude_mean'] = mean(gMag);
    return f;
  }

  // ---------------- UI helpers ----------------
  Widget _buildMagnitudeChart({
    required String title,
    required List<double> dataPoints,
    required Color color,
    required IconData icon,
    required String unit,
  }) {
    final latest = dataPoints.isEmpty ? 0.0 : dataPoints.last;
    final double maxData = dataPoints.isEmpty ? 1.0 : dataPoints.reduce(max);
    final double maxY = (maxData * 1.1).clamp(1.0, 50.0);

    final List<FlSpot> spots = dataPoints
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.only(top: 15, bottom: 8, left: 8, right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF6F00).withOpacity(.25), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: Color(0xFF212121)),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            const Divider(height: 12, color: Color(0xFFECECEC)),
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8),
              child: Text(
                'Current: ${latest.toStringAsFixed(2)} $unit',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF212121)),
              ),
            ),
            Expanded(
              child: spots.isEmpty
                  ? const Center(child: Text('Waiting for sensor data...'))
                  : LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: _maxDataPoints.toDouble() - 1,
                        minY: 0,
                        maxY: maxY,
                        titlesData: const FlTitlesData(
                          show: true,
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => const FlLine(
                            color: Color(0xFFE0E0E0),
                            strokeWidth: 0.5,
                            dashArray: [5, 5],
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: color,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: color.withOpacity(0.28)),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _calculateOverallProgress();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Training Details',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: const Color(0xFF212121),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF212121),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFFAFAFA), Color(0xFFF5F5F5), Color(0xFFEEEEEE)],
          ),
        ),
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---- Progress Card ----
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        elevation: 4,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _runningType,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: const Color(0xFF212121),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Training Progress',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF212121),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 12,
                                  backgroundColor: const Color(0xFFECECEC),
                                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6F00)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF616161),
                                ),
                              ),
                              const Divider(height: 24, thickness: 1, color: Color(0xFFECECEC)),
                              SizedBox(
                                height: 250,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF3E0),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            _statRow('Time', _timeText, '${_timeTargetMin} Min'),
                                            _statRow('Distance', _distanceKm.toStringAsFixed(2), '${_distanceKm.toStringAsFixed(2)} / $_runningTargetText'),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF3E0),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            _statRow('Activity', _activity, ''),
                                            _statRow('Speed', '$_speedKmhText km/h', ''),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ---- Charts ----
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            height: 250,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _buildMagnitudeChart(
                                    title: 'Accel. Magnitude',
                                    dataPoints: _accelMagnitudes,
                                    unit: 'm/s²',
                                    icon: Icons.speed_rounded,
                                    color: const Color(0xFFFF6F00),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMagnitudeChart(
                                    title: 'Gyro. Magnitude',
                                    dataPoints: _gyroMagnitudes,
                                    unit: 'rad/s',
                                    icon: Icons.rotate_right_rounded,
                                    color: const Color(0xFFFF6F00),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ---- Start/Stop ----
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        child: ElevatedButton(
                          onPressed: _isTraining ? _stopTraining : _startCountdown,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            backgroundColor: _isTraining ? Colors.redAccent : const Color(0xFFFF6F00),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: Text(
                            _isTraining ? 'STOP' : 'Start',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_showOverlay)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Text(
                      _countdown > 0 ? '$_countdown' : 'GO!',
                      style: const TextStyle(
                        fontSize: 100,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 10, color: Color(0xFFFF8F00), offset: Offset(2, 2))],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String title, String value, String sub) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2, color: const Color(0xFF212121))),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF616161))),
          if (sub.isNotEmpty)
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF9E9E9E), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
