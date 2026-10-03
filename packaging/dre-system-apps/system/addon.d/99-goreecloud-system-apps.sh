#!/sbin/sh
#
# ADDOND_VERSION=3
#
# Preserve GoreeCloud OS Mobile built-in applications across LineageOS A/B OTAs.
#

. /tmp/backuptool.functions

list_files() {
cat <<'FILES'
product/app/GoreeCloudMemos/GoreeCloudMemos.apk
product/app/GoreeCloudLauncher/GoreeCloudLauncher.apk
product/app/GoreeCloudBrowser/GoreeCloudBrowser.apk
product/app/GoreeCloudKeyboard/GoreeCloudKeyboard.apk
product/app/GoreeCloudGallery/GoreeCloudGallery.apk
product/app/GoreeCloudMail/GoreeCloudMail.apk
product/app/GoreeCloudCamera/GoreeCloudCamera.apk
product/app/GoreeCloudSince/GoreeCloudSince.apk
product/app/GoreeCloudClock/GoreeCloudClock.apk
FILES
}

case "$1" in
  backup)
    list_files | while read -r FILE DUMMY; do
      backup_file "$S/$FILE"
    done
  ;;
  restore)
    list_files | while read -r FILE REPLACEMENT; do
      R=""
      [ -n "${REPLACEMENT:-}" ] && R="$S/$REPLACEMENT"
      [ -e "$C/$S/$FILE" ] && restore_file "$S/$FILE" "$R"
    done
  ;;
  pre-backup|post-backup|pre-restore|post-restore)
    :
  ;;
esac
