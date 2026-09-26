#!/usr/bin/env bash
# debloat.sh - POSIX/git-bash twin of debloat.ps1 (same tiers, same guard, same mechanics).
# Samsung Galaxy Tab A 10.1 (2019) SM-T510 / Android 11 / One UI Core 3.1. No root required.
#
#   ./debloat.sh check                 # adb + device sanity check
#   ./debloat.sh dump                  # full package list -> packages-<serial>.txt
#   ./debloat.sh list  tier1|tier2|tier3   # dry run, changes nothing
#   ./debloat.sh apply tier1|tier2|tier3   # execute; writes restore-<ts>.sh (undo)
#   ./debloat.sh verify restore-<ts>.sh    # re-diff an undo file against the device
#   ./debloat.sh enable <pkg> [...]    # re-install specific packages
#   ./debloat.sh restore restore-<ts>.sh   # undo everything in that file
#
# adb:  winget install Google.PlatformTools   (Windows)  |  apt install adb  (Debian/Ubuntu)
# Override the binary with  ADB=/path/to/adb ./debloat.sh ...
set -uo pipefail

ADB="${ADB:-adb}"
HERE="$(cd "$(dirname "$0")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"

# ---------------------------------------------------------------- protected
# Never touched, even if a tier names them.
PROTECTED=(
  com.android.systemui
  com.android.settings
  com.android.providers.settings
  com.android.providers.contacts
  com.android.providers.media
  com.android.providers.telephony
  com.android.providers.downloads
  com.android.shell
  com.android.packageinstaller
  com.android.permissioncontroller
  com.android.vending
  com.google.android.gms
  com.google.android.gsf
  com.google.android.webview
  com.android.webview
  com.android.keychain
  com.android.documentsui
  com.samsung.android.providers.contacts
  com.samsung.android.providers.media
  com.samsung.android.mtp
  com.samsung.android.MtpApplication
  com.sec.android.app.launcher
  com.samsung.android.app.telephonyui
  com.samsung.android.incallui
  com.samsung.android.mobileservice
  com.samsung.android.forest
  com.samsung.android.lool
  com.sec.android.app.SecSetupWizard
  com.samsung.android.ServiceWizard
  com.samsung.android.keyguardwallpaperupdator
  com.sec.android.app.camera
  com.sec.android.app.clockpackage
  com.sec.android.app.myfiles
  com.samsung.android.app.sbrowser.assistant
  # device-specific keeps (verified present on SM-T510 / One UI Core 3.1)
  com.sec.usbsettings
  com.samsung.android.bluelightfilter
  com.samsung.android.app.dressroom
  com.samsung.android.honeyboard
  com.sec.android.inputmethod
  com.samsung.android.motionphoto.viewer
  com.samsung.android.sdk.handwriting
  com.samsung.android.timezone.updater
  com.sec.timezone
  com.trustonic.teeservice
  com.osp.app.signin
  com.wssyncmldm
  com.sec.android.soagent
  com.samsung.android.localeoverlaymanager
  com.monotype.android.font.samsungone
  com.monotype.android.font.foundation
  com.sec.android.app.ringtoneBR
  com.samsung.android.provider.filterprovider
  com.sec.hearingadjust
  com.sec.sve
  com.sec.imsservice
  com.samsung.advp.imssettings
  com.samsung.android.smartcallprovider
  com.samsung.android.knox.containercore
  com.samsung.android.knox.containeragent
  com.samsung.knox.keychain
  com.samsung.knox.securefolder
  com.samsung.android.kgclient
  com.samsung.android.sdm.config
  com.google.android.syncadapters.contacts
)

# ---------------------------------------------------------------- tier 1: safe
TIER1=(
  # telemetry / diagnostics / logging
  com.samsung.android.dqagent
  com.sec.android.diagmonagent
  com.sec.android.app.DataCreate
  com.samsung.android.knox.analytics.uploader
  com.samsung.android.securitylogagent
  com.sec.imslogger
  com.samsung.android.gpuwatchapp
  # factory / hardware test apps
  com.sec.factory
  com.sec.factory.camera
  com.sec.android.app.factorykeystring
  com.sec.android.app.hwmoduletest
  com.sec.android.app.bluetoothtest
  com.sec.android.app.wlantest
  com.sec.android.app.servicemodeapp
  com.sec.android.RilServiceModeApp
  # preload / widget store hooks
  com.sec.android.preloadinstaller
  com.sec.android.widgetapp.samsungapps
  com.sec.android.widgetapp.webmanual
  com.samsung.android.app.updatecenter
  # unused radios / vendor agents
  com.dsi.ant.server
  com.dsi.ant.plugins.antplus
  com.dsi.ant.sample.acquirechannels
  com.dsi.ant.service.socket
  com.skms.android.agent
  com.hiya.star
  # transfer / PC link / IoT stubs
  com.samsung.android.smartswitchassistant
  com.sec.android.easyMover.Agent
  com.samsung.android.mdx.kit
  com.samsung.android.mdx.quickboard
  com.samsung.android.beaconmanager
  com.samsung.android.kidsinstaller
  com.samsung.android.app.watchmanagerstub
  # share / print / carrier helpers
  com.samsung.android.privateshare
  com.samsung.android.allshare.service.fileshare
  com.samsung.android.allshare.service.mediashare
  com.google.android.printservice.recommendation
  com.google.android.apps.carrier.carrierwifi
  com.microsoft.skydrive
  com.google.android.apps.tachyon
)

