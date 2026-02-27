import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'entry_detail_screen.dart';

class PreviewScreen extends StatelessWidget {
  final String imagePath;
  final String filterName;

  const PreviewScreen({
    super.key,
    required this.imagePath,
    required this.filterName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(imagePath), fit: BoxFit.cover),
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
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop(); // Discard and go back
                      },
                      icon: const Icon(Icons.replay_outlined),
                      label: const Text("Retry"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                              imagePath: imagePath,
                              filterName: filterName,
                            ),
                          ));
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text("Use this Photo"),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
