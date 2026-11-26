#!/usr/bin/env bash
set -euo pipefail

# Builds Breathnote iOS (unsigned Release IPA and/or Simulator .app) with:
# - Isolated per-worktree DerivedData (`<worktree>/build/ios-derived-data`)
# - Global shared LLVM CAS compilation cache (`~/.cache` / `~/Library/Developer/Xcode/CompilationCache.noindex`)
# - Canonical prefix mapping across git worktrees (`/^worktree`, `/^derived`, `/^flutter`, `/^pubcache`)

BUILD_IPA=1
BUILD_SIMULATOR=1
CAS_REMARKS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ipa-only)
      BUILD_IPA=1
      BUILD_SIMULATOR=0
      shift
      ;;
    --simulator-only)
      BUILD_IPA=0
      BUILD_SIMULATOR=1
      shift
      ;;
    --cas-remarks)
      CAS_REMARKS=1
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
WORKTREE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$WORKTREE_ROOT"

RAW_DERIVED_DATA_DIR="${BREATHNOTE_DERIVED_DATA_DIR:-$WORKTREE_ROOT/build/ios-derived-data}"
RAW_CAS_CACHE_DIR="${BREATHNOTE_CAS_CACHE_DIR:-$HOME/Library/Developer/Xcode/CompilationCache.noindex}"
mkdir -p "$RAW_DERIVED_DATA_DIR" "$RAW_CAS_CACHE_DIR" "$WORKTREE_ROOT/artifacts"
export BREATHNOTE_DERIVED_DATA_DIR="$(cd "$RAW_DERIVED_DATA_DIR" && pwd -P)"
export BREATHNOTE_CAS_CACHE_DIR="$(cd "$RAW_CAS_CACHE_DIR" && pwd -P)"

# 1. Bootstrap missing Xcode project files without overwriting existing custom Swift/Info.plist/icons
if [[ ! -f "$WORKTREE_ROOT/ios/Runner.xcodeproj/project.pbxproj" ]]; then
  echo "==> Bootstrapping missing iOS Xcode template files via Flutter..."
  flutter create --platforms=ios --org app.breathnote --project-name breathnote .
  # Remove default generated SceneDelegate entries if Flutter generated UIApplicationSceneManifest,
  # keeping our custom Info.plist / AppDelegate / xcconfigs intact.
fi

flutter pub get

# 2. Prepare Flutter iOS build configuration (generates Generated.xcconfig / Podfile / SwiftPM)
if [[ "$BUILD_IPA" -eq 1 ]]; then
  flutter build ios --config-only --release --no-codesign
else
  flutter build ios --config-only --debug --simulator --no-codesign
fi

# 3. Apply per-worktree DerivedData + shared CAS + worktree prefix mapping to Runner & Podfile
bash "$WORKTREE_ROOT/scripts/configure_ios_cache.sh"

if [[ -f "$WORKTREE_ROOT/ios/Podfile" ]] && find "$WORKTREE_ROOT/ios/Flutter" -maxdepth 2 -name "Flutter.podspec" 2>/dev/null | grep -q .; then
  (cd "$WORKTREE_ROOT/ios" && pod install)
  # Re-apply after pod install in case CocoaPods regenerated target support files
  bash "$WORKTREE_ROOT/scripts/configure_ios_cache.sh"
fi

if [[ -f "$WORKTREE_ROOT/ios/Runner.xcworkspace/contents.xcworkspacedata" ]]; then
  XCODE_CONTAINER=(-workspace "$WORKTREE_ROOT/ios/Runner.xcworkspace")
else
  XCODE_CONTAINER=(-project "$WORKTREE_ROOT/ios/Runner.xcodeproj")
fi

