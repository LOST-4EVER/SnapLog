import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/photo_entry.dart';
import '../services/database_helper.dart';
import '../services/entries_notifier.dart';

class EntryDetailScreen extends StatefulWidget {
  final String imagePath;
  final String filterName;

  const EntryDetailScreen({
    super.key,
    required this.imagePath,
    required this.filterName,
  });

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  final TextEditingController _captionController = TextEditingController();
  String _selectedMood = "😊";
  final List<String> _moods = ["😊", "📸", "🌟", "😴", "🍕", "🌈", "☕", "🎉", "💼", "💪", "🧗", "🎨"];
  bool _isSaving = false;

  Future<void> _saveEntry() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // 1. Move image to permanent storage
      final directory = await getApplicationDocumentsDirectory();
      final fileName = path.basename(widget.imagePath);
      final permanentPath = path.join(directory.path, fileName);
      
      await File(widget.imagePath).copy(permanentPath);

      // 2. Create and save entry
      final entry = PhotoEntry(
        imagePath: permanentPath,
        caption: _captionController.text,
        mood: _selectedMood,
        filter: widget.filterName,
        timestamp: DateTime.now(),
      );

      await DatabaseHelper().insertEntry(entry);
      // Notify listeners that a new entry was added
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Journal Entry"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Hero(
                tag: widget.imagePath,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.file(
                    File(widget.imagePath),
                    height: 400,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Capturing the moment",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _captionController,
                    decoration: InputDecoration(
                      hintText: "What's on your mind?",
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.notes),
                    ),
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  Text(
                    "Select your mood",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 70,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _moods.length,
                      itemBuilder: (context, index) {
                        final mood = _moods[index];
                        final isSelected = _selectedMood == mood;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedMood = mood);
                            HapticFeedback.selectionClick();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 12),
                            width: 60,
                            decoration: BoxDecoration(
                              color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? colorScheme.primary : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(mood, style: const TextStyle(fontSize: 32)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveEntry,
                      icon: _isSaving 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check),
                      label: Text(_isSaving ? "Saving..." : "Complete Entry"),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
