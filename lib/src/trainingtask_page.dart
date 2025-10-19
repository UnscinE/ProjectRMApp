import 'dart:async';
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:location/location.dart' hide LocationAccuracy;
import 'package:geolocator/geolocator.dart';
import 'package:rmapp/src/modelhandle_backend.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'training_repo.dart';

// =================== ScreenTwo (Styled: Premium Orange) ===================

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
  // --- State เดิมทั้งหมด (ลอจิกเดิม) ---
  HarModelPredictor _predictor = HarModelPredictor();
  final double _goalDistanceKm = 500.0;
  String? _currentProgramId;
  double _distance = 0;
  String _activity = 'getting data';
  String _speed = '0.00';
  String _statusMessage = 'Training session idle.';
  String _runningType = 'Long Run';
  double _progress = 0.6;
  bool _isTrainning = false;
  final int _targetSeconds = 180;

  Timer? _timer;
  int _secs = 0;
  bool _running = false;

  int _countdown = 0;
  bool _showOverlay = false;

  double _currentSpeed = 0.0; // m/s
  final Location _location = Location();
  StreamSubscription<Position>? _locationSubscription;

  final double _targetLatitude = 16.4326;
  final double _targetLongitude = 102.8229;

  double _totalDistance = 0.0;
  double _distanceToTarget = 0.0;
  Position? _lastPosition;

  Vector3 _accelerometerData = const Vector3(0, 0, 0);
  Vector3 _gyroscopeData = const Vector3(0, 0, 0);
  double _gForce = 0.0;

  final List<double> _accelMagnitudes = [];
  final List<double> _gyroMagnitudes = [];
  final int _maxDataPoints = 50;

  final List<Map<String, double>> _rawAccelData = [];
  final List<Map<String, double>> _rawGyroData = [];

  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  @override
  void initState() {
    super.initState();
    _predictor.loadModel();
    _loadProgramId();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  // --- GPS/Location Methods (คงเดิม) ---
  Future<void> _initLocationService() async {
    bool serviceEnabled;
    LocationPermission permissionGranted;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permissionGranted = await Geolocator.checkPermission();
    if (permissionGranted == LocationPermission.denied) {
      permissionGranted = await Geolocator.requestPermission();
      if (permissionGranted == LocationPermission.denied ||
          permissionGranted == LocationPermission.deniedForever) {
        return Future.error('Location permissions are denied or denied forever.');
      }
    }

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      if (!mounted) return;

      setState(() {
        _currentSpeed = (position.speed).abs();
        _speed = (_currentSpeed * 3.6).toStringAsFixed(2);

        if (_lastPosition != null) {
          final double incrementalDistance = Geolocator.distanceBetween(
            _lastPosition!.latitude, _lastPosition!.longitude,
            position.latitude, position.longitude,
          );
          _totalDistance += incrementalDistance;
          _distance = (_totalDistance / 1000);
        }

        _lastPosition = position;

        _distanceToTarget = Geolocator.distanceBetween(
          position.latitude, position.longitude,
          _targetLatitude, _targetLongitude,
        );

        _lastPosition = position;
      });

      debugPrint('Speed: ${position.speed} m/s, Total Distance: $_totalDistance m, Target Distance: $_distanceToTarget m');
    });
  }

  Future<void> _recordData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentProgramId == null) return;

    final String userId = user.uid;
    final String dateKey =
        DateTime.now().day.toString().padLeft(2, '0') + '-' +
        DateTime.now().month.toString().padLeft(2, '0') + '-' +
        DateTime.now().year.toString();

    final double avgSpeedKph = (_totalDistance / _secs) * 3.6;
    final Duration totalDuration = Duration(seconds: _secs);

    final double totalDistanceKm = _totalDistance / 1000.0;
    final double progressPercent = (totalDistanceKm / _goalDistanceKm) * 100;
    final int progressBarValue = progressPercent.clamp(0, 100).round();

    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final timeString =
        "${twoDigits(totalDuration.inHours)}:${twoDigits(totalDuration.inMinutes.remainder(60))}:${twoDigits(totalDuration.inSeconds.remainder(60))}";

    final trainingRef = FirebaseFirestore.instance
        .collection('users').doc(userId)
        .collection('Program').doc(_currentProgramId!)
        .collection('Training').doc(dateKey);

    final data = {
      'date': Timestamp.now(),
      'activity': _activity,
      'distance_km': totalDistanceKm,
      'duration_s': _secs,
      'duration_display': timeString,
      'average_speed_kph': avgSpeedKph.toStringAsFixed(2),
      'progress_bar_percent': progressBarValue,
    };

    try {
      await trainingRef.set(data, SetOptions(merge: true));
      debugPrint('✅ Recorded training data');
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  Future<void> _loadProgramId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final programId = await TrainingRepo.fetchCurrentProgramId(user.uid);
    setState(() => _currentProgramId = programId?.first);
  }

  // --- Sensor Methods (คงเดิม) ---
  void _startSensorStreams() {
    final int startTime = DateTime.now().millisecondsSinceEpoch;

    _accelSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((AccelerometerEvent event) {
      if (!mounted) return;

      final double totalForce = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      final double currentTime = (DateTime.now().millisecondsSinceEpoch - startTime) / 1000.0;

      _rawAccelData.add({
        'Time (s)': currentTime,
        'accelerometer_x': event.x,
        'accelerometer_y': event.y,
        'accelerometer_z': event.z,
      });

      setState(() {
        _accelerometerData = Vector3(event.x, event.y, event.z);
        _gForce = totalForce / 9.8;

        _accelMagnitudes.add(totalForce);
        if (_accelMagnitudes.length > _maxDataPoints) {
          _accelMagnitudes.removeAt(0);
        }
      });
    });

    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((GyroscopeEvent event) {
      if (!mounted) return;

      final double totalAngularVelocity = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      final double currentTime = (DateTime.now().millisecondsSinceEpoch - startTime) / 1000.0;

      _rawGyroData.add({
        'Time (s)': currentTime,
        'gyroscope_x': event.x,
        'gyroscope_y': event.y,
        'gyroscope_z': event.z,
      });

      setState(() {
        _gyroscopeData = Vector3(event.x, event.y, event.z);
        _gyroMagnitudes.add(totalAngularVelocity);
        if (_gyroMagnitudes.length > _maxDataPoints) {
          _gyroMagnitudes.removeAt(0);
        }
      });
    });
  }

  // --- Stopwatch (คงเดิม) ---
  void _start_Stopwatch() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _secs++);
    });
    setState(() {});
  }

  void _stop_Stopwatch() {
    _running = false;
    _timer?.cancel();
    setState(() {});
  }

  void _reset_Stopwatch() {
    _stop_Stopwatch();
    setState(() {
      _secs = 0;
      _distance = 0;
    });
  }

  String get _time {
    final m = (_secs ~/ 60).toString().padLeft(2, '0');
    final s = (_secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double _calculatePercentage() {
    if (_targetSeconds <= 0) return 0.0;
    return (_secs / _targetSeconds).clamp(0.0, 1.0);
  }

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
    _rawAccelData.clear();
    _rawGyroData.clear();
    _totalDistance = 0.0;
    _lastPosition = null;
    _distance = 0.0;
    _secs = 0;

    _startSensorStreams();

    Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (!_isTrainning) {
        t.cancel();
        return;
      }
      final features = extractFeaturesDart(_rawAccelData, _rawGyroData);
      if (features.isNotEmpty) {
        final prediction = _predictor.predict(features);
        setState(() => _activity = prediction);
      }
    });

    _isTrainning = true;
    setState(() => _statusMessage = 'Training in progress...');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Training started!')));
    _start_Stopwatch();
    _initLocationService();
  }

  void _stopTraining() {
    _isTrainning = false;
    _stop_Stopwatch();
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _locationSubscription?.cancel();

    _rawAccelData.clear();
    _rawGyroData.clear();

    _recordData();
    setState(() => _statusMessage = 'Training session ended.');
  }

  // --- Stats helpers (คงเดิม) ---
  double calculateMean(List<double> values) =>
      values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;

  double calculateStdDev(List<double> values, double mean) {
    if (values.length < 2) return 0.0;
    final variance = values.map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b) / (values.length - 1);
    return sqrt(variance);
  }

  double calculateSkewness(List<double> values, double mean, double std) {
    if (std == 0.0) return 0.0;
    double sum = 0.0;
    for (var x in values) {
      sum += pow((x - mean) / std, 3);
    }
    return sum / values.length;
  }

  double calculateKurtosis(List<double> values, double mean, double std) {
    if (std == 0.0) return 0.0;
    double sum = 0.0;
    for (var x in values) {
      sum += pow((x - mean) / std, 4);
    }
    return (sum / values.length) - 3.0;
  }

  Map<String, double> extractFeaturesDart(
    List<Map<String, double>> accelData,
    List<Map<String, double>> gyroData,
  ) {
    const windowSize = 100;
    if (accelData.length < windowSize || gyroData.length < windowSize) return {};

    final accelWindow = accelData.sublist(accelData.length - windowSize);
    final gyroWindow = gyroData.sublist(gyroData.length - windowSize);

    final ax = accelWindow.map((d) => d['accelerometer_x']!).toList();
    final ay = accelWindow.map((d) => d['accelerometer_y']!).toList();
    final az = accelWindow.map((d) => d['accelerometer_z']!).toList();
    final gx = gyroWindow.map((d) => d['gyroscope_x']!).toList();
    final gy = gyroWindow.map((d) => d['gyroscope_y']!).toList();
    final gz = gyroWindow.map((d) => d['gyroscope_z']!).toList();

    final accelMag = accelWindow
        .map((d) => sqrt(pow(d['accelerometer_x']!, 2) +
            pow(d['accelerometer_y']!, 2) +
            pow(d['accelerometer_z']!, 2)))
        .toList();
    final gyroMag = gyroWindow
        .map((d) => sqrt(pow(d['gyroscope_x']!, 2) +
            pow(d['gyroscope_y']!, 2) +
            pow(d['gyroscope_z']!, 2)))
        .toList();

    final streams = {
      'accelerometer_x': ax,
      'accelerometer_y': ay,
      'accelerometer_z': az,
      'gyroscope_x': gx,
      'gyroscope_y': gy,
      'gyroscope_z': gz,
    };

    final features = <String, double>{};
    for (var e in streams.entries) {
      final mean = calculateMean(e.value);
      final std = calculateStdDev(e.value, mean);
      features['${e.key}_mean'] = mean;
      features['${e.key}_std'] = std;
      features['${e.key}_max'] = e.value.reduce(max);
      features['${e.key}_min'] = e.value.reduce(min);
      features['${e.key}_skew'] = calculateSkewness(e.value, mean, std);
      features['${e.key}_kurtosis'] = calculateKurtosis(e.value, mean, std);
    }
    features['acceleration_magnitude_mean'] = calculateMean(accelMag);
    features['gyroscope_magnitude_mean'] = calculateMean(gyroMag);
    return features;
  }

  // --- Magnitude Chart (แต่งโทนส้ม + เส้น/ตัวอักษร) ---
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

    final List<FlSpot> spots = dataPoints.asMap().entries
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: Color(0xFF212121),
                ),
              ),
            ]),
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
                  ? Center(
                      child: Text(
                        'Waiting for sensor data...',
                        style: TextStyle(color: color.withOpacity(0.7)),
                      ),
                    )
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

  // --- Build (แต่งสไตล์/ตัวอักษรให้แน่นขึ้นแบบตัวอย่าง) ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double currentProgress = _calculatePercentage();

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
      // พื้นหลังไล่เฉดเหมือนตัวอย่าง
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
                      // การ์ด Progress
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        elevation: 4,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
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
                                  value: currentProgress,
                                  minHeight: 12,
                                  backgroundColor: const Color(0xFFECECEC),
                                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6F00)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(currentProgress * 100).toStringAsFixed(0)}%',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF616161),
                                ),
                              ),
                              const Divider(height: 24, thickness: 1, color: Color(0xFFECECEC)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 250,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF3E0),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _buildDetailRow('Time', _time, _targetSeconds.toString()),
                                          _buildDetailRow('Distance', _distance.toStringAsFixed(2), '${_distance.toStringAsFixed(2)} / 500 km'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Container(
                                      height: 250,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF3E0),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _buildDetailRow('Activity', _activity, ''),
                                          _buildDetailRow('Speed', '$_speed km/hr', ''),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // การ์ดกราฟ (โทนส้ม)
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 250,
                                  child: _buildMagnitudeChart(
                                    title: 'Accel. Magnitude',
                                    dataPoints: _accelMagnitudes,
                                    unit: 'm/s²',
                                    icon: Icons.speed_rounded,
                                    color: const Color(0xFFFF6F00),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: SizedBox(
                                  height: 250,
                                  child: _buildMagnitudeChart(
                                    title: 'Gyro. Magnitude',
                                    dataPoints: _gyroMagnitudes,
                                    unit: 'rad/s',
                                    icon: Icons.rotate_right_rounded,
                                    color: const Color(0xFFFF6F00),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ปุ่ม Start/Stop (ส้ม/แดง)
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        child: ElevatedButton(
                          onPressed: _isTrainning ? _stopTraining : _startCountdown,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            backgroundColor: _isTrainning ? Colors.redAccent : const Color(0xFFFF6F00),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: Text(
                            _isTrainning ? 'STOP' : 'Start',
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

              // Overlay Countdown (แค่เปลี่ยนสีเงาเป็นส้ม)
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

  // --- แค่ปรับน้ำหนัก/ขนาดข้อความให้แน่นแบบตัวอย่าง (ไม่เปลี่ยนลอจิก) ---
  Widget _buildDetailRow(String title, String value, String subValue) {
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
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF616161),
            ),
          ),
          if (subValue.isNotEmpty)
            Text(
              subValue,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF9E9E9E),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
