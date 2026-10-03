#!/usr/bin/env python3
import json
import pathlib
import sys
import zipfile

EXPECTED = {
    "GoreeCloudMemos.apk": "com.goreecloud.memos",
    "GoreeCloudLauncher.apk": "com.goreecloud.launcher",
    "GoreeCloudBrowser.apk": "io.goreecloud.browser",
    "GoreeCloudKeyboard.apk": "com.goreecloud.keyboard",
    "GoreeCloudGallery.apk": "com.goreecloud.gallery",
    "GoreeCloudMail.apk": "com.goreecloud.mail",
    "GoreeCloudCamera.apk": "com.goreecloud.camera",
    "GoreeCloudSince.apk": "com.goreecloud.since",
    "GoreeCloudClock.apk": "com.goreecloud.clock",
}

def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} ZIP", file=sys.stderr)
        return 2
    path = pathlib.Path(sys.argv[1])
    with zipfile.ZipFile(path) as zf:
        names = set(zf.namelist())
        required = {
            "META-INF/com/google/android/update-binary",
            "META-INF/com/google/android/updater-script",
            "payload/addon.d/30-goreecloud-os-apps.sh",
            "goreecloud/sources.lock.json",
            "goreecloud/SHA256SUMS",
        } | {f"payload/apks/{name}" for name in EXPECTED}
        missing = sorted(required - names)
        if missing:
            raise SystemExit("missing entries: " + ", ".join(missing))
        lock = json.loads(zf.read("goreecloud/sources.lock.json"))
        if lock["target"]["device"] != "dre" or lock["target"]["android_sdk"] != 36:
            raise SystemExit("unexpected target lock")
    print(f"verified structure: {path}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
