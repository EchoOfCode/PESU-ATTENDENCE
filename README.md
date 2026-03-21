<div align="center">
  <img src="assets/icon.png" width="100" />
  <h1>PESU Attendance</h1>
  <p>A fast, beautifully designed Flutter app and Android Homescreen Widget for tracking attendance on PESU Academy.</p>
</div>

---

## ✨ Features

- **📱 Dynamic Homescreen Widget**: Your live attendance percentage, right on your Android homescreen. Refreshes automatically in the background every hour, or manually via a tap.
- **📌 Direct Widget Pinning**: Tap a single button inside the app to instantly prompt adding the widget to your homescreen (Android 8.0+).
- **🎨 3 Premium UI Themes (Syncs to Widget!)**:
  - `Default`: Sleek, dark "hacker" aesthetic with neon accents.
  - `Procrastinator (Funny)`: Brutalist, loud style with heavy borders and sarcastic status messages. 
  - `UwU Kawaii (Cute)`: Maximum rounded corners, pastel colors, and bubbly aesthetic to soften the blow of low attendance.
- **🧮 Smart Bunk Calculator**: Slide up the bottom sheet to calculate exactly how many classes you can skip (or must attend) to maintain a specific target percentage.
- **⚡ Super Fast Scraping**: Uses raw HTTP requests and HTML parsing (`dart:html`) instead of heavy headless browsers, keeping the app footprint microscopic.
- **🔒 Secure On-Device Storage**: Credentials are encrypted using the Android Keystore (`flutter_secure_storage`).

---

## 📸 Screenshots
*(Coming soon)*

---

## 🛠️ Architecture

- **Framework**: [Flutter](https://flutter.dev/) (Dart)
- **Background Sync**: [`workmanager`](https://pub.dev/packages/workmanager) triggers the silent scraper every hour.
- **Widget Bridge**: [`home_widget`](https://pub.dev/packages/home_widget) serializes attendance data to Android `SharedPreferences`.
- **Native Android**: A custom Kotlin `AppWidgetProvider` paired with `RemoteViews` layouts that programmatically read the Flutter Theme and draw the appropriate colors/shapes.
- **Edge-to-Edge UI**: Utilizes transparent system navigation and status bars for a modern, fluid user experience on modern Android devices.

## 🚀 Installation (for Developers)

To build and run the app from source:

1. **Install Flutter**: Make sure you have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
2. **Clone the Repo**:
   ```bash
   git clone https://github.com/EchoOfCode/PESU-ATTENDENCE.git
   cd PESU-ATTENDENCE
   ```
3. **Get Dependencies**:
   ```bash
   flutter pub get
   ```
4. **Compile the APK**:
   ```bash
   flutter build apk --debug
   ```
   *The built APK will be located at `build/app/outputs/flutter-apk/app-debug.apk`.*

## ⚠️ Disclaimer
This app is an **unofficial** third-party client. It is not endorsed by, directly affiliated with, or sponsored by PES University. It automates the login and scraping process of the student portal solely for convenience.
