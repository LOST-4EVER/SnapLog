import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../services/database_helper.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  int _dailyLimit = 3;
  String _imageQuality = 'High';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.getSettings();
    setState(() {
      _dailyLimit = settings['dailyLimit'] ?? 3;
      _imageQuality = settings['imageQuality'] ?? 'High';
    });
  }

  Future<void> _updateLimit(int delta) async {
    final newLimit = (_dailyLimit + delta).clamp(1, 10);
    if (newLimit != _dailyLimit) {
      await _settingsService.setDailyLimit(newLimit);
      setState(() => _dailyLimit = newLimit);
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _updateQuality(String? quality) async {
    if (quality != null) {
      await _settingsService.setImageQuality(quality);
      setState(() => _imageQuality = quality);
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _clearCache(BuildContext context) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Cache cleared successfully"),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _fullDataReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset all data?"),
        content: const Text(
          "This will permanently delete all your journal entries and photos. This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text("Delete Everything"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper().clearAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All data has been reset"), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionHeader(title: "Preferences", color: colorScheme.primary),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: colorScheme.surfaceVariant.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.photo_camera),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Daily Photo Limit", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("Maximum captures per day", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _updateLimit(-1),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text("$_dailyLimit", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: () => _updateLimit(1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: colorScheme.surfaceVariant.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.high_quality),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Image Quality", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("Manage data and storage", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  DropdownButton<String>(
                    value: _imageQuality,
                    onChanged: _updateQuality,
                    underline: Container(),
                    items: ['Low', 'Medium', 'High'].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          _SectionHeader(title: "Maintenance", color: colorScheme.error),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.delete_sweep_outlined,
            title: "Clear Cache",
            subtitle: "Free up temporary storage",
            onTap: () => _clearCache(context),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.delete_forever_outlined,
            title: "Full Data Reset",
            subtitle: "Wipe all entries permanently",
            textColor: colorScheme.error,
            iconColor: colorScheme.error,
            onTap: () => _fullDataReset(context),
          ),
          
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.camera, size: 32, color: colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  "SnapLog Pro",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  "Version 1.2.0",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
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
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: color,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Icon(icon, color: iconColor ?? colorScheme.onSurface),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }
}
