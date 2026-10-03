# GoreeCloud OS Mobile — OnePlus Nord N200 system app package

This directory defines the Development recovery package for the current GoreeCloud OS Mobile physical qualification baseline:

- Device: OnePlus Nord N200
- Lineage device codename: `dre`
- Android: 16
- LineageOS: 23.x / current qualification baseline 23.2
- Install location: `/product/app`
- OTA persistence: LineageOS addon.d v3
- Android package versionCode baseline: `2026100302`

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

The CI workflow `.github/workflows/dre-system-app-bundle.yml` pins exact source revisions, assembles canonical release-identity APKs, applies a monotonically increasing Development system-package versionCode, verifies package identity/versionCode, ZIP-aligns each APK, builds the GoreeCloud system-Gallery framework RRO, and publishes one unsigned signing-input bundle.

Final signing is intentionally outside public CI. The nine application APKs and the framework-overlay APK must all be signed with the persistent protected GoreeCloud OS Development signing identity before recovery-ZIP assembly. The private key must never be stored in this public repository or included in a flashable package.

## Protected signed-package assembly

`tools/assemble-signed-package.sh` is the canonical local assembler for the signed Development recovery ZIP. It validates the unsigned artifact checksums, signs all ten APK inputs, verifies that every APK uses the same certificate, verifies package identity and the common Development versionCode, builds the recovery ZIP from the repository packaging source, preserves the default-app integration files, emits relative signed-payload checksums and public certificate metadata, and validates the resulting archive.

The assembler deliberately does **not** accept a password value on its command line. It requires the keystore and local password files to be protected from group/world access. Normal Development assembly also requires the expected public certificate SHA-256 fingerprint, so an accidental signer change fails closed. The exact packaging subtree must be clean and match the requested source revision before assembly proceeds. Ephemeral CI output is classified as `signed-test-only` in provenance rather than as a Development-signed package.

Example shape:

```sh
packaging/dre-system-apps/tools/assemble-signed-package.sh \
  --unsigned-bundle <exact-head-unsigned-bundle.zip> \
  --keystore <protected-development-keystore> \
  --key-alias <development-key-alias> \
  --ks-pass-file <protected-password-file> \
  --expected-cert-sha256 <approved-certificate-sha256> \
  --output <signed-development-recovery.zip>
```

Public CI uses the same assembler only with a short-lived, generated test key and an output filename containing `TEST-ONLY`. That bounded smoke test verifies package assembly but does not create or publish an update-compatible Development package and does not place a persistent private signing identity in CI.

## Default Launcher and Gallery behavior

GoreeCloud OS Mobile intentionally makes the GoreeCloud applications the user-facing defaults on the qualification device:

- `com.goreecloud.launcher` becomes the Android HOME role holder after the first successful boot.
- `com.goreecloud.gallery` becomes Android's static `SYSTEM_GALLERY` holder. A product framework RRO changes `config_systemGallery` from Lineage Glimpse to GoreeCloud Gallery so the package legitimately qualifies for this static role.
- After the GoreeCloud Gallery role is verified, Lineage Glimpse (`org.lineageos.glimpse`) and legacy Gallery2 (`com.android.gallery3d`) are disabled for owner user 0 rather than deleted.
- Lineage `Launcher3QuickStep` remains installed because the current GoreeCloud Launcher Development line does not yet replace Android Quickstep/Recents. It no longer owns HOME after successful initialization.

The runtime initializer is deliberately one-time. It establishes the GoreeCloud defaults for this OS package, then records completion in owner-user secure settings. It does not continually overwrite a later user choice on every reboot.

## Recovery behavior

`META-INF/com/google/android/update-binary` rejects incompatible targets, mounts `/system` and `/product`, installs the nine signed application APKs under `/product/app`, installs the signed framework RRO under `/product/overlay`, installs the one-time default-app initializer under `/product/bin` and `/product/etc/init`, installs the addon.d v3 persistence hook, applies normal system-file modes, and restores SELinux contexts where recovery exposes `restorecon`.

GoreeCloud Keyboard remains an IME that Android requires the user to enable/select separately after boot.

## OTA persistence

`system/addon.d/99-goreecloud-system-apps.sh` declares `ADDOND_VERSION=3` and preserves the product-partition application APKs, Gallery framework overlay, default-app initializer, and init service through `$S/product/...`. This is compatible with LineageOS 23 A/B backuptool behavior, which mounts `product` for addon.d v3 scripts and maps restored product paths into the post-install slot.

## Recovery and rollback boundary

The stock Lineage Gallery and Launcher/Quickstep binaries are retained instead of destructively removed. This keeps a recovery path available while GoreeCloud OS Mobile is in Development. A physical-device rollback exercise is still required before broader qualification; a full LineageOS restore/reflash must remain available while testing this package.

## Lifecycle boundary

This package is a Development system-app bundle for representative-device testing and GoreeCloud OS bring-up. Successful build, signing, flashing, default-role assignment, or boot does not establish Release Candidate, Production Acceptance, Stable, Seal, or Anchor status.
