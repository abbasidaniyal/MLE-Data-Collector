import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../utils/image_saver.dart';

class CameraScreen extends StatefulWidget {
  final List<String> selectedClasses;
  const CameraScreen({super.key, required this.selectedClasses});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isSaving = false;
  String? _lastSavedPath;
  int _captureCount = 0;

  Future<void> _deleteLastPhoto() async {
    if (_lastSavedPath == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('Remove the last captured image?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true && _lastSavedPath != null) {
      await File(_lastSavedPath!).delete();
      setState(() {
        _lastSavedPath = null;
        _captureCount--;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras found')),
          );
        }
        return;
      }
      final controller = CameraController(
        _cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      await controller.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera init error: $e')),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndSave() async {
    if (_isSaving || _controller == null || !_isInitialized) return;
    setState(() => _isSaving = true);
    try {
      final xFile = await _controller!.takePicture();
      final savedPath = await ImageSaver.saveImage(
        sourcePath: xFile.path,
        classes: widget.selectedClasses,
      );
      _captureCount++;
      await File(xFile.path).delete();
      if (mounted) {
        setState(() {
          _lastSavedPath = savedPath;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Capture error: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final folderName = widget.selectedClasses.join('_');
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(folderName,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('$_captureCount captured',
                  style: const TextStyle(color: Colors.white70)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: !_isInitialized
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : CameraPreview(_controller!),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: _lastSavedPath != null
                      ? GestureDetector(
                          onTap: _deleteLastPhoto,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(File(_lastSavedPath!),
                                    fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(),
                ),
                GestureDetector(
                  onTap: _captureAndSave,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _isSaving ? Colors.grey : Colors.white,
                    ),
                    child: _isSaving
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                                strokeWidth: 3, color: Colors.black),
                          )
                        : const Icon(Icons.camera, size: 36, color: Colors.black),
                  ),
                ),
                if (_cameras.length > 1)
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios,
                        color: Colors.white, size: 32),
                    onPressed: () async {
                      final current =
                          _cameras.indexOf(_controller!.description);
                      final next =
                          _cameras[(current + 1) % _cameras.length];
                      await _controller!.dispose();
                      _controller = CameraController(next,
                          ResolutionPreset.medium,
                          enableAudio: false,
                          imageFormatGroup: ImageFormatGroup.jpeg);
                      await _controller!.initialize();
                      if (mounted) setState(() {});
                    },
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
