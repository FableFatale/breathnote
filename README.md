# 初鸣 Android

初鸣 is the first harmonica-learning product under the 鸣阶 brand. It supports
Android 13 and newer.

## V1 features

- Five connected learning lessons with local completion progress and streaks
- Real microphone permission flow
- Real-time local pitch detection for single-note practice and tuning
- Shared, persisted microphone detection sensitivity for practice and tuning
- Note-by-note practice for four built-in songs
- Local custom-song creation with notation such as `4↑ 4↑ 6↑ 6↑`
- Generated guide tones with `0.5×` / `1×` speed and loop controls
- System, light, and dark appearance modes
- Chinese, English, and Japanese interfaces
- Configurable harmonica key, haptics, text scale, contrast, and motion
- Local nickname, practice statistics, and data-clear controls

Audio samples are analyzed on the Android device. Raw microphone audio is not
saved or uploaded. Microphone capture stops when the app leaves an active
practice or tuner flow.

Accounts, cloud synchronization, and payments are not included in this
version.

## Build and verify

The project and CI currently use Flutter `3.47.9` with Dart `3.13.7`.

```powershell
C:\Users\Administrator\flutter\bin\flutter.bat pub get
C:\Users\Administrator\flutter\bin\flutter.bat analyze
C:\Users\Administrator\flutter\bin\flutter.bat test
C:\Users\Administrator\flutter\bin\flutter.bat build apk --debug
```

The GitHub Actions Android workflow runs the same checks and uploads
`breathnote-debug-apk`. The matching APK for the current source is written to
`artifacts/breathnote-current-debug.apk` after CI finishes. Each CI run summary
records the exact commit and APK SHA-256 used for that build.

The debug APK uses Android debug signing for internal testing. A private release
keystore is required before Play Store delivery.
