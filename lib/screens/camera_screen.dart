import 'dart:io' as io;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';
import '../services/database_helper.dart';
import '../services/entries_notifier.dart';
import 'preview_screen.dart';
import 'quiz_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  
  double _currentZoom = 1.0;
  double _maxZoom = 1.0;
  double _minZoom = 1.0;
  FlashMode _flashMode = FlashMode.off;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isCapturingPhoto = false;

  final ColorFilter _currentFilter = const ColorFilter.mode(Colors.transparent, BlendMode.dst);
  final String _filterName = "Normal";
  String? _lastCapturedPath;

  int _todaysPhotoCount = 0;
  int _dailyLimit = 3;
  String _imageQuality = 'High';
  late final EntriesNotifier _notifier;
  late final VoidCallback _notifierListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData().then((_) {
      _notifier = EntriesNotifier();
      _notifierListener = () => _loadData();
      _notifier.addListener(_notifierListener);
      _initializeCamera(widget.cameras[_selectedCameraIndex]);
    });
   }

   @override
   void dispose() {
     WidgetsBinding.instance.removeObserver(this);
     _notifier.removeListener(_notifierListener);
     _controller?.dispose();
     super.dispose();
   }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera(cameraController.description);
    }
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    ResolutionPreset preset;
    // Optimized resolution presets for better frame rate
    switch (_imageQuality) {
      case 'Low': preset = ResolutionPreset.medium; break;
      case 'Medium': preset = ResolutionPreset.high; break;
      case 'High': default: preset = ResolutionPreset.veryHigh; break;
    }

    final controller = CameraController(
      cameraDescription,
      preset,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      _initializeControllerFuture = controller.initialize();
      await _initializeControllerFuture;
      _maxZoom = await controller.getMaxZoomLevel();
      _minZoom = await controller.getMinZoomLevel();
      await controller.setFlashMode(_flashMode);
      if (mounted) {
        setState(() {
          _controller = controller;
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Camera initialization error: $e");
    }
  }

  Future<void> _loadData() async {
    final count = await DatabaseHelper().getTodaysPhotoCount();
    final settings = await SettingsService().getSettings();
    if (mounted) {
      setState(() {
        _todaysPhotoCount = count;
        _dailyLimit = settings['dailyLimit'] ?? 3;
        _imageQuality = settings['imageQuality'] ?? 'High';
      });
    }
  }

  Future<void> _toggleCamera() async {
    if (widget.cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    setState(() => _isCameraInitialized = false);
    await _controller?.dispose();
    await _initializeCamera(widget.cameras[_selectedCameraIndex]);
    HapticFeedback.mediumImpact();
  }

  Future<void> _cycleFlashMode() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.off: nextMode = FlashMode.auto; break;
      case FlashMode.auto: nextMode = FlashMode.always; break;
      case FlashMode.always: nextMode = FlashMode.torch; break;
      case FlashMode.torch: default: nextMode = FlashMode.off; break;
    }
    try {
      await _controller!.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint("Error setting flash mode: $e");
    }
  }

  Future<void> _takePicture() async {
    if (_isCapturingPhoto) return;
    if (_todaysPhotoCount >= _dailyLimit) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Daily limit reached.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() => _isCapturingPhoto = true);
    try {
      final image = await _controller!.takePicture();
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() => _lastCapturedPath = image.path);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewScreen(imagePath: image.path, filterName: _filterName),
        ),
      );
      await _loadData();
    } catch (e) {
      debugPrint("Error taking picture: $e");
    } finally {
      if (mounted) setState(() => _isCapturingPhoto = false);
    }
  }

  Future<void> _deleteLastPhoto() async {
    if (_lastCapturedPath == null) return;
    
    // Unified Quiz for deletion
    final bool? passedQuiz = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QuizScreen()),
    );

    if (passedQuiz == true) {
      try {
        final file = io.File(_lastCapturedPath!);
        if (await file.exists()) {
          await file.delete();
          setState(() => _lastCapturedPath = null);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Photo deleted')),
            );
          }
        }
      } catch (e) {
        debugPrint('Error deleting photo: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cameras.isEmpty) {
      return const Scaffold(body: Center(child: Text("No cameras detected")));
    }

    final size = MediaQuery.of(context).size;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Viewfinder Container - Optimized with RepaintBoundary
          Positioned(
            top: size.height * 0.08,
            bottom: size.height * 0.18,
            left: 15,
            right: 15,
            child: RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _isCameraInitialized && _controller != null
                        ? CameraPreview(_controller!)
                        : const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    
                    if (_filterName != "Normal")
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColorFiltered(
                            colorFilter: _currentFilter,
                            child: Container(color: Colors.transparent),
                          ),
                        ),
                      ),
                    
                    CustomPaint(painter: ViewfinderCornersPainter()),
                  ],
                ),
              ),
            ),
          ),

          // Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _TopIconButton(
                      icon: _flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
                      onPressed: _cycleFlashMode,
                      color: _flashMode == FlashMode.torch ? Colors.yellow : Colors.white,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.photo_library, size: 14, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            "$_todaysPhotoCount / $_dailyLimit",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48), // Spacer for balance
                  ],
                ),
              ),
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24, left: 32, right: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Thumbnail / Delete
                    GestureDetector(
                      onLongPress: _deleteLastPhoto,
                      child: _BottomSideButton(
                        child: _lastCapturedPath != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(io.File(_lastCapturedPath!), width: 44, height: 44, fit: BoxFit.cover),
                              )
                            : Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: const Icon(Icons.image_outlined, color: Colors.white70, size: 20),
                              ),
                        onPressed: () {},
                      ),
                    ),

                    // Capture Button
                    GestureDetector(
                      onTap: _takePicture,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3.5),
                        ),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: _isCapturingPhoto ? 40 : 62,
                            height: _isCapturingPhoto ? 40 : 62,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(_isCapturingPhoto ? 8 : 31),
                            ),
                            child: _isCapturingPhoto
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : null,
                          ),
                        ),
                      ),
                    ),

                    // Flip Camera
                    _BottomSideButton(
                      child: Icon(Icons.flip_camera_ios_outlined, color: Colors.white.withOpacity(0.9), size: 26),
                      onPressed: _toggleCamera,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  const _TopIconButton({required this.icon, required this.onPressed, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: 22),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.1),
        shape: const CircleBorder(),
      ),
    );
  }
}

class _BottomSideButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  const _BottomSideButton({required this.child, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(4),
        child: child,
      ),
    );
  }
}

class ViewfinderCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const length = 30.0;
    const padding = 24.0;

    canvas.drawPath(Path()..moveTo(padding, padding + length)..lineTo(padding, padding)..lineTo(padding + length, padding), paint);
    canvas.drawPath(Path()..moveTo(size.width - padding - length, padding)..lineTo(size.width - padding, padding)..lineTo(size.width - padding, padding + length), paint);
    canvas.drawPath(Path()..moveTo(padding, size.height - padding - length)..lineTo(padding, size.height - padding)..lineTo(padding + length, size.height - padding), paint);
    canvas.drawPath(Path()..moveTo(size.width - padding - length, size.height - padding)..lineTo(size.width - padding, size.height - padding)..lineTo(size.width - padding, size.height - padding - length), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
