import 'dart:developer';
import 'package:camera/camera.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:get/state_manager.dart';
import 'package:permission_handler/permission_handler.dart';

class ScanController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    initCamera();
    initTFLite();
  }

  @override
  void dispose() {
    super.dispose();
    cameraController.dispose();
    Tflite.close();
  }

  late CameraController cameraController;
  late List<CameraDescription> cameras;

  var isCameraInitialized = false.obs;

  var cameraCount = 0;
  bool isProcessing = false;

  var x = 0.0, y = 0.0, w = 0.0, h = 0.0;
  var label = "";

  initCamera() async {
    if (await Permission.camera.request().isGranted) {
      cameras = await availableCameras();

      cameraController = CameraController(cameras[0], ResolutionPreset.max,
          imageFormatGroup: ImageFormatGroup.bgra8888);
      await cameraController.initialize().then((value) {
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
      print("Permission denied");
    }
  }

  initTFLite() async {
    await Tflite.loadModel(
      model: "assets/model.tflite",
      labels: "assets/labels.txt",
      isAsset: true,
      numThreads: 1,
      useGpuDelegate: false,
    );
  }

  objectDetector(CameraImage image) async {
    if (isProcessing) {
      return;
    }

    isProcessing = true;

    try {
      var detector = await Tflite.detectObjectOnFrame(
        bytesList: image.planes.map((e) {
          return e.bytes;
        }).toList(),
        imageHeight: image.height,  
        imageWidth: image.width,
        imageMean: 127.5,
        imageStd: 127.5,
        rotation: 90,
        numResultsPerClass: 1,
        threshold: 0.4,
      );

      print(detector); // Log the detection results

      if (detector != null && detector.isNotEmpty) {
        var ourDetectedObject = detector.first;

        var confidence = ourDetectedObject['confidenceInClass'] ?? ourDetectedObject['confidence'];
        if (confidence != null && confidence > 0.45) {
          label = ourDetectedObject['detectedClass'].toString();
          h = ourDetectedObject['rect']['h'] ?? 0.0;
          w = ourDetectedObject['rect']['w'] ?? 0.0;
          x = ourDetectedObject['rect']['x'] ?? 0.0;
          y = ourDetectedObject['rect']['y'] ?? 0.0;
          print('x: $x, y: $y, w: $w, h: $h, label: $label');
        } else {
          // Reset values if confidence is low or null
          label = "";
          h = 0.0;
          w = 0.0;
          x = 0.0;
          y = 0.0;
        }
      } else {
        // Handle the case where no object is detected
        label = "";
        h = 0.0;
        w = 0.0;
        x = 0.0;
        y = 0.0;
      }
      update();
    } catch (e) {
      print("Error during object detection: $e");
      // Handle the error, perhaps notify the user or restart the camera stream
    } finally {
      isProcessing = false;
    }
  }
}
