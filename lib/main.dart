import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'bluetooth_printer_helper.dart';
import 'image_processing_helper.dart';

void main() {
  runApp(MaterialApp(home: CameraApp()));
}

class CameraApp extends StatefulWidget {
  const CameraApp({Key? key}) : super(key: key);

  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  XFile? _ditheredImage;
  int _countdown = 0;
  Timer? _timer;
  bool _isCountingDown = false;
  int _cameraIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initCameras();
  }

  Future<void> _initCameras() async {
    _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      _cameraIndex = 0;
      _initializeCamera();
    } else {
      print('No cameras found');
    }
  }

  void _initializeCamera() {
    _controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _initializeControllerFuture = _controller!
        .initialize()
        .then((_) {
          setState(() {
            _isLoading = false;
          });
        })
        .catchError((e) {
          print("Camera init error: $e");
        });
  }

  void _switchCamera() {
    if (_cameras.length < 2) return;

    setState(() {
      _isLoading = true;
      _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    });

    _controller?.dispose().then((_) {
      _initializeCamera();
    });
  }

  void startCountdown() {
    setState(() {
      _countdown = 3;
      _isCountingDown = true;
    });

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          timer.cancel();
          _isCountingDown = false;
          _countdown = 0;
          capturePhoto();
        }
      });
    });
  }

  Future<void> capturePhoto() async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) {
        print("Camera not ready");
        return;
      }

      await _initializeControllerFuture;
      final rawImage = await _controller!.takePicture();
      final ditheredPath = await ImageProcessingHelper.processImage(
        rawImage.path,
        flip: _cameras[_cameraIndex].lensDirection == CameraLensDirection.front,
      );
      setState(() {
        _ditheredImage = XFile(ditheredPath);
      });
    } catch (e, stack) {
      print('Error capturing or processing photo: $e');
      print(stack);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body:
          _ditheredImage != null
              ? Column(
                children: [
                  Expanded(child: Image.file(File(_ditheredImage!.path))),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons.print),
                        label: Text("Print"),
                        onPressed: () async {
                          final helper = BluetoothPrinterHelper();
                          await helper.initPrinter();
                          await helper.printImage(_ditheredImage!.path);
                        },
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.refresh),
                        label: Text("Retake"),
                        onPressed: () {
                          setState(() {
                            _ditheredImage = null;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              )
              : _isLoading || _controller == null
              ? Center(child: CircularProgressIndicator())
              : FutureBuilder(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return Column(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Stack(
                            children: [
                              Transform(
                                alignment: Alignment.center,
                                transform:
                                    _cameras[_cameraIndex].lensDirection ==
                                            CameraLensDirection.front
                                        ? Matrix4.rotationY(math.pi)
                                        : Matrix4.identity(),
                                child: CameraPreview(_controller!),
                              ),
                              if (_isCountingDown)
                                Center(
                                  child: Text(
                                    '$_countdown',
                                    style: TextStyle(
                                      fontSize: 72,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 10,
                                          color: Colors.black,
                                          offset: Offset(0, 0),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            color: Colors.black,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '"What a day to smile"',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontStyle: FontStyle.italic,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  iconSize: 48,
                                  icon: Icon(
                                    Icons.cameraswitch,
                                    color: Colors.white,
                                  ),
                                  onPressed: _switchCamera,
                                ),
                                IconButton(
                                  iconSize: 48,
                                  icon: Icon(
                                    Icons.camera_alt,
                                    color:
                                        _isCountingDown
                                            ? Colors.grey
                                            : Colors.white,
                                  ),
                                  onPressed:
                                      _isCountingDown ? null : startCountdown,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Center(child: CircularProgressIndicator());
                  }
                },
              ),
    );
  }
}
