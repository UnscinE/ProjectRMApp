import 'dart:async';
import 'package:flutter/material.dart';
import 'package:location/location.dart' hide LocationAccuracy;
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

// Note: To use the chart, you must add 'fl_chart: ^0.63.0' (or latest)
// to your pubspec.yaml and run 'flutter pub get'.
// import 'package:fl_chart/fl_chart.dart'; // <<< Required for actual chart implementation

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
  // Existing State Variables...
  //String _time = '0.00';
  double _distance = 0;
  String _activity = 'Walking';
  String _speed = '0.00';
  String _statusMessage = 'Training session idle.';
  String _runningType = 'Long Run';
  double _progress = 0.6;
  bool _isTrainning = false;
  final int _targetSeconds = 180; // 10 minutes target

  //Stop watch timer variables
  Timer? _timer;
  int _secs = 0;
  bool _running = false;

  // สำหรับ overlay countdown
  int _countdown = 0;
  bool _showOverlay = false;

  // GPS/Speed State
  double _currentSpeed = 0.0; // m/s
  final Location _location = Location();
  StreamSubscription<Position>? _locationSubscription;

  // Target Location
  final double _targetLatitude = 16.4326;
  final double _targetLongitude = 102.8229;

  double _totalDistance = 0.0; // Distance travelled in meters
  double _distanceToTarget = 0.0; // Distance to the fixed target in meters
  Position? _lastPosition; // To calculate distance traveled

  // Sensor State (Updated to also store magnitude)
  Vector3 _accelerometerData = const Vector3(0, 0, 0);
  Vector3 _gyroscopeData = const Vector3(0, 0, 0);
  double _gForce = 0.0;

  // --- NEW: Data for magnitude charts ---
  final List<double> _accelMagnitudes = [];
  final List<double> _gyroMagnitudes = [];
  final int _maxDataPoints = 50; // Keep the last 50 data points

  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  // --- GPS/Location Methods (for Speed Calculation) ---
  // Inside _ScreenTwoState
  // --- GPS/Location Methods (for Speed and Distance Calculation) ---
  // Inside _ScreenTwoState
  // --- GPS/Location Methods (for Speed and Distance Calculation) ---
  Future<void> _initLocationService() async {
    bool serviceEnabled;
    LocationPermission
    permissionGranted; // Use LocationPermission from geolocator

    // 1. ตรวจสอบว่าเปิด location service หรือยัง
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Note: geolocator doesn't have a direct requestService, usually relying on the user
      return Future.error('Location services are disabled.');
    }

    // 2. ขอ permission
    permissionGranted = await Geolocator.checkPermission();
    if (permissionGranted == LocationPermission.denied) {
      permissionGranted = await Geolocator.requestPermission();
      if (permissionGranted == LocationPermission.denied ||
          permissionGranted == LocationPermission.deniedForever) {
        return Future.error(
          'Location permissions are denied or denied forever.',
        );
      }
    }

    // 3. เริ่มรับข้อมูล location stream
    // We'll use getPositionStream to get real-time updates
    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 1, // Update every 1 meter
          ),
        ).listen((Position position) {
          if (!mounted) return;

          setState(() {
            // 1. Calculate Speed (Geolocator Position object has speed property)
            _currentSpeed = (position.speed).abs(); // m/s
            _speed = (_currentSpeed * 3.6).toStringAsFixed(2); // m/s to km/hr

            // 2. Calculate Distance Traveled (Total Distance)
            if (_lastPosition != null) {
              final double incrementalDistance = Geolocator.distanceBetween(
                _lastPosition!.latitude,
                _lastPosition!.longitude,
                position.latitude,
                position.longitude,
              );
              _totalDistance += incrementalDistance;
              // This updates the display variable:
              _distance = (_totalDistance / 1000); // Display in km
            }

            _lastPosition = position;

            // 3. Calculate Distance to Target
            _distanceToTarget = Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              _targetLatitude,
              _targetLongitude,
            );

            _lastPosition = position;
          });

          debugPrint(
            'Speed: ${position.speed} m/s, Total Distance: $_totalDistance m, Target Distance: $_distanceToTarget m',
          );
        });
  }

  // --- Sensor Methods (Gyroscope and Accelerometer) ---
  void _startSensorStreams() {
    // Accelerometer (รวมแรงโน้มถ่วง)
    _accelSubscription =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 100),
        ).listen((AccelerometerEvent event) {
          if (!mounted) return;

          final double totalForce = sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          );

          setState(() {
            _accelerometerData = Vector3(event.x, event.y, event.z);
            _gForce = totalForce / 9.8;

            // NEW: Add magnitude to the list
            _accelMagnitudes.add(totalForce);
            if (_accelMagnitudes.length > _maxDataPoints) {
              _accelMagnitudes.removeAt(0); // Remove oldest data point
            }
          });
        });

    // Gyroscope
    _gyroSubscription =
        gyroscopeEventStream(
          samplingPeriod: const Duration(milliseconds: 100),
        ).listen((GyroscopeEvent event) {
          if (!mounted) return;

          // Calculate magnitude (total angular velocity)
          final double totalAngularVelocity = sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          );

          setState(() {
            _gyroscopeData = Vector3(event.x, event.y, event.z);

            // NEW: Add magnitude to the list
            _gyroMagnitudes.add(totalAngularVelocity);
            if (_gyroMagnitudes.length > _maxDataPoints) {
              _gyroMagnitudes.removeAt(0); // Remove oldest data point
            }
          });
        });
  }

  // Start Timer
  void _start_Stopwatch() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _secs++;
      });
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

  //Calculate percentage for progress bar
  double _calculatePercentage() {
    if (_targetSeconds <= 0) {
      return 0.0; // Avoid division by zero
    }

    // Calculate the percentage
    double percentage = _secs / _targetSeconds;

    // Clamp the value between 0.0 and 1.0 (0% to 100%)
    return percentage.clamp(0.0, 1.0);
  }

  // Existing methods...
  void _startCountdown() {
    if (_showOverlay) return;

    setState(() {
      _countdown = 3;
      _showOverlay = true;
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          _showOverlay = false;
        });
        _startTraining();
      }
    });
  }

  void _startTraining() {
    _isTrainning = true;
    print('🏃 Training Started!');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Training started!')));
    _start_Stopwatch();
    _startSensorStreams();
    _initLocationService();
  }

  // --- NEW: Magnitude Chart Widget (Placeholder/Simplified for Fl-Chart) ---
  Widget _buildMagnitudeChart({
    required String title,
    required List<double> dataPoints,
    required Color color,
    required IconData icon,
    required String unit,
  }) {
    // Determine bounds for the chart
    final latestMagnitude = dataPoints.isEmpty ? 0.0 : dataPoints.last;
    final double maxData = dataPoints.isEmpty ? 1.0 : dataPoints.reduce(max);
    // Use a sensible upper bound (e.g., 10 m/s² for Accel, or just maxData + 10%)
    final double maxY = (maxData * 1.1).clamp(1.0, 50.0);

    // Convert List<double> to List<FlSpot> for fl_chart
    final List<FlSpot> spots = dataPoints.asMap().entries.map((entry) {
      // X-value is the index (time point), Y-value is the magnitude
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.only(
          top: 15.0,
          bottom: 5.0,
          left: 5.0,
          right: 15.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const Divider(height: 15, color: Colors.grey),
            // Display latest magnitude (numerical representation)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                'Current: ${latestMagnitude.toStringAsFixed(2)} $unit',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            const SizedBox(height: 10),

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
                        maxX:
                            _maxDataPoints.toDouble() -
                            1, // Full width of data window
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
                          ), // Hide X axis titles
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return const FlLine(
                              color: Colors.grey,
                              strokeWidth: 0.5,
                              dashArray: [5, 5],
                            );
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: color,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false), // Hide dots
                            belowBarData: BarAreaData(
                              show: true,
                              color: color.withOpacity(0.3),
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

  // Existing build method...
  @override
  Widget build(BuildContext context) {
    final double currentProgress = _calculatePercentage();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Details'),
        backgroundColor: const Color.fromARGB(255, 233, 233, 233),
      ),
      backgroundColor: const Color.fromARGB(255, 252, 252, 252),
      body: Stack(
        children: [
          // ===== เนื้อหาหลัก =====
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ... (Training Progress Card remains the same)
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _runningType,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Training Progress',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: currentProgress,
                              minHeight: 12,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation(
                                Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(currentProgress * 100).toStringAsFixed(0)}%',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Divider(height: 24, thickness: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Expanded(
                                child: Container(
                                  height: 250,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildDetailRow(
                                        'Time',
                                        _time,
                                        _targetSeconds.toString(),
                                      ),
                                      _buildDetailRow(
                                        'Distance',
                                        _distance.toStringAsFixed(2),
                                        '${_distance.toStringAsFixed(2)} / 500 km',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Container(
                                  height: 250,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildDetailRow(
                                        'Activity',
                                        _activity,
                                        '',
                                      ),
                                      _buildDetailRow(
                                        'Speed',
                                        '$_speed km/hr',
                                        '',
                                      ),
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

                  // ===== SENSOR DATA CARDS (NOW GRAPHS) =====
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 250,
                              child: _buildMagnitudeChart(
                                title: 'Accel. Magnitude (m/s²)',
                                dataPoints: _accelMagnitudes,
                                unit: 'm/s²',
                                icon: Icons.speed_rounded, // Changed icon
                                color: Colors.green,
                              ),
                            ),
                          ),

                          const SizedBox(width: 6),
                          Expanded(
                            child: SizedBox(
                              height: 250,
                              child: _buildMagnitudeChart(
                                title: 'Gyro. Magnitude (rad/s)',
                                dataPoints: _gyroMagnitudes,
                                unit: 'rad/s',
                                icon:
                                    Icons.rotate_right_rounded, // Changed icon
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ===== ปุ่ม Start =====
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: ElevatedButton(
                      onPressed: _startCountdown,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        backgroundColor: Colors.lightBlueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Start',
                        style: TextStyle(fontSize: 24, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ===== Overlay Countdown remains the same =====
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
                        color: Colors.blueAccent,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // UI Build row for time, distance, activity, speed (remains the same)
  Widget _buildDetailRow(String title, String value, String subValue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          if (subValue.isNotEmpty)
            Text(
              subValue,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  // The original _buildDataCard is removed/replaced by _buildMagnitudeChart,
  // but keeping a placeholder if needed for other data.
  // Widget _buildDataCard({
  //   required String title,
  //   ...
  // }) { /* ... */ }
}