EXTRA_XCODE_ARGS=(
  "COMPILATION_CACHE_ENABLE_CACHING=YES"
  "COMPILATION_CACHE_CAS_PATH=$BREATHNOTE_CAS_CACHE_DIR"
  "COMPILATION_CACHE_KEEP_LOCAL_DIRECTORY=YES"
  "MODULE_CACHE_DIR=$BREATHNOTE_CAS_CACHE_DIR/ModuleCache.noindex"
  "CLANG_ENABLE_PREFIX_MAPPING=YES"
  "CLANG_ENABLE_PROJECT_PREFIX_MAPPING=YES"
  "SWIFT_ENABLE_PREFIX_MAPPING=YES"
  "SWIFT_ENABLE_PROJECT_PREFIX_MAPPING=YES"
  "SWIFT_USE_INTEGRATED_DRIVER=YES"
  "SWIFT_ENABLE_EXPLICIT_MODULES=YES"
  "SWIFT_ENABLE_BATCH_MODE=NO"
)

if [[ "$CAS_REMARKS" -eq 1 ]]; then
  EXTRA_XCODE_ARGS+=("COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=YES")
fi

# 4. Build Device Release (.ipa, unsigned)
if [[ "$BUILD_IPA" -eq 1 ]]; then
  flutter build ios --config-only --release --no-codesign
  bash "$WORKTREE_ROOT/scripts/configure_ios_cache.sh"

  echo "==> Compiling iOS Release (iphoneos) with per-worktree DerivedData & shared CAS..."
  xcodebuild build \
    "${XCODE_CONTAINER[@]}" \
    -scheme Runner \
    -configuration Release \
    -sdk iphoneos \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$BREATHNOTE_DERIVED_DATA_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    "${EXTRA_XCODE_ARGS[@]}"

  APP_PATH="$BREATHNOTE_DERIVED_DATA_DIR/Build/Products/Release-iphoneos/Runner.app"
  if [[ ! -d "$APP_PATH" ]]; then
    echo "Expected Release Runner.app not found at $APP_PATH" >&2
    exit 1
  fi

  STAGE_DIR="$BREATHNOTE_DERIVED_DATA_DIR/ipa_stage"
  rm -rf "$STAGE_DIR"
  mkdir -p "$STAGE_DIR/Payload"
  cp -R "$APP_PATH" "$STAGE_DIR/Payload/Runner.app"
  IPA_OUT="$WORKTREE_ROOT/artifacts/breathnote-current-ios-unsigned.ipa"
  rm -f "$IPA_OUT"
  (cd "$STAGE_DIR" && ditto -c -k --sequesterRsrc --keepParent Payload "$IPA_OUT")
  rm -rf "$STAGE_DIR"
  echo "==> Packaged unsigned iOS IPA: $IPA_OUT"
fi

# 5. Build Simulator Debug (.app.zip)
if [[ "$BUILD_SIMULATOR" -eq 1 ]]; then
  flutter build ios --config-only --debug --simulator --no-codesign
  bash "$WORKTREE_ROOT/scripts/configure_ios_cache.sh"

  echo "==> Compiling iOS Simulator (iphonesimulator) with per-worktree DerivedData & shared CAS..."
  xcodebuild build \
    "${XCODE_CONTAINER[@]}" \
    -scheme Runner \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$BREATHNOTE_DERIVED_DATA_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    "${EXTRA_XCODE_ARGS[@]}"

  SIM_APP_PATH="$BREATHNOTE_DERIVED_DATA_DIR/Build/Products/Debug-iphonesimulator/Runner.app"
  if [[ ! -d "$SIM_APP_PATH" ]]; then
    echo "Expected Simulator Runner.app not found at $SIM_APP_PATH" >&2
    exit 1
  fi

  SIM_ZIP_OUT="$WORKTREE_ROOT/artifacts/breathnote-current-ios-simulator.app.zip"
  rm -f "$SIM_ZIP_OUT"
  ditto -c -k --sequesterRsrc --keepParent "$SIM_APP_PATH" "$SIM_ZIP_OUT"
  echo "==> Packaged iOS Simulator app: $SIM_ZIP_OUT"
fi
