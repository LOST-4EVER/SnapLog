import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/photo_entry.dart';
import '../services/database_helper.dart';
import '../services/entries_notifier.dart';

class EntryDetailScreen extends StatefulWidget {
  final List<String> imagePaths;
  final String filterName;
  final String? location;

  const EntryDetailScreen({
    super.key,
    required this.imagePaths,
    required this.filterName,
    this.location,
  });

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  final TextEditingController _captionController = TextEditingController();
  String _selectedMood = "😊";
  final List<String> _moods = ["😊", "📸", "🌟", "😴", "🍕", "🌈", "☕", "🎉", "💼", "💪", "🧗", "🎨"];
  bool _isSaving = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _saveEntry() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final directory = await getApplicationDocumentsDirectory();
      List<String> permanentPaths = [];

      for (String tempPath in widget.imagePaths) {
        final fileName = "img_${DateTime.now().millisecondsSinceEpoch}_${permanentPaths.length}.jpg";
        final permanentPath = path.join(directory.path, fileName);
        
        // Professional Image Compression
        await FlutterImageCompress.compressAndGetFile(
          tempPath,
          permanentPath,
          quality: 85,
          format: CompressFormat.jpeg,
        );
        permanentPaths.add(permanentPath);

        // Cleanup temporary camera file
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }

      final entry = PhotoEntry(
        imagePaths: permanentPaths,
        caption: _captionController.text,
        mood: _selectedMood,
        filter: widget.filterName,
        timestamp: DateTime.now(),
        location: widget.location,
      );

      await DatabaseHelper().insertEntry(entry);
      EntriesNotifier().notifyEntryAdded();

      HapticFeedback.heavyImpact();

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving entry: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Journal Entry"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.imagePaths.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Hero(
                  tag: widget.imagePaths[0],
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.file(
                      File(widget.imagePaths[0]),
                      height: size.height * 0.45,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheHeight: 1000, // Optimization: Avoid loading full res into RAM
                    ),
                  ),
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Capturing the moment",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(widget.location!, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _captionController,
                    decoration: InputDecoration(
                      hintText: "What's on your mind?",
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.notes),
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    "Select your mood",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 75,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _moods.length,
                      itemBuilder: (context, index) {
                        final mood = _moods[index];
                        final isSelected = _selectedMood == mood;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedMood = mood);
                              HapticFeedback.selectionClick();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 65,
                              decoration: BoxDecoration(
                                color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? colorScheme.primary : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(mood, style: const TextStyle(fontSize: 32)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveEntry,
                      icon: _isSaving 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline),
                      label: Text(_isSaving ? "Optimizing & Saving..." : "Complete Entry"),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
