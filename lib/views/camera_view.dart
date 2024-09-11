import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:testod/controller/scan_controller.dart';

class CameraView extends StatelessWidget {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<ScanController>(
        init: ScanController(),
        builder: (controller) {
          return controller.isCameraInitialized.value
              ? Stack(
                  children: [
                    CameraPreview(controller.cameraController),
                    if (controller.w > 0.0 && controller.h > 0.0)
                      Positioned(
                        top: controller.y * MediaQuery.of(context).size.height,
                        left: controller.x * MediaQuery.of(context).size.width,
                        child: Container(
                          width: controller.w * MediaQuery.of(context).size.width,
                          height: controller.h * MediaQuery.of(context).size.height,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green, width: 4.0),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                color: Colors.white,
                                child: Text(controller.label ?? ""),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                )
              : const Center(child: Text("Loading Preview Text"));
        },
      ),
    );
  }
}
