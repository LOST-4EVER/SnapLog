import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'entry_detail_screen.dart';
import 'quiz_screen.dart';
import '../services/settings_service.dart';

// Helper to convert filter name to ColorFilter (kept small set matched to CameraScreen)
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
    // If daily limit is 1, show the quiz before allowing retry.
    if (_dailyLimit == 1) {
      final bool? passedQuiz = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QuizScreen()),
      );
      if (passedQuiz == true && mounted) {
        Navigator.of(context).pop(); // Passed quiz, allow retry
      }
    } else {
      Navigator.of(context).pop(); // No limit, allow retry
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColorFiltered(
            colorFilter: _filterForName(widget.filterName),
            child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black, Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    height: 60,
                    child: OutlinedButton.icon(
                      onPressed: _handleRetry,
                      icon: const Icon(Icons.replay_outlined),
                      label: const Text("Retry"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 60,
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
                        label: const Text("Use this Photo"),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
