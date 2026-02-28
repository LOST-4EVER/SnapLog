import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'entry_detail_screen.dart';
import 'quiz_screen.dart';
import 'full_screen_viewer.dart';
import '../services/settings_service.dart';

ColorFilter _filterForName(String name) {
  switch (name) {
    case 'B&W':
      return const ColorFilter.matrix([
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0,      0,      0,      1, 0,
      ]);
    case 'Sepia':
      return const ColorFilter.matrix([
        0.393, 0.769, 0.189, 0, 0,
        0.349, 0.686, 0.168, 0, 0,
        0.272, 0.534, 0.131, 0, 0,
        0,     0,     0,     1, 0,
      ]);
    case 'Cool':
      return const ColorFilter.matrix([
        1, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1.2, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    case 'Warm':
      return const ColorFilter.matrix([
        1.2, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 0.8, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    case 'Normal':
    default:
      return const ColorFilter.mode(Colors.transparent, BlendMode.dst);
  }
}

class PreviewScreen extends StatefulWidget {
  final String imagePath;
  final String filterName;
  final String? location;

  const PreviewScreen({
    super.key,
    required this.imagePath,
    required this.filterName,
    this.location,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  int _dailyLimit = 3;
  bool _hapticEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService().getSettings();
    if (mounted) {
      setState(() {
        _dailyLimit = settings['dailyLimit'] ?? 3;
        _hapticEnabled = settings['hapticFeedback'] ?? true;
      });
    }
  }

  Future<void> _handleRetry() async {
    if (_hapticEnabled) HapticFeedback.mediumImpact();
    
    if (_dailyLimit == 1) {
      final bool? passedQuiz = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QuizScreen()),
      );
      if (passedQuiz == true && mounted) {
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _shareImage() async {
    if (_hapticEnabled) HapticFeedback.lightImpact();
    await Share.shareXFiles([XFile(widget.imagePath)], text: 'Check out my SnapLog!');
  }

  void _showFullScreen() {
    if (_hapticEnabled) HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenViewer(
          imagePath: widget.imagePath,
          heroTag: 'preview_image',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onDoubleTap: _showFullScreen,
            child: Hero(
              tag: 'preview_image',
              child: ColorFiltered(
                colorFilter: _filterForName(widget.filterName),
                child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
              ),
            ),
          ),
          
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white, size: 28),
                      onPressed: _shareImage,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.38),
                        shape: const CircleBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _handleRetry,
                      icon: const Icon(Icons.replay_outlined),
                      label: const Text("Retry"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (_hapticEnabled) HapticFeedback.lightImpact();
                          Navigator.of(context).pushReplacement(MaterialPageRoute(
                            builder: (context) => EntryDetailScreen(
                              imagePaths: [widget.imagePath],
                              filterName: widget.filterName,
                              location: widget.location,
                            ),
                          ));
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text("Use Photo"),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
