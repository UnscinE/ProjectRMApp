// lib/src/trainingtask_page.dart
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

/// ---------- Interval runtime model ----------
class _IntervalRuntime {
  final double segmentMeters;
  final int totalReps;
  int currentLap = 0; // index 0..totalReps-1
  final List<double> lapMeters; // ระยะสะสมของแต่ละ Lap (เมตร)
  int lastWriteMs = 0;

  _IntervalRuntime({required this.segmentMeters, required this.totalReps})
    : lapMeters = List<double>.filled(max(totalReps, 0), 0.0);

  int get repsDone => lapMeters.where((m) => m >= segmentMeters).length;

  double get currentLapProgress {
    if (currentLap >= totalReps) return 1.0;
    final m = lapMeters[currentLap];
    return (m / segmentMeters).clamp(0.0, 1.0);
  }

  bool get isFinished => repsDone >= totalReps;

  /// เติมระยะให้ Lap ปัจจุบัน, คืนค่า true ถ้าจบทั้งหมด
  bool addDelta(double meters) {
    if (isFinished || totalReps == 0) return false;
    lapMeters[currentLap] += meters;

    // ถ้าเกินตัดให้เท่ากับเป้า
    if (lapMeters[currentLap] > segmentMeters) {
      lapMeters[currentLap] = segmentMeters;
    }
    // ถ้า lap ปัจจุบันครบแล้ว → ไป Lap ถัดไป
    if (lapMeters[currentLap] >= segmentMeters) {
      currentLap++;
      if (currentLap >= totalReps) return true; // จบทั้งหมด
    }
    return false;
  }
}

class _ScreenTwoState extends State<ScreenTwo> {
  final HarModelPredictor _predictor = HarModelPredictor();

  String? _currentProgramId;

  // แผนของวันนี้
  String _runningType = 'Long Run';
  String _runningTargetText = ''; // เช่น "3 KM" หรือ "400 m × 4"
  String _timeTargetText = ''; // เช่น "1:30 / 3:50"
  int _timeTargetSec = 0;
  String _timeTargetMinText = 'N/A';
  double _targetDistanceKm = 0.0;

  // Interval runtime (ถ้าวันนี้เป็น Interval)
  _IntervalRuntime? _interval;
  // โหมดวิ่ง/พัก
  String _intervalMode = 'run'; // "run" | "rest"
  int _intervalRestSec = 90; // เวลาพักต่อรอบ (วินาที)
  int _restLeft = 0; // เวลาพักคงเหลือ
  Timer? _restTimer; // ไทเมอร์นับเวลาพัก

  // ค่าขณะฝึก
  bool _isTraining = false;
  String _activity = 'getting data';
  double _distanceKm = 0.0;
  String _speedKmhText = '0.00';

  // Stopwatch
  Timer? _timer;
  int _secs = 0;
  bool _running = false;
  int _secInter = 0;

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
    _restTimer?.cancel();
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

  /// parse ระยะ/เวลา เพื่อเตรียม interval runtime ถ้าจำเป็น
  _IntervalRuntime? _buildIntervalFromStrings(String distanceText) {
    final re = RegExp(
      r'(\d+(?:\.\d+)?)\s*(km|m)\s*[x×]\s*(\d+)',
      caseSensitive: false,
    );
    final m = re.firstMatch(distanceText.trim());
    if (m == null) return null;
    final seg = double.parse(m.group(1)!);
    final unit = m.group(2)!.toLowerCase();
    final reps = int.parse(m.group(3)!);
    final segMeters = unit == 'km' ? seg * 1000.0 : seg;
    return _IntervalRuntime(segmentMeters: segMeters, totalReps: reps);
  }

