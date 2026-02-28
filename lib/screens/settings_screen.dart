import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/database_helper.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../services/entries_notifier.dart';
import 'quiz_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final NotificationService _notificationService = NotificationService();
  
  int _dailyLimit = 3;
  String _imageQuality = 'High';
  String _defaultFilter = 'Normal';
  bool _remindersEnabled = false;
  bool _useSystemCamera = false;
  bool _mirrorFrontCamera = true;
  bool _hapticFeedback = true;
  bool _shutterSound = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  
  late Future<int> _streakFuture;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsService.getSettings();
      if (!mounted) return;
      
      final timeParts = (settings['reminderTime'] as String).split(':');
      
      setState(() {
        _dailyLimit = settings['dailyLimit'];
        _imageQuality = settings['imageQuality'];
        _defaultFilter = settings['defaultFilter'];
        _remindersEnabled = settings['remindersEnabled'];
        _useSystemCamera = settings['useSystemCamera'] ?? false;
        _mirrorFrontCamera = settings['mirrorFrontCamera'] ?? true;
        _hapticFeedback = settings['hapticFeedback'] ?? true;
        _shutterSound = settings['shutterSound'] ?? true;
        _reminderTime = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
        _streakFuture = DatabaseHelper().calculateStreak();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  void _notifyChange() {
    EntriesNotifier().notifyEntryAdded(); 
  }

  Future<void> _updateLimit(int delta) async {
    final newLimit = (_dailyLimit + delta).clamp(1, 10);
    if (newLimit != _dailyLimit) {
      final bool? passedQuiz = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QuizScreen(difficulty: QuizDifficulty.medium)),
      );

      if (!mounted) return;
      if (passedQuiz == true) {
        await _settingsService.setDailyLimit(newLimit);
        setState(() => _dailyLimit = newLimit);
        _notifyChange();
        if (_hapticFeedback) HapticFeedback.selectionClick();
      }
    }
  }

  Future<void> _toggleReminders(bool value) async {
    if (value) {
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Notification permission denied")),
          );
        }
        return;
      }
      await _notificationService.scheduleDailyReminder(_reminderTime);
    } else {
      await _notificationService.cancelAllReminders();
    }
    
    await _settingsService.setRemindersEnabled(value);
    if (!mounted) return;
    setState(() => _remindersEnabled = value);
    _notifyChange();
    if (_hapticFeedback) HapticFeedback.lightImpact();
  }

  Future<void> _toggleSystemCamera(bool value) async {
    await _settingsService.setUseSystemCamera(value);
    if (!mounted) return;
    setState(() => _useSystemCamera = value);
    _notifyChange();
    if (_hapticFeedback) HapticFeedback.selectionClick();
  }

  Future<void> _toggleMirrorFront(bool value) async {
    await _settingsService.setMirrorFrontCamera(value);
    if (!mounted) return;
    setState(() => _mirrorFrontCamera = value);
    _notifyChange();
    if (_hapticFeedback) HapticFeedback.selectionClick();
  }

  Future<void> _toggleHaptics(bool value) async {
    await _settingsService.setHapticFeedback(value);
    if (!mounted) return;
    setState(() => _hapticFeedback = value);
    _notifyChange();
    if (value) HapticFeedback.mediumImpact();
  }

  Future<void> _toggleShutterSound(bool value) async {
    await _settingsService.setShutterSound(value);
    if (!mounted) return;
    setState(() => _shutterSound = value);
    _notifyChange();
    if (_hapticFeedback) HapticFeedback.selectionClick();
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null && picked != _reminderTime) {
      await _settingsService.setReminderTime("${picked.hour}:${picked.minute}");
      if (_remindersEnabled) {
        await _notificationService.scheduleDailyReminder(picked);
      }
      if (!mounted) return;
      setState(() => _reminderTime = picked);
      _notifyChange();
      if (_hapticFeedback) HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            title: Text("Settings"),
            centerTitle: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStreakCard(colorScheme),
                  const SizedBox(height: 32),
                  const _SectionHeader(title: "Capture Preferences"),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.photo_library_outlined,
                        title: "Daily Limit",
                        subtitle: "Current limit: $_dailyLimit photos",
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.filledTonal(
                              onPressed: () => _updateLimit(-1),
                              icon: const Icon(Icons.remove, size: 18),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: () => _updateLimit(1),
                              icon: const Icon(Icons.add, size: 18),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      SwitchListTile(
                        value: _useSystemCamera,
                        onChanged: _toggleSystemCamera,
                        secondary: Icon(Icons.camera_outlined, color: colorScheme.primary),
                        title: const Text("Use System Camera", style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text("High-quality hardware capture"),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      SwitchListTile(
                        value: _mirrorFrontCamera,
                        onChanged: _toggleMirrorFront,
                        secondary: Icon(Icons.flip_camera_android_outlined, color: colorScheme.primary),
                        title: const Text("Mirror Front Camera", style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text("Save selfies as seen in preview"),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _SettingsTile(
                        icon: Icons.auto_awesome_outlined,
                        title: "Default Filter",
                        subtitle: "Selected: $_defaultFilter",
                        onTap: () => _showFilterPicker(),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _SettingsTile(
                        icon: Icons.high_quality_outlined,
                        title: "Image Quality",
                        subtitle: "Current: $_imageQuality",
                        onTap: () => _showQualityPicker(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const _SectionHeader(title: "Interface & Feedback"),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    children: [
                      SwitchListTile(
                        value: _hapticFeedback,
                        onChanged: _toggleHaptics,
                        secondary: Icon(Icons.vibration_outlined, color: colorScheme.primary),
                        title: const Text("Haptic Feedback", style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text("Tactile response on actions"),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      SwitchListTile(
                        value: _shutterSound,
                        onChanged: _toggleShutterSound,
                        secondary: Icon(Icons.volume_up_outlined, color: colorScheme.primary),
                        title: const Text("Shutter Sound", style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text("Audible feedback on capture"),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const _SectionHeader(title: "Notifications"),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    children: [
                      SwitchListTile(
                        value: _remindersEnabled,
                        onChanged: _toggleReminders,
                        secondary: Icon(Icons.notifications_active_outlined, color: colorScheme.primary),
                        title: const Text("Daily Reminders", style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text("Get notified to snap a photo"),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      ),
                      if (_remindersEnabled) ...[
                        const Divider(height: 1, indent: 56, endIndent: 16),
                        _SettingsTile(
                          icon: Icons.access_time,
                          title: "Reminder Time",
                          subtitle: _reminderTime.format(context),
                          onTap: _selectTime,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 32),
                  const _SectionHeader(title: "Community"),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.rate_review_outlined,
                        title: "Rate SnapLog Pro",
                        subtitle: "Share your feedback with us",
                        onTap: () {
                          if (_hapticFeedback) HapticFeedback.selectionClick();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Redirecting to App Store...")),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _SettingsTile(
                        icon: Icons.share_outlined,
                        title: "Invite Friends",
                        subtitle: "Help others capture their story",
                        onTap: () {
                          if (_hapticFeedback) HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Sharing SnapLog Pro...")),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const _SectionHeader(title: "Data Management"),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    color: colorScheme.errorContainer.withValues(alpha: 0.1),
                    children: [
                      _SettingsTile(
                        icon: Icons.cleaning_services_outlined,
                        title: "Clear App Cache",
                        subtitle: "Removes temporary images",
                        onTap: () => _clearCache(),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _SettingsTile(
                        icon: Icons.restart_alt_outlined,
                        title: "Reset Preferences",
                        subtitle: "Restore default settings",
                        onTap: () => _resetSettings(),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _SettingsTile(
                        icon: Icons.delete_forever_outlined,
                        title: "Wipe All Data",
                        textColor: colorScheme.error,
                        subtitle: "Permanent deletion of all memories",
                        onTap: () => _fullReset(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  const Center(
                    child: Column(
                      children: [
                        Text("SnapLog Pro", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text("v1.3.0+5", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        SizedBox(height: 8),
                        Text("Crafted with Passion & AI", style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 48),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Current Streak",
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                ),
                FutureBuilder<int>(
                  future: _streakFuture,
                  builder: (context, snapshot) {
                    final streak = snapshot.data ?? 0;
                    return Text(
                      "$streak Days",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children, Color? color}) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: color ?? Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(children: children),
    );
  }

  void _showFilterPicker() async {
    final filters = ['Normal', 'B&W', 'Sepia', 'Cool', 'Warm'];
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Select Default Filter", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            ...filters.map((f) => ListTile(
              title: Text(f),
              onTap: () => Navigator.pop(context, f),
              trailing: _defaultFilter == f ? const Icon(Icons.check_circle, color: Colors.green) : null,
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (selected != null && selected != _defaultFilter) {
      await _settingsService.setDefaultFilter(selected);
      if (!mounted) return;
      setState(() => _defaultFilter = selected);
      _notifyChange();
    }
  }

  void _showQualityPicker() async {
    final options = ['Low', 'Medium', 'High'];
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Image Resolution", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            ...options.map((o) => ListTile(
              title: Text(o),
              onTap: () => Navigator.pop(context, o),
              trailing: _imageQuality == o ? const Icon(Icons.check_circle, color: Colors.green) : null,
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (selected != null && selected != _imageQuality) {
      await _settingsService.setImageQuality(selected);
      if (!mounted) return;
      setState(() => _imageQuality = selected);
      _notifyChange();
    }
  }

  Future<void> _clearCache() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Cache?"),
        content: const Text("This will remove temporary files. Your saved photos are safe."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Clear")),
        ],
      ),
    );
    if (confirm == true) {
      await _settingsService.clearAppCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cache cleared successfully")));
      }
    }
  }

  Future<void> _resetSettings() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Preferences?"),
        content: const Text("All settings will return to their default values."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Reset")),
        ],
      ),
    );
    if (confirm == true) {
      await _settingsService.resetAllSettings();
      if (!mounted) return;
      _loadSettings();
      _notifyChange();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preferences reset")));
    }
  }

  Future<void> _fullReset() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("WIPE ALL DATA?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("This action is permanent and irreversible. All photos and history will be deleted forever."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("DELETE EVERYTHING", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper().deleteAllEntries();
      await _settingsService.resetAllSettings();
      if (!mounted) return;
      _loadSettings();
      _notifyChange();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All data wiped. Fresh start!")));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? textColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12)) : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, size: 20) : null),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}
