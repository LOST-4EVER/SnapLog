import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';
import '../services/database_helper.dart';
import 'preview_screen.dart';

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
  
  ColorFilter _currentFilter = const ColorFilter.mode(Colors.transparent, BlendMode.dst);
  String _filterName = "Normal";
  
  int _todaysPhotoCount = 0;
  int _dailyLimit = 3;
  String _imageQuality = 'High';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData().then((_) {
      _initializeCamera(widget.cameras[_selectedCameraIndex]);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera(cameraController.description);
    }
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    ResolutionPreset preset;
    switch (_imageQuality) {
      case 'Low':
        preset = ResolutionPreset.low;
        break;
      case 'Medium':
        preset = ResolutionPreset.medium;
        break;
      case 'High':
      default:
        preset = ResolutionPreset.max;
        break;
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

  Future<void> _takePicture() async {
    if (_todaysPhotoCount >= _dailyLimit) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Daily limit reached ($_dailyLimit photos).'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final image = await _controller!.takePicture();
      HapticFeedback.mediumImpact();
      
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewScreen(
            imagePath: image.path,
            filterName: _filterName,
          ),
        ),
      ).then((_) => _loadData());
    } catch (e) {
      debugPrint("Error taking picture: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cameras.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("No cameras detected")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview filling the screen
          _isCameraInitialized && _controller != null
              ? Center(
                  child: AspectRatio(
                    aspectRatio: 1 / _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  ),
                )
              : const Center(child: CircularProgressIndicator(color: Colors.white)),
          
          // Apply Filter Overlay
          if (_filterName != "Normal")
            Positioned.fill(
              child: IgnorePointer(
                child: ColorFiltered(
                  colorFilter: _currentFilter,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

          // Top Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleIconButton(
                    icon: _flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
                    onPressed: () {
                      setState(() {
                        _flashMode = _flashMode == FlashMode.off ? FlashMode.always : FlashMode.off;
                        _controller?.setFlashMode(_flashMode);
                      });
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library, size: 16, color: _todaysPhotoCount >= _dailyLimit ? Colors.orange : Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          '$_todaysPhotoCount / $_dailyLimit',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  _CircleIconButton(
                    icon: Icons.cached,
                    onPressed: _toggleCamera,
                  ),
                ],
              ),
            ),
          ),

          // Bottom UI
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 40, top: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Filter selection
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _filters.length,
                      itemBuilder: (context, index) {
                        String name = _filters.keys.elementAt(index);
                        bool isSelected = _filterName == name;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _filterName = name;
                                _currentFilter = _filters[name]!;
                              });
                              HapticFeedback.selectionClick();
                            },
                            child: Chip(
                              label: Text(name),
                              backgroundColor: isSelected ? Colors.white : Colors.white10,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Zoom & Capture
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Zoom display
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${_currentZoom.toStringAsFixed(1)}x',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      // Capture Button
                      GestureDetector(
                        onTap: _takePicture,
                        child: Container(
                          height: 84,
                          width: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              height: 68,
                              width: 68,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: _todaysPhotoCount >= _dailyLimit 
                                ? const Icon(Icons.lock, color: Colors.black)
                                : null,
                            ),
                          ),
                        ),
                      ),
                      
                      // Selfie shortcut
                      SizedBox(
                        width: 60,
                        child: IconButton(
                          icon: const Icon(Icons.camera_front, color: Colors.white70),
                          onPressed: _toggleCamera,
                        ),
                      ),
                    ],
                  ),
                  
                  // Zoom Slider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20),
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                        overlayColor: Colors.white.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: _currentZoom,
                        min: _minZoom,
                        max: _maxZoom,
                        onChanged: (value) {
                          setState(() {
                            _currentZoom = value;
                            _controller?.setZoomLevel(value);
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CircleIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        onPressed: onPressed,
      ),
    );
  }
}