  // กำหนดน้ำหนักการคิด % ตามชนิดการวิ่ง
  List<double> _weightsForType() {
    final t = _runningType.toLowerCase();

    // Tempo = คิดแบบเดียวกับ Recovery/Long/Easy → “ระยะทางล้วน”
    // if (t.contains('recovery') ||
    //     t.contains('easy') ||
    //     t.contains('long') ||
    //     t.contains('tempo')) {
    //   return [0.0, 1.0]; // [น้ำหนักเวลา, น้ำหนักระยะ]
    // }

    // ดีฟอลต์: มีทั้งเวลาและระยะ → 50/50, มีอย่างเดียวก็อิงอย่างเดียว
    final hasTime = _timeTargetSec > 0;
    final hasDist = _targetDistanceKm > 0;
    if (hasTime && hasDist) return [0.5, 0.5];
    if (hasTime) return [1.0, 0.0];
    if (hasDist) return [0.0, 1.0];
    return [0.0, 0.0];
  }

  /// ดึง "เวลาพัก" (วินาที) จากสตริงเวลา เช่น "1:30 / 3:50" → 90
  int _parseRestSec(String timeText) {
    // หา mm:ss ตัวแรกในสตริง
    final mmss = RegExp(r'(\d{1,2}):(\d{2})');
    final m = mmss.firstMatch(timeText);
    if (m != null) {
      final mm = int.tryParse(m.group(1)!) ?? 0;
      final ss = int.tryParse(m.group(2)!) ?? 0;
      return (mm * 60) + ss;
    }
    // ถ้าไม่เจอ ลองเขียนเป็นนาทีล้วน ๆ เช่น "90"
    final onlyNum =
        int.tryParse(timeText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (onlyNum >= 30 && onlyNum <= 600) return onlyNum; // เดาว่าเป็นวินาที
    // fallback
    return 90;
  }

  Future<void> _loadTodayPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentProgramId == null) return;