# ---------------------------------------------------------------- tier 2: Samsung extras
TIER2=(
  com.samsung.android.app.reminder
  com.samsung.android.scloud
  com.samsung.android.rubin.app
  com.samsung.android.aware.service
  com.samsung.android.mapsagent
  com.samsung.android.mcfds
  com.samsung.android.mcfserver
  com.samsung.android.appseparation
  com.samsung.android.homemode
  com.samsung.android.sm.devicesecurity
  com.samsung.android.sm.policy
  com.samsung.android.game.gos
  com.samsung.android.video
  com.samsung.android.easysetup
  com.samsung.android.smartmirroring
  com.samsung.android.app.simplesharing
  com.samsung.android.app.sharelive
  com.sec.spp.push
  # gallery / media extras
  com.samsung.storyservice
  com.samsung.app.newtrim
  com.sec.android.mimage.photoretouching
  com.sec.android.app.ve.vebgm
  com.samsung.android.livestickers
  com.samsung.android.stickercenter
  # theming / wallpaper / sound extras
  com.samsung.android.themecenter
  com.samsung.android.dynamiclock
  com.sec.android.app.soundalive
  com.samsung.android.secsoundpicker
  com.samsung.android.app.soundpicker
  # edge panels
  com.samsung.android.app.appsedge
  com.samsung.android.app.clipboardedge
  com.samsung.android.app.cocktailbarservice
  com.sec.android.app.chromecustomizations
)

# ---------------------------------------------------------------- tier 3: your call
TIER3=(
  com.google.android.googlequicksearchbox
  com.google.android.youtube
  com.google.android.apps.maps
  com.google.android.gm
  com.google.android.syncadapters.calendar
  com.samsung.android.calendar
  com.samsung.android.app.contacts
  com.samsung.android.dialer
  com.samsung.android.app.galaxyfinder
  com.android.autoinstalls.config.samsung
)

# ---------------------------------------------------------------- helpers
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

need_adb() {
  command -v "$ADB" >/dev/null 2>&1 || die "adb not found ('$ADB'). See README, or set ADB=/path/to/adb."
}

need_device() {
  need_adb
  local n
  n="$("$ADB" devices | awk 'NR>1 && $2=="device"' | wc -l)"
  [ "$n" -ge 1 ] || die "no authorized device. Enable Developer options > USB debugging, plug in, accept the RSA prompt."
}

is_protected() {
  local p="$1" x
  for x in "${PROTECTED[@]}"; do [ "$x" = "$p" ] && return 0; done
  return 1
}

get_installed() { "$ADB" shell pm list packages 2>/dev/null | tr -d '\r' | sed 's/^package://' | sort -u; }
get_disabled()  { "$ADB" shell pm list packages -d 2>/dev/null | tr -d '\r' | sed 's/^package://' | sort -u; }

tier_list() {
  case "$1" in
    tier1) printf '%s\n' "${TIER1[@]}" ;;
    tier2) printf '%s\n' "${TIER1[@]}" "${TIER2[@]}" ;;
    tier3) printf '%s\n' "${TIER1[@]}" "${TIER2[@]}" "${TIER3[@]}" ;;
    *) die "unknown tier: $1 (use tier1|tier2|tier3)" ;;
  esac
}

do_list() {
  local tier="$1" p
  get_installed > "$HERE/.installed.txt"
  local hit=0 miss=0
  while read -r p; do
    [ -n "$p" ] || continue
    if grep -qx "$p" "$HERE/.installed.txt"; then
      if is_protected "$p"; then printf '  SKIP (protected) %s\n' "$p"
      else printf '  REMOVE %s\n' "$p"; hit=$((hit+1)); fi
    else miss=$((miss+1)); fi
  done < <(tier_list "$tier")
  printf -- '-- would remove: %d   not present on this build: %d\n' "$hit" "$miss"
}

