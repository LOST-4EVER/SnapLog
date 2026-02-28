import 'dart:io' as io;
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import '../services/settings_service.dart';
import '../services/database_helper.dart';
import '../services/entries_notifier.dart';
import 'preview_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final bool isActive;
  const CameraScreen({super.key, required this.cameras, this.isActive = true});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final ImagePicker _picker = ImagePicker();
  
  FlashMode _flashMode = FlashMode.off;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isCapturingPhoto = false;
  
  bool _showGrid = false;

  ColorFilter _currentFilter = const ColorFilter.mode(Colors.transparent, BlendMode.dst);
  String _filterName = "Normal";
  String? _lastCapturedPath;

  int _todaysPhotoCount = 0;
  int _dailyLimit = 3;
  String _imageQuality = 'High';
  int _shutterDelay = 0;
  String _hapticIntensity = 'Medium';
  bool _autoSaveToGallery = false;
  bool _useSystemCamera = false;
  bool _hapticEnabled = true;
  bool _shutterSound = true;
  
  late final EntriesNotifier _notifier;
  late final VoidCallback _notifierListener;

  final Map<String, ColorFilter> _filters = {
    "Normal": const ColorFilter.mode(Colors.transparent, BlendMode.dst),
    "B&W": const ColorFilter.matrix([
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0,      0,      0,      1, 0,
    ]),
    "Sepia": const ColorFilter.matrix([
      0.393, 0.769, 0.189, 0, 0,
      0.349, 0.686, 0.168, 0, 0,
      0.272, 0.534, 0.131, 0, 0,
      0,     0,     0,     1, 0,
    ]),
    "Cool": const ColorFilter.matrix([
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1.2, 0, 0,
      0, 0, 0, 1, 0,
    ]),
    "Warm": const ColorFilter.matrix([
      1.2, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 0.8, 0, 0,
      0, 0, 0, 1, 0,
    ]),
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifier = EntriesNotifier();
    _notifierListener = () => _loadData();
    _notifier.addListener(_notifierListener);
    _loadData().then((_) {
      if (mounted && !_useSystemCamera && widget.isActive) {
        _initializeCamera(widget.cameras[_selectedCameraIndex]);
      }
    });
    _checkLostData();
   }

   Future<void> _checkLostData() async {
     if (!io.Platform.isAndroid) return;
     final LostDataResponse response = await _picker.retrieveLostData();
     if (response.isEmpty) return;
     if (response.file != null) {
       _handlePickedImage(response.file!.path);
     }
   }

   @override
   void dispose() {
     WidgetsBinding.instance.removeObserver(this);
     _notifier.removeListener(_notifierListener);
     _controller?.dispose();
     super.dispose();
   }

  @override
  void didUpdateWidget(CameraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      if (!_useSystemCamera) _initializeCamera(widget.cameras[_selectedCameraIndex]);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller?.dispose();
      _controller = null;
      _isCameraInitialized = false;
      _initializeControllerFuture = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
      _isCameraInitialized = false;
    } else if (state == AppLifecycleState.resumed && !_useSystemCamera && widget.isActive) {
      _initializeCamera(widget.cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    if (_initializeControllerFuture != null || _isCapturingPhoto) return;

    ResolutionPreset preset;
    switch (_imageQuality) {
      case 'Low': preset = ResolutionPreset.medium; break;
      case 'Medium': preset = ResolutionPreset.high; break;
      case 'High': preset = ResolutionPreset.veryHigh; break;
      case 'Max (Ultra)': preset = ResolutionPreset.max; break;
      default: preset = ResolutionPreset.high; break;
    }

    final controller = CameraController(
      cameraDescription,
      preset,
      enableAudio: false,
      imageFormatGroup: io.Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    try {
      _initializeControllerFuture = controller.initialize();
      await _initializeControllerFuture;
      
      if (controller.value.isInitialized) {
        await controller.setExposureMode(ExposureMode.auto);
        await controller.setFocusMode(FocusMode.auto);
        await controller.setFlashMode(_flashMode);
      }
      
      if (mounted) {
        setState(() {
          _controller = controller;
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Camera initialization error: $e");
    } finally {
      _initializeControllerFuture = null;
    }
  }

  Future<void> _loadData() async {
    final count = await DatabaseHelper().getTodaysPhotoCount();
    final settings = await SettingsService().getSettings();
    final oldUseSystemCamera = _useSystemCamera;
    
    if (mounted) {
      setState(() {
        _todaysPhotoCount = count;
        _dailyLimit = settings['dailyLimit'] ?? 3;
        _imageQuality = settings['imageQuality'] ?? 'High';
        _filterName = settings['defaultFilter'] ?? 'Normal';
        _shutterDelay = settings['shutterDelay'] ?? 0;
        _hapticIntensity = settings['hapticIntensity'] ?? 'Medium';
        _autoSaveToGallery = settings['autoSaveToGallery'] ?? false;
        _currentFilter = _filters[_filterName]!;
        _useSystemCamera = settings['useSystemCamera'] ?? false;
        _hapticEnabled = settings['hapticFeedback'] ?? true;
        _shutterSound = settings['shutterSound'] ?? true;
      });

      if (widget.isActive) {
        if (oldUseSystemCamera && !_useSystemCamera) {
          _initializeCamera(widget.cameras[_selectedCameraIndex]);
        } else if (!oldUseSystemCamera && _useSystemCamera) {
          _controller?.dispose();
          _controller = null;
          _isCameraInitialized = false;
        }
      }
    }
  }

  Future<void> _onTapToFocus(TapUpDetails details, BoxConstraints constraints) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final offset = details.localPosition;
    final double x = offset.dx / constraints.maxWidth;
    final double y = offset.dy / constraints.maxHeight;

    try {
      await _controller!.setFocusPoint(Offset(x, y));
      await _controller!.setExposurePoint(Offset(x, y));
      if (_hapticEnabled) HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint("Focus error: $e");
    }
  }

  Future<void> _toggleCamera() async {
    if (_useSystemCamera) return;
    if (widget.cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    setState(() => _isCameraInitialized = false);
    await _controller?.dispose();
    _controller = null;
    await _initializeCamera(widget.cameras[_selectedCameraIndex]);
    if (_hapticEnabled) HapticFeedback.mediumImpact();
  }

  Future<void> _cycleFlashMode() async {
    if (_useSystemCamera) return;
    if (_controller == null || !_controller!.value.isInitialized) return;
    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.off: nextMode = FlashMode.auto; break;
      case FlashMode.auto: nextMode = FlashMode.always; break;
      case FlashMode.always: nextMode = FlashMode.torch; break;
      case FlashMode.torch: nextMode = FlashMode.off; break;
    }
    try {
      await _controller!.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
      if (_hapticEnabled) HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint("Error setting flash mode: $e");
    }
  }

  Future<String?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      
      if (permission == LocationPermission.deniedForever) return null;

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 3),
        ),
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return "${place.locality}, ${place.subAdministrativeArea}";
      }
    } catch (e) {
      debugPrint("Location error: $e");
    }
    return null;
  }

  Future<void> _handlePickedImage(String path) async {
    final location = await _getCurrentLocation();
    if (!mounted) return;
    setState(() => _lastCapturedPath = path);
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewScreen(
          imagePath: path, 
          filterName: _filterName,
          location: location,
        ),
      ),
    );
    await _loadData();
  }

  Future<void> _takePicture() async {
    if (_isCapturingPhoto) return;
    final count = await DatabaseHelper().getTodaysPhotoCount();
    if (count >= _dailyLimit) {
      if (_hapticEnabled) HapticFeedback.vibrate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily limit reached.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isCapturingPhoto = true);

    if (_shutterDelay > 0) {
      if (_hapticEnabled) HapticFeedback.lightImpact();
      await Future.delayed(Duration(seconds: _shutterDelay));
    }
    
    try {
      if (_useSystemCamera) {
        await _controller?.dispose();
        _controller = null;
        _isCameraInitialized = false;

        final XFile? photo = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 100,
        );
        
        if (photo == null) {
          if (mounted) {
            setState(() => _isCapturingPhoto = false);
            if (widget.isActive) _initializeCamera(widget.cameras[_selectedCameraIndex]);
          }
          return;
        }

        _playHardwareFeedback();
        
        if (_autoSaveToGallery) {
          // Placeholder for real gallery save if library were available
          debugPrint("Auto-saving to gallery: ${photo.path}");
        }
        
        await _handlePickedImage(photo.path);
      } else {
        if (_controller == null || !_controller!.value.isInitialized) {
          if (mounted) setState(() => _isCapturingPhoto = false);
          return;
        }
        final locationFuture = _getCurrentLocation();
        final image = await _controller!.takePicture();
        final location = await locationFuture;
        
        _playHardwareFeedback();

        if (_autoSaveToGallery) {
          debugPrint("Auto-saving to gallery: ${image.path}");
        }

        if (!mounted) return;
        setState(() => _lastCapturedPath = image.path);
        
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewScreen(
              imagePath: image.path, 
              filterName: _filterName,
              location: location,
            ),
          ),
        );
        await _loadData();
      }
    } catch (e) {
      debugPrint("Error taking picture: $e");
    } finally {
      if (mounted) setState(() => _isCapturingPhoto = false);
    }
  }

  void _playHardwareFeedback() {
    if (_hapticEnabled) {
      switch (_hapticIntensity) {
        case 'Soft': HapticFeedback.lightImpact(); break;
        case 'Sharp': HapticFeedback.vibrate(); break;
        default: HapticFeedback.heavyImpact(); break;
      }
    }
    if (_shutterSound) SystemSound.play(SystemSoundType.click);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Viewfinder
          Positioned.fill(
            child: _useSystemCamera 
              ? _buildSystemCameraPlaceholder(colorScheme)
              : _buildAutofitCameraView(size),
          ),

          // Glassmorphic Top Controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildGlassTopBar(colorScheme),
          ),

          // Bottom Pro Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildProBottomControls(colorScheme, size),
          ),
        ],
      ),
    );
  }

  Widget _buildAutofitCameraView(Size size) {
    if (!_isCameraInitialized || _controller == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    var cameraValue = _controller!.value;
    var scale = size.aspectRatio * cameraValue.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return ColorFiltered(
      colorFilter: _currentFilter,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapUp: (details) => _onTapToFocus(details, constraints),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Transform.scale(
                  scale: scale,
                  child: Center(
                    child: CameraPreview(_controller!),
                  ),
                ),
                if (_showGrid)
                  const CustomPaint(painter: GridPainter()),
                const CustomPaint(painter: ViewfinderCornersPainter()),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildGlassTopBar(ColorScheme colorScheme) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            border: const Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ProIconButton(
                icon: _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                onPressed: () => setState(() => _showGrid = !_showGrid),
                isActive: _showGrid,
                isDisabled: _useSystemCamera,
              ),
              _buildPhotoCounter(colorScheme),
              _ProIconButton(
                icon: _getFlashIcon(),
                onPressed: _cycleFlashMode,
                isActive: _flashMode != FlashMode.off,
                activeColor: Colors.yellow,
                isDisabled: _useSystemCamera,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off: return Icons.flash_off_rounded;
      case FlashMode.auto: return Icons.flash_auto_rounded;
      case FlashMode.always: return Icons.flash_on_rounded;
      case FlashMode.torch: return Icons.flashlight_on_rounded;
    }
  }

  Widget _buildPhotoCounter(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.camera_rounded, size: 14, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            "$_todaysPhotoCount / $_dailyLimit",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildProBottomControls(ColorScheme colorScheme, Size size) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildGalleryButton(colorScheme),
          _buildCaptureShutter(colorScheme),
          _buildFlipButton(colorScheme),
        ],
      ),
    );
  }

  Widget _buildGalleryButton(ColorScheme colorScheme) {
    return InkWell(
      onTap: () {
        if (_lastCapturedPath != null) {
          if (_hapticEnabled) HapticFeedback.lightImpact();
          Navigator.push(context, MaterialPageRoute(builder: (context) => PreviewScreen(imagePath: _lastCapturedPath!, filterName: _filterName)));
        }
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: _lastCapturedPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.file(
                  io.File(_lastCapturedPath!), 
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              )
            : const Icon(Icons.photo_library_outlined, color: Colors.white70, size: 24),
      ),
    );
  }

  Widget _buildCaptureShutter(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: _takePicture,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        padding: const EdgeInsets.all(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.4),
                blurRadius: _isCapturingPhoto ? 0 : 20,
                spreadRadius: _isCapturingPhoto ? 0 : 2,
              )
            ],
          ),
          child: _isCapturingPhoto
              ? Center(child: CircularProgressIndicator(strokeWidth: 3, color: colorScheme.primary))
              : Icon(Icons.camera_alt_rounded, color: colorScheme.primary, size: 36),
        ),
      ),
    );
  }

  Widget _buildFlipButton(ColorScheme colorScheme) {
    return _ProIconButton(
      icon: Icons.flip_camera_ios_rounded,
      onPressed: _toggleCamera,
      isDisabled: _useSystemCamera,
    );
  }


  Widget _buildSystemCameraPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_enhance_rounded, size: 80, color: colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 24),
            const Text("SYSTEM CAMERA ACTIVE", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 8),
            const Text("MAXIMIZING AI & HARDWARE QUALITY", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: _takePicture,
              icon: const Icon(Icons.camera_alt),
              label: const Text("OPEN CAMERA"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final bool isDisabled;
  final Color? activeColor;

  const _ProIconButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.isDisabled = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isActive ? (activeColor ?? Colors.white).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: isActive ? (activeColor ?? Colors.white) : Colors.white24, width: 1.5),
          ),
          child: Icon(icon, color: isDisabled ? Colors.white24 : (isActive ? (activeColor ?? Colors.white) : Colors.white70), size: 24),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  const GridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(2 * size.width / 3, 0), Offset(2 * size.width / 3, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, 2 * size.height / 3), Offset(size.width, 2 * size.height / 3), paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ViewfinderCornersPainter extends CustomPainter {
  const ViewfinderCornersPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
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
