# GoreeCloud OS Mobile — dre Physical Qualification Procedure

**Requirement level:** Mandatory for representative-device acceptance  
**Lifecycle:** Development  
**Target:** OnePlus Nord N200 (`dre`)  
**Baseline:** LineageOS 23.2 / Android 16  
**Candidate:** GoreeCloud/os-mobile PR #6

## Purpose

This procedure defines the evidence required to qualify the current GoreeCloud OS Mobile Development system-app package on the physical `dre` device. It is intentionally separate from build/CI success.

The current candidate is expected to:

- install nine GoreeCloud applications as `/product/app` system applications;
- install the GoreeCloud Gallery framework overlay under `/product/overlay`;
- make `com.goreecloud.launcher` the owner-user Android HOME holder;
- make `com.goreecloud.gallery` the static Android `SYSTEM_GALLERY` holder;
- retain `com.android.launcher3` / Launcher3QuickStep as the current Development Recents/Quickstep backend;
- suppress Lineage Glimpse / legacy Gallery2 only after GoreeCloud Gallery role assignment succeeds;
- preserve the package and default-app integration through LineageOS addon.d v3.

Passing this procedure does not establish Release Candidate, Production Acceptance, Stable, Seal, or Anchor status.

## 1. Required safety gates before flashing

Do not begin physical qualification until all of the following are true:

1. A recoverable known-good LineageOS state and the normal device restore/reflash path are available.
2. The exact signed recovery ZIP has been copied to the authorized GoreeCloud Google Drive delivery directory.
3. The candidate ZIP filename, byte size, and SHA-256 checksum are recorded in the active Tasks Management record.
4. All ten APKs in the signed package use the same approved persistent GoreeCloud OS Development signing identity and Development versionCode `2026100302`.
5. The signer fingerprint has been verified against the approved Development signing record.
6. The device is the OnePlus Nord N200 codename `dre`, running Android 16 and a LineageOS 23.x / 23.2 qualification baseline.
7. If the Development signer differs from any previously installed GoreeCloud package signer, stop and resolve update-continuity implications before flashing. Do not use uninstall/reinstall as the normal update path.

Record the exact device build fingerprint before installation:

```sh
adb shell getprop ro.product.device
adb shell getprop ro.build.version.release
adb shell getprop ro.lineage.version
adb shell getprop ro.build.fingerprint
```

Expected target identity:

- `ro.product.device`: `dre`
- Android release: `16`
- Lineage version: `23.x`

Any target mismatch is a hard stop.

## 2. Recovery installation

Boot the device into Lineage Recovery, choose **Apply Update** → **Apply from ADB**, then sideload the exact approved Development ZIP:

```sh
adb sideload <SIGNED_GOREECLOUD_DRE_ZIP>
```

A third-party add-on signature warning is expected when the outer recovery ZIP is not signed by the LineageOS release key. Continue only when the filename and SHA-256 checksum match the approved candidate.

A recovery installation failure, mount failure, target-guard failure, extraction failure, or unexpected reboot is a failed qualification attempt. Preserve the recovery log where available.

## 3. First-boot evidence

After the first successful Android boot, wait until `sys.boot_completed` reports `1`:

```sh
adb wait-for-device
adb shell getprop sys.boot_completed
```

Capture the default-app initializer log:

```sh
adb shell logcat -d -s GoreeCloudDefaults
```

Expected result: the initializer reports that GoreeCloud Launcher and Gallery defaults were initialized, with no preceding failure message.

Also verify the one-time marker:

```sh
adb shell settings --user 0 get secure goreecloud_default_apps_initialized
```

Expected result: `1`.

The marker alone is not acceptance evidence; all role and routing checks below must also pass.

## 4. Package-manager acceptance

Verify every GoreeCloud package resolves to an installed path:

```sh
adb shell pm path --user 0 com.goreecloud.memos
adb shell pm path --user 0 com.goreecloud.launcher
adb shell pm path --user 0 io.goreecloud.browser
adb shell pm path --user 0 com.goreecloud.keyboard
adb shell pm path --user 0 com.goreecloud.gallery
adb shell pm path --user 0 com.goreecloud.mail
adb shell pm path --user 0 com.goreecloud.camera
adb shell pm path --user 0 com.goreecloud.since
adb shell pm path --user 0 com.goreecloud.clock
adb shell pm path --user 0 com.goreecloud.overlay.gallery.frameworksbase
```

