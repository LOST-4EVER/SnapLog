import 'package:camera/camera.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  late CameraController _controller;
  double _currentZoom = 1.0;
  double _maxZoom = 5.0;
  FlashMode _flashMode = FlashMode.off;

  factory CameraService() => _instance;

  CameraService._internal();

  Future<void> initializeCamera(CameraDescription camera) async {
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
    );
    await _controller.initialize();
    _maxZoom = await _controller.getMaxZoomLevel();
  }

  CameraController get controller => _controller;

  double get currentZoom => _currentZoom;
  double get maxZoom => _maxZoom;
  FlashMode get flashMode => _flashMode;

  Future<void> setZoomLevel(double zoom) async {
    if (zoom < 1.0 || zoom > _maxZoom) return;
    _currentZoom = zoom;
    await _controller.setZoomLevel(zoom);
  }

  Future<void> setFlashMode(FlashMode mode) async {
    _flashMode = mode;
    await _controller.setFlashMode(mode);
  }

  Future<void> toggleFlash() async {
    _flashMode = _flashMode == FlashMode.off ? FlashMode.always : FlashMode.off;
    await _controller.setFlashMode(_flashMode);
  }

  void dispose() {
    _controller.dispose();
  }
}

