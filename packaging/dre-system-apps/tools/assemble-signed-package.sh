#!/usr/bin/env bash
set -euo pipefail
umask 077

usage() {
  cat <<'USAGE'
Usage:
  assemble-dre-signed-package.sh \
    --unsigned-bundle PATH \
    --keystore PATH \
    --key-alias ALIAS \
    --ks-pass-file PATH \
    --key-pass-file PATH \
    [--expected-cert-sha256 HEX] \
    [--source-revision GIT_SHA] \
    [--ephemeral-test-signing] \
    --output PATH

The script never accepts a signing password as a command-line value. Passwords must be
provided through protected local files consumed directly by apksigner.

For a normal GoreeCloud Development package, --expected-cert-sha256 is mandatory. The
--ephemeral-test-signing escape hatch exists only for bounded CI/package-assembly tests;
its output filename must contain TEST-ONLY and must never be distributed or installed as
an update-compatible Development package.
USAGE
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

note() {
  printf '%s\n' "$*"
}

normalize_sha256() {
  printf '%s' "$1" | tr -d ':[:space:]' | tr '[:upper:]' '[:lower:]'
}

find_android_tool() {
  local tool="$1"
  local sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  local found=""

  if command -v "$tool" >/dev/null 2>&1; then
    command -v "$tool"
    return 0
  fi
  if [ -n "$sdk_root" ] && [ -d "$sdk_root/build-tools" ]; then
    found="$(find "$sdk_root/build-tools" -type f -name "$tool" -perm -u+x -print 2>/dev/null | sort -V | tail -n 1)"
  fi
  [ -n "$found" ] || fail "Could not locate Android build-tool '$tool'. Set ANDROID_HOME/ANDROID_SDK_ROOT or PATH."
  printf '%s\n' "$found"
}

require_secret_file() {
  local path="$1"
  local label="$2"
  [ -f "$path" ] || fail "$label does not exist: $path"
  [ -r "$path" ] || fail "$label is not readable: $path"
  if command -v stat >/dev/null 2>&1; then
    local mode=""
    mode="$(stat -c '%a' "$path" 2>/dev/null || true)"
    if [ -n "$mode" ]; then
      local last_two="${mode: -2}"
      case "$last_two" in
        00) ;;
        *) fail "$label must not be group/world-readable; current mode is $mode" ;;
      esac
    fi
  fi
}

UNSIGNED_BUNDLE=""
KEYSTORE=""
KEY_ALIAS=""
KS_PASS_FILE=""
KEY_PASS_FILE=""
EXPECTED_CERT_SHA256=""
SOURCE_REVISION=""
OUTPUT=""
EPHEMERAL_TEST_SIGNING=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --unsigned-bundle)
      [ "$#" -ge 2 ] || fail "--unsigned-bundle requires a value"
      UNSIGNED_BUNDLE="$2"; shift 2 ;;
    --keystore)
      [ "$#" -ge 2 ] || fail "--keystore requires a value"
      KEYSTORE="$2"; shift 2 ;;
    --key-alias)
      [ "$#" -ge 2 ] || fail "--key-alias requires a value"
      KEY_ALIAS="$2"; shift 2 ;;
    --ks-pass-file)
      [ "$#" -ge 2 ] || fail "--ks-pass-file requires a value"
      KS_PASS_FILE="$2"; shift 2 ;;
    --key-pass-file)
      [ "$#" -ge 2 ] || fail "--key-pass-file requires a value"
      KEY_PASS_FILE="$2"; shift 2 ;;
    --expected-cert-sha256)
      [ "$#" -ge 2 ] || fail "--expected-cert-sha256 requires a value"
      EXPECTED_CERT_SHA256="$(normalize_sha256 "$2")"; shift 2 ;;
    --source-revision)
      [ "$#" -ge 2 ] || fail "--source-revision requires a value"
      SOURCE_REVISION="$2"; shift 2 ;;
    --ephemeral-test-signing)
      EPHEMERAL_TEST_SIGNING=1; shift ;;
    --output)
      [ "$#" -ge 2 ] || fail "--output requires a value"
      OUTPUT="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

