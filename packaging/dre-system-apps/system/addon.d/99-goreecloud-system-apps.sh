#!/sbin/sh
#
# ADDOND_VERSION=3
#
# Preserve GoreeCloud OS Mobile built-in applications and default-app integration across
# LineageOS A/B OTAs.
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
product/overlay/GoreeCloudGalleryFrameworksBaseOverlay.apk
product/bin/goreecloud-default-apps.sh
product/etc/init/goreecloud-default-apps.rc
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
  post-restore)
    chmod 0644 "$S/product/overlay/GoreeCloudGalleryFrameworksBaseOverlay.apk" 2>/dev/null || true
    chmod 0755 "$S/product/bin/goreecloud-default-apps.sh" 2>/dev/null || true
    chmod 0644 "$S/product/etc/init/goreecloud-default-apps.rc" 2>/dev/null || true
  ;;
  pre-backup|post-backup|pre-restore)
    :
  ;;
esac
