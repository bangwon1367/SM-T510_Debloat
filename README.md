Tiered, reversible ADB debloat for Samsung tablets/phones, written for and verified on a
**Galaxy Tab A 10.1 (2019) SM-T510** running Android 11 / One UI Core 3.1.

No root. No bootloader unlock. No custom recovery. Removed packages stay in `/system`, so every
change is undone with `cmd package install-existing`.

    packages before : 328
    packages after  : 258
    removals that stuck through a cold boot : 70 of 71
    (com.samsung.android.game.gos self-heals - see docs/DEVICE-NOTES.md)

The scripts were run end to end against the real device; the numbers above come from that run,
not from a plan.

## Requirements

- `adb` (Android Platform Tools)
  - Windows: `winget install Google.PlatformTools`
  - Debian/Ubuntu: `apt install adb`
- On the device: Settings -> About tablet -> Software info -> tap *Build number* 7x, then
  Developer options -> **USB debugging** ON. Plug in, unlock the screen, accept the RSA prompt.
- `adb devices` must show `<serial>  device` (not `unauthorized`).
- Windows: PowerShell 5.1+. Linux/macOS/git-bash: `bash`.
- If `adb` is not on PATH: `$env:ADB='C:\path\adb.exe'` (PowerShell) or `ADB=/path/adb ./debloat.sh`.

## Quick start

PowerShell (primary, Windows):

```powershell
.\debloat.ps1 check                 # adb + device sanity check
.\debloat.ps1 dump                  # full package list -> packages-<serial>.txt
.\debloat.ps1 list tier2            # dry run: what would be removed. Changes nothing.
.\debloat.ps1 apply tier2           # execute, writes restore-<timestamp>.ps1
.\debloat.ps1 verify .\restore-<timestamp>.ps1   # re-diff the undo file against the device
```

bash twin (same tiers, same guard, same mechanics):

```bash
./debloat.sh check
./debloat.sh dump
./debloat.sh list tier2
./debloat.sh apply tier2
./debloat.sh verify ./restore-<timestamp>.sh
```

**Always run `dump` and `list` before `apply`.** Preloaded apps differ per model, CSC and sales
region; the tier lists here were built from an actual dump of one PHN (Netherlands) SM-T510. `list`
reports how many entries are not present on *your* build, so you can see whether the list fits.

## Commands

| Command | What it does |
|---|---|
| `check` | adb version, device state, model, Android version, build, serial |
| `dump` | writes the full package list to `packages-<serial>.txt` |
| `list <tier>` | dry run; prints `REMOVE`/`SKIP (protected)` plus how many are absent on this build |
| `apply <tier>` | removes (or disables) the tier, writes the undo file, then **verifies** and retries anything that came back |
| `verify <undo-file>` | re-diffs that undo file against the device: still removed / disabled (inert) / ACTIVE AGAIN |
| `enable <pkg> [...]` | re-install specific packages removed earlier |
| `restore <undo-file>` | undo everything in that file |

## Tiers

| Tier | Packages (this device) | Contents |
|---|---|---|
| `tier1` | 38 | telemetry/diagnostics/factory self-test apps, preload + widget-store hooks, unused radios (ANT+), vendor agents (`skms`, `hiya`), Smart Switch, Link-to-Windows, IoT stubs, Kids, Wearable stub, private/allshare, print + carrier helpers, OneDrive, Duo |
| `tier2` | +33 (71 total) | Samsung background features: Reminder, Samsung Cloud, `rubin.app`, `aware.service`, `mapsagent`, mcf*, Dual Messenger, Device Security, GOS, Video, Smart View, Quick Share, Samsung push, gallery extras (Story/NewTrim/PhotoRetouching), stickers, ThemeCenter, dynamiclock, sound extras, Edge panels, chromecustomizations |
| `tier3` | +9 (80 total) | apps you may actually use: Google app/searchbox, YouTube, Maps, Gmail, Google Calendar sync, Samsung Calendar, Contacts, Dialer, Galaxy Finder |

Tier 3 is opt-in on purpose. If you only want "nothing user-visible disappears", stop at `tier1`.

## Safety model

