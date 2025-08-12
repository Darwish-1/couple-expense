#!/bin/bash
set -euo pipefail

echo "== CI fix script starting =="
echo "PWD: $(pwd)"

# Use a safe parameter expansion so this doesn't fail if the env var is unset
echo "== ENV before normalization: TARGET_DEVICE_OS_VERSION='${TARGET_DEVICE_OS_VERSION:-}'"

# If it's set and non-empty, normalize; otherwise leave empty or set a default if you prefer
if [ -n "${TARGET_DEVICE_OS_VERSION:-}" ]; then
  NORMALIZED=$(echo "$TARGET_DEVICE_OS_VERSION" | sed -E 's/[^0-9.].*$//')
  export TARGET_DEVICE_OS_VERSION="$NORMALIZED"
  echo "== Normalized TARGET_DEVICE_OS_VERSION='$TARGET_DEVICE_OS_VERSION'"
else
  echo "== TARGET_DEVICE_OS_VERSION is empty or unset"
  # Optional: set a safe default instead of leaving unset:
  # export TARGET_DEVICE_OS_VERSION="18.0"
  # echo "== Forced TARGET_DEVICE_OS_VERSION='$TARGET_DEVICE_OS_VERSION'"
fi

# Clean pods and reinstall (CI-safe)
cd ios
rm -rf Pods Podfile.lock .symlinks || true
pod cache clean --all || true
pod repo update || true
pod install --verbose || true
cd ..

flutter pub get || true
echo "== CI fix script finished =="
