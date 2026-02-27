# SnapLog Pro 📸✨

**SnapLog Pro** is a professional-grade daily photo-journaling application. It combines minimalist Material 3 design with powerful features to help you capture and organize your daily moments with ease.

## 🚀 Key Features

- **🎨 Live Viewfinder Filters**: Apply professional filters directly on the camera preview:
  - **Black & White**: Grayscale for classic photography.
  - **Sepia**: Vintage-warm tones.
  - **Cool/Warm**: Atmospheric temperature shifts.
  - **Normal**: Natural colors.

- **📝 Advanced Photo Journaling**:
  - Write custom captions for your moments.
  - Track your mood with an integrated emoji selector.
  - **Edit Captions**: Update your thoughts even after saving.
  - **Share Everything**: Share your journal entries or the app APK directly via Quick Share, Bluetooth, etc.

- **📊 Smart History & Archives**: 
  - **View Modes**: Daily, Monthly, and Yearly grid views.
  - **On This Day**: Relive moments from previous years.
  - SQLite-backed persistent storage with chronological ordering.

- **📸 Pro Camera Controls**: 
  - **Digital Zoom**: Smooth slider-based zoom.
  - **Multimode Flash**: Off, Auto, Always, and **Torch** (Flashlight) modes.
  - **Daily Limits**: Configurable capture goals to help you stay mindful.
  - **Security**: Math-based "Security Checks" for sensitive actions like deleting memories or changing limits.

- **🛠️ Robust Settings**:
  - **Default Filter**: Set your favorite filter to apply automatically.
  - **Image Quality**: Manage resolution vs. storage space.
  - **Daily Reminders**: Scheduled notifications to never miss a day.
  - **Maintenance**: Clear cache or perform a full data wipe (secured by quiz).

- **🎯 Performance & Optimization**:
  - **Responsive Design**: Works perfectly on all screen sizes and aspect ratios.
  - **Smart Compression**: Built-in optimization to reduce photo file sizes by up to 70%.
  - **Memory Efficient**: Uses lazy loading and background camera "warm-up" for instant tab switching.

## ⚙️ Technical Specifications

- **Design System**: Material 3 (Google Spec)
- **Database**: SQLite (via sqflite)
- **Target SDK**: Android 16 (API 35)
- **Primary Font**: Plus Jakarta Sans
- **Optimization**: ProGuard/R8 ready with on-the-fly JPEG compression

## 📦 Core Dependencies

```yaml
dependencies:
  camera: ^0.11.0+2          # Capture logic
  sqflite: ^2.3.3+3          # Database
  share_plus: ^10.0.0        # Native sharing
  flutter_image_compress: ^2.3.0 # File size optimization
  flutter_local_notifications: ^17.1.2 # Reminders
```

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

## 🧹 Optimization Tips

- **App Size**: Build using `flutter build apk --split-per-abi` for the smallest footprint.
- **Storage**: The app automatically compresses images to ~85% quality to save space while maintaining detail.

---

**made by LOSY-4EVER ❤️ with Ai**  
*v1.2.0 - Capturing your journey, one day at a time.*
