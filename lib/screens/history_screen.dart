import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/photo_entry.dart';
import '../services/database_helper.dart';
import '../services/entries_notifier.dart';
import '../services/settings_service.dart';
import '../services/insights_service.dart';
import 'quiz_screen.dart';
import 'full_screen_viewer.dart';

enum ViewMode { day, month, year }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late Future<List<PhotoEntry>> _entriesFuture;
  late Future<List<PhotoEntry>> _onThisDayFuture;
  late Future<List<MoodData>> _moodTrendsFuture;
  ViewMode _viewMode = ViewMode.day;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late final EntriesNotifier _notifier;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _hapticEnabled = true;
  bool _showInsights = false;

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
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService().getSettings();
    if (mounted) {
      setState(() {
        _hapticEnabled = settings['hapticFeedback'] ?? true;
      });
    }
  }

  @override
  void dispose() {
    _notifier.removeListener(_refreshEntries);
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _refreshEntries() {
    if (!mounted) return;
    setState(() {
      _entriesFuture = DatabaseHelper().getEntries();
      _onThisDayFuture = DatabaseHelper().getOnThisDayEntries();
      _moodTrendsFuture = InsightsService().getMoodTrends();
    });
  }

  List<PhotoEntry> _filterEntries(List<PhotoEntry> entries) {
    if (_searchQuery.isEmpty) return entries;
    final query = _searchQuery.toLowerCase().trim();
    return entries.where((entry) {
      final captionMatch = entry.caption.toLowerCase().contains(query);
      final locationMatch = entry.location?.toLowerCase().contains(query) ?? false;
      final moodMatch = entry.mood.toLowerCase().contains(query);
      final filterMatch = entry.filter.toLowerCase().contains(query);
      return captionMatch || locationMatch || moodMatch || filterMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: const Text("Journal"),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(_showInsights ? Icons.bar_chart : Icons.bar_chart_outlined),
                onPressed: () {
                  if (_hapticEnabled) HapticFeedback.selectionClick();
                  setState(() => _showInsights = !_showInsights);
                },
              ),
              PopupMenuButton<ViewMode>(
                icon: const Icon(Icons.grid_view_outlined),
                onSelected: (ViewMode mode) {
                  if (_hapticEnabled) HapticFeedback.selectionClick();
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SearchBar(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                hintText: "Search captions, locations...",
                leading: const Icon(Icons.search),
                trailing: [
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        if (_hapticEnabled) HapticFeedback.lightImpact();
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    ),
                ],
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)),
                padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
                shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
            ),
          ),
          if (_showInsights && _searchQuery.isEmpty)
            SliverToBoxAdapter(child: _buildMoodInsights()),
          SliverToBoxAdapter(
            child: _searchQuery.isEmpty ? _buildOnThisDaySection() : const SizedBox.shrink(),
          ),
          FutureBuilder<List<PhotoEntry>>(
            future: _entriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: _HistoryLoadingSkeleton(),
                );
              } else if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(child: Text("Error: ${snapshot.error}")),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return SliverFillRemaining(
                  child: _buildEmptyState(),
                );
              }

              final filteredEntries = _filterEntries(snapshot.data!);
              
              if (filteredEntries.isEmpty && _searchQuery.isNotEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        const Text("No matches found for your search."),
                      ],
                    ),
                  ),
                );
              }

              return _buildGallery(filteredEntries);
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildMoodInsights() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Mood Trends", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: FutureBuilder<List<MoodData>>(
              future: _moodTrendsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("Not enough data for insights yet"));
                }
                final data = snapshot.data!;
                return LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < data.length) {
                              return Text(data[value.toInt()].date, style: const TextStyle(fontSize: 10));
                            }
                            return const Text("");
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.score)).toList(),
                        isCurved: true,
                        color: colorScheme.primary,
                        barWidth: 4,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 4,
                            color: colorScheme.primary,
                            strokeWidth: 2,
                            strokeColor: colorScheme.surface,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: colorScheme.primary.withValues(alpha: 0.1),
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

  Widget _buildOnThisDaySection() {
    return FutureBuilder<List<PhotoEntry>>(
      future: _onThisDayFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        if (_animationController.status == AnimationStatus.dismissed) {
          _animationController.forward();
        }
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
          const Text("Your journal is empty", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Text("Capture moments to see them here", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildGallery(List<PhotoEntry> entries) {
    switch (_viewMode) {
      case ViewMode.day:
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            separatorBuilder: (context, index) => const SizedBox(height: 20),
            itemCount: entries.length,
            itemBuilder: (context, index) => _EntryCard(entry: entries[index], onRefresh: _refreshEntries, hapticEnabled: _hapticEnabled),
          ),
        );
      case ViewMode.month:
        return SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, 
              crossAxisSpacing: 12, 
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) => _GridItem(entry: entries[index], onRefresh: _refreshEntries, hapticEnabled: _hapticEnabled),
          ),
        );
      case ViewMode.year:
        return SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5, 
              crossAxisSpacing: 8, 
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) => _GridItem(entry: entries[index], showDetails: false, onRefresh: _refreshEntries, hapticEnabled: _hapticEnabled),
          ),
        );
    }
  }
}

class _HistoryLoadingSkeleton extends StatelessWidget {
  const _HistoryLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemBuilder: (context, index) => Container(
        height: 300,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(32),
        ),
      ),
    );
  }
}