Expected application locations are under `/product/app/GoreeCloud...`. The Gallery framework overlay is expected under `/product/overlay/GoreeCloudGalleryFrameworksBaseOverlay.apk`.

Record installed version codes:

```sh
for p in \
  com.goreecloud.memos \
  com.goreecloud.launcher \
  io.goreecloud.browser \
  com.goreecloud.keyboard \
  com.goreecloud.gallery \
  com.goreecloud.mail \
  com.goreecloud.camera \
  com.goreecloud.since \
  com.goreecloud.clock \
  com.goreecloud.overlay.gallery.frameworksbase
do
  adb shell dumpsys package "$p" | grep -m1 versionCode
done
```

Expected Development versionCode for every candidate package: `2026100302`.

## 5. Gallery framework-overlay resolution

First verify that Android sees the GoreeCloud overlay:

```sh
adb shell cmd overlay list --user 0 android
adb shell cmd overlay dump --user 0 com.goreecloud.overlay.gallery.frameworksbase
```

Then verify the effective framework resource after all enabled overlays are applied:

```sh
adb shell cmd overlay lookup --user 0 android android:string/config_systemGallery
```

The resolved value must identify `com.goreecloud.gallery`. If it resolves to `org.lineageos.glimpse`, the GoreeCloud overlay has not won the effective configuration and the candidate fails the system-Gallery gate.

Also record overlay partition ordering:

```sh
adb shell cmd overlay partition-order
```

If an overlay configuration file changes the expected mutability, enabled state, or priority of the GoreeCloud overlay, treat that as a failure until the packaged overlay configuration is corrected.

## 6. HOME role qualification

Verify the HOME holder:

```sh
adb shell cmd role get-role-holders --user 0 android.app.role.HOME
```

Expected holder:

```text
com.goreecloud.launcher
```

Then exercise the user-visible behavior:

1. Press Home from at least three unrelated applications.
2. Launch several applications from GoreeCloud Launcher and return Home.
3. Reboot and repeat the Home-key test.
4. Confirm no repeated default-launcher chooser appears during ordinary use.
5. If the user intentionally changes HOME later, confirm the one-time initializer does not overwrite that later user choice on each boot.

Any crash loop, unresolved HOME chooser, role loss after reboot, or inability to reach a usable launcher fails the HOME gate.

## 7. Recents / Quickstep continuity

The current Development candidate does not replace Quickstep/Recents. Verify the Lineage Launcher3 package remains installed:

```sh
adb shell pm path --user 0 com.android.launcher3
```

Exercise Recents repeatedly from GoreeCloud Launcher and several running apps. Verify:

- Recents opens reliably;
- recent tasks render;
- task switching works;
- dismissing a recent task works;
- returning Home still returns to GoreeCloud Launcher;
- no Launcher3 HOME takeover occurs during normal Recents use.

Failure of Recents/Quickstep is a candidate failure even if the HOME role itself is correct.

## 8. SYSTEM_GALLERY role qualification

Verify Android's static system-Gallery holder:

```sh
adb shell cmd role get-role-holders --user 0 android.app.role.SYSTEM_GALLERY
```

Expected holder:

```text
com.goreecloud.gallery
```

Then inspect fallback Gallery package state:

```sh
adb shell pm list packages -d | grep -E 'org\.lineageos\.glimpse|com\.android\.gallery3d'
adb shell pm path --user 0 org.lineageos.glimpse
adb shell pm path --user 0 com.android.gallery3d
```

The fallback binaries may remain installed, but their user-facing packages should only be disabled after the GoreeCloud Gallery role is successfully verified. A missing GoreeCloud role combined with disabled fallback Gallery packages is a hard failure.

## 9. Gallery routing and secure-review behavior

Use known local image and video files already present on the qualification device. Do not use private or sensitive media for the test evidence.

Validate each supported routing path:

- ordinary image VIEW opens GoreeCloud Gallery;
- ordinary video VIEW opens GoreeCloud Gallery;
- Android REVIEW routing opens GoreeCloud Gallery for supported local image/video URIs;
- secure-review routing opens GoreeCloud Gallery and prevents screenshots/screen capture as required by the secure-review contract;
- unsupported MIME types and unrelated URI schemes are rejected rather than silently broadening authority;
- externally supplied VIEW/REVIEW requests do not cause Gallery to enumerate unrelated media beyond the supplied local URI.

