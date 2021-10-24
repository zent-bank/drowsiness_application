import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_lib;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

import '../../utils/image_utils.dart';

class FaceMesh {
  static const String MODEL_FILE_NAME = 'models/face_landmark.tflite';
  static const int INPUT_SIZE = 192;

  Interpreter? _interpreter;

  final _outputShapes = <List<int>>[];
  final _outputTypes = <TfLiteType>[];

  Interpreter? get interpreter => _interpreter;
  int get getAddress => _interpreter!.address;

  FaceMesh({Interpreter? interpreter}) {
    _loadModel(interpreter: interpreter);
  }

  void _loadModel({Interpreter? interpreter}) async {
    try {
      final interpreterOptions = InterpreterOptions();

      _interpreter = interpreter ??
          await Interpreter.fromAsset(MODEL_FILE_NAME,
              options: interpreterOptions);

      final outputTensors = _interpreter!.getOutputTensors();

      outputTensors.forEach((tensor) {
        _outputShapes.add(tensor.shape);
        _outputTypes.add(tensor.type);
      });
    } catch (e) {
      print('Error while creating interpreter: $e');
    }
  }

  TensorImage _getProcessedImage(TensorImage inputImage) {
    final imageProcessor = ImageProcessorBuilder()
        .add(ResizeOp(INPUT_SIZE, INPUT_SIZE, ResizeMethod.BILINEAR))
        .add(NormalizeOp(0, 255))
        .build();

    inputImage = imageProcessor.process(inputImage);
    return inputImage;
  }

  Map<String, dynamic>? _predict(image_lib.Image image) {
    if (_interpreter == null) {
      print('Interpreter not initialized');
      return null;
    }

    if (Platform.isAndroid) {
      image = image_lib.copyRotate(image, -90);
      image = image_lib.flipHorizontal(image);
    }
    final tensorImage = TensorImage(TfLiteType.float32);
    tensorImage.loadImage(image);
    final inputImage = _getProcessedImage(tensorImage);

    TensorBuffer outputLandmarks = TensorBufferFloat(_outputShapes[0]);
    TensorBuffer outputScores = TensorBufferFloat(_outputShapes[1]);

    final inputs = <Object>[inputImage.buffer];

    final outputs = <int, Object>{
      0: outputLandmarks.buffer,
      1: outputScores.buffer,
    };

    _interpreter!.runForMultipleInputs(inputs, outputs);

    if (outputScores.getDoubleValue(0) < 0) {
      return null;
    }

    final landmarkPoints = outputLandmarks.getDoubleList().reshape([468, 3]);
    final landmarkResults = <Offset>[];
    for (var point in landmarkPoints) {
      landmarkResults.add(Offset(
        point[0] / INPUT_SIZE * image.width,
        point[1] / INPUT_SIZE * image.height,
      ));
    }

    return {'point': landmarkResults};
  }
}

Map<String, dynamic>? runFaceMesh(Map<String, dynamic> params) {
  final faceDetection = FaceMesh(interpreter: Interpreter.fromAddress(params['detectorAddress']));

  final image = ImageUtils.convertCameraImage(params['cameraImage']);
  final result = faceDetection._predict(image!);
  print("result: $result");
  
  return result;
}