class _OnThisDayCard extends StatelessWidget {
  final List<PhotoEntry> entries;
  const _OnThisDayCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.7),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history, color: Colors.white, size: 18),
              ),
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
                      _GridItem(entry: entry, onRefresh: () {}, hapticEnabled: true),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
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
  final bool hapticEnabled;
  const _EntryCard({required this.entry, required this.onRefresh, required this.hapticEnabled});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 1),
      ),
      child: InkWell(
        onTap: () {
          if (hapticEnabled) HapticFeedback.lightImpact();
          _showDetails(context);
        },
        onDoubleTap: () => _showFullScreenImage(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if (entry.imagePaths.isNotEmpty)
                  Hero(
                    tag: 'history_image_${entry.id}',
                    child: Image.file(
                      File(entry.imagePaths[0]), 
                      height: 280, 
                      width: double.infinity, 
                      fit: BoxFit.cover,
                      cacheWidth: 800,
                    ),
                  ),
                Positioned(
                  top: 16, 
                  right: 16, 
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5), 
                      borderRadius: BorderRadius.circular(16),
                    ), 
                    child: Text(entry.filter, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                Positioned(
                  bottom: 12, 
                  left: 12, 
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Text(entry.mood, style: const TextStyle(fontSize: 28)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                    children: [
                      Text(DateFormat('MMM dd, yyyy').format(entry.timestamp), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), 
                      Text(DateFormat('hh:mm a').format(entry.timestamp), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                    ]
                  ),
                  if (entry.caption.isNotEmpty) ...[
                    const SizedBox(height: 8), 
                    Text(
                      entry.caption, 
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (entry.location != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Expanded(child: Text(entry.location!, style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w500))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context) {
    if (entry.imagePaths.isEmpty) return;
    if (hapticEnabled) HapticFeedback.mediumImpact();
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => FullScreenViewer(imagePath: entry.imagePaths[0], heroTag: 'history_image_${entry.id}'),
    ));
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (context) => _EntryDetailModal(entry: entry, onRefresh: onRefresh, hapticEnabled: hapticEnabled),
    );
  }
}

class _GridItem extends StatelessWidget {
  final PhotoEntry entry;
  final bool showDetails;
  final VoidCallback onRefresh;
  final bool hapticEnabled;
  const _GridItem({required this.entry, this.showDetails = true, required this.onRefresh, required this.hapticEnabled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (hapticEnabled) HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context, 
          isScrollControlled: true, 
          backgroundColor: Colors.transparent, 
          builder: (context) => _EntryDetailModal(entry: entry, onRefresh: onRefresh, hapticEnabled: hapticEnabled),
        );
      },
      onDoubleTap: () {
        if (hapticEnabled) HapticFeedback.mediumImpact();
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => FullScreenViewer(imagePath: entry.imagePaths[0], heroTag: 'grid_image_${entry.id}'),
        ));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand, 
          children: [
            if (entry.imagePaths.isNotEmpty) 
              Hero(
                tag: 'grid_image_${entry.id}',
                child: Image.file(File(entry.imagePaths[0]), fit: BoxFit.cover, cacheWidth: 300),
              ), 
            if (showDetails) 
              Positioned(
                bottom: 4, 
                right: 4, 
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: Text(entry.mood, style: const TextStyle(fontSize: 14)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntryDetailModal extends StatefulWidget {
  final PhotoEntry entry;
  final VoidCallback onRefresh;
  final bool hapticEnabled;
  const _EntryDetailModal({required this.entry, required this.onRefresh, required this.hapticEnabled});

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entry deleted permanently.")));
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Caption updated.")));
    if (widget.hapticEnabled) HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface, 
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
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
                    child: Image.file(File(widget.entry.imagePaths[0]), fit: BoxFit.cover, cacheWidth: 1000),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Text(widget.entry.mood, style: const TextStyle(fontSize: 40)),
                ), 
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end, 
                  children: [
                    Text(DateFormat('MMMM dd, yyyy').format(widget.entry.timestamp), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), 
                    Text(DateFormat('EEEE, hh:mm a').format(widget.entry.timestamp), style: TextStyle(color: colorScheme.onSurfaceVariant))
                  ]
                )
              ]
            ),
            const Divider(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("MY THOUGHTS", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, letterSpacing: 1.2, fontSize: 12)),
                IconButton.filledTonal(
                  icon: Icon(_isEditing ? Icons.check : Icons.edit_outlined, size: 18),
                  onPressed: () {
                    if (widget.hapticEnabled) HapticFeedback.selectionClick();
                    if (_isEditing) {
                      _saveCaption();
                    } else {
                      setState(() => _isEditing = true);
                    }
                  },
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
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                )
              : Text(
                  _captionController.text.isNotEmpty ? _captionController.text : "No caption added for this memory.", 
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6)
                ),
            const SizedBox(height: 32),
            _DetailChip(icon: Icons.filter_vintage_outlined, label: "Applied Filter", value: widget.entry.filter),
            if (widget.entry.location != null) ...[
              const SizedBox(height: 12),
              _DetailChip(icon: Icons.location_on_outlined, label: "Location", value: widget.entry.location!),
            ],
            
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sharePhoto,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text("Share"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _deletePhoto,
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text("Delete"),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
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

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
