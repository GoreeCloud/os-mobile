#!/sbin/sh
#
# ADDOND_VERSION=3
#
# GoreeCloud OS Mobile system-app preservation for LineageOS 23.2.
#
. /tmp/backuptool.functions

list_files() {
cat <<'EOF'
product/app/GoreeCloudMemos/GoreeCloudMemos.apk
product/app/GoreeCloudLauncher/GoreeCloudLauncher.apk
product/app/GoreeCloudBrowser/GoreeCloudBrowser.apk
product/app/GoreeCloudKeyboard/GoreeCloudKeyboard.apk
product/app/GoreeCloudGallery/GoreeCloudGallery.apk
product/app/GoreeCloudMail/GoreeCloudMail.apk
product/app/GoreeCloudCamera/GoreeCloudCamera.apk
product/app/GoreeCloudSince/GoreeCloudSince.apk
product/app/GoreeCloudClock/GoreeCloudClock.apk
EOF
}

case "$1" in
  backup)
    list_files | while read -r FILE REPLACEMENT; do
      backup_file "$S/$FILE"
    done
    ;;
  restore)
    list_files | while read -r FILE REPLACEMENT; do
      R=""
      [ -n "$REPLACEMENT" ] && R="$S/$REPLACEMENT"
      restore_file "$S/$FILE" "$R"
    done
    ;;
  post-restore)
    list_files | while read -r FILE REPLACEMENT; do
      F="$(get_output_path "$S/$FILE")"
      [ -e "$F" ] || continue
      chown root:root "$F"
      chmod 0644 "$F"
      chmod 0755 "$(dirname "$F")"
      command -v restorecon >/dev/null 2>&1 && restorecon -F "$F" >/dev/null 2>&1 || true
    done
    ;;
esac
