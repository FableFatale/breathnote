# Breathnote Android

Breathnote (`息音`) is a Flutter harmonica-learning app for Android 13 and
newer.

## V1 features

- Five connected learning lessons with local completion progress and streaks
- Real microphone permission flow
- Real-time local pitch detection for single-note practice and tuning
- Note-by-note practice for four built-in songs
- Local custom-song creation with notation such as `4↑ 4↑ 6↑ 6↑`
- Generated guide tones with `0.5×` / `1×` speed and loop controls
- Configurable harmonica key, haptics, text scale, contrast, and motion
- Local nickname, practice statistics, and data-clear controls

Audio samples are analyzed on the Android device. Raw microphone audio is not
saved or uploaded. Microphone capture stops when the app leaves an active
practice or tuner flow.

Accounts, cloud synchronization, and payments are not included in this
version.

## Build and verify

```powershell
C:\Users\Administrator\flutter\bin\flutter.bat pub get
C:\Users\Administrator\flutter\bin\flutter.bat analyze
C:\Users\Administrator\flutter\bin\flutter.bat test
C:\Users\Administrator\flutter\bin\flutter.bat build apk --debug
```

The GitHub Actions Android workflow runs the same checks and uploads
`breathnote-debug-apk`.

The debug APK uses Android debug signing for internal testing. A private release
keystore is required before Play Store delivery.