- **Protected list.** `debloat.ps1` / `debloat.sh` carry an explicit allowlist that is never
  touched even if a tier names it: SystemUI, Settings, providers, Play Store (`com.android.vending`),
  GMS/GSF, WebView, shell/packageinstaller/permissioncontroller, the stock launcher, camera, My Files,
  Clock, blue-light filter, wallpaper service, Device Care (`forest`/`lool`), timezone updater,
  TEE/DRM service, Samsung account, OTA updaters, Knox container/keychain/Secure Folder, and Google
  contact sync. On this device it also kept USB settings, the Samsung keyboard + IME, handwriting SDK,
  dictation/photo providers, and IMS/telephony packages. `list` prints `SKIP (protected)` for these.
- **No APK is destroyed.** `pm uninstall -k --user 0 <pkg>` removes the app for the current user and
  keeps its data; the APK remains in `/system`. Undo = `cmd package install-existing <pkg>`.
- **Fallback.** If `pm uninstall` refuses, the script uses `pm disable-user --user 0` and records that
  in the undo file instead.
- **Verification is built in.** A `Success` reply is not proof: see *self-healing* below. `apply`
  re-lists packages afterwards, retries bounced ones, and reports each as
  `removed` / `disabled (sticky)` / `REVERTED`.
- **Undo file per run.** `restore-<timestamp>.ps1|.sh` lists exactly what was acted on and replays
  `install-existing` + `pm enable`.
- Rebooting the tablet after a batch is recommended so launcher/services settle.

## Self-healing packages

On this One UI build, `com.samsung.android.game.gos` (Game Optimizing Service) cannot be removed:
`pm uninstall -k --user 0`, plain `pm uninstall --user 0` and `pm disable-user --user 0` all appear to
succeed, and the package is back within ~20-30 seconds (fresh `ceDataInode`, `PACKAGE_ADDED` broadcast
in logcat). `pm hide` fails with `SecurityException: ... MANAGE_USERS` unless the shell has that
permission. Such packages are reported as `REVERTED - cannot be removed` and need root.

## After the debloat (settings side)

Applied during the verified run on this tablet:

- Developer options -> Window / Transition / Animator duration scale -> **0.5x** (all three).
- Developer options -> **Don't keep activities -> OFF** (leaving it on makes app switching *slower*).
- Developer options -> Standby apps (adb: `am set-standby-bucket <pkg> restricted`) for YouTube, Maps
  and the Google app -> landed in **RARE**; verified to hold.
- Developer options -> Logger buffer sizes -> **64K** (UI-only setting).
- Automatic system updates -> OFF.
- Leave OFF: Force 4x MSAA, Force GPU rendering, Disable HW overlays, Show layout bounds, GPU watch,
  Strict mode, pointer location, show taps.
- Skip `Background process limit` (not persistent) and `Force allow apps on external` (slower storage,
  only worth it if internal storage is actually full).

## Repo layout

    debloat.ps1                    Windows/PowerShell script (primary)
    debloat.sh                     bash twin, same tiers and guard
    test/adb.cmd                   stub adb for testing the PowerShell script with no device
    test/fakeadb                   stub adb for testing the bash script with no device

## Testing without a device

Both scripts were exercised against stub `adb` implementations, so the logic is covered even when no
tablet is attached:

```powershell
# PowerShell
$env:ADB = "$PWD\test\adb.cmd"; .\debloat.ps1 list tier1
```

```bash
# bash
ADB=./test/fakeadb ./debloat.sh list tier1
```

The stubs answer `devices`, `version`, `get-state`, `shell pm list packages`, `shell pm uninstall`
(`Success`), `shell pm enable` and `shell pm disable-user`.

## Caveats

- Package names are Samsung/vendor internals; they change between One UI versions. Re-`dump` and
  re-`list` after any firmware change.
- Tier lists here are tuned for a Wi-Fi-only tablet (no SIM). On a phone, keep the telephony/IMS
  entries - they are protected in the scripts for that reason.
- No pre-debloat idle-RAM baseline was captured, so this repo makes no perf claim. What is verified is
  the package delta and that removals survive a reboot. Measure your own before/after, e.g.
  `adb shell dumpsys meminfo | grep -E "Total RAM|Free RAM|Used RAM|ZRAM"`.
- This method does not unlock the bootloader or trip Knox. Anything that does (TWRP/LineageOS) is a
  different trade-off entirely.
- No license file included yet - add one before publishing.
