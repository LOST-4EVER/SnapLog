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
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart);
    _notifier = EntriesNotifier();
    _notifierListener = () => _refreshEntries();
    _notifier.addListener(_notifierListener);
    _refreshEntries();
    _loadSettings();
  }

  late final VoidCallback _notifierListener;

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
    _notifier.removeListener(_notifierListener);
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
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.medium(
            title: const Text("Journal Archive"),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(_showInsights ? Icons.insights_rounded : Icons.insights_outlined),
                onPressed: () {
                  if (_hapticEnabled) HapticFeedback.selectionClick();
                  setState(() => _showInsights = !_showInsights);
                },
              ),
              PopupMenuButton<ViewMode>(
                icon: const Icon(Icons.tune_rounded),
                onSelected: (ViewMode mode) {
                  if (_hapticEnabled) HapticFeedback.selectionClick();
                  setState(() => _viewMode = mode);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: ViewMode.day, child: Text("Memoir View")),
                  const PopupMenuItem(value: ViewMode.month, child: Text("Monthly Mosaic")),
                  const PopupMenuItem(value: ViewMode.year, child: Text("Yearly Glimpse")),
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
                hintText: "Search your timeline...",
                leading: const Icon(Icons.search_rounded),
                trailing: [
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        if (_hapticEnabled) HapticFeedback.lightImpact();
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    ),
                ],
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)),
                padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20)),
                shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
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
                        Icon(Icons.search_off_rounded, size: 80, color: colorScheme.outlineVariant),
                        const SizedBox(height: 24),
                        Text("No fragments match your query.", style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                );
              }

              return _buildGallery(filteredEntries);
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildMoodInsights() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Emotional Pulse", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              Icon(Icons.auto_awesome_rounded, size: 16, color: colorScheme.primary.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: FutureBuilder<List<MoodData>>(
              future: _moodTrendsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("Continuing the journey..."));
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
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(data[value.toInt()].date, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                              );
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
                        curveSmoothness: 0.4,
                        color: colorScheme.primary,
                        barWidth: 6,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 3,
                            strokeColor: colorScheme.primary,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [colorScheme.primary.withValues(alpha: 0.2), colorScheme.primary.withValues(alpha: 0.0)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
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
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(_fadeAnimation),
            child: OnThisDayCard(entries: snapshot.data!),
          ),
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
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [colorScheme.primaryContainer, colorScheme.surface]),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 80, color: colorScheme.primary),
          ),
          const SizedBox(height: 32),
          const Text("The First Page is Blank", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 12),
          Text("Begin your story today.", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: () {
               if (_hapticEnabled) HapticFeedback.mediumImpact();
               widget.onCaptureRequested?.call();
            },
            icon: const Icon(Icons.photo_camera_rounded),
            label: const Text("CAPTURE A MOMENT"),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallery(List<PhotoEntry> entries) {
    return SliverToBoxAdapter(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: _viewMode == ViewMode.day 
          ? _buildMemoirList(entries) 
          : _buildMosaicGrid(entries, _viewMode == ViewMode.month ? 3 : 5),
      ),
    );
  }

  Widget _buildMemoirList(List<PhotoEntry> entries) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      separatorBuilder: (context, index) => const SizedBox(height: 24),
      itemCount: entries.length,
      itemBuilder: (context, index) => EntryCard(entry: entries[index], onRefresh: _refreshEntries, hapticEnabled: _hapticEnabled),
    );
  }

  Widget _buildMosaicGrid(List<PhotoEntry> entries, int crossAxisCount) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount, 
        crossAxisSpacing: 12, 
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => GridItem(
        entry: entries[index], 
        showDetails: crossAxisCount < 5,
        onRefresh: _refreshEntries, 
        hapticEnabled: _hapticEnabled
      ),
    );
  }
}
