# SnapLog Pro 📸✨

**SnapLog Pro** is a high-performance, professional-grade daily photo-journaling application. It combines minimalist Material 3 design with mindful constraints to help you capture, track, and organize your life's journey with precision and style.

## 🚀 What's New (v1.6.0+8) - The "Control & Momentum" Update

- **📱 Android Home Widget**: Keep your journaling momentum front and center. Sync your Elite Streak directly to your Android home screen with the new reactive widget.
- **⚙️ Elite Control Center**: Completely revamped Settings tab. Organized into Pro categories like "Capture System" and "Tactile Engine" for a smoother configuration experience.
- **✨ Subtle Micro-interactions**: Smooth spring-scale animations on cards and grids for a more tactile, premium feel.
- **📖 Journal Archive 2.0**: Redesigned Journal tab with high-end typography, smoother transitions, and an "Animated Switcher" for seamless view mode changes.
- **🛡️ Google-Verified Local Security**: 
  - Integrated **Biometric Encryption** (Fingerprint/Face ID).
  - Disabled cleartext traffic for maximum data safety.
  - Certified Encrypted Local Storage (No cloud leaks).
- **🗺️ Memory Map**: Visualize your journey on an interactive globe. Every photo with location data is now plotted on your personal memory map.
- **⚡ Pro-Lazy Camera 2.5**: Final optimizations for camera initialization and memory cleanup, ensuring the fastest load times in its class.

## 🌟 Key Features

- **🏆 Achievement System**: 25+ unlockable badges based on streaks, mood variety, and consistency.
- **🎨 Live Viewfinder Filters**: Apply professional filters (B&W, Sepia, Cool, Warm) directly on the camera preview.
- **📊 Smart History & Archives**: 
  - **Dynamic Views**: Memoir, Mosaic, and Glimpse modes.
  - **Timeless Echoes**: Auto-surfacing memories from previous years.
  - **Emotional Pulse**: Visualize your emotional journey with integrated charts.
- **📸 Pro Camera Controls**: 
  - Max-quality capture with battery-efficient previews.
  - Exposure compensation slider for perfect lighting.
- **🧠 Mindfulness & Security**:
  - **Biometric Lock**: Secure your data with device-level authentication.
  - **Security Quizzes**: Math challenges protect critical actions.

## 🛠️ Technical Stack

- **Framework**: Flutter (Material 3)
- **Storage**: SQLite (sqflite) for local data persistence.
- **Authentication**: `local_auth` for Biometric security.
- **Widgets**: `home_widget` for Android Home integration.
- **Maps**: `google_maps_flutter` for memory visualization.

## 🏗️ Project Structure

```
lib/
├── main.dart                    # M3 Theme & Tab Navigation
├── widgets/                     # Reusable UI components
│   ├── entry_widgets.dart       # Enhanced Cards & Modals
│   ├── mood_selector.dart       # Animated mood tracker
│   └── streak_badge.dart        # Reactive Snapstreak icon
├── screens/
│   ├── camera_screen.dart       # Pro Viewfinder
│   ├── history_screen.dart      # Revamped Journal
│   ├── map_screen.dart          # Memory Map
│   ├── settings_screen.dart     # Control Center (Revamped)
│   └── quiz_screen.dart         # Security challenge system
└── services/
    ├── database_helper.dart     # DB Operations
    └── entries_notifier.dart    # Global state & Widget syncing
```

## 📖 Getting Started

1. **Clone & Install**:
   ```bash
   git clone https://github.com/LOST-4EVER/SnapLog.git
   flutter pub get
   ```
2. **Run**:
   ```bash
   flutter run
   ```

---

**developed by LOSY-4EVER ❤️ with Ai**  
*v1.6.0+8 - Control & Momentum Edition*
