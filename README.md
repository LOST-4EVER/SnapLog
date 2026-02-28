# SnapLog Pro 📸✨

**SnapLog Pro** is a high-performance, professional-grade daily photo-journaling application. It combines minimalist Material 3 design with mindful constraints to help you capture, track, and organize your life's journey with precision and style.

## 🚀 What's New (v1.5.0+7) - The "Aesthetic Memoir" Update

- **✨ Subtle Micro-interactions**: Added spring-scale animations to cards and grid items for a more tactile, premium feel.
- **📖 Journal Archive Revamp**: A completely redesigned Journal tab with smoother transitions, better typography, and an "Animated Switcher" for seamless view mode changes.
- **✍️ Glassmorphic Memoir Editor**: Revamped the caption editing experience with a glassmorphic design and smoother "Animated Switcher" transitions between display and edit modes.
- **🛡️ Elite Security**: Integrated Biometric Lock (Fingerprint/Face ID) to keep your memories truly private.
- **🗺️ Memory Map**: Visualize your journey on an interactive globe. Every photo with location data is now plotted on your personal memory map.
- **🔥 Snapstreak Optimization**: The streak icon now "lights up" and animates the moment you capture your first photo of the day.
- **⚡ Pro-Lazy Camera 2.0**: Further optimized camera initialization and memory cleanup for maximum battery efficiency.

## 🌟 Key Features

- **🏆 Achievement System**: 25+ unlockable badges based on streaks, mood variety, and consistency.
- **🎨 Live Viewfinder Filters**: Apply professional filters (B&W, Sepia, Cool, Warm) directly on the camera preview.
- **📊 Smart History & Archives**: 
  - **Dynamic Views**: Memoir, Mosaic, and Glimpse modes.
  - **Timeless Echoes**: Auto-surfacing memories from previous years.
  - **Emotional Pulse**: Visualize your emotional journey with integrated charts.
- **📸 Pro Camera Controls**: 
  - Max-quality capture with battery-efficient previews.
  - Smooth digital zoom and multi-mode flash.
  - Exposure compensation slider for perfect lighting.
- **🧠 Mindfulness & Security**:
  - **Biometric Lock**: Secure your data with device-level authentication.
  - **Security Quizzes**: Math challenges protect critical actions.
- **🎙️ Speech-to-Text**: Record your thoughts instantly using integrated voice-to-caption technology.

## 🛠️ Technical Stack

- **Framework**: Flutter (Material 3)
- **Storage**: SQLite (sqflite) for local data persistence.
- **Authentication**: `local_auth` for Biometric security.
- **Maps**: `google_maps_flutter` for memory visualization.
- **Optimization**: Lazy decoding and **Lazy Camera Initialization**.

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
│   ├── advancements_screen.dart # Legacy & Badges
│   ├── settings_screen.dart     # Pro Preferences
│   └── quiz_screen.dart         # Security challenge system
└── services/
    ├── database_helper.dart     # DB Operations
    ├── entries_notifier.dart    # Global state syncing
    └── notification_service.dart # Smart reminder logic
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
*v1.5.0+7 - Aesthetic Memoir Edition*
