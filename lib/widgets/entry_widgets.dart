import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/photo_entry.dart';
import '../services/database_helper.dart';
import '../screens/quiz_screen.dart';
import '../screens/full_screen_viewer.dart';

class EntryCard extends StatefulWidget {
  final PhotoEntry entry;
  final VoidCallback onRefresh;
  final bool hapticEnabled;
  const EntryCard({super.key, required this.entry, required this.onRefresh, required this.hapticEnabled});

  @override
  State<EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<EntryCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onPanDown: (_) => setState(() => _scale = 0.98),
      onPanCancel: () => setState(() => _scale = 1.0),
      onPanEnd: (_) => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 1),
          ),
          child: InkWell(
            onTap: () {
              if (widget.hapticEnabled) HapticFeedback.lightImpact();
              _showDetails(context);
            },
            onDoubleTap: () => _showFullScreenImage(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    if (widget.entry.imagePaths.isNotEmpty)
                      Hero(
                        tag: 'history_image_${widget.entry.id}',
                        child: Image.file(
                          File(widget.entry.imagePaths[0]), 
                          height: 300, 
                          width: double.infinity, 
                          fit: BoxFit.cover,
                          cacheWidth: 1000,
                        ),
                      ),
                    Positioned(
                      top: 16, 
                      right: 16, 
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                            color: Colors.black.withValues(alpha: 0.3), 
                            child: Text(widget.entry.filter, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12, 
                      left: 12, 
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Text(widget.entry.mood, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                        children: [
                          Text(DateFormat('MMMM dd').format(widget.entry.timestamp), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)), 
                          Text(DateFormat('hh:mm a').format(widget.entry.timestamp), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                        ]
                      ),
                      if (widget.entry.caption.isNotEmpty) ...[
                        const SizedBox(height: 12), 
                        Text(
                          widget.entry.caption, 
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5, color: colorScheme.onSurface.withValues(alpha: 0.8)),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (widget.entry.location != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 16, color: colorScheme.primary),
                            const SizedBox(width: 6),
                            Expanded(child: Text(widget.entry.location!, style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context) {
    if (widget.entry.imagePaths.isEmpty) return;
    if (widget.hapticEnabled) HapticFeedback.mediumImpact();
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => FullScreenViewer(imagePath: widget.entry.imagePaths[0], heroTag: 'history_image_${widget.entry.id}'),
    ));
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (context) => EntryDetailModal(entry: widget.entry, onRefresh: widget.onRefresh, hapticEnabled: widget.hapticEnabled),
    );
  }
}

class GridItem extends StatefulWidget {
  final PhotoEntry entry;
  final bool showDetails;
  final VoidCallback onRefresh;
  final bool hapticEnabled;
  const GridItem({super.key, required this.entry, this.showDetails = true, required this.onRefresh, required this.hapticEnabled});

  @override
  State<GridItem> createState() => _GridItemState();
}

class _GridItemState extends State<GridItem> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (_) => setState(() => _scale = 0.95),
      onPanCancel: () => setState(() => _scale = 1.0),
      onPanEnd: (_) => setState(() => _scale = 1.0),
      onTap: () {
        if (widget.hapticEnabled) HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context, 
          isScrollControlled: true, 
          backgroundColor: Colors.transparent, 
          builder: (context) => EntryDetailModal(entry: widget.entry, onRefresh: widget.onRefresh, hapticEnabled: widget.hapticEnabled),
        );
      },
      onDoubleTap: () {
        if (widget.hapticEnabled) HapticFeedback.mediumImpact();
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => FullScreenViewer(imagePath: widget.entry.imagePaths[0], heroTag: 'grid_image_${widget.entry.id}'),
        ));
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand, 
            children: [
              if (widget.entry.imagePaths.isNotEmpty) 
                Hero(
                  tag: 'grid_image_${widget.entry.id}',
                  child: Image.file(File(widget.entry.imagePaths[0]), fit: BoxFit.cover, cacheWidth: 400),
                ), 
              if (widget.showDetails) 
                Positioned(
                  bottom: 8, 
                  right: 8, 
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        color: Colors.black26,
                        child: Text(widget.entry.mood, style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EntryDetailModal extends StatefulWidget {
  final PhotoEntry entry;
  final VoidCallback onRefresh;
  final bool hapticEnabled;
  const EntryDetailModal({super.key, required this.entry, required this.onRefresh, required this.hapticEnabled});

  @override
  State<EntryDetailModal> createState() => _EntryDetailModalState();
}

class _EntryDetailModalState extends State<EntryDetailModal> {
  late TextEditingController _captionController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.entry.caption);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _sharePhoto() async {
    if (widget.hapticEnabled) HapticFeedback.lightImpact();
    if (widget.entry.imagePaths.isNotEmpty) {
      await Share.shareXFiles([XFile(widget.entry.imagePaths[0])], text: widget.entry.caption.isNotEmpty ? widget.entry.caption : "Check out my SnapLog!");
    }
  }

  Future<void> _deletePhoto() async {
    final bool? passedQuiz = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QuizScreen(difficulty: QuizDifficulty.hard)),
    );

    if (passedQuiz == true) {
      if (widget.entry.id != null) {
        await DatabaseHelper().deleteEntry(widget.entry.id!);
        for (var path in widget.entry.imagePaths) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }
        if (!mounted) return;
        Navigator.pop(context); // Close modal
        widget.onRefresh();
        if (widget.hapticEnabled) HapticFeedback.heavyImpact();
      }
    }
  }

  Future<void> _saveCaption() async {
    final updatedEntry = PhotoEntry(
      id: widget.entry.id,
      imagePaths: widget.entry.imagePaths,
      caption: _captionController.text,
      mood: widget.entry.mood,
      filter: widget.entry.filter,
      timestamp: widget.entry.timestamp,
      location: widget.entry.location,
      tags: widget.entry.tags,
    );

    await DatabaseHelper().updateEntry(updatedEntry);
    if (!mounted) return;
    setState(() => _isEditing = false);
    widget.onRefresh();
    if (widget.hapticEnabled) HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface, 
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                children: [
                  if (widget.entry.imagePaths.isNotEmpty) 
                    GestureDetector(
                      onDoubleTap: () {
                        if (widget.hapticEnabled) HapticFeedback.mediumImpact();
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => FullScreenViewer(imagePath: widget.entry.imagePaths[0], heroTag: 'detail_image_${widget.entry.id}'),
                        ));
                      },
                      child: Hero(
                        tag: 'detail_image_${widget.entry.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32), 
                          child: Image.file(File(widget.entry.imagePaths[0]), fit: BoxFit.cover, cacheWidth: 1200),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Text(widget.entry.mood, style: const TextStyle(fontSize: 40)),
                      ), 
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Text(DateFormat('EEEE').format(widget.entry.timestamp), style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12)),
                            Text(DateFormat('MMMM dd, yyyy').format(widget.entry.timestamp), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), 
                            Text(DateFormat('hh:mm a').format(widget.entry.timestamp), style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500))
                          ]
                        ),
                      )
                    ]
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Divider(height: 1)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("MEMOIR", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 2, fontSize: 11)),
                      TextButton.icon(
                        onPressed: () {
                          if (widget.hapticEnabled) HapticFeedback.selectionClick();
                          if (_isEditing) {
                            _saveCaption();
                          } else {
                            setState(() => _isEditing = true);
                          }
                        },
                        icon: Icon(_isEditing ? Icons.check_circle : Icons.edit_note_rounded, size: 20),
                        label: Text(_isEditing ? "SAVE" : "EDIT"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isEditing 
                      ? TextField(
                          key: const ValueKey("editing"),
                          controller: _captionController,
                          autofocus: true,
                          maxLines: null,
                          style: const TextStyle(fontSize: 18, height: 1.6),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.all(24),
                            hintText: "Pen your thoughts...",
                          ),
                        )
                      : Container(
                          key: const ValueKey("display"),
                          width: double.infinity,
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            _captionController.text.isNotEmpty ? _captionController.text : "A moment frozen in time, awaiting your words.", 
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.8, color: colorScheme.onSurface.withValues(alpha: 0.9))
                          ),
                        ),
                  ),
                  const SizedBox(height: 48),
                  DetailChip(icon: Icons.auto_awesome_rounded, label: "Aesthetic", value: widget.entry.filter),
                  if (widget.entry.location != null) ...[
                    const SizedBox(height: 12),
                    DetailChip(icon: Icons.location_on_rounded, label: "Discovery", value: widget.entry.location!),
                  ],
                  
                  const SizedBox(height: 64),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _sharePhoto,
                          icon: const Icon(Icons.ios_share_rounded),
                          label: const Text("Export"),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _deletePhoto,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text("Discard"),
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.8),
                            foregroundColor: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnThisDayCard extends StatelessWidget {
  final List<PhotoEntry> entries;
  const OnThisDayCard({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.8),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colorScheme.primaryContainer.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.3), blurRadius: 10)]
                ),
                child: const Icon(Icons.history_toggle_off_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                "Timeless Echoes",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    children: [
                      GridItem(entry: entry, onRefresh: () {}, hapticEnabled: true),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              color: Colors.black45,
                              child: Text(
                                entry.timestamp.year.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryLoadingSkeleton extends StatelessWidget {
  const HistoryLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemBuilder: (context, index) => Container(
        height: 350,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(32),
        ),
      ),
    );
  }
}

class DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const DetailChip({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }
}
