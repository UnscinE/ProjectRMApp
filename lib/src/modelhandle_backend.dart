import 'package:tflite_flutter/tflite_flutter.dart';

import 'dart:typed_data';

// Define a type for the update callback for clarity
typedef ModelStatusCallback = void Function({bool? isLoading, String? error});

class HarModelPredictor {
  Interpreter? _interpreter;
  Delegate? _delegate;

  final List<String> _labels = [
    'Interval',
    'Longrun',
    'Recovery',
    'Tempo',
    'Walk',
  ];

  // NOTE: This array MUST match the order of features used during model training
  final List<String> _featureKeys = const [
    // Accelerometer X, Y, Z (18 features)
    'accelerometer_x_mean', 'accelerometer_x_std', 'accelerometer_x_max',
    'accelerometer_x_min', 'accelerometer_x_skew', 'accelerometer_x_kurtosis',
    'accelerometer_y_mean', 'accelerometer_y_std', 'accelerometer_y_max',
    'accelerometer_y_min', 'accelerometer_y_skew', 'accelerometer_y_kurtosis',
    'accelerometer_z_mean', 'accelerometer_z_std', 'accelerometer_z_max',
    'accelerometer_z_min', 'accelerometer_z_skew', 'accelerometer_z_kurtosis',
    // Gyroscope X, Y, Z (18 features)
    'gyroscope_x_mean', 'gyroscope_x_std', 'gyroscope_x_max',
    'gyroscope_x_min', 'gyroscope_x_skew', 'gyroscope_x_kurtosis',
    'gyroscope_y_mean', 'gyroscope_y_std', 'gyroscope_y_max',
    'gyroscope_y_min', 'gyroscope_y_skew', 'gyroscope_y_kurtosis',
    'gyroscope_z_mean', 'gyroscope_z_std', 'gyroscope_z_max',
    'gyroscope_z_min', 'gyroscope_z_skew', 'gyroscope_z_kurtosis',
    // Magnitude Features (2 features)
    'acceleration_magnitude_mean',
    'gyroscope_magnitude_mean',
  ];

  int get featureCount => _featureKeys.length;

  /// Load TFLite model
  Future<void> loadModel() async {
    Interpreter? tempInterpreter;
    Delegate? tempDelegate;

    // Options that might be used by the final interpreter
    InterpreterOptions finalOptions = InterpreterOptions();

    try {
      final options = InterpreterOptions();

      // ✅ เพิ่ม Flex Delegate เพื่อรองรับ SELECT_TF_OPS
      //final flexDelegate = FlexDelegate();
      // options.addDelegate(flexDelegate);

      final _interpreter = await Interpreter.fromAsset(
        'assets/models/lstm_activity_model_tf.tflite',
         options: finalOptions,
      );

      print("✅ Model loaded successfully with SELECT_TF_OPS.");
    } catch (e) {
      print("❌ Failed to load model: $e");
    }
  }

  /// Close interpreter when not needed
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _delegate = null;
  }

  /// Run prediction
  /// @param featureMap: A single map containing all statistical features.
  String predict(Map<String, double> featureMap) {
    if (_interpreter == null) {
      return 'Model not loaded';
    }

    final inputShape = _interpreter!.getInputTensor(0).shape;
    final outputShape = _interpreter!.getOutputTensor(0).shape;

    print('Input shape: $inputShape');
    print('Output shape: $outputShape');

    // Reverting to the old logic: creating a flat List<double> input
    final inputList = List<double>.filled(_featureKeys.length, 0.0);
    for (int i = 0; i < _featureKeys.length; i++) {
      // Use the class-level _featureKeys to ensure correct order
      inputList[i] = featureMap[_featureKeys[i]] ?? 0.0;
    }

    // Prepare input with the correct batch dimension
    // This assumes the model input is [1, num_features] OR [num_features]
    List input;
    if (inputShape.length == 2 && inputShape[0] == 1) {
      // Model expects [1, N]
      input = [inputList];
    } else if (inputShape.length == 3 && inputShape[0] == 1) {
      // WARNING: This is an LSTM. It expects [1, SEQUENCE_LENGTH, NUM_FEATURES].
      // If the model expects a sequence, this single input will fail or give bad results.
      // Assuming SEQUENCE_LENGTH is 1 for a makeshift fix:
      input = [
        [inputList],
      ];
    } else {
      // Fallback: send flat list [N]
      input = inputList;
    }

    // Create output container based on output shape
    // Assuming output is [1, numLabels] or [numLabels]
    final numLabels = outputShape.last;

    final output = List.generate(
      outputShape[0], // batch size (usually 1)
      (_) => Float32List.fromList(List.filled(numLabels, 0.0)),
    );

    // Run inference
    _interpreter!.run(input, output);

    // Extract probabilities (output is List<Float32List>)
    final List<double> outputProbabilities = output[0].toList().cast<double>();

    int maxIndex = 0;
    double maxProb = -1.0;
    for (int i = 0; i < outputProbabilities.length; i++) {
      if (outputProbabilities[i] > maxProb) {
        maxProb = outputProbabilities[i];
        maxIndex = i;
      }
    }

    print(
      'Predicted Index: $maxIndex, Probability: ${maxProb.toStringAsFixed(3)}',
    );
    return _labels[maxIndex];
  }
}
