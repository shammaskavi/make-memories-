import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'bluetooth_printer_helper.dart'; // 👈 Add this import

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MaterialApp(home: CameraApp(camera: firstCamera)));
}

class CameraApp extends StatefulWidget {
  final CameraDescription camera;
  const CameraApp({Key? key, required this.camera}) : super(key: key);

  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  XFile? _capturedImage;

  int _countdown = 0;
  Timer? _timer;
  bool _isCountingDown = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void startCountdown() {
    setState(() {
      _countdown = 5;
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
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      setState(() {
        _capturedImage = image;
      });
    } catch (e) {
      print('Error capturing photo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body:
          _capturedImage != null
              ? Column(
                children: [
                  Expanded(child: Image.file(File(_capturedImage!.path))),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons.print),
                        label: Text("Print"),
                        onPressed: () async {
                          final helper = BluetoothPrinterHelper();
                          await helper.initPrinter();
                          await helper.printImage(_capturedImage!.path);
                        },
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.refresh),
                        label: Text("Retake"),
                        onPressed: () {
                          setState(() {
                            _capturedImage = null;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              )
              : FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return Column(
                      children: [
                        // Camera preview - 2/3 of screen
                        Expanded(
                          flex: 2,
                          child: Stack(
                            children: [
                              CameraPreview(_controller),
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

                        // Bottom 1/3 with quote and capture button
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
                                    '"Smile, it\'s a beautiful moment!"',
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
