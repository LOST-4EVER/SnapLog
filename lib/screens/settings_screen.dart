import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../services/database_helper.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import 'quiz_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

const int _minDailyLimit = 1;
const int _maxDailyLimit = 10;
const double _cardBorderRadius = 24.0;
const double _sectionHeaderSpacing = 32.0;

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  final SettingsService _settingsService = SettingsService();
  final NotificationService _notificationService = NotificationService();
  
  int _dailyLimit = 3;
  String _imageQuality = 'High';
  String _defaultFilter = 'Normal';
  
  late Future<int> _streakFuture;
  bool _remindersEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSettings();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOutCubic));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsService.getSettings();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _dailyLimit = settings['dailyLimit'] ?? 3;
        _imageQuality = settings['imageQuality'] ?? 'High';
        _defaultFilter = settings['defaultFilter'] ?? 'Normal';
        _remindersEnabled = prefs.getBool('remindersEnabled') ?? false;
        final timeString = prefs.getString('reminderTime');
        if (timeString != null) {
          final parts = timeString.split(':');
          _reminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
        _streakFuture = DatabaseHelper().calculateStreak();
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _shareApp() async {
    try {
      // 1. Get the path to the current APK
      // Note: On most Android devices, this is /data/app/.../base.apk
      final String apkPath = Platform.resolvedExecutable;
      
      if (apkPath.isEmpty || !apkPath.contains('.apk')) {
        // Fallback for debug mode or if path detection fails
        await Share.share(
          "Hey! I'm using SnapLog to capture my daily moments. You should try it too! Download it here: https://github.com/yourusername/snaplog. We appreciate you! ❤️",
          subject: "Join me on SnapLog",
        );
        return;
      }

      // 2. Create a temporary copy of the APK to share
      final File originalApk = File(apkPath);
      final tempDir = await getTemporaryDirectory();
      final String tempApkPath = "${tempDir.path}/SnapLog_Pro.apk";
      final File tempApk = File(tempApkPath);

      if (!await tempApk.exists()) {
        await originalApk.copy(tempApkPath);
      }

      // 3. Trigger native share
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(tempApkPath)],
        text: "SnapLog Pro - Capture your life daily. We appreciate you! ❤️",
        subject: "Install SnapLog Pro",
        sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } catch (e) {
      debugPrint("Error sharing APK: $e");
      // UI Fallback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to locate APK. Sharing text link instead.")),
        );
        await Share.share("Hey! Try SnapLog Pro: Capture your daily moments. We appreciate you! ❤️");
      }
    }
  }

  Future<void> _updateLimit(int delta) async {
    final newLimit = (_dailyLimit + delta).clamp(_minDailyLimit, _maxDailyLimit);
    if (newLimit != _dailyLimit) {
      final bool? passedQuiz = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QuizScreen(difficulty: QuizDifficulty.normal)),
      );

      if (passedQuiz == true) {
        await _settingsService.setDailyLimit(newLimit);
        if (!mounted) return;
        setState(() => _dailyLimit = newLimit);
        HapticFeedback.selectionClick();
      }
    }
  }

  Future<void> _updateQuality(String? quality) async {
    if (quality != null && quality != _imageQuality) {
      await _settingsService.setImageQuality(quality);
      if (!mounted) return;
      setState(() => _imageQuality = quality);
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _updateFilter(String? filter) async {
    if (filter != null && filter != _defaultFilter) {
      await _settingsService.setDefaultFilter(filter);
      if (!mounted) return;
      setState(() => _defaultFilter = filter);
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _updateReminders(bool enabled) async {
    if (!mounted) return;
    setState(() => _remindersEnabled = enabled);
    HapticFeedback.lightImpact();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (enabled) {
        final status = await Permission.notification.request();
        if (status.isGranted) {
          await _notificationService.scheduleDailyReminder(_reminderTime);
          await prefs.setBool('remindersEnabled', true);
        } else {
          if (!mounted) return;
          setState(() => _remindersEnabled = false);
          _showPermissionDialog();
        }
      } else {
        await _notificationService.cancelAllReminders();
        await prefs.setBool('remindersEnabled', false);
      }
    } catch (e) {
      debugPrint('Error updating reminders: $e');
      if (!mounted) return;
      setState(() => _remindersEnabled = !enabled);
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Notifications Disabled"),
        content: const Text("Please enable notifications in your phone settings to use reminders."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text("Settings"),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime(BuildContext context) async {
    if (!_remindersEnabled) return;
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked != null && picked != _reminderTime) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        setState(() => _reminderTime = picked);
        await prefs.setString('reminderTime', '${picked.hour}:${picked.minute}');
        await _notificationService.scheduleDailyReminder(picked);
        HapticFeedback.mediumImpact();
      } catch (e) {
        debugPrint('Error updating time: $e');
      }
    }
  }

  Future<void> _clearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Cache?"),
        content: const Text("This will delete temporary image files and free up space."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Clear")),
        ],
      ),
    );
    if (confirmed == true) {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cache cleared")));
    }
  }

  Future<void> _fullDataReset(BuildContext context) async {
    final bool? passedQuiz = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QuizScreen(difficulty: QuizDifficulty.hard)),
    );
    if (passedQuiz != true) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Wipe All Data?"),
        content: const Text("This action is permanent. All your photos and journal entries will be deleted."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete Everything"),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper().clearAllData();
      if (!mounted) return;
      setState(() => _streakFuture = DatabaseHelper().calculateStreak());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All data wiped")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), centerTitle: true),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SectionHeader(title: "Your Progress", color: colorScheme.primary),
              const SizedBox(height: 12),
              _buildStreakCard(colorScheme),
              
              const SizedBox(height: _sectionHeaderSpacing),
              _SectionHeader(title: "Daily Reminders", color: colorScheme.primary),
              const SizedBox(height: 12),
              _buildNotificationCard(colorScheme),

              const SizedBox(height: _sectionHeaderSpacing),
              _SectionHeader(title: "Photography Prefs", color: colorScheme.primary),
              const SizedBox(height: 12),
              _buildPreferenceCard(colorScheme),

              const SizedBox(height: _sectionHeaderSpacing),
              _SectionHeader(title: "Community", color: colorScheme.primary),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.share_outlined,
                title: "Share SnapLog App",
                subtitle: "Tell others we appreciate you! ❤️",
                onTap: _shareApp,
              ),
              
              const SizedBox(height: _sectionHeaderSpacing),
              _SectionHeader(title: "Danger Zone", color: colorScheme.error),
              const SizedBox(height: 12),
              _DangerZoneTile(icon: Icons.cleaning_services_outlined, title: "Clear App Cache", onTap: () => _clearCache(context)),
              const SizedBox(height: 12),
              _DangerZoneTile(icon: Icons.delete_forever_outlined, title: "Wipe All Data", isLast: true, onTap: () => _fullDataReset(context)),
              
              const SizedBox(height: 60),
              Center(
                child: Opacity(
                  opacity: 0.6,
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("made by "),
                          Text("LOSY-4EVER", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                          const Text(" ❤️ with Ai"),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text("v1.2.0", style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardBorderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department, color: Colors.orange, size: 40),
            const SizedBox(width: 20),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Current Streak", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text("Capture daily to grow!", style: TextStyle(fontSize: 12, color: Colors.grey))])),
            FutureBuilder<int>(
              future: _streakFuture,
              builder: (context, snapshot) {
                final streak = snapshot.data ?? 0;
                return Row(children: [Text("$streak", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)), const SizedBox(width: 4), const Text("Days", style: TextStyle(fontWeight: FontWeight.bold))]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardBorderRadius)),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            value: _remindersEnabled,
            onChanged: _updateReminders,
            title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_remindersEnabled ? "Daily alerts active" : "Alerts disabled"),
            secondary: Icon(_remindersEnabled ? Icons.notifications_active : Icons.notifications_off_outlined, color: _remindersEnabled ? colorScheme.primary : Colors.grey),
          ),
          if (_remindersEnabled) ...[
            const Divider(indent: 70, endIndent: 24, height: 1),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: const Icon(Icons.access_time, size: 24),
              title: const Text("Reminder Time"),
              trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(_reminderTime.format(context), style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold))),
              onTap: () => _selectTime(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferenceCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardBorderRadius)),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text("Daily Photo Limit", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Cap your moments"),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [_LimitButton(icon: Icons.remove, onTap: () => _updateLimit(-1)), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text("$_dailyLimit", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), _LimitButton(icon: Icons.add, onTap: () => _updateLimit(1))]),
          ),
          const Divider(indent: 70, endIndent: 24, height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text("Default Filter", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Auto-apply on capture"),
            trailing: DropdownButton<String>(
              value: _defaultFilter,
              underline: const SizedBox(),
              items: ['Normal', 'B&W', 'Sepia', 'Cool', 'Warm'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: _updateFilter,
            ),
          ),
          const Divider(indent: 70, endIndent: 24, height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            leading: const Icon(Icons.high_quality_outlined),
            title: const Text("Image Quality", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Manage resolution"),
            trailing: DropdownButton<String>(
              value: _imageQuality,
              underline: const SizedBox(),
              items: ['Low', 'Medium', 'High'].map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
              onChanged: _updateQuality,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: color.withOpacity(0.7))));
  }
}

class _LimitButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _LimitButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary)));
  }
}

class _DangerZoneTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isLast;

  const _DangerZoneTile({required this.icon, required this.title, required this.onTap, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Card(elevation: 0, margin: EdgeInsets.zero, color: Colors.red.withOpacity(0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.red.withOpacity(0.1))), child: ListTile(leading: Icon(icon, color: Colors.redAccent), title: Text(title, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)), trailing: const Icon(Icons.chevron_right, color: Colors.redAccent, size: 20), onTap: onTap));
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }
}
