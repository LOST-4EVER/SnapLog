import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/photo_entry.dart';
import '../services/database_helper.dart';
import '../services/entries_notifier.dart';
import 'quiz_screen.dart';

enum ViewMode { day, month, year }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late Future<List<PhotoEntry>> _entriesFuture;
  late Future<List<PhotoEntry>> _onThisDayFuture;
  ViewMode _viewMode = ViewMode.day;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late final EntriesNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _notifier = EntriesNotifier();
    _notifier.addListener(_refreshEntries);
    _refreshEntries();
  }

  @override
  void dispose() {
    _notifier.removeListener(_refreshEntries);
    _animationController.dispose();
    super.dispose();
  }

  void _refreshEntries() {
    setState(() {
      _entriesFuture = DatabaseHelper().getEntries();
      _onThisDayFuture = DatabaseHelper().getOnThisDayEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Journal"),
        centerTitle: true,
        actions: [
          PopupMenuButton<ViewMode>(
            icon: const Icon(Icons.grid_view_outlined),
            onSelected: (ViewMode mode) {
              setState(() => _viewMode = mode);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: ViewMode.day, child: Text("Daily View")),
              const PopupMenuItem(value: ViewMode.month, child: Text("Monthly Grid")),
              const PopupMenuItem(value: ViewMode.year, child: Text("Yearly Grid")),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshEntries(),
        child: FutureBuilder<List<PhotoEntry>>(
          future: _entriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState();
            }

            final entries = snapshot.data!;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildOnThisDaySection(),
                ),
                _buildGallery(entries),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOnThisDaySection() {
    return FutureBuilder<List<PhotoEntry>>(
      future: _onThisDayFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        _animationController.forward();
        return FadeTransition(
          opacity: _fadeAnimation,
          child: _OnThisDayCard(entries: snapshot.data!),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_motion, size: 80, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 24),
          Text("Your journal is empty", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text("Capture moments to see them here", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildGallery(List<PhotoEntry> entries) {
    switch (_viewMode) {
      case ViewMode.day:
        return SliverList.separated(
          separatorBuilder: (context, index) => const SizedBox(height: 24),
          itemCount: entries.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _EntryCard(entry: entries[index], onRefresh: _refreshEntries),
          ),
        );
      case ViewMode.month:
        return SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: entries.length,
            itemBuilder: (context, index) => _GridItem(entry: entries[index], onRefresh: _refreshEntries),
          ),
        );
      case ViewMode.year:
        return SliverPadding(
          padding: const EdgeInsets.all(4),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 4, mainAxisSpacing: 4),
            itemCount: entries.length,
            itemBuilder: (context, index) => _GridItem(entry: entries[index], showDetails: false, onRefresh: _refreshEntries),
          ),
        );
    }
  }
}

class _OnThisDayCard extends StatelessWidget {
  final List<PhotoEntry> entries;
  const _OnThisDayCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [colorScheme.primaryContainer.withOpacity(0.5), colorScheme.surfaceVariant.withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colorScheme.primaryContainer, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_toggle_off, color: Colors.blueAccent),
              const SizedBox(width: 12),
              Text(
                "From the Archives",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    children: [
                      _GridItem(entry: entry, onRefresh: () {}),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            entry.timestamp.year.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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

class _EntryCard extends StatelessWidget {
  final PhotoEntry entry;
  final VoidCallback onRefresh;
  const _EntryCard({required this.entry, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
      ),
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.file(File(entry.imagePath), height: 300, width: double.infinity, fit: BoxFit.cover),
                Positioned(top: 16, right: 16, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)), child: Text(entry.filter, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                Positioned(bottom: 16, left: 16, child: Text(entry.mood, style: const TextStyle(fontSize: 40))),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(DateFormat('MMMM dd, yyyy').format(entry.timestamp), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), Text(DateFormat('hh:mm a').format(entry.timestamp), style: Theme.of(context).textTheme.bodySmall)]),
                  if (entry.caption.isNotEmpty) ...[const SizedBox(height: 12), Text(entry.caption, style: Theme.of(context).textTheme.bodyLarge)],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => _EntryDetailModal(entry: entry, onRefresh: onRefresh));
  }
}

class _GridItem extends StatelessWidget {
  final PhotoEntry entry;
  final bool showDetails;
  final VoidCallback onRefresh;
  const _GridItem({required this.entry, this.showDetails = true, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => _EntryDetailModal(entry: entry, onRefresh: onRefresh)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(fit: StackFit.expand, children: [Image.file(File(entry.imagePath), fit: BoxFit.cover), if (showDetails) Positioned(bottom: 4, right: 4, child: Text(entry.mood, style: const TextStyle(fontSize: 16)))]),
      ),
    );
  }
}

class _EntryDetailModal extends StatefulWidget {
  final PhotoEntry entry;
  final VoidCallback onRefresh;
  const _EntryDetailModal({required this.entry, required this.onRefresh});

  @override
  State<_EntryDetailModal> createState() => _EntryDetailModalState();
}

class _EntryDetailModalState extends State<_EntryDetailModal> {
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
    await Share.shareXFiles([XFile(widget.entry.imagePath)], text: widget.entry.caption.isNotEmpty ? widget.entry.caption : "Check out my SnapLog!");
  }

  Future<void> _deletePhoto(BuildContext context) async {
    final bool? passedQuiz = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QuizScreen(difficulty: QuizDifficulty.hard)),
    );

    if (passedQuiz == true) {
      if (widget.entry.id != null) {
        await DatabaseHelper().deleteEntry(widget.entry.id!);
        final file = File(widget.entry.imagePath);
        if (await file.exists()) {
          await file.delete();
        }
        if (mounted) {
          Navigator.pop(context); // Close modal
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entry deleted permanently.")));
          widget.onRefresh();
        }
      }
    }
  }

  Future<void> _saveCaption() async {
    final updatedEntry = PhotoEntry(
      id: widget.entry.id,
      imagePath: widget.entry.imagePath,
      caption: _captionController.text,
      mood: widget.entry.mood,
      filter: widget.entry.filter,
      timestamp: widget.entry.timestamp,
    );

    await DatabaseHelper().updateEntry(updatedEntry);
    setState(() => _isEditing = false);
    widget.onRefresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Caption updated.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            ClipRRect(borderRadius: BorderRadius.circular(32), child: Image.file(File(widget.entry.imagePath), fit: BoxFit.cover)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                Text(widget.entry.mood, style: const TextStyle(fontSize: 48)), 
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end, 
                  children: [
                    Text(DateFormat('MMMM dd, yyyy').format(widget.entry.timestamp), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), 
                    Text(DateFormat('EEEE, hh:mm a').format(widget.entry.timestamp))
                  ]
                )
              ]
            ),
            const Divider(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Caption", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, letterSpacing: 1.1)),
                IconButton(
                  icon: Icon(_isEditing ? Icons.check : Icons.edit_outlined, size: 20),
                  onPressed: _isEditing ? _saveCaption : () => setState(() => _isEditing = true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _isEditing 
              ? TextField(
                  controller: _captionController,
                  autofocus: true,
                  maxLines: null,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                )
              : Text(
                  _captionController.text.isNotEmpty ? _captionController.text : "No caption added.", 
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)
                ),
            const SizedBox(height: 32),
            Row(children: [const Icon(Icons.filter_vintage_outlined, size: 16), const SizedBox(width: 8), Text("Applied Filter: ${widget.entry.filter}", style: Theme.of(context).textTheme.bodySmall)]),
            
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sharePhoto,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text("Share"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _deletePhoto(context),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text("Delete"),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
