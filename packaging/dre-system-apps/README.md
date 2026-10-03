# GoreeCloud OS Mobile — OnePlus Nord N200 system app package

This directory defines the Development recovery package for the current GoreeCloud OS Mobile physical qualification baseline:

- Device: OnePlus Nord N200
- Lineage device codename: `dre`
- Android: 16
- LineageOS: 23.x / current qualification baseline 23.2
- Install location: `/product/app`
- OTA persistence: LineageOS addon.d v3
- Android package versionCode baseline: `2026100301`

## Built-in applications

The package installs the canonical Android package identities for:

1. GoreeCloud Memos — `com.goreecloud.memos`
2. GoreeCloud Launcher — `com.goreecloud.launcher`
3. GoreeCloud Browser — `io.goreecloud.browser`
4. GoreeCloud Keyboard — `com.goreecloud.keyboard`
5. GoreeCloud Gallery — `com.goreecloud.gallery`
6. GoreeCloud Mail — `com.goreecloud.mail`
7. GoreeCloud Camera — `com.goreecloud.camera`
8. GoreeCloud Since — `com.goreecloud.since`
9. GoreeCloud Clock — `com.goreecloud.clock`

The CI workflow `.github/workflows/dre-system-app-bundle.yml` pins exact source revisions, assembles canonical release-identity APKs, applies a monotonically increasing Development system-package versionCode, verifies package identity/versionCode, ZIP-aligns each APK, and publishes an unsigned signing-input bundle.

Final signing is intentionally outside public CI. The exact APK set must be signed with the persistent protected GoreeCloud OS Development signing identity before recovery-ZIP assembly. The private key must never be stored in this public repository or included in a flashable package.

## Recovery behavior

`META-INF/com/google/android/update-binary` rejects incompatible targets, mounts `/system` and `/product`, installs the nine signed APKs under `/product/app`, installs the addon.d v3 persistence hook, applies normal system-app file modes, and restores SELinux contexts where recovery exposes `restorecon`.

The package does not delete or replace LineageOS applications. After the first boot, Android may require the user to select GoreeCloud Launcher as HOME and enable/select GoreeCloud Keyboard as the active IME.

## OTA persistence

`system/addon.d/99-goreecloud-system-apps.sh` declares `ADDOND_VERSION=3` and lists the product-partition APKs through `$S/product/...`. This is compatible with LineageOS 23 A/B backuptool behavior, which mounts `product` for addon.d v3 scripts and maps restored product paths into the post-install slot.

## Lifecycle boundary

This package is a Development system-app bundle for representative-device testing and GoreeCloud OS bring-up. Successful build, signing, flashing, or boot does not establish Release Candidate, Production Acceptance, Stable, Seal, or Anchor status.
