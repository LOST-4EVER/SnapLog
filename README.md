# SnapLog Pro 📸✨

**SnapLog Pro** is a high-performance daily photo-journaling application. It combines minimalist Material 3 design with mindful constraints to help you capture and organize your life's journey.

## 🚀 What's New (v1.2.1)

- **⚡ Performance Core**: Optimized image decoding and memory management. The app now handles high-resolution captures without RAM spikes or freezing using smart lazy-loading and cache-constrained decoding.
- **🎨 UI Refinement**: Unified Material 3 button system with consistent sizing, outlines, and haptic feedback.
- **🛡️ Stability**: Improved async handling for permissions and notifications to ensure toggle states never get "stuck."
- **📸 Camera Pro**: Enhanced camera initialization lifecycle and exposure compensation for professional-grade photography.

## 🌟 Key Features

- **🎨 Live Viewfinder Filters**: Apply professional filters (B&W, Sepia, Cool, Warm) directly on the camera preview.
- **📊 Smart History & Archives**: 
  - **Dynamic Views**: Day, Month, and Year grid modes.
  - **On This Day**: Auto-surfacing memories from previous years.
- **📸 Pro Camera Controls**: 
  - Smooth digital zoom and multi-mode flash (including Torch).
  - Exposure compensation slider for perfect lighting.
- **🧠 Mindfulness Tools**:
  - **Daily Limits**: Set a limit (1-10 photos) to encourage intentional photography.
  - **Security Quizzes**: Math challenges protect your memories from accidental deletion.
- **📝 Rich Journaling**:
  - Mood tracking via emojis.
  - Auto-location tagging and editable captions.
  - **Share Pro**: Share entries or even the app APK directly from settings.

## 🛠️ Technical Stack

- **Framework**: Flutter (Material 3)
- **Storage**: SQLite (sqflite) for local data persistence.
- **Image Processing**: `flutter_image_compress` for 70%+ storage reduction without quality loss.
- **Optimization**: Lazy decoding (`cacheWidth`/`cacheHeight`) for butter-smooth scrolling and minimal memory footprint.

## 🏗️ Project Structure

```
lib/
├── main.dart                    # M3 Theme & Tab Navigation
├── models/
│   └── photo_entry.dart         # Entry data model
├── screens/
│   ├── camera_screen.dart       # Live viewfinder & capture
│   ├── history_screen.dart      # Journal, grid views, & archives
│   ├── settings_screen.dart     # Preferences & APK sharing
│   └── quiz_screen.dart         # Security challenge system
└── services/
    ├── database_helper.dart     # DB Operations
    └── notification_service.dart # Reminder logic
```

## 📖 Getting Started

1. **Clone & Install**:
   ```bash
   git clone <repository-url>
   flutter pub get
   ```
2. **Run**:
   ```bash
   flutter run
   ```

---

**developed by LOSY-4EVER ❤️ with Ai**  
*v1.2.1 - Performance Edition*
