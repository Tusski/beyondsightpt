import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:get/state_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper_plus/tflite_flutter_helper_plus.dart'; // Correct helper package
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img; // For manual image processing

class ScanController extends GetxController {
  late Interpreter interpreter;
  late CameraController cameraController;
  var isCameraInitialized = false.obs;
  var cameraCount = 0;
  bool isProcessing = false;

  var x = 0.0, y = 0.0, w = 0.0, h = 0.0;
  var label = "";
  var confidence = 0.0;
  List<String> labels = [];

  @override
  void onInit() {
    super.onInit();
    loadLabels();
    initCamera();
    initTFLite();
  }

  @override
  void dispose() {
    super.dispose();
    cameraController.dispose();
    interpreter.close();
  }

  Future<void> loadLabels() async {
    labels = await rootBundle.loadString('assets/labels.txt').then((String contents) {
      return contents.split('\n'); // Split by new line
    });
    print("Labels loaded: ${labels.length}");
  }

  initCamera() async {
    if (await Permission.camera.request().isGranted) {
      List<CameraDescription> cameras = await availableCameras();
      cameraController = CameraController(cameras[0], ResolutionPreset.max);
      await cameraController.initialize().then((_) {
        cameraController.startImageStream((image) {
          cameraCount++;
          if (cameraCount % 10 == 0) {
            objectDetector(image);
          }
          update();
        });
      });
      isCameraInitialized(true);
      update();
    } else {
      print("Camera permission denied");
    }
  }

  initTFLite() async {
    try {
      interpreter = await Interpreter.fromAsset('yolov5s.tflite');
      print("TFLite model loaded successfully");
    } catch (e) {
      print("Error loading TFLite model: $e");
    }
  }

  objectDetector(CameraImage image) async {
    if (isProcessing) {
      return;
    }

    isProcessing = true;

    try {
      // Preprocess CameraImage to input tensor
      var input = _preProcessImage(image);

      // Define output tensor based on YOLOv5's output shape
      var output = List.generate(1, (i) => List.generate(25200, (j) => List.filled(85, 0.0)));

      // Run model inference
      interpreter.run(input.buffer.asFloat32List(), output);

      // Process the output (apply NMS, thresholding, etc.)
      _postProcessResults(output);

      update();
    } catch (e) {
      print("Error during object detection: $e");
    } finally {
      isProcessing = false;
    }
  }

  Float32List _preProcessImage(CameraImage image) {
    // Convert YUV camera image to RGB and resize it to 640x640
    img.Image? imgRGB = _convertYUV420ToImage(image);
    img.Image resizedImage = img.copyResize(imgRGB!, width: 640, height: 640); // Resize image

    // Convert to TensorImage (required by TFLite)
    TensorImage tensorImage = TensorImage.fromImage(resizedImage);

    // Apply normalization (0-255)
    ImageProcessor imageProcessor = ImageProcessorBuilder()
        .add(NormalizeOp(0, 255))  // Normalize pixel values to [0, 1]
        .build();

    tensorImage = imageProcessor.process(tensorImage);  // Apply preprocessing

    return tensorImage.buffer.asFloat32List(); // Return as Float32List
  }

  img.Image _convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final img.Image imgRGB = img.Image(width, height);  // Create an empty RGB image

    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;

    for (int h = 0; h < height; h++) {
      for (int w = 0; w < width; w++) {
        final int uvIndex = uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();
        final int index = h * width + w;

        final int y = image.planes[0].bytes[index];
        final int u = image.planes[1].bytes[uvIndex];
        final int v = image.planes[2].bytes[uvIndex];

        imgRGB.setPixel(w, h, _yuvToRgb(y, u, v));
      }
    }

    return imgRGB;
  }

  int _yuvToRgb(int y, int u, int v) {
    // YUV to RGB conversion formula
    int r = (y + (1.370705 * (v - 128))).round();
    int g = (y - (0.337633 * (u - 128)) - (0.698001 * (v - 128))).round();
    int b = (y + (1.732446 * (u - 128))).round();

    r = r.clamp(0, 255);
    g = g.clamp(0, 255);
    b = b.clamp(0, 255);

    return img.getColor(r, g, b);
  }

  void _postProcessResults(List<List<List<double>>> output) {
    // Extract bounding boxes, objectness scores, class probabilities
    // Implement post-processing: Apply Non-Maximum Suppression (NMS), filter by confidence, etc.

    for (var i = 0; i < output[0].length; i++) {
      // YOLOv5 output format: [x, y, w, h, objectness_score, class_1, class_2, ..., class_80]
      var bbox = output[0][i];

      double x = bbox[0];
      double y = bbox[1];
      double w = bbox[2];
      double h = bbox[3];
      double objectnessScore = bbox[4];

      // Find class with the highest score
      var classIndex = bbox.sublist(5).indexOf(bbox.sublist(5).reduce((a, b) => a > b ? a : b));
      double confidence = bbox[5 + classIndex]; // Class confidence
      String detectedClass = _getLabel(classIndex); // Get the class name from the label

      if (objectnessScore > 0.5 && confidence > 0.5) {
        // Apply your confidence threshold (0.5 in this case)
        print("Detected: $detectedClass, Confidence: $confidence, Box: x:$x, y:$y, w:$w, h:$h");
        // You can now display these boxes and labels on the screen
      }
    }
  }

  String _getLabel(int index) {
    // Return the label for the class index (e.g., from COCO dataset labels)
    return labels[index];
  }

  void resetDetectionValues() {
    label = "";
    h = 0.0;
    w = 0.0;
    x = 0.0;
    y = 0.0;
    confidence = 0.0;
  }
}
