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
  await NotificationService().init();
  
  await AchievementService().initNotificationState();
  
  final cameras = await availableCameras();
  runApp(
    SnapLogApp(cameras: cameras),
  );
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
    const roundedBorderRadius = 28.0;
    const buttonBorderRadius = 24.0;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11, 
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
          );
        }),
      ),

      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(roundedBorderRadius),
        ),
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
      ),

      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonBorderRadius),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonBorderRadius),
          ),
          side: BorderSide(color: colorScheme.outline, width: 1.5),
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
  late List<Widget> _screens;
  final QuickActions _quickActions = const QuickActions();
  final LocalAuthentication _auth = LocalAuthentication();
  late final EntriesNotifier _notifier;
  late final VoidCallback _notifierListener;
  bool _isLocked = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _screens = [
      CameraScreen(cameras: widget.cameras, isActive: _selectedIndex == 0),
      HistoryScreen(onCaptureRequested: () => _onItemTapped(0)),
      const AdvancementsScreen(),
      const SettingsScreen(),
    ];

    _initQuickActions();
    _checkBiometricLock();
    
    _notifier = EntriesNotifier();
    _notifierListener = () => _checkAchievements();
    _notifier.addListener(_notifierListener);
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAchievements());
  }

  Future<void> _checkBiometricLock() async {
    final settings = await SettingsService().getSettings();
    final bool biometricEnabled = settings['biometricLock'] ?? false;
    
    if (!biometricEnabled) {
      if (mounted) setState(() => _isLocked = false);
      return;
    }

    try {
      final bool authenticated = await _auth.authenticate(
        localizedReason: 'Please authenticate to access SnapLog Pro',
        options: const AuthenticationOptions(stickyAuth: true),
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
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Text(a.icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "ACHIEVEMENT UNLOCKED!",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      a.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
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
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              const Text("SnapLog Pro is Locked", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _checkBiometricLock,
                icon: const Icon(Icons.fingerprint),
                label: const Text("UNLOCK NOW"),
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
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.photo_camera_outlined),
            selectedIcon: Icon(Icons.photo_camera),
            label: 'Capture',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_motion_outlined),
            selectedIcon: Icon(Icons.auto_awesome_motion),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Achievements',
          ),
          NavigationDestination(
            icon: Padding(
              padding: EdgeInsets.only(top: 4),
              child: StreakBadge(size: 20),
            ),
            selectedIcon: Padding(
              padding: EdgeInsets.only(top: 4),
              child: StreakBadge(size: 20),
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