[ -n "$UNSIGNED_BUNDLE" ] || fail "--unsigned-bundle is required"
[ -e "$UNSIGNED_BUNDLE" ] || fail "Unsigned bundle does not exist: $UNSIGNED_BUNDLE"
[ -n "$KEYSTORE" ] || fail "--keystore is required"
[ -f "$KEYSTORE" ] || fail "Keystore does not exist: $KEYSTORE"
[ -n "$KEY_ALIAS" ] || fail "--key-alias is required"
[ -n "$KS_PASS_FILE" ] || fail "--ks-pass-file is required"
[ -n "$KEY_PASS_FILE" ] || fail "--key-pass-file is required"
[ -n "$OUTPUT" ] || fail "--output is required"
require_secret_file "$KS_PASS_FILE" "Keystore password file"
require_secret_file "$KEY_PASS_FILE" "Key password file"

if [ "$EPHEMERAL_TEST_SIGNING" -eq 1 ]; then
  case "$(basename "$OUTPUT")" in
    *TEST-ONLY*) ;;
    *) fail "Ephemeral test signing requires an output filename containing TEST-ONLY" ;;
  esac
else
  [ -n "$EXPECTED_CERT_SHA256" ] || fail "Normal Development signing requires --expected-cert-sha256"
  [ "${#EXPECTED_CERT_SHA256}" -eq 64 ] || fail "Expected certificate SHA-256 must contain 64 hexadecimal characters"
  printf '%s' "$EXPECTED_CERT_SHA256" | grep -Eq '^[0-9a-f]{64}$' || fail "Expected certificate SHA-256 is not valid hexadecimal"
fi

APKSIGNER="${APKSIGNER:-$(find_android_tool apksigner)}"
AAPT="${AAPT:-$(find_android_tool aapt)}"
command -v zip >/dev/null 2>&1 || fail "zip is required"
command -v unzip >/dev/null 2>&1 || fail "unzip is required"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required"
command -v zipinfo >/dev/null 2>&1 || fail "zipinfo is required"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$PACKAGE_ROOT/../.." && pwd)"

[ -f "$PACKAGE_ROOT/META-INF/com/google/android/update-binary" ] || fail "Package source is incomplete"
[ -f "$PACKAGE_ROOT/META-INF/com/google/android/updater-script" ] || fail "Package source is incomplete"
[ -f "$PACKAGE_ROOT/system/addon.d/99-goreecloud-system-apps.sh" ] || fail "Package source is incomplete"
[ -f "$PACKAGE_ROOT/product/bin/goreecloud-default-apps.sh" ] || fail "Package source is incomplete"
[ -f "$PACKAGE_ROOT/product/etc/init/goreecloud-default-apps.rc" ] || fail "Package source is incomplete"

if [ -z "$SOURCE_REVISION" ]; then
  SOURCE_REVISION="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || true)"
fi
[ -n "$SOURCE_REVISION" ] || fail "Could not determine source revision; pass --source-revision"
CHECKOUT_REVISION="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || true)"
[ "$CHECKOUT_REVISION" = "$SOURCE_REVISION" ] || fail "Packaging checkout does not match the requested source revision"

OUTPUT_DIR="$(dirname -- "$OUTPUT")"
OUTPUT_NAME="$(basename -- "$OUTPUT")"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(CDPATH= cd -- "$OUTPUT_DIR" && pwd)"
OUTPUT="$OUTPUT_DIR/$OUTPUT_NAME"

