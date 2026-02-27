import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'entry_detail_screen.dart';
import 'quiz_screen.dart';
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

  const PreviewScreen({
    super.key,
    required this.imagePath,
    required this.filterName,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  int _dailyLimit = 3;

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
      });
    }
  }

  Future<void> _handleRetry() async {
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
    await Share.shareXFiles([XFile(widget.imagePath)], text: 'Check out my SnapLog!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The photo preview is already full screen (Image.file with fit: BoxFit.cover)
          ColorFiltered(
            colorFilter: _filterForName(widget.filterName),
            child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
          ),
          
          // Top Bar for Share
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
                        backgroundColor: Colors.black38,
                        shape: const CircleBorder(),
                      ),
                    ),
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
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pushReplacement(MaterialPageRoute(
                            builder: (context) => EntryDetailScreen(
                              imagePath: widget.imagePath,
                              filterName: widget.filterName,
                            ),
                          ));
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text("Use Photo"),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
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
