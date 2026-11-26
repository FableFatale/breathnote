#!/usr/bin/env bash
set -euo pipefail

# Verifies cross-worktree LLVM CAS cache hit rate across two real git worktrees:
# - Worktree A: current git worktree (`<worktree-A>/build/ios-derived-data`)
# - Worktree B: temporary detached git worktree (`/tmp/breathnote-cas-wt-b/build/ios-derived-data`)
# Both share a single global CAS store and apply `scripts/configure_ios_cache.sh`.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
WT_A="$(cd "$SCRIPT_DIR/.." && pwd -P)"
WT_B="/tmp/breathnote-cas-wt-b-$$"
SHARED_CAS="${BREATHNOTE_CAS_CACHE_DIR:-/tmp/breathnote-cas-shared-$$}"

cleanup() {
  git -C "$WT_A" worktree remove --force "$WT_B" >/dev/null 2>&1 || rm -rf "$WT_B"
  if [[ "$SHARED_CAS" == /tmp/breathnote-cas-shared-* ]]; then
    rm -rf "$SHARED_CAS"
  fi
}
trap cleanup EXIT

mkdir -p "$SHARED_CAS"
git -C "$WT_A" worktree add --detach "$WT_B" HEAD >/dev/null

# Ensure uncommitted working-tree iOS sources are mirrored if running before commit
mkdir -p "$WT_B/ios/Runner" "$WT_B/scripts"
cp "$WT_A/ios/Runner/HarmonicaPitchEngine.swift" "$WT_B/ios/Runner/HarmonicaPitchEngine.swift"
cp "$WT_A/scripts/configure_ios_cache.sh" "$WT_B/scripts/configure_ios_cache.sh"

BREATHNOTE_CAS_CACHE_DIR="$SHARED_CAS" BREATHNOTE_DERIVED_DATA_DIR="$WT_A/build/ios-derived-data" \
  bash "$WT_A/scripts/configure_ios_cache.sh" >/dev/null
BREATHNOTE_CAS_CACHE_DIR="$SHARED_CAS" BREATHNOTE_DERIVED_DATA_DIR="$WT_B/build/ios-derived-data" \
  bash "$WT_B/scripts/configure_ios_cache.sh" >/dev/null

WT_B_REAL="$(cd "$WT_B" && pwd -P)"
SDK_PATH="$(realpath "$(xcrun --sdk macosx --show-sdk-path)")"

mkdir -p "$WT_A/build/ios-derived-data/cas_probe" "$WT_B_REAL/build/ios-derived-data/cas_probe"

cat > "$WT_A/build/ios-derived-data/cas_probe/dsp_util.c" <<'EOF'
#include <math.h>
double breathnote_cents_delta(double f, double ref) {
  return 1200.0 * log(f / ref) / log(2.0);
}
EOF
cp "$WT_A/build/ios-derived-data/cas_probe/dsp_util.c" "$WT_B_REAL/build/ios-derived-data/cas_probe/dsp_util.c"

echo "==> [Worktree A: $WT_A] Cold compilation into global CAS ($SHARED_CAS)..."
(
  cd "$WT_A"
  clang -isysroot "$SDK_PATH" -O2 -g -c "$WT_A/build/ios-derived-data/cas_probe/dsp_util.c" \
    -o "$WT_A/build/ios-derived-data/cas_probe/dsp_util.o" \
    -fdepscan=inline -fdepscan-prefix-map-sdk=/^sdk -fdepscan-prefix-map-toolchain=/^toolchain \
    -fdepscan-prefix-map="$WT_A=/^worktree" \
    -Xclang -fcas-path -Xclang "$SHARED_CAS" \
    -Xclang -fcache-compile-job -Rcompile-job-cache

  swiftc -sdk "$SDK_PATH" -O -g -parse-as-library -module-name BreathnotePitch \
    -c "$WT_A/ios/Runner/HarmonicaPitchEngine.swift" \
    -o "$WT_A/build/ios-derived-data/cas_probe/HarmonicaPitchEngine.o" \
    -file-compilation-dir /^worktree \
    -explicit-module-build \
    -module-cache-path "$SHARED_CAS/ModuleCache.noindex" \
    -cache-compile-job -cas-path "$SHARED_CAS" -Rcache-compile-job \
    -scanner-prefix-map-sdk /^sdk -scanner-prefix-map-toolchain /^toolchain \
    -scanner-prefix-map "$WT_A=/^worktree"
) 2>&1 | tee "$WT_A/build/ios-derived-data/cas_probe/wt_a.log"

echo "==> [Worktree B: $WT_B_REAL] Warm cross-worktree compilation with isolated DerivedData..."
(
  cd "$WT_B_REAL"
  clang -isysroot "$SDK_PATH" -O2 -g -c "$WT_B_REAL/build/ios-derived-data/cas_probe/dsp_util.c" \
    -o "$WT_B_REAL/build/ios-derived-data/cas_probe/dsp_util.o" \
    -fdepscan=inline -fdepscan-prefix-map-sdk=/^sdk -fdepscan-prefix-map-toolchain=/^toolchain \
    -fdepscan-prefix-map="$WT_B_REAL=/^worktree" \
    -Xclang -fcas-path -Xclang "$SHARED_CAS" \
    -Xclang -fcache-compile-job -Rcompile-job-cache

  swiftc -sdk "$SDK_PATH" -O -g -parse-as-library -module-name BreathnotePitch \
    -c "$WT_B_REAL/ios/Runner/HarmonicaPitchEngine.swift" \
    -o "$WT_B_REAL/build/ios-derived-data/cas_probe/HarmonicaPitchEngine.o" \
    -file-compilation-dir /^worktree \
    -explicit-module-build \
    -module-cache-path "$SHARED_CAS/ModuleCache.noindex" \
    -cache-compile-job -cas-path "$SHARED_CAS" -Rcache-compile-job \
    -scanner-prefix-map-sdk /^sdk -scanner-prefix-map-toolchain /^toolchain \
    -scanner-prefix-map "$WT_B_REAL=/^worktree"
) 2>&1 | tee "$WT_B_REAL/build/ios-derived-data/cas_probe/wt_b.log"

python3 - "$WT_B_REAL/build/ios-derived-data/cas_probe/wt_b.log" <<'PY'
import pathlib, re, sys

log = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
clang_hits = len(re.findall(r"compile job cache hit", log))
swift_hits = len(re.findall(r"replay output file '.*\.o'", log))
misses = len(re.findall(r"cache miss", log))
hits = clang_hits + swift_hits
total = hits + misses
pct = (hits * 100.0 / total) if total else 0.0
print(f"\n==> Cross-Worktree CAS Cache Hit Summary: {hits}/{total} units hit ({pct:.1f}%), misses={misses}")
if hits < 2 or misses > 0:
    sys.exit("Expected 100% cross-worktree CAS cache hit across Clang and Swift!")
PY

rm -rf "$WT_A/build/ios-derived-data/cas_probe"