WORK="$(mktemp -d)"
cleanup() {
  rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

INPUT_ROOT="$WORK/input"
mkdir -p "$INPUT_ROOT"
if [ -d "$UNSIGNED_BUNDLE" ]; then
  cp -a "$UNSIGNED_BUNDLE/." "$INPUT_ROOT/"
else
  if zipinfo -1 "$UNSIGNED_BUNDLE" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
    fail "Unsigned bundle contains an unsafe archive path"
  fi
  unzip -q "$UNSIGNED_BUNDLE" -d "$INPUT_ROOT"
fi

[ -d "$INPUT_ROOT/apks" ] || fail "Unsigned bundle is missing apks/"
[ -d "$INPUT_ROOT/provenance" ] || fail "Unsigned bundle is missing provenance/"
[ -f "$INPUT_ROOT/SHA256SUMS-UNSIGNED" ] || fail "Unsigned bundle is missing SHA256SUMS-UNSIGNED"
[ -f "$INPUT_ROOT/provenance/gallery-framework-overlay.provenance.txt" ] || fail "Unsigned bundle is missing Gallery overlay provenance"

BUNDLE_SOURCE_REVISION="$(sed -n 's/^source_revision=//p' "$INPUT_ROOT/provenance/gallery-framework-overlay.provenance.txt" | head -n 1)"
[ -n "$BUNDLE_SOURCE_REVISION" ] || fail "Gallery overlay provenance does not contain source_revision"
[ "$BUNDLE_SOURCE_REVISION" = "$SOURCE_REVISION" ] || fail "Unsigned bundle source revision does not match the packaging checkout"

EXPECTED_APKS=(
  browser.apk
  camera.apk
  clock.apk
  gallery-framework-overlay.apk
  gallery.apk
  keyboard.apk
  launcher.apk
  mail.apk
  memos.apk
  since.apk
)

ACTUAL_COUNT="$(find "$INPUT_ROOT/apks" -maxdepth 1 -type f -name '*.apk' | wc -l | tr -d '[:space:]')"
[ "$ACTUAL_COUNT" = "10" ] || fail "Expected exactly 10 unsigned APKs; found $ACTUAL_COUNT"
PROVENANCE_COUNT="$(find "$INPUT_ROOT/provenance" -maxdepth 1 -type f -name '*.provenance.txt' | wc -l | tr -d '[:space:]')"
[ "$PROVENANCE_COUNT" = "10" ] || fail "Expected exactly 10 provenance records; found $PROVENANCE_COUNT"
for apk in "${EXPECTED_APKS[@]}"; do
  [ -f "$INPUT_ROOT/apks/$apk" ] || fail "Unsigned bundle is missing apks/$apk"
done
for provenance in "$INPUT_ROOT"/provenance/*.provenance.txt; do
  grep -Fxq 'signing_state=unsigned' "$provenance" || fail "Provenance is not marked unsigned: $(basename "$provenance")"
done

note "Verifying unsigned input checksums..."
(
  cd "$INPUT_ROOT/apks"
  sha256sum -c ../SHA256SUMS-UNSIGNED
)

mapfile -t VERSION_CODES < <(
  grep -h '^version_code=' "$INPUT_ROOT"/provenance/*.provenance.txt \
    | cut -d= -f2- \
    | sed '/^$/d' \
    | sort -u
)
[ "${#VERSION_CODES[@]}" -eq 1 ] || fail "Expected one unique version_code across provenance; found ${#VERSION_CODES[@]}"
VERSION_CODE="${VERSION_CODES[0]}"
printf '%s' "$VERSION_CODE" | grep -Eq '^[0-9]+$' || fail "Invalid version_code in provenance: $VERSION_CODE"

SIGNED_DIR="$WORK/signed"
mkdir -p "$SIGNED_DIR"

sign_one() {
  local input="$1"
  local output="$2"
  "$APKSIGNER" sign \
    --ks "$KEYSTORE" \
    --ks-key-alias "$KEY_ALIAS" \
    --ks-pass "file:$KS_PASS_FILE" \
    --key-pass "file:$KEY_PASS_FILE" \
    --out "$output" \
    "$input"
  "$APKSIGNER" verify --verbose --print-certs "$output" >/dev/null
}

note "Confirming signing input APKs are not already signed..."
for apk in "${EXPECTED_APKS[@]}"; do
  if "$APKSIGNER" verify "$INPUT_ROOT/apks/$apk" >/dev/null 2>&1; then
    fail "Signing input is already signed: $apk"
  fi
done

note "Signing 10 APKs without exposing signing passwords..."
for apk in "${EXPECTED_APKS[@]}"; do
  sign_one "$INPUT_ROOT/apks/$apk" "$SIGNED_DIR/$apk"
done

CERT_SHA256=""
CERT_DN=""
for apk in "${EXPECTED_APKS[@]}"; do
  VERIFY_OUTPUT="$WORK/verify-${apk}.txt"
  "$APKSIGNER" verify --verbose --print-certs "$SIGNED_DIR/$apk" > "$VERIFY_OUTPUT" 2>&1

  THIS_CERT="$(
    sed -n -E 's/^Signer #[0-9]+ certificate SHA-256 digest:[[:space:]]*//p' "$VERIFY_OUTPUT" \
      | head -n 1
  )"
  if [ -z "$THIS_CERT" ]; then
    THIS_CERT="$(
      sed -n -E 's/^Signer certificate SHA-256 digest:[[:space:]]*//p' "$VERIFY_OUTPUT" \
        | head -n 1
    )"
  fi
  THIS_CERT="$(normalize_sha256 "$THIS_CERT")"
  if [ "${#THIS_CERT}" -ne 64 ]; then
    grep -E 'certificate (SHA-256 digest|DN):' "$VERIFY_OUTPUT" >&2 || true
    fail "Could not read signing certificate SHA-256 from $apk"
  fi

  if [ -z "$CERT_SHA256" ]; then
    CERT_SHA256="$THIS_CERT"
    CERT_DN="$(
      sed -n -E 's/^Signer #[0-9]+ certificate DN:[[:space:]]*//p' "$VERIFY_OUTPUT" \
        | head -n 1
    )"
    if [ -z "$CERT_DN" ]; then
      CERT_DN="$(
        sed -n -E 's/^Signer certificate DN:[[:space:]]*//p' "$VERIFY_OUTPUT" \
          | head -n 1
      )"
    fi
  else
    [ "$THIS_CERT" = "$CERT_SHA256" ] || fail "Signer mismatch detected for $apk"
  fi
