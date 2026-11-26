#!/usr/bin/env bash
set -euo pipefail

# Configures per-worktree isolated DerivedData, global shared LLVM CAS cache,
# and canonical scanner-level Prefix Mapping (including git worktree root mapping)
# so Clang & Swift builds across git worktrees achieve ~100% CAS cache hits.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
RAW_WORKTREE_ROOT="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel 2>/dev/null || (cd "$SCRIPT_DIR/.." && pwd))"
WORKTREE_ROOT="$(cd "$RAW_WORKTREE_ROOT" && pwd -P)"

RAW_DERIVED_DATA="${BREATHNOTE_DERIVED_DATA_DIR:-$WORKTREE_ROOT/build/ios-derived-data}"
mkdir -p "$RAW_DERIVED_DATA"
DERIVED_DATA_DIR="$(cd "$RAW_DERIVED_DATA" && pwd -P)"

RAW_CAS_DIR="${BREATHNOTE_CAS_CACHE_DIR:-$HOME/Library/Developer/Xcode/CompilationCache.noindex}"
mkdir -p "$RAW_CAS_DIR" "$RAW_CAS_DIR/ModuleCache.noindex"
CAS_CACHE_DIR="$(cd "$RAW_CAS_DIR" && pwd -P)"

RAW_PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
mkdir -p "$RAW_PUB_CACHE"
PUB_CACHE_DIR="$(cd "$RAW_PUB_CACHE" && pwd -P)"

FLUTTER_ROOT_DIR=""
if [[ -f "$WORKTREE_ROOT/ios/Flutter/Generated.xcconfig" ]]; then
  GEN_FLUTTER_ROOT="$(grep -E '^FLUTTER_ROOT=' "$WORKTREE_ROOT/ios/Flutter/Generated.xcconfig" | head -n 1 | cut -d'=' -f2- || true)"
  if [[ -n "$GEN_FLUTTER_ROOT" && -d "$GEN_FLUTTER_ROOT" ]]; then
    FLUTTER_ROOT_DIR="$(cd "$GEN_FLUTTER_ROOT" && pwd -P)"
  fi
fi
if [[ -z "$FLUTTER_ROOT_DIR" ]] && command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN="$(command -v flutter)"
  FLUTTER_BIN_DIR="$(cd "$(dirname "$FLUTTER_BIN")" && pwd -P)"
  FLUTTER_ROOT_DIR="$(cd "$FLUTTER_BIN_DIR/.." && pwd -P)"
fi

mkdir -p "$WORKTREE_ROOT/ios/Flutter"

# Use ONLY scanner/depscan prefix maps (`-fdepscan-prefix-map` and `-scanner-prefix-map`),
# NOT `-ffile-prefix-map` / `-file-prefix-map` (which forward raw worktree paths into -cc1
# and poison LLVM CAS keys). Also set `-file-compilation-dir /^worktree` for Swift DWARF.
CLANG_MAPS=(
  "-fdepscan-prefix-map=${WORKTREE_ROOT}=/^worktree"
  "-fdepscan-prefix-map=${PUB_CACHE_DIR}=/^pubcache"
)

SWIFT_MAPS=(
  "-file-compilation-dir" "/^worktree"
  "-scanner-prefix-map" "${WORKTREE_ROOT}=/^worktree"
  "-scanner-prefix-map" "${PUB_CACHE_DIR}=/^pubcache"
)

# Only add a separate `/^derived` prefix map when DerivedData lives outside WORKTREE_ROOT
# (avoiding overlapping prefix ambiguity when DerivedData is `<WORKTREE_ROOT>/build/ios-derived-data`).
if [[ "$DERIVED_DATA_DIR" != "$WORKTREE_ROOT/"* ]]; then
  CLANG_MAPS=("-fdepscan-prefix-map=${DERIVED_DATA_DIR}=/^derived" "${CLANG_MAPS[@]}")
  SWIFT_MAPS+=("-scanner-prefix-map" "${DERIVED_DATA_DIR}=/^derived")
fi

# Map symlinked worktree alias too (e.g. /tmp/... vs /private/tmp/... on macOS) if distinct.
if [[ "$RAW_WORKTREE_ROOT" != "$WORKTREE_ROOT" ]]; then
  CLANG_MAPS+=("-fdepscan-prefix-map=${RAW_WORKTREE_ROOT}=/^worktree")
  SWIFT_MAPS+=("-scanner-prefix-map" "${RAW_WORKTREE_ROOT}=/^worktree")
fi

if [[ -n "$FLUTTER_ROOT_DIR" ]]; then
  CLANG_MAPS+=("-fdepscan-prefix-map=${FLUTTER_ROOT_DIR}=/^flutter")
  SWIFT_MAPS+=("-scanner-prefix-map" "${FLUTTER_ROOT_DIR}=/^flutter")
fi

