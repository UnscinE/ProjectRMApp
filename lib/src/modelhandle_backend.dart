import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';

class HarModelPredictor {
  Interpreter? _interpreter;
  Delegate? _delegate; // Optional: Keep if you plan to use GPU/Flex delegate later

  final List<String> _labels = [
    'Interval',
    'Longrun',
    'Recovery',
    'Tempo',
    'Walk',
  ];

  /// Load TFLite model
  Future<void> loadModel() async {
    try {
      var options = InterpreterOptions();

      // 2. Try to add GPU Delegate (Primary acceleration) if available
      try {
        final gpuDelegate = GpuDelegate();
        options.addDelegate(gpuDelegate);
        _delegate = gpuDelegate;
      } catch (e) {
        // GPU delegate not available; continue without it
        print('GPU delegate unavailable: $e');
      }
      
      // 3. Optionally add Flex Delegate (For operations GPU doesn't support, like those in LSTMs)
      // This requires the 'tensorflow-lite-select-tf-ops' dependency; uncomment if you add it.
      // try {
      //   final flex = FlexDelegate();
      //   options.addDelegate(flex);
      //   _delegate = flex;
      // } catch (e) {
      //   print('Flex delegate unavailable: $e');
      // }

      _interpreter = await Interpreter.fromAsset(
        'assets/models/lstm_activity_model_float32.tflite', // path inside assets (no 'assets/' prefix)
        options: options,
      );

      print('✅ TFLite model loaded successfully.');
      print('Input tensor shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Output tensor shape: ${_interpreter!.getOutputTensor(0).shape}');
    } catch (e) {
      print('❌ Failed to load model: $e');
    }
  }

  /// Close interpreter when not needed
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _delegate = null;
  }

  /// Run prediction
  String predict(Map<String, double> featureMap) {
    if (_interpreter == null) {
      return 'Model not loaded';
    }

    final inputShape = _interpreter!.getInputTensor(0).shape;
    final outputShape = _interpreter!.getOutputTensor(0).shape;

    print('Input shape: $inputShape');
    print('Output shape: $outputShape');

    // ⚠️ Must include all features in correct order
    final featureKeys = const [
      // Accelerometer X, Y, Z (18 features)
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
      'accelerometer_z_mean',
      'accelerometer_z_std',
      'accelerometer_z_max',
      'accelerometer_z_min',
      'accelerometer_z_skew',
      'accelerometer_z_kurtosis',

      // Gyroscope X, Y, Z (18 features)
      'gyroscope_x_mean',
      'gyroscope_x_std',
      'gyroscope_x_max',
      'gyroscope_x_min',
      'gyroscope_x_skew',
      'gyroscope_x_kurtosis',
      'gyroscope_y_mean',
      'gyroscope_y_std',
      'gyroscope_y_max',
      'gyroscope_y_min',
      'gyroscope_y_skew',
      'gyroscope_y_kurtosis',
      'gyroscope_z_mean',
      'gyroscope_z_std',
      'gyroscope_z_max',
      'gyroscope_z_min',
      'gyroscope_z_skew',
      'gyroscope_z_kurtosis',

      // Magnitude Features (2 features)
      'acceleration_magnitude_mean',
      'gyroscope_magnitude_mean',
    ];

    final inputList = List<double>.filled(featureKeys.length, 0.0);
    for (int i = 0; i < featureKeys.length; i++) {
      inputList[i] = featureMap[featureKeys[i]] ?? 0.0;
    }

    // Prepare input with the correct batch dimension (assume first dimension is batch)
    List input;
    if (inputShape.length == 2 && inputShape[0] == 1) {
      input = [inputList];
    } else {
      // Fallback: send flat list
      input = inputList;
    }

    // Create output container based on output shape
    dynamic output;
    if (outputShape.length == 1) {
      output = List<double>.filled(outputShape[0], 0.0);
    } else if (outputShape.length == 2) {
      output = List.generate(outputShape[0], (_) => List<double>.filled(outputShape[1], 0.0));
    } else {
      // Generic flat output
      output = List<double>.filled(outputShape.reduce((a, b) => a * b), 0.0);
    }

    // Run inference
    _interpreter!.run(input, output);

    // Extract probabilities assuming output is [1, numLabels] or [numLabels]
    List<double> outputProbabilities;
    if (output is List && output.isNotEmpty && output[0] is List) {
      outputProbabilities = (output[0] as List).cast<double>();
    } else if (output is List<double>) {
      outputProbabilities = (output as List<double>).cast<double>();
    } else {
      outputProbabilities = (output as List).cast<double>();
    }

    int maxIndex = 0;
    double maxProb = -1.0;
    for (int i = 0; i < outputProbabilities.length; i++) {
      if (outputProbabilities[i] > maxProb) {
        maxProb = outputProbabilities[i];
        maxIndex = i;
      }
    }

    return _labels[maxIndex];
  }
}
