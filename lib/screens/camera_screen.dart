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
  const CameraScreen({super.key, required this.cameras});

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
  double _exposureOffset = 0.0;
  double _minExposure = 0.0;
  double _maxExposure = 0.0;

  ColorFilter _currentFilter = const ColorFilter.mode(Colors.transparent, BlendMode.dst);
  String _filterName = "Normal";
  String? _lastCapturedPath;

  int _todaysPhotoCount = 0;
  int _dailyLimit = 3;
  String _imageQuality = 'High';
  bool _useSystemCamera = false;
  bool _hapticEnabled = true;
  
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
      if (mounted && !_useSystemCamera) {
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _isCameraInitialized = false;
      _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && !_useSystemCamera) {
      _initializeCamera(widget.cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    if (_initializeControllerFuture != null) {
      await _initializeControllerFuture;
    }

    ResolutionPreset preset;
    switch (_imageQuality) {
      case 'Low': preset = ResolutionPreset.medium; break;
      case 'Medium': preset = ResolutionPreset.high; break;
      case 'High': preset = ResolutionPreset.veryHigh; break;
      default: preset = ResolutionPreset.max; break;
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
      
      _minExposure = await controller.getMinExposureOffset();
      _maxExposure = await controller.getMaxExposureOffset();
      
      await controller.setExposureMode(ExposureMode.auto);
      await controller.setFocusMode(FocusMode.auto);
      
      await controller.setFlashMode(_flashMode);
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
        _currentFilter = _filters[_filterName]!;
        _useSystemCamera = settings['useSystemCamera'] ?? false;
        _hapticEnabled = settings['hapticFeedback'] ?? true;
      });

      if (oldUseSystemCamera && !_useSystemCamera) {
        _initializeCamera(widget.cameras[_selectedCameraIndex]);
      } else if (!oldUseSystemCamera && _useSystemCamera) {
        _controller?.dispose();
        _controller = null;
        _isCameraInitialized = false;
      }
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

  Future<void> _resetExposure() async {
    if (_controller == null) return;
    await _controller!.setExposureOffset(0.0);
    setState(() => _exposureOffset = 0.0);
    if (_hapticEnabled) HapticFeedback.lightImpact();
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
    if (_todaysPhotoCount >= _dailyLimit) {
      if (_hapticEnabled) HapticFeedback.vibrate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Daily limit reached.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    setState(() => _isCapturingPhoto = true);
    
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
            _initializeCamera(widget.cameras[_selectedCameraIndex]);
          }
          return;
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
        
        if (_hapticEnabled) HapticFeedback.mediumImpact();
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

  Future<void> _handleExposureChanged(double value) async {
    if (_controller == null) return;
    setState(() => _exposureOffset = value);
    await _controller!.setExposureOffset(value);
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
              : _buildCustomCameraView(colorScheme),
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

  Widget _buildGlassTopBar(ColorScheme colorScheme) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            border: const Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ProIconButton(
                icon: _flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
                onPressed: _cycleFlashMode,
                isActive: _flashMode != FlashMode.off,
                activeColor: Colors.yellow,
                isDisabled: _useSystemCamera,
              ),
              _buildPhotoCounter(colorScheme),
              _ProIconButton(
                icon: _showGrid ? Icons.grid_on : Icons.grid_off,
                onPressed: () => setState(() => _showGrid = !_showGrid),
                isActive: _showGrid,
                isDisabled: _useSystemCamera,
              ),
            ],
          ),
        ),
      ),
    );
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_useSystemCamera && _isCameraInitialized)
            _buildExposureSlider(),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Gallery Thumbnail
              _buildGalleryButton(colorScheme),

              // Capture Shutter
              _buildCaptureShutter(colorScheme),

              // Switch Camera
              _buildFlipButton(colorScheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExposureSlider() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 18),
                onPressed: _resetExposure,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.light_mode_outlined, color: Colors.white54, size: 16),
              Expanded(
                child: SliderTheme(
                  data: const SliderThemeData(
                    trackHeight: 2,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: Colors.yellow,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: _exposureOffset,
                    min: _minExposure,
                    max: _maxExposure,
                    onChanged: _handleExposureChanged,
                  ),
                ),
              ),
              const Icon(Icons.light_mode, color: Colors.yellow, size: 16),
            ],
          ),
        ),
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

  Widget _buildCustomCameraView(ColorScheme colorScheme) {
    return ColorFiltered(
      colorFilter: _currentFilter,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _isCameraInitialized && _controller != null
              ? CameraPreview(_controller!)
              : const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (_showGrid) const CustomPaint(painter: GridPainter()),
          const CustomPaint(painter: ViewfinderCornersPainter()),
        ],
      ),
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