do_apply() {
  local tier="$1" p rf ok=0 fail=0 bounced
  rf="$HERE/restore-$TS.sh"
  printf '#!/usr/bin/env bash\n# undo file %s - re-runs install-existing + pm enable\nset -uo pipefail\nADB="${ADB:-adb}"\n' "$TS" > "$rf"
  get_installed > "$HERE/.installed.txt"
  while read -r p; do
    [ -n "$p" ] || continue
    grep -qx "$p" "$HERE/.installed.txt" || continue
    if is_protected "$p"; then printf 'SKIP protected %s\n' "$p"; continue; fi
    if "$ADB" shell pm uninstall -k --user 0 "$p" 2>&1 | grep -qi 'Success'; then
      printf 'removed  %s\n' "$p"
      { printf 'echo restoring %s\n' "$p"
        printf '"$ADB" shell cmd package install-existing %s\n' "$p"
        printf '"$ADB" shell pm enable %s >/dev/null 2>&1\n' "$p"; } >> "$rf"
      ok=$((ok+1))
    elif "$ADB" shell pm disable-user --user 0 "$p" 2>&1 | grep -qi 'new state: disabled'; then
      printf 'disabled %s\n' "$p"
      printf '"$ADB" shell pm enable %s\n' "$p" >> "$rf"
      ok=$((ok+1))
    else
      printf 'FAILED   %s\n' "$p"; fail=$((fail+1))
    fi
  done < <(tier_list "$tier")

  # verify: some Samsung packages (e.g. com.samsung.android.game.gos) self-heal within ~30s
  get_installed > "$HERE/.after.txt"
  bounced="$(comm -12 <(grep -oE 'com\.[a-zA-Z0-9._]+' "$rf" | sort -u) "$HERE/.after.txt")"
  if [ -n "$bounced" ]; then
    printf -- '-- package(s) came back, retrying with disable-user\n'
    while read -r p; do [ -n "$p" ] && "$ADB" shell pm disable-user --user 0 "$p" >/dev/null 2>&1; done <<< "$bounced"
    sleep 20
    get_disabled > "$HERE/.dis.txt"
    while read -r p; do
      [ -n "$p" ] || continue
      if grep -qx "$p" "$HERE/.dis.txt"; then printf 'disabled (sticky)            %s\n' "$p"
      elif "$ADB" shell pm list packages "$p" | tr -d '\r' | grep -qx "package:$p"; then printf 'REVERTED - cannot be removed: %s\n' "$p"
      else printf 'removed on 2nd pass          %s\n' "$p"; fi
    done <<< "$bounced"
  fi

  chmod +x "$rf" 2>/dev/null
  printf -- '-- removed/disabled: %d  failed: %d\n-- undo file: %s\n-- power-cycle the tablet now.\n' "$ok" "$fail" "$rf"
}

do_verify() {
  local f="$1" p back=0 tot=0
  [ -f "$f" ] || die "no such file: $f"
  get_installed > "$HERE/.now.txt"; get_disabled > "$HERE/.dis.txt"
  while read -r p; do
    [ -n "$p" ] || continue; tot=$((tot+1))
    if grep -qx "$p" "$HERE/.now.txt"; then
      back=$((back+1))
      if grep -qx "$p" "$HERE/.dis.txt"; then printf '  disabled (inert) %s\n' "$p"
      else printf '  ACTIVE AGAIN    %s\n' "$p"; fi
    fi
  done < <(grep -oE 'com\.[a-zA-Z0-9._]+' "$f" | sort -u)
  printf -- 'checked %d packages from %s\nstill removed : %d\nback on device: %d\n' "$tot" "$(basename "$f")" "$((tot-back))" "$back"
}

case "${1:-}" in
  check)
    need_adb
    "$ADB" version | head -1
    printf 'state : %s\n' "$("$ADB" get-state 2>&1 | tr -d '\r')"
    for p in ro.product.model ro.build.version.release ro.build.display.id ro.serialno; do
      printf '%s : %s\n' "$p" "$("$ADB" shell getprop "$p" | tr -d '\r')"
    done ;;
  dump)
    need_device
    s="$("$ADB" shell getprop ro.serialno | tr -d '\r')"
    out="$HERE/packages-$s.txt"
    "$ADB" shell pm list packages -f 2>/dev/null | tr -d '\r' | sed 's/^package://' | sort > "$out"
    printf '%s packages -> %s\n' "$(wc -l < "$out" | tr -d ' ')" "$out" ;;
  list)    need_device; do_list   "${2:-tier1}" ;;
  apply)   need_device; do_apply  "${2:-tier1}" ;;
  verify)  need_device; do_verify "${2:?usage: verify restore-<ts>.sh}" ;;
  restore)
    need_device
    f="${2:?usage: restore restore-<ts>.sh}"
    [ -f "$f" ] || die "no such file: $f"
    ADB="$ADB" bash "$f"
    printf -- '-- undo complete; power-cycle the tablet now.\n' ;;
  enable)
    need_device
    shift
    [ $# -gt 0 ] || die 'usage: enable <pkg> [<pkg>...]'
    for p in "$@"; do
      printf 'restoring %s\n' "$p"
      "$ADB" shell cmd package install-existing "$p" 2>&1 | tr -d '\r'
      "$ADB" shell pm enable "$p" 2>&1 | tr -d '\r'
    done ;;
  *)
    sed -n '2,16p' "$0" ;;
esac
