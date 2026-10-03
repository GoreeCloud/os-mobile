# GoreeCloud OS Mobile — LineageOS System App Pack

**Requirement level:** Development / device-qualified engineering package.

This package installs the canonical Android package IDs for nine GoreeCloud applications as non-privileged system apps under `/product/app` on the current GoreeCloud physical baseline: OnePlus Nord N200 (`dre`) running LineageOS 23.2 / Android 16 (API 36).

Included applications:

- GoreeCloud Memos
- GoreeCloud Launcher
- GoreeCloud Browser
- GoreeCloud Keyboard
- GoreeCloud Gallery
- GoreeCloud Mail
- GoreeCloud Camera
- GoreeCloud Since
- GoreeCloud Clock

## Safety boundary

The recovery installer fails closed unless the device identifies as `dre`, `OnePlusN200`, or `OnePlusN200TMO`, reports API 36, reports LineageOS 23.2, and uses `arm64-v8a` as its primary ABI. It does not grant privileged permissions or platform signing authority.

The installer writes only the nine app directories under `/product/app` plus `/system/addon.d/30-goreecloud-os-apps.sh`. The addon.d v3 script preserves those APKs across compatible LineageOS OTA updates.

Launcher and Keyboard are installed as system applications but Android still controls the HOME and input-method selections. The installer does not silently seize those roles.

## Signing boundary

The repository workflow intentionally emits **unsigned canonical release APK inputs**. Signing material must remain outside source control. Before creating a flashable ZIP, sign every APK with the same approved persistent GoreeCloud Development signing identity, then put the signed files in `signed-apks/` using the exact filenames expected by `make-package.sh`.

Do not distribute an engineering package produced with an ephemeral/debug signer as update-compatible. Stable release authority is separate.

## Build

The workflow `.github/workflows/build-lineage-system-app-pack.yml` checks out the exact revisions recorded in `sources.lock.json`, assembles all nine canonical release APKs, verifies package IDs with `aapt`, records hashes and source provenance, and uploads a build-input artifact.

After approved signing:

```bash
packaging/lineage-system-app-pack/make-package.sh /path/to/signed-apks /path/to/output.zip
python3 scripts/verify_lineage_system_app_pack.py /path/to/output.zip
```

Physical sideload, boot, role-selection, camera/IME/browser runtime behavior, and OTA preservation remain device validation gates; repository build success is not equivalent to those checks.
