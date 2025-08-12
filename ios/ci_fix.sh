#!/bin/bash
set -euo pipefail

echo "== CI fix script starting =="
echo "PWD: $(pwd)"

# Print the variable that Flutter/Xcode parsing complains about
echo "== ENV before normalization: TARGET_DEVICE_OS_VERSION='$TARGET_DEVICE_OS_VERSION'"

# Normalize: keep only leading digits and dots (e.g. "18.0 (Build ...)" -> "18.0")
if [ -n "${TARGET_DEVICE_OS_VERSION:-}" ]; then
  NORMALIZED=$(echo "$TARGET_DEVICE_OS_VERSION" | sed -E 's/[^0-9.].*$//')
  export TARGET_DEVICE_OS_VERSION="$NORMALIZED"
  echo "== Normalized TARGET_DEVICE_OS_VERSION='$TARGET_DEVICE_OS_VERSION'"
else
  echo "== TARGET_DEVICE_OS_VERSION is empty or unset"
fi

# Clean pods and caches (safe to run on CI)
cd ios
rm -rf Pods Podfile.lock .symlinks
pod cache clean --all || true
pod repo update || true
pod install --verbose

echo "== CI fix script finished =="
