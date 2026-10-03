#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIGNED_DIR="${1:-$ROOT/signed-apks}"
OUT="${2:-$PWD/GoreeCloud-OS-Lineage23.2-dre-SystemApps-development.zip}"

apps=(
  GoreeCloudMemos GoreeCloudLauncher GoreeCloudBrowser GoreeCloudKeyboard
  GoreeCloudGallery GoreeCloudMail GoreeCloudCamera GoreeCloudSince GoreeCloudClock
)

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/META-INF/com/google/android" "$work/payload/apks" "$work/payload/addon.d" "$work/goreecloud"

cp "$ROOT/update-binary" "$work/META-INF/com/google/android/update-binary"
printf '# GoreeCloud OS custom recovery package\n' > "$work/META-INF/com/google/android/updater-script"
cp "$ROOT/30-goreecloud-os-apps.sh" "$work/payload/addon.d/30-goreecloud-os-apps.sh"
chmod 0755 "$work/META-INF/com/google/android/update-binary" "$work/payload/addon.d/30-goreecloud-os-apps.sh"

for app in "${apps[@]}"; do
  test -s "$SIGNED_DIR/$app.apk" || {
    echo "Missing signed APK: $SIGNED_DIR/$app.apk" >&2
    exit 1
  }
  cp "$SIGNED_DIR/$app.apk" "$work/payload/apks/$app.apk"
done

LOCK="$ROOT/sources.lock.json"
[ -f "$LOCK" ] || LOCK="$ROOT/../sources.lock.json"
test -f "$LOCK" || {
  echo "Missing sources.lock.json" >&2
  exit 1
}
cp "$LOCK" "$work/goreecloud/sources.lock.json"

(
  cd "$work"
  find payload goreecloud -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > goreecloud/SHA256SUMS
)

mkdir -p "$(dirname "$OUT")"
OUT="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
rm -f "$OUT"
(
  cd "$work"
  zip -q -9 -r "$OUT" META-INF payload goreecloud
)

echo "$OUT"
