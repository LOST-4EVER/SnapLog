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
  String _defaultFilter = 'Normal';
  int _shutterDelay = 0;
  String _hapticIntensity = 'Medium';
  bool _autoSaveToGallery = false;
  bool _remindersEnabled = false;
  bool _useSystemCamera = false;
  bool _hapticFeedback = true;
  bool _shutterSound = true;
  bool _biometricLock = false;
  bool _showWidgetOnHome = true;
  bool _amoledMode = false;
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
        _defaultFilter = settings['defaultFilter'] ?? 'Normal';
        _shutterDelay = settings['shutterDelay'] ?? 0;
        _hapticIntensity = settings['hapticIntensity'] ?? 'Medium';
        _autoSaveToGallery = settings['autoSaveToGallery'] ?? false;
        _remindersEnabled = settings['remindersEnabled'];
        _useSystemCamera = settings['useSystemCamera'] ?? false;
        _hapticFeedback = settings['hapticFeedback'] ?? true;
        _shutterSound = settings['shutterSound'] ?? true;
        _biometricLock = settings['biometricLock'] ?? false;
        _showWidgetOnHome = settings['showWidgetOnHome'] ?? true;
        _amoledMode = settings['amoledMode'] ?? false;
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

  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text("Restart Required"),
        content: const Text("Hardware integration and resolution changes will take full effect after restarting SnapLog."),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text("UNDERSTOOD")),
        ],
      ),
    );
  }

  Future<void> _updateHomeWidget() async {
    final streak = await DatabaseHelper().calculateStreak();
    final countToday = await DatabaseHelper().getTodaysPhotoCount();
    final entries = await DatabaseHelper().getEntries();
    String lastTime = "--";
    if (entries.isNotEmpty) {
      final last = entries.first;
      lastTime = "${last.timestamp.hour}:${last.timestamp.minute.toString().padLeft(2, '0')}";
    }

    await HomeWidget.saveWidgetData<int>('streak_count', streak);
    await HomeWidget.saveWidgetData<bool>('is_today_done', countToday > 0);
    await HomeWidget.saveWidgetData<String>('last_snap_time', lastTime);
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
            const SnackBar(content: Text("Biometrics not available")),
          );
        }
        return;
      }

      try {
        final bool authenticated = await _auth.authenticate(
          localizedReason: 'Verify identity to enable Vault Lock',
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
    _showRestartDialog();
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
            actions: [
              StreakBadge(size: 28),
              SizedBox(width: 16),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(title: "Security & Vault"),
                  _buildSettingsCard(
                    children: [
                      SwitchListTile(
                        value: _biometricLock,
                        onChanged: _toggleBiometrics,
                        secondary: Icon(Icons.fingerprint_rounded, color: colorScheme.primary),
                        title: const Text("Biometric Lock", style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text("Secure memories with hardware auth"),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const _SectionHeader(title: "Camera Hardware"),
                  _buildSettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.camera_alt_rounded,
                        title: "Daily Snap Limit",
                        subtitle: "$_dailyLimit photos allowed / 24h",
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
                        secondary: Icon(Icons.settings_input_component_rounded, color: colorScheme.primary),
                        title: const Text("Hardware Integration", style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text("Direct system camera access"),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _SettingsTile(
                        icon: Icons.high_quality_rounded,
                        title: "Master Resolution",
                        subtitle: "Current: $_imageQuality",
                        onTap: () => _showQualityPicker(),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _SettingsTile(
                        icon: Icons.auto_awesome_rounded,
                        title: "Default Aesthetic",
                        subtitle: "Filter: $_defaultFilter",
                        onTap: () => _showFilterPicker(),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _SettingsTile(
                        icon: Icons.timer_rounded,
                        title: "Shutter Delay",
                        subtitle: _shutterDelay == 0 ? "Instant" : "${_shutterDelay}s delay",
                        onTap: () => _showDelayPicker(),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      SwitchListTile(
                        value: _autoSaveToGallery,
                        onChanged: (v) async {
                          await _settingsService.setAutoSaveToGallery(v);
                          if (mounted) setState(() => _autoSaveToGallery = v);
                          _notifyChange();
                        },
                        secondary: Icon(Icons.save_alt_rounded, color: colorScheme.primary),
                        title: const Text("Archive to Gallery", style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text("Auto-save copies to system photos"),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  const _SectionHeader(title: "Experience Engine"),
                  _buildSettingsCard(
                    children: [
                      SwitchListTile(
                        value: _remindersEnabled,
                        onChanged: _toggleReminders,
                        secondary: Icon(Icons.alarm_on_rounded, color: colorScheme.primary),
                        title: const Text("Daily Reminder", style: TextStyle(fontWeight: FontWeight.bold)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _SettingsTile(
                        icon: Icons.schedule_rounded,
                        title: "Delivery Window",
                        subtitle: _reminderTime.format(context),
                        onTap: _selectTime,
                        enabled: _remindersEnabled,
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      SwitchListTile(
                        value: _amoledMode,
                        onChanged: (v) async {
                          await _settingsService.setAmoledMode(v);
                          if (mounted) setState(() => _amoledMode = v);
                          _notifyChange();
                        },
                        secondary: Icon(Icons.dark_mode_rounded, color: colorScheme.primary),
                        title: const Text("AMOLED Black", style: TextStyle(fontWeight: FontWeight.bold)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _SettingsTile(
                        icon: Icons.vibration_rounded,
                        title: "Haptic Intensity",
                        subtitle: "Current: $_hapticIntensity",
                        onTap: () => _showHapticPicker(),
                        enabled: _hapticFeedback,
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      SwitchListTile(
                        value: _hapticFeedback,
                        onChanged: _toggleHaptics,
                        secondary: Icon(Icons.touch_app_rounded, color: colorScheme.primary),
                        title: const Text("Tactile Engine", style: TextStyle(fontWeight: FontWeight.bold)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      SwitchListTile(
                        value: _shutterSound,
                        onChanged: _toggleShutterSound,
                        secondary: Icon(Icons.volume_up_rounded, color: colorScheme.primary),
                        title: const Text("Audio Confirmation", style: TextStyle(fontWeight: FontWeight.bold)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                        title: const Text("Home Widget", style: TextStyle(fontWeight: FontWeight.bold)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const _SectionHeader(title: "Data Stewardship"),
                  _buildSettingsCard(
                    color: colorScheme.errorContainer.withValues(alpha: 0.05),
                    children: [
                      _SettingsTile(
                        icon: Icons.cleaning_services_rounded,
                        title: "Optimize Storage",
                        onTap: () => _clearCache(),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _SettingsTile(
                        icon: Icons.delete_forever_rounded,
                        title: "Total Factory Reset",
                        textColor: colorScheme.error,
                        onTap: () => _fullReset(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),
                  Center(
                    child: Column(
                      children: [
                        const Text("SnapLog Pro", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        const Text("Version 1.0.1", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        const Text("Vidvit Elite Transformation", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.orange)),
                        const Text("Developed by LOST-4EVER", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("with ", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                            Icon(Icons.favorite, size: 14, color: Colors.red),
                            Text(" and with AI", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_user_rounded, size: 14, color: Colors.green),
                              SizedBox(width: 8),
                              Text("100% OFFLINE SECURE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.green)),
                            ],
                          ),
                        ),
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

  Widget _buildSettingsCard({required List<Widget> children, Color? color}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      color: color ?? Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(children: children),
    );
  }

  void _showDelayPicker() async {
    final options = [0, 2, 5, 10];
    await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text("Shutter Delay", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            ),
            ...options.map((o) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
              title: Text(o == 0 ? "Instant" : "${o}s delay", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              onTap: () {
                Navigator.pop(context, o);
                if (o != _shutterDelay) {
                  _settingsService.setShutterDelay(o);
                  if (mounted) setState(() => _shutterDelay = o);
                  _notifyChange();
                }
              },
              trailing: _shutterDelay == o ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary) : null,
            )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showHapticPicker() async {
    final options = ['Soft', 'Medium', 'Sharp'];
    await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text("Haptic Intensity", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            ),
            ...options.map((o) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
              title: Text(o, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              onTap: () {
                Navigator.pop(context, o);
                if (o != _hapticIntensity) {
                  _settingsService.setHapticIntensity(o);
                  if (mounted) setState(() => _hapticIntensity = o);
                  _notifyChange();
                  if (_hapticFeedback) {
                    if (o == 'Soft') HapticFeedback.lightImpact();
                    if (o == 'Medium') HapticFeedback.mediumImpact();
                    if (o == 'Sharp') HapticFeedback.vibrate();
                  }
                }
              },
              trailing: _hapticIntensity == o ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary) : null,
            )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showFilterPicker() async {
    final options = ['Normal', 'B&W', 'Sepia', 'Cool', 'Warm'];
    await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text("Default Filter", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            ),
            ...options.map((o) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
              title: Text(o, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              onTap: () {
                Navigator.pop(context, o);
                if (o != _defaultFilter) {
                  _settingsService.setDefaultFilter(o);
                  if (mounted) setState(() => _defaultFilter = o);
                  _notifyChange();
                }
              },
              trailing: _defaultFilter == o ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary) : null,
            )),
            const SizedBox(height: 24),
          ],
        ),
      ),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
              title: Text(o, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              onTap: () {
                Navigator.pop(context, o);
                if (o != _imageQuality) {
                  _settingsService.setImageQuality(o);
                  if (mounted) setState(() => _imageQuality = o);
                  _notifyChange();
                  _showRestartDialog();
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
        title: const Text("Optimize Storage?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("OPTIMIZE")),
        ],
      ),
    );
    if (confirm == true) {
      await _settingsService.clearAppCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Storage optimized.")));
      }
    }
  }

  Future<void> _fullReset() async {
    final bool? passedQuiz = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QuizScreen(difficulty: QuizDifficulty.hard)),
    );

    if (passedQuiz != true) return;

    if (!mounted) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text("FINAL CONFIRMATION"),
        content: const Text("This will permanently delete all your photos and reset all settings. This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ABORT")),
          FilledButton(
            onPressed: () => Navigator.pop(context, true), 
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("ERASE EVERYTHING")
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All data has been wiped.")));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 0, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
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
  final bool enabled;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.textColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: enabled ? 0.1 : 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary.withValues(alpha: enabled ? 1.0 : 0.4), size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: textColor?.withValues(alpha: enabled ? 1.0 : 0.4), fontSize: 16)),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: enabled ? 0.8 : 0.4))) : null,
      trailing: trailing ?? (onTap != null ? Icon(Icons.chevron_right_rounded, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: enabled ? 1.0 : 0.4)) : null),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
