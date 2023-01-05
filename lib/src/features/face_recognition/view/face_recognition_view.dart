import 'dart:io';

import 'package:camera/camera.dart';
import 'package:face_recognition/src/common/throttle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

List<CameraDescription> _cameras = [];

class FaceReconitionView extends StatefulWidget {
  const FaceReconitionView({super.key});

  @override
  State<FaceReconitionView> createState() => _FaceReconitionViewState();
}

class _FaceReconitionViewState extends State<FaceReconitionView> {
  CameraController? controller;
  late Throttler throttler;

  double rotX = 0;
  double rotY = 0;
  double rotZ = 0;

  int noseX = 0;
  int noseY = 0;

  bool showBox = false;

  Rect? boundingBox;

  setupCamera() async {
    _cameras = await availableCameras();
    final cameraDescription = _cameras
        .where(
          (element) => element.lensDirection == CameraLensDirection.front,
        )
        .first;

    controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await controller!.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            print('User denied camera access.');
            break;
          default:
            print('Handle other errors.');
            break;
        }
      }
    });

    controller!.startImageStream((image) {
      throttler.run(() async {
        try {
          final planeData = image.planes.map(
            (Plane plane) {
              return InputImagePlaneMetadata(
                bytesPerRow: plane.bytesPerRow,
                height: plane.height,
                width: plane.width,
              );
            },
          ).toList();

          final InputImageRotation imageRotation = InputImageRotationValue.fromRawValue(cameraDescription.sensorOrientation)!;

          final InputImageFormat inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw)!;

          final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

          final inputImageData = InputImageData(
            size: imageSize,
            imageRotation: imageRotation,
            inputImageFormat: inputImageFormat,
            planeData: planeData,
          );
          final WriteBuffer allBytes = WriteBuffer();
          for (final Plane plane in image.planes) {
            allBytes.putUint8List(plane.bytes);
          }
          final bytes = allBytes.done().buffer.asUint8List();
          processImage(bytes, inputImageData);
        } on Exception catch (e) {
          print(e);
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    throttler = Throttler(milliSeconds: 200);

    setupCamera();
  }

  Future<void> processImage(Uint8List bytes, InputImageData inputImageData) async {
    final inputImage = InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);
    final options = FaceDetectorOptions(enableLandmarks: true);
    final faceDetector = FaceDetector(options: options);

    final List<Face> faces = await faceDetector.processImage(inputImage);

    setState(() {
      if (faces.isNotEmpty) {
        showBox = true;
      } else {
        showBox = false;
      }
    });

    for (Face face in faces) {
      setState(() {
        boundingBox = face.boundingBox;

        rotX = face.headEulerAngleX ?? 0;
        rotY = face.headEulerAngleY ?? 0;
        rotZ = face.headEulerAngleZ ?? 0;
      });

      print("TAGGED =========================");
      print("TAGGED Rotation X :$rotX");
      print("TAGGED Rotation Y :$rotY");
      print("TAGGED Rotation Z :$rotZ");

      print("TAGGED ============");
      print("TAGGED t d l r : ${boundingBox!.top} ${boundingBox!.bottom} ${boundingBox!.left} ${boundingBox!.right}");

      final FaceLandmark? nose = face.landmarks[FaceLandmarkType.noseBase];
      if (nose != null) {
        setState(() {
          noseX = nose.position.x;
          noseY = nose.position.y;
        });
      }

      if (face.smilingProbability != null) {
        final double? smileProb = face.smilingProbability;
        print("TAGGED Smiling Probability: $smileProb");
      }
    }

    faceDetector.close();
  }

  @override
  void dispose() {
    controller!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameras.isEmpty || controller == null || !controller!.value.isInitialized) {
      return Container();
    }
    var scale = MediaQuery.of(context).size.aspectRatio * controller!.value.aspectRatio;

    if (scale < 1) scale = 1 / scale;

    return MaterialApp(
      home: Scaffold(
        body: Stack(
          alignment: FractionalOffset.center,
          children: <Widget>[
            Positioned.fill(
              child: Transform.scale(scale: scale, child: Center(child: CameraPreview(controller!))),
            ),

            if (boundingBox != null && showBox) ...[
              Positioned(
                top: boundingBox!.top - 250 > 0 ? boundingBox!.top - 250 : boundingBox!.top,
                right: boundingBox!.left - 100,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: boundingBox!.width > 120 ? boundingBox!.width - 120 : boundingBox!.width,
                    height: boundingBox!.height > 30 ? boundingBox!.height - 30 : boundingBox!.height,
                    decoration: BoxDecoration(
                      border: Border.all(
                        width: 2,
                        color: Colors.blue,
                      ),
                    ),
                    child: Text(
                      "X :$rotX\nY :$rotY\nZ :$rotZ",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
            // if (noseX > 0 && noseY > 0) ...[
            //   Positioned(
            //     top: noseY.toDouble() - 270,
            //     right: noseX.toDouble() - 200,
            //     child: Container(
            //       width: 80,
            //       height: 50,
            //       decoration: BoxDecoration(
            //         border: Border.all(
            //           width: 2,
            //           color: Colors.red,
            //         ),
            //       ),
            //       child: const Text(
            //         "nose",
            //         style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            //       ),
            //     ),
            //   ),
            // ],

            // Positioned.fill(
            //   child: Opacity(
            //       opacity: 0.5,
            //       child: Image.asset(
            //         'asset/face_overlay.png',
            //         fit: BoxFit.fitHeight,
            //       )),
            // ),
            // Align(
            //   alignment: Alignment.bottomCenter,
            //   child: Material(
            //     color: Colors.transparent,
            //     child: InkWell(
            //       borderRadius: const BorderRadius.all(Radius.circular(50.0)),
            //       onTap: () {},
            //       child: Container(
            //           padding: const EdgeInsets.only(bottom: 16),
            //           child: ElevatedButton(
            //             onPressed: () async {
            //               // await _capture().then((res) async {
            //               //   if (res != null) {
            //               //     final capt = img.decodeImage(res.readAsBytesSync());
            //               //     final ori = img.bakeOrientation(capt!);
            //               //     await res.writeAsBytes(img.encodeJpg(ori)).then((value) {
            //               //       widget.pathController.text = res.path;
            //               //       widget.base64Controller.text = base64Encode(value.readAsBytesSync());
            //               //       widget.imageFile.value = res;

            //               //       Navigator.pop(context);
            //               //     });
            //               //   }
            //               // });
            //             },
            //             style: ElevatedButton.styleFrom(
            //               shape: const CircleBorder(),
            //               padding: const EdgeInsets.all(20),
            //               backgroundColor: Colors.blue, // <-- Button color
            //               foregroundColor: Colors.grey, // <-- Splash color
            //             ),
            //             child: const Icon(Icons.camera_alt, color: Colors.white),
            //           )),
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Future<File?> _capture() async {
    if (!controller!.value.isInitialized) {
      return null;
    }
    final result = await controller!.takePicture();
    File image = File(result.path);

    return image;
  }
}
