# 初鸣 Android

初鸣 is the first harmonica-learning product under the 鸣阶 brand. It supports
Android 13 and newer.

## Current features (v1.8.0)

See the full product specification in [docs/PRD.md](docs/PRD.md).

- First-launch harmonica registration (defaults to C 10-hole, skippable) with Hole-4 blow auto key detection, quick key switching, and Pro multi-harmonica presets
- Seven progressive learning lessons (Lessons 01–05 free, Lessons 06–07 Pro): includes dedicated Breathing (`02`) and Chord & Rhythm (`07`, beat pulse + breath volume envelope + chord guide demo)
- Real microphone permission flow
- Real-time local pitch detection for single-note practice and tuning, paired with a live 1–10 hole harmonica strip (highlighting enharmonic `2↓`/`3↑` together)
- 10-hole harmonica checkup, session pitch distribution, and 7-day weak-note accuracy map
- Shared, persisted microphone detection sensitivity for practice and tuning
- Dual-mode song practice (Follow mode + Beat-synced Scoring mode with 4-beat count-in, live score/combo, 1–3 stars, and Pro 3D Pitch/Timing/Stability breakdown + tap-to-hear note review + tailored coaching tip)
- Eight copyright-clean public-domain & original songs (3 starter songs free, 5 songs + custom songs Pro) with star badges, favorites, and `All / Starter / Done / Saved` filters
- 3-step custom song import wizard: Tab/Jianpu (`1-7`) input or native local MIDI (`.mid`) / MusicXML (`.xml/.musicxml`) import → auto optimal transposition, bend preview & skip-bend practice mode → enharmonic (`2↓`/`3↑`) least-hand-movement check & custom cover icons
- Real 48-hour new-player offer (computed from persisted `firstInstallAt`) with automatic transition to standard lifetime Pro buyout pricing, Restore Purchases, and native billing MethodChannel bridge (`app.breathnote/billing`)
- Generated guide tones with `0.5×` / `1×` speed and loop controls
- Achievement share cards after completing lessons and songs
- System, light, and dark appearance modes (Palermo 2.0 design system)
- Chinese, English, and Japanese interfaces
- Configurable 12-key harmonica tuning, haptics, text scale, high contrast, and reduced motion
- Local nickname, practice statistics, and data-clear controls

Audio samples are analyzed on the Android device. Raw microphone audio is not
saved or uploaded. Microphone capture stops when the app leaves an active
practice or tuner flow.

Self-hosted user accounts and cloud synchronization are intentionally omitted;
Pro lifetime entitlement uses local persistence plus store Restore Purchases.

## Build and verify

The project and CI currently use Flutter `3.47.9` with Dart `3.13.7`.

```powershell
C:\Users\Administrator\flutter\bin\flutter.bat pub get
C:\Users\Administrator\flutter\bin\flutter.bat analyze
C:\Users\Administrator\flutter\bin\flutter.bat test
C:\Users\Administrator\flutter\bin\flutter.bat build apk --debug
```

### Release signing

Copy `android/key.properties.example` to `android/key.properties` (gitignored) and point `storeFile` to your private release keystore (or provide `RELEASE_STORE_FILE`, `RELEASE_STORE_PASSWORD`, `RELEASE_KEY_ALIAS`, `RELEASE_KEY_PASSWORD` in CI), then run:

```powershell
C:\Users\Administrator\flutter\bin\flutter.bat build apk --release
```

The GitHub Actions Android workflow runs the same checks and uploads
`breathnote-debug-apk`. The matching APK for the current source is written to
`artifacts/breathnote-current-debug.apk` after CI finishes. Each CI run summary
records the exact commit and APK SHA-256 used for that build.
