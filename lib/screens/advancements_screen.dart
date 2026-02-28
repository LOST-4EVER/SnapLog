import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/achievement_service.dart';
import '../services/settings_service.dart';

class AdvancementsScreen extends StatefulWidget {
  const AdvancementsScreen({super.key});

  @override
  State<AdvancementsScreen> createState() => _AdvancementsScreenState();
}

class _AdvancementsScreenState extends State<AdvancementsScreen> {
  late Future<List<Achievement>> _achievementsFuture;
  bool _hapticEnabled = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadSettings();
  }

  void _refresh() {
    setState(() {
      _achievementsFuture = AchievementService().getAchievements();
    });
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: const Text("Achievements", style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            expandedHeight: 150,
            backgroundColor: colorScheme.surface,
          ),
          FutureBuilder<List<Achievement>>(
            future: _achievementsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text("No achievements yet")),
                );
              }

              final achievements = snapshot.data!;
              final unlockedCount = achievements.where((a) => a.isUnlocked).length;

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _buildProgressHero(unlockedCount, achievements.length, colorScheme),
                      ),
                    ),
                    SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.8,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final a = achievements[index];
                          return _AchievementBadge(
                            achievement: a, 
                            onTap: () => _showAchievementDetails(a),
                          );
                        },
                        childCount: achievements.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHero(int unlocked, int total, ColorScheme colorScheme) {
    final progress = unlocked / total;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Your Legacy",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                "${(progress * 100).toInt()}%",
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Text(
            "$unlocked of $total challenges conquered",
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
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
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isUnlocked 
                    ? colorScheme.primaryContainer.withValues(alpha: 0.4) 
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isUnlocked ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Center(
                child: Opacity(
                  opacity: isUnlocked ? 1.0 : 0.2,
                  child: Text(
                    achievement.icon,
                    style: const TextStyle(
                      fontSize: 32,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            achievement.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
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
          Text(achievement.icon, style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 16),
          Text(
            achievement.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            achievement.description,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
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
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: isUnlocked ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                foregroundColor: isUnlocked ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
              ),
              child: Text(isUnlocked ? "CHALLENGE COMPLETE" : "KEEP PUSHING"),
            ),
          ),
        ],
      ),
    );
  }
}
