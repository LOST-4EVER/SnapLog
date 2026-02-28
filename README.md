# SnapLog Pro 📸✨

**SnapLog Pro** is a high-performance, professional-grade daily photo-journaling application. It combines minimalist Material 3 design with mindful constraints to help you capture, track, and organize your life's journey with precision and style.

## 🚀 What's New (v1.3.0+5) - The "Synchronized Legacy" Update

- **🏆 Legacy & Badges**: A completely revamped achievement system. Track your progress simultaneously with your journal entries. Includes a new **Milestones** tab to see exactly what challenge is next.
- **⚡ Pro-Lazy Camera**: Significant performance boost. The camera hardware now only initializes when the Capture tab is active and disposes instantly when switching, saving battery and memory.
- **🔄 Simultaneous Sync**: All tabs (Capture, Journal, Achievements, Settings) now work in perfect harmony. A photo taken in the camera instantly updates your journal and unlocks badges in real-time.
- **🛡️ Enhanced Security**: Quizzes are now more dynamic and integrated with system haptics. Critical actions are protected by varying difficulty levels.
- **📱 Modern UI Revamp**: Cleaned up every screen with better spacing, consistent Material 3 styling, and a new **Community** section in Settings.
- **📝 Optimized Journal**: Improved "Empty State" with direct navigation to the camera and smoother grid transitions.

## 🌟 Key Features

- **🏆 Achievement System**: 25+ unlockable badges based on streaks, mood variety, and consistency.
- **🎨 Live Viewfinder Filters**: Apply professional filters (B&W, Sepia, Cool, Warm) directly on the camera preview.
- **📊 Smart History & Archives**: 
  - **Dynamic Views**: Day, Month, and Year grid modes.
  - **On This Day**: Auto-surfacing memories from previous years.
  - **Mood Trends**: Visualize your emotional journey with integrated charts.
- **📸 Pro Camera Controls**: 
  - Smooth digital zoom and multi-mode flash (including Torch).
  - Exposure compensation slider for perfect lighting.
  - **System Camera Toggle**: Use your phone's native high-end hardware for maximum AI processing.
- **🧠 Mindfulness & Security**:
  - **Daily Limits**: Set a limit (1-10 photos) to encourage intentional photography.
  - **Security Quizzes**: Math challenges protect your memories from accidental deletion or limit changes.
- **🎙️ Speech-to-Text**: Record your thoughts instantly using integrated voice-to-caption technology.
- **📝 Rich Journaling**:
  - 24+ Mood tracking emojis.
  - Auto-location tagging and editable captions.

## 🛠️ Technical Stack

- **Framework**: Flutter (Material 3)
- **Storage**: SQLite (sqflite) for local data persistence.
- **Image Processing**: `flutter_image_compress` for 70%+ storage reduction without quality loss.
- **Optimization**: Lazy decoding (`cacheWidth`/`cacheHeight`) and **Lazy Camera Initialization** for a minimal memory footprint.
- **State Management**: Reactive `ChangeNotifier` pattern for simultaneous updates across all screens.

## 🏗️ Project Structure

```
lib/
├── main.dart                    # M3 Theme & Tab Navigation
├── widgets/                     # Reusable UI components (New!)
│   ├── entry_widgets.dart       # Journal cards & modals
│   └── mood_selector.dart       # Animated mood tracker
├── screens/
│   ├── camera_screen.dart       # Lazy-loading viewfinder
│   ├── history_screen.dart      # Journal & grid modes
│   ├── advancements_screen.dart # Legacy & Badges (Revamped)
│   ├── settings_screen.dart     # Pro Preferences & Community
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
*v1.3.0+5 - Synchronized Legacy Edition*
