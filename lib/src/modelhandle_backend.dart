import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';

class HarModelPredictor {
  Interpreter? _interpreter;
  final List<String> _labels = [
    'Interval',
    'Longrun',
    'Recovery',
    'Tempo',
    'Walk',
  ];

  Future<void> loadModel() async {
    try {
      // โหลดโมเดลจาก assets
      _interpreter = await Interpreter.fromAsset(
        'assets/models/lstm_activity_model_float32.tflite',
      );
      print('✅ TFLite model loaded successfully.');
    } catch (e) {
      print('❌ Failed to load model: $e');
    }
  }

  void dispose() {
    _interpreter?.close();
  }

  String predict(Map<String, double> featureMap) {
    if (_interpreter == null) {
      return 'Model not loaded';
    }

    // 1. เรียง Features ให้เป็น Vector ตามลำดับที่โมเดลต้องการ (สำคัญมาก!)
    // คุณต้องแน่ใจว่าลำดับของ Features ตรงกับลำดับที่ใช้ในการฝึกโมเดล PyTorch
    final featuresList = [
      featureMap['accelerometer_x_mean']!,
      featureMap['accelerometer_x_std']!, //...
      // (ต่อด้วย Features อีก 36 ตัวตามลำดับ)
    ];

    // **ตัวอย่างการเรียงลำดับสมมติ** (ต้องปรับให้ตรงกับโมเดลจริง)
    final inputOrder = [
      'accelerometer_x_mean',
      'accelerometer_x_std',
      'accelerometer_x_max',
      'accelerometer_x_min',
      'accelerometer_x_skew',
      'accelerometer_x_kurtosis',
      'accelerometer_y_mean',
      'accelerometer_y_std',
      'accelerometer_y_max',
      'accelerometer_y_min',
      'accelerometer_y_skew',
      'accelerometer_y_kurtosis',
      // ... (แกนที่เหลือ)
      'gyroscope_z_kurtosis',
      'acceleration_magnitude_mean', 'gyroscope_magnitude_mean',
    ];

    // 2. สร้าง Input Tensor (Shape: [1, 38] หรือตามโมเดลของคุณ)
    // การทำ Scaling ต้องเกิดขึ้นที่นี่!
    final inputTensor = Float32List(featuresList.length);
    for (int i = 0; i < inputOrder.length; i++) {
      final featureValue = featureMap[inputOrder[i]]!;
      // หากโมเดลใช้ Scaling:
      // final scaledValue = (featureValue - feature_mean[i]) / feature_std[i];
      // inputTensor[i] = scaledValue;

      inputTensor[i] = featureValue; // ถ้าไม่ได้ใช้ Scaling (ไม่แนะนำ)
    }

    // TFLite ต้องการ Input Shape [1, 38]
    final input = inputTensor.reshape([1, featuresList.length]);

    // 3. เตรียม Output Tensor (Shape: [1, 5] สำหรับ 5 Classes)
    final output = List.filled(
      1 * _labels.length,
      0.0,
    ).reshape([1, _labels.length]);

    // 4. รัน Inference
    _interpreter!.run(input, output);

    // 5. แปลงผลลัพธ์เป็น Label
    final outputProbabilities = output[0] as List<double>;

    // หา Class ที่มีความน่าจะเป็นสูงสุด (argmax)
    int maxIndex = 0;
    double maxProb = -1.0;
    for (int i = 0; i < outputProbabilities.length; i++) {
      if (outputProbabilities[i] > maxProb) {
        maxProb = outputProbabilities[i];
        maxIndex = i;
      }
    }

    // Label mapping: {'Interval': 0, 'Longrun': 1, 'Recovery': 2, 'Tempo': 3, 'Walk': 4}
    return _labels[maxIndex];
  }
}