done

if [ "$EPHEMERAL_TEST_SIGNING" -eq 0 ]; then
  [ "$CERT_SHA256" = "$EXPECTED_CERT_SHA256" ] || fail "Signing certificate does not match the approved Development certificate fingerprint"
fi

expected_package_for() {
  case "$1" in
    browser.apk) printf '%s\n' 'io.goreecloud.browser' ;;
    camera.apk) printf '%s\n' 'com.goreecloud.camera' ;;
    clock.apk) printf '%s\n' 'com.goreecloud.clock' ;;
    gallery-framework-overlay.apk) printf '%s\n' 'com.goreecloud.overlay.gallery.frameworksbase' ;;
    gallery.apk) printf '%s\n' 'com.goreecloud.gallery' ;;
    keyboard.apk) printf '%s\n' 'com.goreecloud.keyboard' ;;
    launcher.apk) printf '%s\n' 'com.goreecloud.launcher' ;;
    mail.apk) printf '%s\n' 'com.goreecloud.mail' ;;
    memos.apk) printf '%s\n' 'com.goreecloud.memos' ;;
    since.apk) printf '%s\n' 'com.goreecloud.since' ;;
    *) fail "No package mapping for $1" ;;
  esac
}

note "Validating signed package identity and versionCode..."
for apk in "${EXPECTED_APKS[@]}"; do
  BADGING="$("$AAPT" dump badging "$SIGNED_DIR/$apk" | head -n 1)"
  PACKAGE_ID="$(printf '%s\n' "$BADGING" | sed -n "s/^package: name='\([^']*\)'.*/\1/p")"
  APK_VERSION_CODE="$(printf '%s\n' "$BADGING" | sed -n "s/.* versionCode='\([^']*\)'.*/\1/p")"
  EXPECTED_PACKAGE="$(expected_package_for "$apk")"
  [ "$PACKAGE_ID" = "$EXPECTED_PACKAGE" ] || fail "$apk package id mismatch: expected $EXPECTED_PACKAGE, found $PACKAGE_ID"
  [ "$APK_VERSION_CODE" = "$VERSION_CODE" ] || fail "$apk versionCode mismatch: expected $VERSION_CODE, found $APK_VERSION_CODE"
done

STAGE="$WORK/package"
mkdir -p "$STAGE/payload" "$STAGE/provenance"
cp -a "$PACKAGE_ROOT/META-INF" "$STAGE/"
cp -a "$PACKAGE_ROOT/product" "$STAGE/"
cp -a "$PACKAGE_ROOT/system" "$STAGE/"
cp -a "$PACKAGE_ROOT/PHYSICAL-VALIDATION.md" "$STAGE/"

for apk in "${EXPECTED_APKS[@]}"; do
  cp -f "$SIGNED_DIR/$apk" "$STAGE/payload/$apk"
done