PREFIX_XCCONFIG="$WORKTREE_ROOT/ios/Flutter/WorktreePrefixMap.xcconfig"
cat > "$PREFIX_XCCONFIG" <<EOF
// Auto-generated per git worktree by scripts/configure_ios_cache.sh — DO NOT COMMIT.
BREATHNOTE_WORKTREE_ROOT = ${WORKTREE_ROOT}
BREATHNOTE_DERIVED_DATA_DIR = ${DERIVED_DATA_DIR}
BREATHNOTE_CAS_CACHE_DIR = ${CAS_CACHE_DIR}
COMPILATION_CACHE_CAS_PATH = ${CAS_CACHE_DIR}
MODULE_CACHE_DIR = ${CAS_CACHE_DIR}/ModuleCache.noindex

BREATHNOTE_CLANG_PREFIX_MAP_FLAGS = ${CLANG_MAPS[*]}
BREATHNOTE_SWIFT_PREFIX_MAP_FLAGS = ${SWIFT_MAPS[*]}

OTHER_CFLAGS = \$(inherited) \$(BREATHNOTE_CLANG_PREFIX_MAP_FLAGS)
OTHER_CPLUSPLUSFLAGS = \$(inherited) \$(BREATHNOTE_CLANG_PREFIX_MAP_FLAGS)
OTHER_SWIFT_FLAGS = \$(inherited) \$(BREATHNOTE_SWIFT_PREFIX_MAP_FLAGS)
EOF

# Generate per-worktree LLDB source-map helper so breakpoints resolve virtual prefixes locally.
cat > "$DERIVED_DATA_DIR/lldbinit" <<EOF
settings set target.source-map /^worktree "${WORKTREE_ROOT}"
settings append target.source-map /^src "${WORKTREE_ROOT}/ios"
settings append target.source-map /^derived "${DERIVED_DATA_DIR}"
EOF

# Ensure Xcode workspace/project settings isolate DerivedData per worktree.
for ws_dir in \
  "$WORKTREE_ROOT/ios/Runner.xcworkspace/xcshareddata" \
  "$WORKTREE_ROOT/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata"; do
  if [[ -d "$(dirname "$ws_dir")" ]]; then
    mkdir -p "$ws_dir"
    cat > "$ws_dir/WorkspaceSettings.xcsettings" <<'WSEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>BuildLocationStyle</key>
	<string>UseAppPreferences</string>
	<key>CustomBuildLocationType</key>
	<string>RelativeToDerivedData</string>
	<key>DerivedDataCustomLocation</key>
	<string>../build/ios-derived-data</string>
	<key>DerivedDataLocationStyle</key>
	<string>WorkspaceRelativePath</string>
	<key>IDEWorkspaceSharedSettings_AutocreateContextsIfNeeded</key>
	<false/>
</dict>
</plist>
WSEOF
  fi
done

python3 - "$WORKTREE_ROOT" <<'PY'
import pathlib
import re
import sys

worktree_root = pathlib.Path(sys.argv[1])

pbx_path = worktree_root / "ios" / "Runner.xcodeproj" / "project.pbxproj"
if pbx_path.exists():
    pbx = pbx_path.read_text(encoding="utf-8")
    orig_pbx = pbx

    pbx = re.sub(
        r"IPHONEOS_DEPLOYMENT_TARGET\s*=\s*[0-9.]+;",
        "IPHONEOS_DEPLOYMENT_TARGET = 15.0;",
        pbx,
    )
    pbx = re.sub(
        r"PRODUCT_BUNDLE_IDENTIFIER\s*=\s*app\.breathnote\.breathnote(\.RunnerTests)?;",
        lambda m: f"PRODUCT_BUNDLE_IDENTIFIER = app.breathnote{m.group(1) or ''};",
        pbx,
    )

    if "PBXFileSystemSynchronizedRootGroup" not in pbx:
        extra_swift_files = [
            ("HarmonicaPitchEngine.swift", "B9A100012C90000100000001", "B9A100022C90000100000001"),
            ("PitchDetector.swift", "B9A100032C90000100000001", "B9A100042C90000100000001"),
            ("GuideTonePlayer.swift", "B9A100052C90000100000001", "B9A100062C90000100000001"),
        ]
        for filename, file_ref_id, build_file_id in extra_swift_files:
            if filename in pbx:
                continue
            pbx = pbx.replace(
                "/* Begin PBXBuildFile section */\n",
                f"/* Begin PBXBuildFile section */\n\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};\n",
                1,
            )
            pbx = pbx.replace(
                "/* Begin PBXFileReference section */\n",
                f"/* Begin PBXFileReference section */\n\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n",
                1,
            )
            pbx = re.sub(
                r"([A-F0-9]{24}\s*/\*\s*AppDelegate\.swift\s*\*/,)",
                rf"\1\n\t\t\t\t{file_ref_id} /* {filename} */,",
                pbx,
                count=1,
            )
            pbx = re.sub(
                r"([A-F0-9]{24}\s*/\*\s*AppDelegate\.swift in Sources\s*\*/,)",
                rf"\1\n\t\t\t\t{build_file_id} /* {filename} in Sources */,",
                pbx,
                count=1,
            )

    if pbx != orig_pbx:
        pbx_path.write_text(pbx, encoding="utf-8")