    final todayId = 
    //'02-11-2025';
    DateFormat('dd-MM-yyyy').format(DateTime.now());
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
          _timeTargetText = 'N/A';
          _timeTargetSec = 0;
          _targetDistanceKm = 0.0;
          _interval = null;
        });
        return;
      }

      String targetmintext = 'N/A';

      final data = snap.data()!;
      var distanceText = (data['distance']?.toString() ?? '').trim();
      final timeText = (data['time']?.toString() ?? '').trim();
      final typeText = (data['type']?.toString() ?? 'Rest').trim();

      // minutes (เฉพาะใช้โชว์)
      var secondsNum = 0;

      if (_interval != null) {
        secondsNum =
            int.tryParse(timeText.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0 * 60;

        targetmintext = secondsNum.toString();
      } else {
        var min = 0;
        var sec = 0;
        //minutesNum = int.tryParse(timeText.replaceAll(RegExp(r'(?<=\/\s*)\d{1,2}:\d{2}'), '')) ?? 0;

        min =
            int.tryParse(
              RegExp(r'(?<=\/\s*)\d{1,2}').firstMatch(timeText)?.group(0) ??
                  '0',
            ) ??
            0;
        sec =
            int.tryParse(
              RegExp(
                    r'(?<=\/\s*\d{1,2}:)\d{2}',
                  ).firstMatch(timeText)?.group(0) ??
                  '0',
            ) ??
            0;

        secondsNum = min * 60 + sec;

        targetmintext = '$min:$sec';
        print(targetmintext);
        print(secondsNum);
      }
      ;

      final distanceNum =
          double.tryParse(distanceText.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0.0;

      _IntervalRuntime? interval;
      if (typeText.toLowerCase() == 'interval') {
        double inttexttoshow = 0.0;

        interval = _buildIntervalFromStrings(distanceText);
        final RegExpMatch? match = RegExp(
          r'(\d+)\s*m\s*[x×]\s*(\d+)',
        ).firstMatch(distanceText.trim());

        inttexttoshow = (match == null)
            ? 0
            : ((double.tryParse(match.group(1)!) ?? 0) *
                  (double.tryParse(match.group(2)!) ?? 0));
        distanceText = '${(inttexttoshow / 1000).toStringAsFixed(1)} KM';
      }

      setState(() {
        _runningType = typeText;
        _runningTargetText = distanceText;
        _timeTargetText = timeText;
        _timeTargetSec = secondsNum;
        _timeTargetMinText = targetmintext;
        _interval = interval;
        _intervalMode = 'run';
        _intervalRestSec = _parseRestSec(timeText); // ดึงเวลาพักจากสตริง
        _restLeft = 0;

        if (interval != null) {
          _targetDistanceKm =
              (interval.segmentMeters * interval.totalReps) / 1000.0;
        } else {
          _targetDistanceKm = distanceNum;
        }
      });
    } catch (_) {
      setState(() {
        _runningType = 'Error';
        _runningTargetText = 'Error';
        _timeTargetText = 'Error';
        _timeTargetSec = 0;
        _targetDistanceKm = 0.0;
        _interval = null;
      });
    }
  }

  // ---------------- Firestore writer (throttle) ----------------
  Future<void> _writeIntervalUpdateThrottled() async {
    if (!_isTraining || _interval == null || _currentProgramId == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _interval!.lastWriteMs < 1500) return; // throttle ~1.5s
    _interval!.lastWriteMs = now;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dateKey = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Program')
        .doc(_currentProgramId!)
        .collection('Training')
        .doc(dateKey);

    try {
      await ref.set({
        'type': _runningType,
        // summary
        'distance_km': _totalDistanceMeters / 1000.0,
        'duration_s': _secs,
        'average_speed_kph': _secs == 0
            ? 0.0
            : ((_totalDistanceMeters / 1000.0) / (_secs / 3600.0)).roundToDouble(),
        // interval detail
        'interval': {
          'segment_m': _interval!.segmentMeters,
          'total_reps': _interval!.totalReps,
          'reps_done': _interval!.repsDone,
          'lap_progress': _interval!.currentLapProgress, // 0..1 for current lap
          'laps': _interval!.lapMeters, // array ของระยะจริง (เมตร)
          'mode': _intervalMode, // "run" | "rest"
          'rest_left_s': _intervalMode == 'rest' ? _restLeft : 0,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        // overall progress bar
        'progress_bar_percent': (_calculateOverallProgress() * 100)
            .round()
            .clamp(0, 100),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Interval write error: $e');
    }
  }

  Future<void> _recordData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentProgramId == null) return;

    final dateKey = DateFormat('dd-MM-yyyy').format(DateTime.now());
    var totalDistanceKm = 0.00;

    String two(int n) => n.toString().padLeft(2, '0');
    final durationStr =
        '${two(Duration(seconds: _secs).inHours)}:'
        '${two(Duration(seconds: _secs).inMinutes.remainder(60))}:'
        '${two(_secs % 60)}';

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Program')
        .doc(_currentProgramId!)
        .collection('Training')
        .doc(dateKey);

    if (_interval != null) {
      double i = 0;
      for (double meters in _interval!.lapMeters) {
        i += meters;
      }
      totalDistanceKm = i / 1000.0;
    } else {
      totalDistanceKm = _totalDistanceMeters / 1000.0;
    }

    final avgSpeedKph = _secs == 0 ? 0.0 : (totalDistanceKm / (_secs / 3600));

    final body = {
      'date': Timestamp.now(),
      'type': _runningType,
      //'distance': _runningTargetText,
      'activity': _activity,
      'distance_km': totalDistanceKm,
      'duration_s': _secs,
      'duration_display': durationStr,
      'average_speed_kph': avgSpeedKph.toStringAsFixed(2),
      'progress_bar_percent': (_calculateOverallProgress() * 100).round().clamp(
        0,
        100,
      ),
    };

    if (_interval != null) {
      body['interval'] = {
        'segment_m': _interval!.segmentMeters,
        'total_reps': _interval!.totalReps,
        'reps_done': _interval!.repsDone,
        'lap_progress': _interval!.currentLapProgress,
        //
        'laps': _interval!.lapMeters,
        'mode': _intervalMode,
        'rest_left_s': _intervalMode == 'rest' ? _restLeft : 0,
        'finished': _interval!.isFinished,
        'updatedAt': FieldValue.serverTimestamp(),
      };
    }

    try {
      await ref.set(body, SetOptions(merge: true));
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
          perm == LocationPermission.deniedForever)
        return;
    }

    _locationSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 1,
          ),
        ).listen((pos) {
          if (!mounted) return;

          double inc = 0.0;
          if (_lastPosition != null) {
            inc = Geolocator.distanceBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              pos.latitude,
              pos.longitude,
            );

            // ---- เงื่อนไขการนับระยะ ----
            // นับระยะรวมกับระยะอินเทอวอลเฉพาะตอน "run"
            if (_interval == null || _intervalMode == 'run') {
              _totalDistanceMeters += inc;
              _distanceKm = _totalDistanceMeters / 1000.0;
            }

            // ---- Interval distance split ----
            if (_interval != null && _intervalMode == 'run' && inc > 0) {
              // เก็บสถานะก่อนอัปเดต
              final prevLapIndex =
                  _interval!.currentLap; // 0..N-1 (Lap ที่กำลังวิ่งก่อนอัปเดต)

              final finishedAll = _interval!.addDelta(inc);

              // เพิ่งจบ Lap เดิมใน tick นี้ ถ้า currentLap ขยับขึ้นแสดงว่าปิด Lap ได้พอดี
              final lapJustCompleted = _interval!.currentLap > prevLapIndex;

              if (finishedAll) {
                _writeIntervalUpdateThrottled();
                _stopTraining();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎯 Interval completed — session ended.'),
                  ),
                );
              } else if (lapJustCompleted && _intervalMode == 'run') {
                // เข้าพักเฉพาะเมื่อเพิ่งจบ Lap ในรอบนี้จริง ๆ
                _startRestPhase();
                _writeIntervalUpdateThrottled();
              } else {
                // ยังวิ่ง Lap เดิมอยู่
                _writeIntervalUpdateThrottled();
              }
            }
          }

          setState(() {
            _currentSpeedMs = (pos.speed).abs();
            _speedKmhText = (_currentSpeedMs * 3.6).toStringAsFixed(2);
            _lastPosition = pos;
          });
        });
  }

  // ---------------- REST phase helpers ----------------
  void _startRestPhase() {
    if (_interval == null) return;
    setState(() {
      _intervalMode = 'rest';
      _restLeft = _intervalRestSec;
    });
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isTraining || _intervalMode != 'rest') {
        t.cancel();
        return;
      }
      if (_restLeft > 0) {
        setState(() => _restLeft--);
        _writeIntervalUpdateThrottled();
      } else {
        t.cancel();
        setState(() {
          _intervalMode = 'run'; // กลับไปวิ่ง Lap ถัดไป
        });
        _writeIntervalUpdateThrottled();
      }
    });
  }

  // ---------------- Sensors ----------------
  void _startSensorStreams() {
    final int t0 = DateTime.now().millisecondsSinceEpoch;

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
        if (_accelMagnitudes.length > _maxDataPoints)
          _accelMagnitudes.removeAt(0);
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
        if (_gyroMagnitudes.length > _maxDataPoints)
          _gyroMagnitudes.removeAt(0);
      });
    });
  }

  // ---------------- Stopwatch / Progress ----------------
  void _startStopwatch() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      try {
        if (_interval == null) {
          setState(() => _secs++);
        } else if (_intervalMode == 'run' && _interval != null) {
          setState(() => _secInter++);
          setState(() => _secs++);
        } else if (_intervalMode == 'rest') {
          _secInter = 0;
        }
      } catch (e) {
        print(e);
      }

      // Auto-stop สำหรับแผนแบบ non-interval ด้วย "เป้าระยะรวม"
      if (_interval == null &&
          _targetDistanceKm > 0 &&
          _distanceKm >= _targetDistanceKm) {
        t.cancel();
        _stopTraining();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Goal reached! Session ended.')),
        );
      }
      // เขียนสรุปครั้งคราว
      _writeIntervalUpdateThrottled();
    });
  }

  void _stopStopwatch() {
    _running = false;
    _timer?.cancel();
  }

  double _calculateOverallProgress({
    double? weightTime,
    double? weightDistance,
  }) {
    // Interval: เหมือนเดิม (คิดจากจำนวน lap)
    if (_interval != null && _interval!.totalReps > 0) {
      final p =
          (_interval!.repsDone + _interval!.currentLapProgress) /
          _interval!.totalReps;
      return p.clamp(0.0, 1.0);
    }

    // Non-interval: กำหนดน้ำหนักตามชนิดการวิ่ง (Tempo = ระยะล้วน)
    final w = _weightsForType();
    final wTime = weightTime ?? w[0];
    final wDist = weightDistance ?? w[1];

    double pTime = 0.0;
    if (_timeTargetSec > 0 && _secs <= _timeTargetSec) {
      final targetSecs = _timeTargetSec;

      pTime = _secs / targetSecs;
    } else {
      pTime = 1.0 - _timeTargetSec / _secs;
    }

    double pDist = 0.0;
    if (_targetDistanceKm > 0) {
      pDist = _distanceKm / _targetDistanceKm;
    }

    final p = (pTime.clamp(0.0, 1.0) * wTime) + (pDist.clamp(0.0, 1.0) * wDist);
    return p.clamp(0.0, 1.0);
  }

  String get _timeText {
    final m;
    final s;

    if (_interval != null) {
      m = (_secInter ~/ 60).toString().padLeft(2, '0');
      s = (_secInter % 60).toString().padLeft(2, '0');
    } else {
      m = (_secs ~/ 60).toString().padLeft(2, '0');
      s = (_secs % 60).toString().padLeft(2, '0');
    }
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
    if (_runningType.toLowerCase() == 'rest') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('วันนี้เป็นวันพักตามแผนครับ')),
      );
      return;
    }

    // reset
    _rawAccelData.clear();
    _rawGyroData.clear();
    _totalDistanceMeters = 0.0;
    _lastPosition = null;
    _distanceKm = 0.0;
    _secs = 0;

    _startSensorStreams();
    _isTraining = true;

    // รีเซ็ตโหมด interval
    if (_runningType.toLowerCase() == 'interval') {
      _intervalMode = 'run';
      _restLeft = 0;
      if (_interval == null) {
        _interval = _buildIntervalFromStrings(_runningTargetText);
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Training started!')));

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
    _restTimer?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _locationSub?.cancel();
    _recordData();
  }

  // ---------------- Feature Extraction (เดิม) ----------------
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
    final aX = col(ax, 'accelerometer_x'),
        aY = col(ax, 'accelerometer_y'),
        aZ = col(ax, 'accelerometer_z');
    final gX = col(gx, 'gyroscope_x'),
        gY = col(gx, 'gyroscope_y'),
        gZ = col(gx, 'gyroscope_z');

    List<double> mag(
      List<Map<String, double>> d,
      String x,
      String y,
      String z,
    ) => d
        .map((m) => sqrt(pow(m[x]!, 2) + pow(m[y]!, 2) + pow(m[z]!, 2)))
        .toList();
    final aMag = mag(
      ax,
      'accelerometer_x',
      'accelerometer_y',
      'accelerometer_z',
    );
    final gMag = mag(gx, 'gyroscope_x', 'gyroscope_y', 'gyroscope_z');

    double mean(List<double> v) =>
        v.isEmpty ? 0.0 : v.reduce((a, b) => a + b) / v.length;
    double std(List<double> v, double m) {
      if (v.length < 2) return 0.0;
      final s = v.map((x) => pow(x - m, 2)).reduce((a, b) => a + b);
      return sqrt(s / (v.length - 1));
    }

    double skew(List<double> v, double m, double s) {
      if (s == 0.0) return 0.0;
      double sum = 0.0;
      for (var x in v) sum += pow((x - m) / s, 3);
      for (var x in v) sum += pow((x - m) / s, 3);
      return sum / v.length;
    }

    double kurt(List<double> v, double m, double s) {
      if (s == 0.0) return 0.0;
      double sum = 0.0;
      for (var x in v) sum += pow((x - m) / s, 4);
      for (var x in v) sum += pow((x - m) / s, 4);
      return (sum / v.length) - 3.0;
    }

    final streams = {
      'accelerometer_x': aX,
      'accelerometer_y': aY,
      'accelerometer_z': aZ,
      'gyroscope_x': gX,
      'gyroscope_y': gY,
      'gyroscope_z': gZ,
    };

    final f = <String, double>{};
    for (final e in streams.entries) {
      final m = mean(e.value), s = std(e.value, m);
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

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _calculateOverallProgress();

    final isInterval = _runningType.toLowerCase() == 'interval';
    final intervalPanel = isInterval && _interval != null
        ? _buildIntervalPanel(theme)
        : const SizedBox.shrink();

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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
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
                                  valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFFFF6F00),
                                  ),
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
                              const Divider(
                                height: 24,
                                thickness: 1,
                                color: Color(0xFFECECEC),
                              ),

                              // ---- Interval Panel (ใหม่) ----
                              intervalPanel,

                              const SizedBox(height: 12),
                              SizedBox(
                                height: 250,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF3E0),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _statRow(
                                              'Time',
                                              _timeText,
                                              '${_timeTargetMinText} Min',
                                            ),
                                            _statRow(
                                              'Distance',
                                              _distanceKm.toStringAsFixed(2),
                                              '${_distanceKm.toStringAsFixed(2)} / $_runningTargetText',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF3E0),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _statRow('Activity', _activity, ''),
                                            _statRow(
                                              'Speed',
                                              '$_speedKmhText km/h',
                                              '',
                                            ),
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
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        child: ElevatedButton(
                          onPressed: _isTraining
                              ? _stopTraining
                              : _startCountdown,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            backgroundColor: _isTraining
                                ? Colors.redAccent
                                : const Color(0xFFFF6F00),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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
                        shadows: [
                          Shadow(
                            blurRadius: 10,
                            color: Color(0xFFFF8F00),
                            offset: Offset(2, 2),
                          ),
                        ],
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

  // ---- Interval panel UI (ใหม่) ----
  Widget _buildIntervalPanel(ThemeData theme) {
    final seg = _interval!.segmentMeters;
    final reps = _interval!.totalReps;
    final lapIdx = _interval!.currentLap.clamp(0, max(0, reps - 1));
    final done = _interval!.repsDone;
    final p = _interval!.currentLapProgress;

    final List<double> percents = List.generate(reps, (i) {
      if (i < done) return 1.0;
      if (i == done) return p;
      return 0.0;
    });

    final modeBadgeColor = _intervalMode == 'rest'
        ? const Color(0xFF0EA5E9)
        : const Color(0xFFFF6F00);

    final modeText = _intervalMode == 'rest'
        ? 'REST • ${_fmtRest(_restLeft)}'
        : 'RUN • Lap ${min(lapIdx + 1, reps)} / $reps';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: modeBadgeColor.withOpacity(.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                modeText,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: modeBadgeColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '${seg.toStringAsFixed(0)} m × $reps',
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFF616161),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Column(
          children: List.generate(reps, (i) {
            final percent = percents[i];
            final curMeters = (i < _interval!.lapMeters.length)
                ? _interval!.lapMeters[i]
                : 0.0;
            final label =
                'Lap ${i + 1} • ${curMeters.toStringAsFixed(0)} m / ${seg.toStringAsFixed(0)} m';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LapBar(
                index: i + 1,
                percent: percent,
                overlayLabel: label,
              ),
            );
          }),
        ),
      ],
    );
  }

  String _fmtRest(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  Widget _statRow(String title, String value, String sub) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: const Color(0xFF212121),
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF616161),
            ),
          ),
          if (sub.isNotEmpty)
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF9E9E9E),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  // ----- chart helper เดิม -----
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6F00).withOpacity(.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: Color(0xFF212121),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 12, color: Color(0xFFECECEC)),
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8),
              child: Text(
                'Current: ${latest.toStringAsFixed(2)} $unit',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF212121),
                ),
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
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
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
                            belowBarData: BarAreaData(
                              show: true,
                              color: color.withOpacity(0.28),
                            ),
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
}

class _LapBar extends StatelessWidget {
  final int index;
  final double percent;
  final String overlayLabel;
  const _LapBar({
    required this.index,
    required this.percent,
    required this.overlayLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFECECEC);
    final gradient = const LinearGradient(
      colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
    );

    return SizedBox(
      height: 22,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          FractionallySizedBox(
            widthFactor: percent.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6F00).withOpacity(.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Text(
                overlayLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