for src in "$INPUT_ROOT"/provenance/*.provenance.txt; do
  base="$(basename "$src")"
  awk -v cert="$CERT_SHA256" '
    BEGIN { replaced = 0 }
    /^signing_state=/ {
      print "signing_state=signed-development"
      print "signing_certificate_sha256=" cert
      replaced = 1
      next
    }
    { print }
    END {
      if (!replaced) {
        print "signing_state=signed-development"
        print "signing_certificate_sha256=" cert
      }
    }
  ' "$src" > "$STAGE/provenance/$base"
done

(
  cd "$STAGE"
  find payload -maxdepth 1 -type f -name '*.apk' -print | sort | xargs sha256sum > SHA256SUMS-SIGNED
)

if [ "$EPHEMERAL_TEST_SIGNING" -eq 1 ]; then
  SIGNING_LABEL="Ephemeral CI package-assembly test identity"
else
  SIGNING_LABEL="GoreeCloud OS Development Android signing identity"
fi

cat > "$STAGE/SIGNING-CERTIFICATE.txt" <<EOF_CERT
$SIGNING_LABEL
Certificate DN: $CERT_DN
Certificate SHA-256: $CERT_SHA256
Private key included in this package: No
EOF_CERT

cat > "$STAGE/README.txt" <<EOF_README
GoreeCloud OS Mobile Development system-app bundle
Target: OnePlus Nord N200 (dre)
Baseline: LineageOS 23.2 / Android 16
System app versionCode: $VERSION_CODE
Source revision: $SOURCE_REVISION
Install location: /product/app
OTA persistence: LineageOS addon.d v3
Default HOME package: com.goreecloud.launcher
System Gallery package: com.goreecloud.gallery
Signing certificate SHA-256: $CERT_SHA256

Built-in applications:
- GoreeCloud Memos
- GoreeCloud Launcher
- GoreeCloud Browser
- GoreeCloud Keyboard
- GoreeCloud Gallery
- GoreeCloud Mail
- GoreeCloud Camera
- GoreeCloud Since
- GoreeCloud Clock

The package also installs the GoreeCloud Gallery framework RRO, default-app initializer,
and LineageOS OTA persistence hook.

Lineage Recovery can warn that signature verification failed for a third-party add-on when
the outer recovery ZIP is not signed with LineageOS's official release key. That warning is
separate from the Android APK signatures verified by this package assembly process.

This package is Development bring-up material, not a Stable or production-qualified OS release.
EOF_README

if [ "$EPHEMERAL_TEST_SIGNING" -eq 1 ]; then
  cat > "$STAGE/TEST-ONLY-NOT-FOR-INSTALLATION.txt" <<'EOF_TEST'
This recovery ZIP was assembled with an ephemeral CI test signing identity.
It exists only to validate package assembly and must not be distributed, installed, or treated
as an update-compatible GoreeCloud Development package.
EOF_TEST
fi

chmod 0755 "$STAGE/META-INF/com/google/android/update-binary"
chmod 0644 "$STAGE/META-INF/com/google/android/updater-script"
chmod 0755 "$STAGE/system/addon.d/99-goreecloud-system-apps.sh"
chmod 0755 "$STAGE/product/bin/goreecloud-default-apps.sh"
chmod 0644 "$STAGE/product/etc/init/goreecloud-default-apps.rc"
find "$STAGE/payload" -type f -name '*.apk' -exec chmod 0644 {} +

sh -n "$STAGE/META-INF/com/google/android/update-binary"
sh -n "$STAGE/system/addon.d/99-goreecloud-system-apps.sh"
sh -n "$STAGE/product/bin/goreecloud-default-apps.sh"
[ "$(find "$STAGE/payload" -maxdepth 1 -type f -name '*.apk' | wc -l | tr -d '[:space:]')" = "10" ] || fail "Signed package staging does not contain exactly 10 APKs"

grep -Fq 'payload/gallery-framework-overlay.apk' "$STAGE/META-INF/com/google/android/update-binary" || fail "Recovery installer does not install the Gallery framework overlay"
grep -Fq 'com.goreecloud.launcher' "$STAGE/product/bin/goreecloud-default-apps.sh" || fail "Default-app initializer does not reference GoreeCloud Launcher"
grep -Fq 'com.goreecloud.gallery' "$STAGE/product/bin/goreecloud-default-apps.sh" || fail "Default-app initializer does not reference GoreeCloud Gallery"

rm -f "$OUTPUT"
(
  cd "$STAGE"
  zip -X -q -r "$OUTPUT" .
)
unzip -tq "$OUTPUT" >/dev/null

OUTPUT_SHA256="$(sha256sum "$OUTPUT" | awk '{print $1}')"
OUTPUT_SIZE="$(wc -c < "$OUTPUT" | tr -d '[:space:]')"

note "Package assembly succeeded."
note "Output: $OUTPUT"
note "Size: $OUTPUT_SIZE bytes"
note "SHA-256: $OUTPUT_SHA256"
note "APK signing certificate SHA-256: $CERT_SHA256"
if [ "$EPHEMERAL_TEST_SIGNING" -eq 1 ]; then
  note "TEST ONLY: ephemeral signing was used; destroy this output after validation."
fi
