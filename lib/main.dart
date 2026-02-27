import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/camera_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(SnapLogApp(cameras: cameras));
}

class SnapLogApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const SnapLogApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapLog Pro',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: MainNavigation(cameras: cameras),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    var baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: Colors.indigo,
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(baseTheme.textTheme),
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
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      CameraScreen(cameras: widget.cameras),
      const HistoryScreen(),
      const SettingsScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        elevation: 3,
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
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
