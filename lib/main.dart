import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:local_auth/local_auth.dart';
import 'services/entries_notifier.dart';
import 'services/notification_service.dart';
import 'services/achievement_service.dart';
import 'services/settings_service.dart';
import 'screens/camera_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/advancements_screen.dart';
import 'widgets/streak_badge.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint("Camera hardware not detected or timeout: $e");
  }
  
  runApp(SnapLogApp(cameras: cameras));
}

class SnapLogApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const SnapLogApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.light,
    );
    
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFD0BCFF), 
      brightness: Brightness.dark,
      surface: const Color(0xFF1C1B1F),
    );

    return MaterialApp(
      title: 'SnapLog Pro',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(lightColorScheme),
      darkTheme: _buildTheme(darkColorScheme),
      themeMode: ThemeMode.system,
      home: MainNavigation(cameras: cameras),
    );
  }

  ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10, 
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          );
        }),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final List<CameraDescription> cameras;
  const MainNavigation({super.key, required this.cameras});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  late PageController _pageController;
  final QuickActions _quickActions = const QuickActions();
  final LocalAuthentication _auth = LocalAuthentication();
  late final EntriesNotifier _notifier;
  late final VoidCallback _notifierListener;
  
  bool _isInitializing = true;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _notifier = EntriesNotifier();
    _notifierListener = () => _checkAchievements();
    _notifier.addListener(_notifierListener);
    
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      // Parallel background init with timeout safety
      await Future.wait([
        NotificationService().init().timeout(const Duration(seconds: 2)),
        AchievementService().initNotificationState().timeout(const Duration(seconds: 2)),
      ]).catchError((e) => []);

      final settings = await SettingsService().getSettings();
      final bool biometricEnabled = settings['biometricLock'] ?? false;

      if (biometricEnabled) {
        if (mounted) {
          setState(() {
            _isLocked = true;
            _isInitializing = false;
          });
        }
        _checkBiometricLock();
      } else {
        if (mounted) {
          setState(() {
            _isLocked = false;
            _isInitializing = false;
          });
        }
      }

      _initQuickActions();
      _checkAchievements();
    } catch (e) {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _checkBiometricLock() async {
    try {
      final bool authenticated = await _auth.authenticate(
        localizedReason: 'Authenticate to access your journal',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
      if (authenticated) {
        if (mounted) setState(() => _isLocked = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLocked = false);
    }
  }

  Future<void> _checkAchievements() async {
    await AchievementService().checkNewUnlocks((achievement) {
      if (!mounted) return;
      _showAchievementToast(achievement);
    });
  }

  void _showAchievementToast(Achievement a) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.primary),
          ),
          child: Row(
            children: [
              Text(a.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("BADGE EARNED", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey)),
                    Text(a.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _initQuickActions() {
    _quickActions.initialize((String shortcutType) {
      if (shortcutType == 'action_capture') {
        _onItemTapped(0);
      } else if (shortcutType == 'action_journal') {
        _onItemTapped(1);
      }
    });
    _quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(type: 'action_capture', localizedTitle: 'Instant Capture', icon: 'ic_camera'),
      const ShortcutItem(type: 'action_journal', localizedTitle: 'View Journal', icon: 'ic_journal'),
    ]);
  }

  @override
  void dispose() {
    _notifier.removeListener(_notifierListener);
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(index, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isLocked) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person_rounded, size: 72, color: Colors.grey),
              const SizedBox(height: 24),
              const Text("Vault Locked", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: _checkBiometricLock,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text("UNLOCK VAULT"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: [
          CameraScreen(key: const ValueKey('camera_screen'), cameras: widget.cameras, isActive: _selectedIndex == 0),
          HistoryScreen(key: const ValueKey('history_screen'), onCaptureRequested: () => _onItemTapped(0)),
          const AdvancementsScreen(key: ValueKey('advancements_screen')),
          const SettingsScreen(key: ValueKey('settings_screen')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.photo_camera_outlined), selectedIcon: Icon(Icons.photo_camera), label: 'Capture'),
          const NavigationDestination(icon: Icon(Icons.auto_awesome_motion_outlined), selectedIcon: Icon(Icons.auto_awesome_motion), label: 'Journal'),
          const NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Legacy'),
          NavigationDestination(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.tune_outlined),
                Positioned(
                  top: -8,
                  right: -12,
                  child: ScaleTransition(scale: const AlwaysStoppedAnimation(0.6), child: const StreakBadge()),
                ),
              ],
            ),
            selectedIcon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.tune_rounded),
                Positioned(
                  top: -8,
                  right: -12,
                  child: ScaleTransition(scale: const AlwaysStoppedAnimation(0.6), child: const StreakBadge()),
                ),
              ],
            ),
            label: 'Elite',
          ),
        ],
      ),
    );
  }
}
