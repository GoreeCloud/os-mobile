#!/system/bin/sh
set -u

TAG="GoreeCloudDefaults"
MARKER="goreecloud_default_apps_initialized"
USER_ID=0
GALLERY_PACKAGE="com.goreecloud.gallery"
LAUNCHER_PACKAGE="com.goreecloud.launcher"
SYSTEM_GALLERY_ROLE="android.app.role.SYSTEM_GALLERY"
HOME_ROLE="android.app.role.HOME"

log_note() {
    log -t "$TAG" "$*" 2>/dev/null || true
}

has_package() {
    pm path --user "$USER_ID" "$1" >/dev/null 2>&1
}

wait_for_packages() {
    attempt=0
    while [ "$attempt" -lt 30 ]; do
        if has_package "$GALLERY_PACKAGE" && has_package "$LAUNCHER_PACKAGE"; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    return 1
}

role_contains() {
    role_name="$1"
    package_name="$2"
    holders="$(cmd role get-role-holders --user "$USER_ID" "$role_name" 2>/dev/null || true)"
    printf '%s' "$holders" | tr ',' '\n' | grep -Fxq "$package_name"
}

already_initialized="$(settings --user "$USER_ID" get secure "$MARKER" 2>/dev/null || true)"
if [ "$already_initialized" = "1" ]; then
    exit 0
fi

if ! wait_for_packages; then
    log_note "GoreeCloud default-app initialization stopped: required packages were not visible."
    exit 1
fi

if ! cmd package set-home-activity --user "$USER_ID" "$LAUNCHER_PACKAGE" >/dev/null 2>&1; then
    log_note "Could not assign GoreeCloud Launcher as HOME."
    exit 1
fi
if ! role_contains "$HOME_ROLE" "$LAUNCHER_PACKAGE"; then
    log_note "Android did not retain GoreeCloud Launcher as HOME."
    exit 1
fi

# SYSTEM_GALLERY is a static role. The packaged framework RRO changes config_systemGallery so
# GoreeCloud Gallery qualifies as its configured default holder before this command executes.
if ! cmd role add-role-holder --user "$USER_ID" "$SYSTEM_GALLERY_ROLE" "$GALLERY_PACKAGE" 0 >/dev/null 2>&1; then
    log_note "Could not assign GoreeCloud Gallery as SYSTEM_GALLERY."
    exit 1
fi
if ! role_contains "$SYSTEM_GALLERY_ROLE" "$GALLERY_PACKAGE"; then
    log_note "Android did not retain GoreeCloud Gallery as SYSTEM_GALLERY."
    exit 1
fi

# Only suppress the Lineage gallery surfaces after the GoreeCloud role assignment is verified.
if has_package "org.lineageos.glimpse"; then
    pm disable-user --user "$USER_ID" org.lineageos.glimpse >/dev/null 2>&1 || true
fi
if has_package "com.android.gallery3d"; then
    pm disable-user --user "$USER_ID" com.android.gallery3d >/dev/null 2>&1 || true
fi

# Launcher3QuickStep intentionally remains installed. GoreeCloud Launcher owns HOME while the
# Lineage package continues to provide the current Development Quickstep/Recents backend.
settings --user "$USER_ID" put secure "$MARKER" 1 >/dev/null 2>&1 || {
    log_note "Default roles were applied, but the one-time initialization marker could not be saved."
    exit 1
}

log_note "GoreeCloud Launcher and Gallery defaults initialized for owner user."
exit 0
