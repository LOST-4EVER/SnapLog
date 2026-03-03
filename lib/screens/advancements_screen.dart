import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/achievement_service.dart';
import '../services/settings_service.dart';
import '../services/entries_notifier.dart';

class AdvancementsScreen extends StatefulWidget {
  const AdvancementsScreen({super.key});

  @override
  State<AdvancementsScreen> createState() => _AdvancementsScreenState();
}

class _AdvancementsScreenState extends State<AdvancementsScreen> with SingleTickerProviderStateMixin {
  late Future<List<Achievement>> _achievementsFuture;
  late TabController _tabController;
  bool _hapticEnabled = true;
  late final EntriesNotifier _notifier;
  late final VoidCallback _notifierListener;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _notifier = EntriesNotifier();
    _notifierListener = () => _refresh();
    _notifier.addListener(_notifierListener);
    
    _refresh();
    _loadSettings();
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _achievementsFuture = AchievementService().getAchievements();
      });
    }
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
    _tabController.dispose();
    _notifier.removeListener(_notifierListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar.large(
            title: const Text("Legacy & Badges"),
            centerTitle: true,
            pinned: true,
            expandedHeight: 180,
            bottom: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: "Progress"),
                Tab(text: "Gallery"),
              ],
            ),
          ),
        ],
        body: FutureBuilder<List<Achievement>>(
          future: _achievementsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("No achievements data available"));
            }

            final achievements = snapshot.data!;
            final unlocked = achievements.where((a) => a.isUnlocked).toList();
            final locked = achievements.where((a) => !a.isUnlocked).toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _buildProgressTab(unlocked, locked, achievements.length, colorScheme),
                _buildGalleryTab(achievements, colorScheme),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressTab(List<Achievement> unlocked, List<Achievement> locked, int total, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildStatsCard(unlocked.length, total, colorScheme),
        const SizedBox(height: 32),
        const Text("NEXT MILESTONES", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey)),
        const SizedBox(height: 16),
        ...locked.take(5).map((a) => _buildMilestoneTile(a, colorScheme)),
        if (locked.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text("🏆 You've conquered every challenge!", style: TextStyle(fontWeight: FontWeight.bold)),
          )),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildGalleryTab(List<Achievement> all, ColorScheme colorScheme) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.8,
      ),
      itemCount: all.length,
      itemBuilder: (context, index) {
        final a = all[index];
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 600 + (index % 6 * 100)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: _AchievementBadge(
            achievement: a,
            onTap: () => _showAchievementDetails(a),
          ),
        );
      },
    );
  }

  Widget _buildStatsCard(int unlocked, int total, ColorScheme colorScheme) {
    final progress = unlocked / total;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Completion", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  Text("${(progress * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.emoji_events, color: Colors.white, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white24,
            color: Colors.white,
            minHeight: 12,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 16),
          Text("$unlocked of $total badges earned", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMilestoneTile(Achievement a, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
      child: ListTile(
        onTap: () => _showAchievementDetails(a),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Text(a.icon, style: const TextStyle(fontSize: 28)),
        title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.description, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: a.progress,
                minHeight: 4,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
        trailing: a.stat.isNotEmpty ? Text(a.stat, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)) : null,
      ),
    );
  }

  void _showAchievementDetails(Achievement a) {
    if (_hapticEnabled) HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AchievementDetailSheet(achievement: a),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback onTap;

  const _AchievementBadge({required this.achievement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUnlocked = achievement.isUnlocked;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: isUnlocked 
                    ? colorScheme.primaryContainer.withValues(alpha: 0.5) 
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isUnlocked ? colorScheme.primary : Colors.transparent,
                  width: 2,
                ),
                boxShadow: isUnlocked ? [
                  BoxShadow(color: colorScheme.primary.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))
                ] : null,
              ),
              child: Center(
                child: ColorFiltered(
                  colorFilter: isUnlocked 
                      ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                      : const ColorFilter.matrix([
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0,      0,      0,      1, 0,
                        ]),
                  child: Text(achievement.icon, style: const TextStyle(fontSize: 36)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isUnlocked ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementDetailSheet extends StatelessWidget {
  final Achievement achievement;
  const _AchievementDetailSheet({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUnlocked = achievement.isUnlocked;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 32),
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isUnlocked ? colorScheme.primaryContainer.withValues(alpha: 0.3) : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Text(achievement.icon, style: const TextStyle(fontSize: 80)),
          ),
          const SizedBox(height: 24),
          Text(
            achievement.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            achievement.description,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 32),
          if (achievement.stat.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                achievement.stat,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: isUnlocked ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                foregroundColor: isUnlocked ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(isUnlocked ? "CHALLENGE COMPLETE" : "KEEP PUSHING"),
            ),
          ),
        ],
      ),
    );
  }
}