Record the invoking action, URI type/scheme, MIME type, observed target activity, and result for each case.

## 10. GoreeCloud Keyboard

Android requires the user to enable/select an IME separately. Verify GoreeCloud Keyboard is installed, then enable it through the normal Android input-method settings and select it as the active keyboard.

Test typing in at least two unrelated applications. Record whether the keyboard survives application switching and reboot.

Do not treat the package installer as having authority to silently enable the IME for the user.

## 11. Application smoke tests

Launch and perform one representative basic action in each of the nine built-in applications:

- Memos
- Launcher
- Browser
- Keyboard
- Gallery
- Mail
- Camera
- Since
- Clock

At minimum, record launch success, immediate crash/ANR status, basic navigation, and any permission prompt that materially affects normal use.

For Gallery specifically, also validate permission grant, denial, and revocation behavior relevant to its system-Gallery role. Do not broaden its authority beyond the implemented Android permission/role contract merely to make a test pass.

## 12. Reboot persistence

Perform a normal reboot, then repeat:

```sh
adb shell cmd role get-role-holders --user 0 android.app.role.HOME
adb shell cmd role get-role-holders --user 0 android.app.role.SYSTEM_GALLERY
adb shell cmd overlay lookup --user 0 android android:string/config_systemGallery
adb shell settings --user 0 get secure goreecloud_default_apps_initialized
```

All expected results must remain valid after reboot.

## 13. LineageOS OTA / addon.d v3 persistence

Only perform this test with a compatible LineageOS OTA and a verified rollback path.

Before OTA, record the package paths, versionCodes, role holders, effective `config_systemGallery`, and SHA-256 hashes of the installed GoreeCloud APK files where practical.

Apply the compatible LineageOS OTA through the normal supported update path, boot the updated slot, then verify:

1. all nine GoreeCloud applications remain present;
2. the Gallery framework overlay remains present;
3. `/product/bin/goreecloud-default-apps.sh` remains present and executable;
4. `/product/etc/init/goreecloud-default-apps.rc` remains present;
5. the addon.d hook remains present;
6. HOME still resolves to GoreeCloud Launcher;
7. `SYSTEM_GALLERY` still resolves to GoreeCloud Gallery;
8. `config_systemGallery` still resolves to `com.goreecloud.gallery`;
9. Recents/Quickstep remains usable;
10. all nine applications still pass basic launch checks.

An OTA that boots but drops any required GoreeCloud payload or default-role behavior fails the persistence gate.

## 14. Rollback / recovery exercise

The Development package deliberately retains upstream fallback binaries. Qualification still requires an actual recovery exercise.

With a known-good LineageOS restore/reflash path available, verify that the device can be returned to a usable baseline if the GoreeCloud package fails.

Record:

- rollback method used;
- restored LineageOS build fingerprint;
- boot success;
- usable HOME/Recents state;
- usable Gallery/media-opening state;
- whether any user data was lost.

Do not present uninstall/reinstall of GoreeCloud packages as the normal update mechanism. If uninstall is ever used as a recovery workaround, explicitly record that application-local data may be removed.

## 15. Evidence record

For each physical qualification attempt, record at minimum:

- date/time;
- tester;
- device model and serial redacted to the minimum necessary;
- `ro.product.device`;
- LineageOS version;
- Android version;
- build fingerprint;
- signed package filename, byte size, SHA-256;
- Development signing certificate SHA-256 fingerprint;
- source PR and exact Git commit;
- CI run ID used as build evidence;
- result of every section in this procedure;
- relevant non-secret logs/screenshots;
- failures, workarounds, and retest result.

Never include private signing-key material, passphrases, authentication tokens, recovery codes, or unrelated personal data in qualification evidence.

## Acceptance rule

Representative-device qualification passes only when every mandatory section above succeeds against the exact signed candidate being evaluated. A result from a different source head, APK set, signing identity, or recovery ZIP is not inherited.

If any mandatory check fails, keep the candidate in Development, preserve the failure in GoreeCloud Tasks Management, correct the authoritative source, build a new exact-head candidate, and repeat the affected acceptance work.
