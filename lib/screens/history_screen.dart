import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/photo_entry.dart';
import '../services/database_helper.dart';

enum ViewMode { day, month, year }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<PhotoEntry>> _entriesFuture;
  ViewMode _viewMode = ViewMode.day;

  @override
  void initState() {
    super.initState();
    _refreshEntries();
  }

  void _refreshEntries() {
    setState(() {
      _entriesFuture = DatabaseHelper().getEntries();
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
            icon: const Icon(Icons.grid_view),
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
      body: FutureBuilder<List<PhotoEntry>>(
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
          return RefreshIndicator(
            onRefresh: () async => _refreshEntries(),
            child: _buildGallery(entries),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_motion,
            size: 80,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 24),
          Text(
            "Your journal is empty",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            "Capture moments to see them here",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallery(List<PhotoEntry> entries) {
    switch (_viewMode) {
      case ViewMode.day:
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: entries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 24),
          itemBuilder: (context, index) => _EntryCard(entry: entries[index]),
        );
      case ViewMode.month:
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) => _GridItem(entry: entries[index]),
        );
      case ViewMode.year:
        return GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) => _GridItem(entry: entries[index], showDetails: false),
        );
    }
  }
}

class _EntryCard extends StatelessWidget {
  final PhotoEntry entry;
  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
      ),
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.file(
                  File(entry.imagePath),
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      entry.filter,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Text(entry.mood, style: const TextStyle(fontSize: 40)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('MMMM dd, yyyy').format(entry.timestamp),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat('hh:mm a').format(entry.timestamp),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  if (entry.caption.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(entry.caption, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EntryDetailModal(entry: entry),
    );
  }
}

class _GridItem extends StatelessWidget {
  final PhotoEntry entry;
  final bool showDetails;
  const _GridItem({required this.entry, this.showDetails = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _EntryDetailModal(entry: entry),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(entry.imagePath), fit: BoxFit.cover),
            if (showDetails)
              Positioned(
                bottom: 4,
                right: 4,
                child: Text(entry.mood, style: const TextStyle(fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntryDetailModal extends StatelessWidget {
  final PhotoEntry entry;
  const _EntryDetailModal({required this.entry});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.file(File(entry.imagePath), fit: BoxFit.cover),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.mood, style: const TextStyle(fontSize: 48)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('MMMM dd, yyyy').format(entry.timestamp),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(DateFormat('EEEE, hh:mm a').format(entry.timestamp)),
                  ],
                ),
              ],
            ),
            const Divider(height: 48),
            Text(
              "Caption",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              entry.caption.isNotEmpty ? entry.caption : "No caption added.",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                const Icon(Icons.filter_vintage_outlined, size: 16),
                const SizedBox(width: 8),
                Text("Applied Filter: ${entry.filter}", style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
