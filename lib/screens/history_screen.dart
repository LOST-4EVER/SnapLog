import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/photo_entry.dart';
import '../services/database_helper.dart';
import '../services/entries_notifier.dart';
import '../services/settings_service.dart';
import '../services/insights_service.dart';
import '../widgets/entry_widgets.dart';

enum ViewMode { day, month, year }

class HistoryScreen extends StatefulWidget {
  final VoidCallback? onCaptureRequested;
  const HistoryScreen({super.key, this.onCaptureRequested});

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
                  child: HistoryLoadingSkeleton(),
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
          const Text("Mood Trends", style: TextStyle(fontWeight: FontWeight.bold)),
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
                        dotData: const FlDotData(show: false),
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
          child: OnThisDayCard(entries: snapshot.data!),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_motion, size: 64, color: colorScheme.primary),
          ),
          const SizedBox(height: 24),
          const Text("Your journal is empty", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text("Capture moments to see them here", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16)),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () {
               if (_hapticEnabled) HapticFeedback.mediumImpact();
               widget.onCaptureRequested?.call();
            },
            icon: const Icon(Icons.photo_camera),
            label: const Text("Capture Your First Moment"),
          ),
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
            itemBuilder: (context, index) => EntryCard(entry: entries[index], onRefresh: _refreshEntries, hapticEnabled: _hapticEnabled),
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
            itemBuilder: (context, index) => GridItem(entry: entries[index], onRefresh: _refreshEntries, hapticEnabled: _hapticEnabled),
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
            itemBuilder: (context, index) => GridItem(entry: entries[index], showDetails: false, onRefresh: _refreshEntries, hapticEnabled: _hapticEnabled),
          ),
        );
    }
  }
}
