# Breathnote Android

Flutter implementation of the Breathnote harmonica-learning UI.

## V1 scope

- Android 13 and newer (`minSdk 33`)
- Learn, songs, tuner demo, profile, and single-note practice screens
- Local UI state only
- No microphone capture, account backend, synchronization, or payments

## Build

```powershell
C:\Users\Administrator\flutter\bin\flutter.bat pub get
C:\Users\Administrator\flutter\bin\flutter.bat test
C:\Users\Administrator\flutter\bin\flutter.bat build apk --debug
```

The initial build uses the Android debug signing key and is intended for
internal testing. Add a private release keystore before Play Store delivery.
