# ML Data Collection App

An Android application for capturing labelled image datasets intended for machine learning classification tasks. Images are captured via the device camera, resized to 128x128 RGB PNG, and stored locally with a folder hierarchy that encodes the class labels. The entire dataset can be exported as a ZIP archive ready for model training.

## Class Labels

The application supports the following 12 object classes:

```
pen, paper, book, clock, phone, laptop,
chair, desk, bottle, keychain, backpack, calculator
```

## Dataset Format

Images are stored under the following folder structure inside the ZIP export:

```
dataset.zip
    backpack/
        img0.png
        img1.png
    backpack_chair/
        img0.png
    pen_paper_book/
        img0.png
    ...
```

- A single-class image is placed in `<class>/`.
- A multi-class image is placed in `<class1>_<class2>_.../` where labels are sorted alphabetically.
- All images are 128x128 pixels, RGB, PNG format.

---

## Prerequisites

| Tool | Minimum Version |
|---|---|
| Flutter SDK | 3.41.0 |
| Dart SDK | 3.11.0 |
| Java JDK | 17 |
| Android SDK | API 35 / 36 |
| Android Build Tools | 28.0.3 |
| Android NDK | bundled with Flutter |
| Target device | Android 11+ (API 30+) for wireless debugging |

---

## Development Environment Setup

### 1. Install Flutter

Download the Flutter SDK and extract it:

```bash
wget -O ~/flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.41.5-stable.tar.xz
tar xJf ~/flutter.tar.xz -C ~/
```

Add Flutter to your PATH (add this line to `~/.bashrc` or `~/.zshrc`):

```bash
export PATH="$PATH:$HOME/flutter/bin"
```

Verify:

```bash
flutter --version
```

### 2. Install Java 17

```bash
sudo apt-get update
sudo apt-get install -y openjdk-17-jdk
sudo update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java
```

Add to `~/.bashrc` or `~/.zshrc`:

```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
```

### 3. Install Android SDK Command-Line Tools

```bash
mkdir -p ~/Android/Sdk/cmdline-tools
wget -O /tmp/cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip /tmp/cmdline-tools.zip -d /tmp/cmdtools
mv /tmp/cmdtools/cmdline-tools ~/Android/Sdk/cmdline-tools/latest
```

Add to `~/.bashrc` or `~/.zshrc`:

```bash
export ANDROID_HOME=$HOME/Android/Sdk
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"
```

Accept licenses and install required SDK components:

```bash
printf 'y\ny\ny\ny\ny\ny\ny\ny\n' | sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-36" "build-tools;28.0.3"
```

### 4. Install Additional Build Tools

```bash
sudo apt-get install -y ninja-build
```

### 5. Verify Setup

```bash
flutter doctor
```

All items except the Linux desktop toolchain should show as passing (the app targets Android only).

---

## Building the App

### Clone the repository

```bash
git clone <repository-url>
cd data_collection_app
```

### Install dependencies

```bash
flutter pub get
```

### Build a debug APK

```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Build a release APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## Installing on a Device

### Option 1: USB / ADB

```bash
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### Option 2: Wireless Debugging (Android 11+)

1. On the device: Settings > Developer Options > Wireless Debugging > Pair device with pairing code
2. Note the pairing IP:port and the 6-digit pairing code.
3. After pairing, note the connection IP:port on the main Wireless Debugging screen.

```bash
# Ensure the newer platform-tools adb is used
export PATH="$HOME/Android/Sdk/platform-tools:$PATH"

# Pair (one-time)
adb pair <ip>:<pairing-port>

# Connect
adb connect <ip>:<connection-port>

# Verify
adb devices
```

### Option 3: Flutter run (direct)

With a device connected and visible in `adb devices`:

```bash
flutter run
```

---

## Using the App

1. **Select classes**: Tap one or more class chips on the home screen. The folder name under which the image will be saved is shown as a preview.
2. **Capture**: Tap the camera button to open the camera and press the shutter to capture. Each photo is automatically resized to 128x128 RGB PNG and saved.
3. **Delete last photo**: Tap the thumbnail in the bottom-left of the camera screen to delete the most recently captured image.
4. **Gallery**: Tap the gallery icon in the top-right to browse all collected images by folder. Long-press any image to delete it.
5. **Export ZIP**: Tap the archive icon in the top-right of the home screen to generate `ml_dataset_<timestamp>.zip` in the app documents directory.

---

## Project Structure

```
lib/
    main.dart                  Application entry point
    screens/
        home_screen.dart       Class selection, stats, and navigation
        camera_screen.dart     Camera preview and image capture
        gallery_screen.dart    Folder and image browser
    utils/
        image_saver.dart       Image decode, resize, and persistence
        zip_exporter.dart      ZIP archive generation
android/
    app/src/main/
        AndroidManifest.xml    Camera and storage permissions
```

## Key Dependencies

| Package | Purpose |
|---|---|
| `camera` | Camera preview and image capture |
| `image` | Image decoding and resizing in an isolate |
| `path_provider` | App documents directory path |
| `archive` | ZIP file creation |
| `permission_handler` | Runtime permission requests |
| `share_plus` | Optional file sharing |

---

## CI / CD

A GitHub Actions workflow is included at `.github/workflows/build.yml`. It triggers on every push to `main` and on version tags (`v*.*.*`). Tagged builds automatically create a GitHub Release and attach the APK.

See [.github/workflows/build.yml](.github/workflows/build.yml) for configuration details.
