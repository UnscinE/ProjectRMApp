import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';


class TrainningTab extends StatefulWidget {
  const TrainningTab({super.key});


  @override
  State<TrainningTab> createState() => _TrainningTabState();
}


class _TrainningTabState extends State<TrainningTab> {
  // --- GPS/Speed State ---
  double _currentSpeed = 0.0; // m/s
  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;


  // --- Sensor State ---
  Vector3 _accelerometerData = const Vector3(0, 0, 0);
  Vector3 _gyroscopeData = const Vector3(0, 0, 0);
  double _gForce = 0.0; // g value (≈ total acceleration / 9.8)


  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;


  @override
  void initState() {
    super.initState();
    _initLocationService();
    _startSensorStreams();
  }


  @override
  void dispose() {
    _locationSubscription?.cancel();
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    super.dispose();
  }


  // --------------------------------------------------------------------------
  // --- GPS/Location Methods (for Speed Calculation) ---
  Future<void> _initLocationService() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;


    // 1. ตรวจสอบว่าเปิด location service หรือยัง
    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }


    // 2. ขอ permission
    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }


    // 3. ตั้งค่า location update ให้แม่นยำ
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 1000, // update ทุก 1 วินาที
      distanceFilter: 0,
    );


    // 4. เริ่มรับข้อมูล location
    _locationSubscription = _location.onLocationChanged.listen((LocationData data) {
      if (!mounted) return;
      setState(() {
        _currentSpeed = (data.speed ?? 0.0).abs(); // m/s
      });
      debugPrint('Speed: ${data.speed} m/s, Lat: ${data.latitude}, Lng: ${data.longitude}');
    });
  }


  // --------------------------------------------------------------------------
  // --- Sensor Methods (Gyroscope and Accelerometer) ---
  void _startSensorStreams() {
    // Accelerometer (รวมแรงโน้มถ่วง)
    _accelSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((AccelerometerEvent event) {
      if (!mounted) return;
      // คำนวณแรงรวมทั้งหมด (รวมแรง g)
      final double totalForce = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      setState(() {
        _accelerometerData = Vector3(event.x, event.y, event.z);
        _gForce = totalForce / 9.8; // แปลงเป็นหน่วย g
      });
    });


    // Gyroscope
    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((GyroscopeEvent event) {
      if (!mounted) return;
      setState(() {
        _gyroscopeData = Vector3(event.x, event.y, event.z);
      });
    });
  }


  // --------------------------------------------------------------------------
  // --- UI Build Method ---
  @override
  Widget build(BuildContext context) {
    final double speedKmh = _currentSpeed * 3.6; // แปลงจาก m/s เป็น km/h


    return Scaffold(
      appBar: AppBar(title: const Text('Training Data')),
      body: Center(

        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildDataCard(
                title: 'Current Speed (GPS)',
                value: speedKmh.toStringAsFixed(2),
                unit: ' km/h',
                icon: Icons.speed_rounded,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 15),
              _buildDataCard(
                title: 'Accelerometer (m/s²)',
                value:
                    'X: ${_accelerometerData.x.toStringAsFixed(2)}\nY: ${_accelerometerData.y.toStringAsFixed(2)}\nZ: ${_accelerometerData.z.toStringAsFixed(2)}',
                unit: '',
                icon: Icons.multiline_chart_rounded,
                color: Colors.green,
              ),
              const SizedBox(height: 15),
              _buildDataCard(
                title: 'G-Force',
                value: _gForce.toStringAsFixed(2),
                unit: ' g',
                icon: Icons.electric_bolt,
                color: Colors.purple,
              ),
              const SizedBox(height: 15),
              _buildDataCard(
                title: 'Gyroscope (rad/s)',
                value:
                    'X: ${_gyroscopeData.x.toStringAsFixed(2)}\nY: ${_gyroscopeData.y.toStringAsFixed(2)}\nZ: ${_gyroscopeData.z.toStringAsFixed(2)}',
                unit: '',
                icon: Icons.screen_rotation_rounded,
                color: Colors.orange,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const Divider(height: 15, color: Colors.grey),
            Text(
              value + unit,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}


// Simple class to hold sensor data
class Vector3 {
  final double x;
  final double y;
  final double z;
  const Vector3(this.x, this.y, this.z);
}



