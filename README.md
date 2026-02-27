# SnapLog Pro

**SnapLog Pro** is a professional-grade daily photo-journaling application optimized for **Android 16**. It combines minimalist Material 3 design with powerful features to help you capture and organize your daily moments with ease.

## 🚀 Key Features

- **🎨 Live Filters**: Apply professional filters directly on the camera preview:
  - **Black & White**: Convert to grayscale for classic photography
  - **Sepia**: Vintage-style warm tone filter
  - **Vivid**: Enhanced color saturation
  - **Normal**: Unfiltered natural colors

- **📝 Photo Journaling**: Add meaningful context to every photo:
  - Write custom captions for your moments
  - Track your mood with emoji-based selector (😊, 📸, 🌟, 😴, 🍕, 🌈, ☕, 🎉)
  - Automatic timestamps for each entry

- **📊 Smart History Log**: 
  - SQLite-backed persistent storage
  - Browse all your entries with beautiful Material 3 cards
  - Filter information displayed (which filter was used)
  - Chronological ordering with detailed timestamps
  - High-resolution image preview

- **📸 Advanced Camera Controls**: 
  - **Digital Zoom**: Smooth slider-based zoom from 1x to 5x+
  - **Flash Toggle**: Quick toggle for lighting conditions
  - **Daily Limits**: Track and manage your daily photo goals (configurable)
  - Real-time daily count display

- **🛠️ Settings & Maintenance**:
  - **Clear Cache**: Free up space from temporary camera files
  - **Full Data Reset**: Permanently wipe all logs and photos (with confirmation)
  - **Daily Limit Configuration**: Set your personal daily photo goals
  - App information and version details

- **🎯 Material 3 Design**: 
  - Modern, clean UI with professional appearance
  - Dark mode support
  - Smooth animations and transitions
  - Responsive layout for all screen sizes

## ⚙️ Technical Specifications

- **Platform**: Flutter (Cross-platform support)
- **Target SDK**: Android 16 (SDK 35)
- **Dart/Flutter Version**: Dart 3.11.0 / Flutter 3.41.2+
- **Database**: SQLite (via sqflite)
- **Design System**: Material 3 (useMaterial3: true)
- **State Management**: Provider for scalable architecture

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  camera: ^0.11.0+2          # Camera capture and preview
  sqflite: ^2.3.3+3          # Local SQLite database
  path_provider: ^2.1.3      # File system access
  path: ^1.9.0               # Path utilities
  intl: ^0.19.0              # Internationalization
  provider: ^6.1.2           # State management
  shared_preferences: ^2.2.3 # Settings persistence
  google_fonts: ^6.2.1       # Material 3 typography
```

## 🏗️ Project Structure

```
lib/
├── main.dart                    # App entry point, navigation hub
├── models/
│   └── photo_entry.dart         # Photo entry data model
├── screens/
│   ├── camera_screen.dart       # Camera capture with filters & zoom
│   ├── history_screen.dart      # Photo history and entries
│   ├── entry_detail_screen.dart # Photo details & metadata entry
│   └── settings_screen.dart     # Settings & maintenance
└── services/
    ├── database_helper.dart     # SQLite database operations
    ├── camera_service.dart      # Camera control service
    └── settings_service.dart    # Settings & preferences management
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.11.0 or higher
- Android SDK 35 (API level 35)
- A device with Android 16 or Dart VM for testing

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd snaplog
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

### Building for Release

```bash
# Build APK
flutter build apk --release

# Build App Bundle (for Google Play)
flutter build appbundle --release
```

## 📖 User Guide

### Taking a Photo

1. **Navigate to Camera tab** at the bottom navigation
2. **Select a filter** from the horizontal filter list
3. **Adjust zoom** using the slider (1x - 5x+)
4. **Toggle flash** if needed
5. **Tap the camera button** to capture
6. **Add caption** describing your moment
7. **Select your mood** emoji
8. **Save Entry** to add to history

### Viewing History

1. **Navigate to History tab**
2. **Scroll through** your photo entries
3. Each card shows:
   - High-resolution photo thumbnail
   - Applied filter badge
   - Mood emoji
   - Timestamp
   - Caption text

### Managing Settings

1. **Navigate to Settings tab**
2. **Clear Cache**: Remove temporary files to free up storage
3. **Full Data Reset**: Permanently delete all entries (requires confirmation)
4. **Daily Limit**: Configure your daily photo goals
5. **View App Info**: Check version and app details

## 🧹 Maintenance

### Database Management

The app uses SQLite to store:
- **photo_entries**: Photo metadata, captions, moods, filters, timestamps
- **app_settings**: User preferences and configuration

Data is stored locally on the device and never transmitted to external servers.

### Cache Management

The app automatically manages temporary camera files. Use the "Clear Cache" feature to manually free up space when needed.

### Daily Photo Counting

The app tracks daily photo counts using `shared_preferences` to help you stay on track with your journaling goals. Counts reset at midnight.

## 🎨 UI/UX Highlights

- **Bottom Navigation**: Easy access to Camera, History, and Settings
- **Material 3 Cards**: Beautiful, elevated cards for photo entries
- **Real-time Zoom Display**: Visual feedback on zoom level
- **Daily Limit Counter**: Always visible in camera view
- **Smooth Transitions**: Professional animations between screens
- **Dark Mode Support**: Full Material 3 dark theme support

## 🐛 Troubleshooting

### Camera Not Working
- Ensure camera permissions are granted in Android settings
- Check that the device has an available camera
- Restart the app

### Database Issues
- Use "Full Data Reset" to clear corrupted data
- Reinstall the app if issues persist

### Performance Issues
- Clear cache regularly
- Remove old entries from history if needed
- Update to the latest Flutter version

## 📝 Code Quality

The project maintains high code quality standards:
- ✅ Zero Flutter analysis warnings/errors
- ✅ Clean architecture with modular services
- ✅ Proper error handling and user feedback
- ✅ Responsive and accessible UI

## 📄 License

This project is provided as-is for personal and educational use.

## 🙌 Contributing

We welcome contributions! Please ensure:
1. Code follows Flutter best practices
2. No new warnings/errors introduced
3. Changes are documented
4. Functionality is tested

## 📞 Support

For issues or feature requests, please open an issue in the project repository.

---

**SnapLog Pro** - *Capturing your journey, one day at a time.* 📸✨
