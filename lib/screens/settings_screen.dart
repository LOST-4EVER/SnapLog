import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:local_auth/local_auth.dart';
import 'package:home_widget/home_widget.dart';
import '../services/database_helper.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../services/entries_notifier.dart';
import '../widgets/streak_badge.dart';
import 'quiz_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final NotificationService _notificationService = NotificationService();
  final LocalAuthentication _auth = LocalAuthentication();
  
  int _dailyLimit = 3;
  String _imageQuality = 'High';
  bool _remindersEnabled = false;
  bool _useSystemCamera = false;
  bool _hapticFeedback = true;
  bool _shutterSound = true;
  bool _biometricLock = false;
  bool _showWidgetOnHome = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  
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
        _remindersEnabled = settings['remindersEnabled'];
        _useSystemCamera = settings['useSystemCamera'] ?? false;
        _hapticFeedback = settings['hapticFeedback'] ?? true;
        _shutterSound = settings['shutterSound'] ?? true;
        _biometricLock = settings['biometricLock'] ?? false;
        _showWidgetOnHome = settings['showWidgetOnHome'] ?? true;
        _reminderTime = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  void _notifyChange() {
    EntriesNotifier().notifyEntryAdded(); 
    _updateHomeWidget();
  }

  Future<void> _updateHomeWidget() async {
    final streak = await DatabaseHelper().calculateStreak();
    await HomeWidget.saveWidgetData<int>('streak_count', streak);
    await HomeWidget.updateWidget(name: 'StreakWidgetProvider');
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

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      
      if (!canAuthenticate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Biometrics not available on this device")),
          );
        }
        return;
      }

      try {
        final bool authenticated = await _auth.authenticate(
          localizedReason: 'Verify identity to enable lock',
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
        );
        if (!authenticated) return;
      } catch (e) {
        return;
      }
    }

    await _settingsService.setBiometricLock(value);
    if (!mounted) return;
    setState(() => _biometricLock = value);
    _notifyChange();
    if (_hapticFeedback) HapticFeedback.selectionClick();
  }

  Future<void> _toggleSystemCamera(bool value) async {
    await _settingsService.setUseSystemCamera(value);
    if (!mounted) return;
    setState(() => _useSystemCamera = value);
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
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverAppBar.large(
            title: Text("Preferences"),
            centerTitle: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStreakHero(colorScheme),
                  const SizedBox(height: 24),
                  
                  const _SectionHeader(title: "Security"),
                  _buildSettingsCard(
                    children: [
                      SwitchListTile(
                        value: _biometricLock,
                        onChanged: _toggleBiometrics,
                        secondary: Icon(Icons.fingerprint_rounded, color: colorScheme.primary),
                        title: const Text("App Lock", style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text("Require authentication on launch"),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        dense: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const _SectionHeader(title: "Camera & Capture"),
                  _buildSettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.photo_camera_rounded,
                        title: "Daily Limit",
                        subtitle: "$_dailyLimit photos / day",
                        onTap: () => _updateLimit(1),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.filledTonal(
                              onPressed: () => _updateLimit(-1),
                              icon: const Icon(Icons.remove, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: () => _updateLimit(1),
                              icon: const Icon(Icons.add, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      SwitchListTile(
                        value: _useSystemCamera,
                        onChanged: _toggleSystemCamera,
                        secondary: Icon(Icons.camera_rounded, color: colorScheme.primary),
                        title: const Text("Use System Camera", style: TextStyle(fontWeight: FontWeight.w600)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        dense: true,
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _SettingsTile(
                        icon: Icons.high_quality_rounded,
                        title: "Resolution",
                        subtitle: _imageQuality,
                        onTap: () => _showQualityPicker(),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  const _SectionHeader(title: "Interface & Reminders"),
                  _buildSettingsCard(
                    children: [
                      SwitchListTile(
                        value: _remindersEnabled,
                        onChanged: _toggleReminders,
                        secondary: Icon(Icons.alarm_rounded, color: colorScheme.primary),
                        title: const Text("Daily Reminders", style: TextStyle(fontWeight: FontWeight.w600)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        dense: true,
                      ),
                      if (_remindersEnabled) ...[
                        const Divider(height: 1, indent: 56, endIndent: 16),
                        _SettingsTile(
                          icon: Icons.schedule_rounded,
                          title: "Reminder Time",
                          subtitle: _reminderTime.format(context),
                          onTap: _selectTime,
                        ),
                      ],
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      SwitchListTile(
                        value: _hapticFeedback,
                        onChanged: _toggleHaptics,
                        secondary: Icon(Icons.vibration_rounded, color: colorScheme.primary),
                        title: const Text("Haptic Feedback", style: TextStyle(fontWeight: FontWeight.w600)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        dense: true,
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      SwitchListTile(
                        value: _shutterSound,
                        onChanged: _toggleShutterSound,
                        secondary: Icon(Icons.volume_up_rounded, color: colorScheme.primary),
                        title: const Text("Shutter Sound", style: TextStyle(fontWeight: FontWeight.w600)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        dense: true,
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      SwitchListTile(
                        value: _showWidgetOnHome,
                        onChanged: (v) async {
                          await _settingsService.setShowWidgetOnHome(v);
                          if (mounted) setState(() => _showWidgetOnHome = v);
                          _notifyChange();
                        },
                        secondary: Icon(Icons.widgets_rounded, color: colorScheme.primary),
                        title: const Text("Streak Widget", style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text("Show on home screen"),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        dense: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const _SectionHeader(title: "Data"),
                  _buildSettingsCard(
                    color: colorScheme.errorContainer.withValues(alpha: 0.05),
                    children: [
                      _SettingsTile(
                        icon: Icons.delete_outline_rounded,
                        title: "Clear Cache",
                        onTap: () => _clearCache(),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _SettingsTile(
                        icon: Icons.delete_forever_rounded,
                        title: "Erase All Data",
                        textColor: colorScheme.error,
                        onTap: () => _fullReset(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),
                  Center(
                    child: Column(
                      children: [
                        const Text("SnapLog Pro", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        const Text("v1.6.0+8", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text("100% Offline Secure Storage", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.green.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakHero(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primaryContainer, colorScheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          const StreakBadge(size: 48),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "STREAK ACTIVE",
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 10),
                ),
                SizedBox(height: 2),
                Text(
                  "Keep it up!",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      color: color ?? Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(children: children),
    );
  }

  void _showQualityPicker() async {
    final options = ['Low', 'Medium', 'High', 'Max (Ultra)'];
    await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text("Capture Resolution", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            ),
            ...options.map((o) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 32),
              title: Text(o, style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context, o);
                if (o != _imageQuality) {
                  _settingsService.setImageQuality(o);
                  if (mounted) setState(() => _imageQuality = o);
                  _notifyChange();
                }
              },
              trailing: _imageQuality == o ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary) : null,
            )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _clearCache() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text("Clear Cache?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("CLEAR")),
        ],
      ),
    );
    if (confirm == true) {
      await _settingsService.clearAppCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cache cleared.")));
      }
    }
  }

  Future<void> _fullReset() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text("ERASE ALL DATA?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900)),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          FilledButton(
            onPressed: () => Navigator.pop(context, true), 
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("ERASE")
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("App reset to factory state.")));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 0, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
        ),
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
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 18),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14)),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8))) : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right_rounded, size: 18) : null),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      dense: true,
    );
  }
}