podfile_path = worktree_root / "ios" / "Podfile"
if podfile_path.exists():
    podfile = podfile_path.read_text(encoding="utf-8")
    orig_podfile = podfile

    if re.search(r"^#?\s*platform\s+:ios\s*,", podfile, flags=re.MULTILINE):
        podfile = re.sub(
            r"^#?\s*platform\s+:ios\s*,\s*'[^']+'",
            "platform :ios, '15.0'",
            podfile,
            count=1,
            flags=re.MULTILINE,
        )
    else:
        podfile = "platform :ios, '15.0'\n" + podfile

    marker_start = "  # BEGIN BREATHNOTE_CAS_PREFIX_MAP"
    marker_end = "  # END BREATHNOTE_CAS_PREFIX_MAP"
    cas_ruby_block = """  # BEGIN BREATHNOTE_CAS_PREFIX_MAP
  cas_path = ENV['BREATHNOTE_CAS_CACHE_DIR'] || File.expand_path('~/Library/Developer/Xcode/CompilationCache.noindex')
  prefix_xcconfig = File.expand_path('Flutter/WorktreePrefixMap.xcconfig', __dir__)
  clang_prefix_flags = ''
  swift_prefix_flags = ''
  if File.exist?(prefix_xcconfig)
    File.readlines(prefix_xcconfig).each do |line|
      if line.start_with?('BREATHNOTE_CLANG_PREFIX_MAP_FLAGS =')
        clang_prefix_flags = line.sub('BREATHNOTE_CLANG_PREFIX_MAP_FLAGS =', '').strip
      elsif line.start_with?('BREATHNOTE_SWIFT_PREFIX_MAP_FLAGS =')
        swift_prefix_flags = line.sub('BREATHNOTE_SWIFT_PREFIX_MAP_FLAGS =', '').strip
      end
    end
  end
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target) if defined?(flutter_additional_ios_build_settings)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['COMPILATION_CACHE_ENABLE_CACHING'] = 'YES'
      config.build_settings['COMPILATION_CACHE_CAS_PATH'] = cas_path
      config.build_settings['COMPILATION_CACHE_KEEP_LOCAL_DIRECTORY'] = 'YES'
      config.build_settings['MODULE_CACHE_DIR'] = File.join(cas_path, 'ModuleCache.noindex')
      config.build_settings['SWIFT_USE_INTEGRATED_DRIVER'] = 'YES'
      config.build_settings['SWIFT_ENABLE_EXPLICIT_MODULES'] = 'YES'
      config.build_settings['SWIFT_ENABLE_BATCH_MODE'] = 'NO'
      config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
      config.build_settings['CLANG_ENABLE_PREFIX_MAPPING'] = 'YES'
      config.build_settings['CLANG_ENABLE_PROJECT_PREFIX_MAPPING'] = 'YES'
      config.build_settings['SWIFT_ENABLE_PREFIX_MAPPING'] = 'YES'
      config.build_settings['SWIFT_ENABLE_PROJECT_PREFIX_MAPPING'] = 'YES'
      unless clang_prefix_flags.empty?
        config.build_settings['OTHER_CFLAGS'] = "$(inherited) #{clang_prefix_flags}"
        config.build_settings['OTHER_CPLUSPLUSFLAGS'] = "$(inherited) #{clang_prefix_flags}"
      end
      unless swift_prefix_flags.empty?
        config.build_settings['OTHER_SWIFT_FLAGS'] = "$(inherited) #{swift_prefix_flags}"
      end
    end
  end
  # END BREATHNOTE_CAS_PREFIX_MAP"""

    if marker_start in podfile and marker_end in podfile:
        podfile = re.sub(
            rf"{re.escape(marker_start)}.*?{re.escape(marker_end)}",
            lambda _: cas_ruby_block,
            podfile,
            flags=re.DOTALL,
        )
    elif "post_install do |installer|" in podfile:
        podfile = podfile.replace(
            "post_install do |installer|\n",
            f"post_install do |installer|\n{cas_ruby_block}\n",
            1,
        )

    if podfile != orig_podfile:
        podfile_path.write_text(podfile, encoding="utf-8")
PY

echo "Configured Breathnote iOS CAS & Worktree Prefix Mapping:"
echo "  Worktree Root : $WORKTREE_ROOT (-> /^worktree)"
echo "  DerivedData   : $DERIVED_DATA_DIR"
echo "  Global CAS    : $CAS_CACHE_DIR"
