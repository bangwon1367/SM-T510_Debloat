# debloat.ps1 - Windows-native debloat helper for Samsung Galaxy Tab A 10.1 (2019) SM-T510
# Android 11 / One UI Core 3.1. No root, no git-bash, no WSL needed. PowerShell 5.1+.
#
#   .\debloat.ps1 check                # adb + device sanity check
#   .\debloat.ps1 dump                 # save full package list to packages-<serial>.txt
#   .\debloat.ps1 list  tier1|tier2    # dry run, changes nothing
#   .\debloat.ps1 apply tier1|tier2    # execute; writes restore-<ts>.ps1 (undo)
#   .\debloat.ps1 restore .\restore-<ts>.ps1
#   .\debloat.ps1 enable <pkg> [<pkg>] # re-install specific packages after a debloat
#
# adb: install with  winget install Google.PlatformTools   (adds ...\WinGet\Links\adb.exe to PATH)
# If adb is elsewhere:  $env:ADB = 'C:\path\to\adb.exe'  before calling this script.

[CmdletBinding()]
param(
  [Parameter(Position=0)][ValidateSet('check','dump','list','apply','restore','enable','verify')][string]$Command,
  [Parameter(Position=1, ValueFromRemainingArguments=$true)][string[]]$Rest
)

$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Adb  = if ($env:ADB) { $env:ADB } else { 'adb' }
function Die($m) { Write-Error $m; exit 1 }

$Protected = @(
  'com.android.systemui','com.android.settings','com.android.providers.settings',
  'com.android.providers.contacts','com.android.providers.media','com.android.providers.telephony',
  'com.android.providers.downloads','com.android.shell','com.android.packageinstaller',
  'com.android.permissioncontroller','com.android.vending','com.google.android.gms',
  'com.google.android.gsf','com.google.android.webview','com.android.webview','com.android.keychain',
  'com.samsung.android.providers.contacts','com.samsung.android.providers.media',
  'com.samsung.android.mtp','com.samsung.android.MtpApplication',
  'com.sec.android.app.launcher','com.samsung.android.app.telephonyui','com.samsung.android.incallui',
  'com.samsung.android.mobileservice','com.samsung.android.forest','com.samsung.android.lool',
  'com.sec.android.app.SecSetupWizard','com.samsung.android.ServiceWizard',
  'com.samsung.android.keyguardwallpaperupdator','com.sec.android.app.camera',
  'com.sec.android.app.clockpackage','com.android.documentsui','com.sec.android.app.myfiles',
  'com.samsung.android.app.sbrowser.assistant',
  # device-specific keeps (SM-T510 / One UI Core 3.1, verified present)
  'com.sec.usbsettings','com.samsung.android.bluelightfilter','com.samsung.android.app.dressroom',
  'com.samsung.android.honeyboard','com.sec.android.inputmethod','com.samsung.android.motionphoto.viewer',
  'com.samsung.android.sdk.handwriting','com.samsung.android.timezone.updater','com.sec.timezone',
  'com.trustonic.teeservice','com.osp.app.signin','com.wssyncmldm','com.sec.android.soagent',
  'com.samsung.android.localeoverlaymanager','com.monotype.android.font.samsungone',
  'com.monotype.android.font.foundation','com.sec.android.app.ringtoneBR',
  'com.samsung.android.provider.filterprovider','com.sec.hearingadjust','com.sec.sve',
  'com.sec.imsservice','com.samsung.advp.imssettings','com.samsung.android.smartcallprovider',
  'com.samsung.android.knox.containercore','com.samsung.android.knox.containeragent',
  'com.samsung.knox.keychain','com.samsung.knox.securefolder','com.samsung.android.kgclient',
  'com.samsung.android.sdm.config','com.google.android.syncadapters.contacts'
)

$Tier1 = @(
  # telemetry / diagnostics / logging
  'com.samsung.android.dqagent','com.sec.android.diagmonagent','com.sec.android.app.DataCreate',
  'com.samsung.android.knox.analytics.uploader','com.samsung.android.securitylogagent',
  'com.sec.imslogger','com.samsung.android.gpuwatchapp',
  # factory / hardware test apps
  'com.sec.factory','com.sec.factory.camera','com.sec.android.app.factorykeystring',
  'com.sec.android.app.hwmoduletest','com.sec.android.app.bluetoothtest','com.sec.android.app.wlantest',
  'com.sec.android.app.servicemodeapp','com.sec.android.RilServiceModeApp',
  # preload / widget store hooks
  'com.sec.android.preloadinstaller','com.sec.android.widgetapp.samsungapps',
  'com.sec.android.widgetapp.webmanual','com.samsung.android.app.updatecenter',
  # unused radios / vendor agents
  'com.dsi.ant.server','com.dsi.ant.plugins.antplus','com.dsi.ant.sample.acquirechannels',
  'com.dsi.ant.service.socket','com.skms.android.agent','com.hiya.star',
  # transfer / PC link / IoT stubs
  'com.samsung.android.smartswitchassistant','com.sec.android.easyMover.Agent',
  'com.samsung.android.mdx.kit','com.samsung.android.mdx.quickboard','com.samsung.android.beaconmanager',
  'com.samsung.android.kidsinstaller','com.samsung.android.app.watchmanagerstub',
  # share/print/carrier helpers
  'com.samsung.android.privateshare','com.samsung.android.allshare.service.fileshare',
  'com.samsung.android.allshare.service.mediashare','com.google.android.printservice.recommendation',
  'com.google.android.apps.carrier.carrierwifi','com.microsoft.skydrive',
  'com.google.android.apps.tachyon'
)

$Tier2 = @(
  # Samsung features with real background cost (RAM/CPU) - you may or may not want them
  'com.samsung.android.app.reminder','com.samsung.android.scloud','com.samsung.android.rubin.app',
  'com.samsung.android.aware.service','com.samsung.android.mapsagent','com.samsung.android.mcfds',
  'com.samsung.android.mcfserver','com.samsung.android.appseparation','com.samsung.android.homemode',
  'com.samsung.android.sm.devicesecurity','com.samsung.android.sm.policy',
  'com.samsung.android.game.gos','com.samsung.android.video','com.samsung.android.easysetup',
  'com.samsung.android.smartmirroring','com.samsung.android.app.simplesharing',
  'com.samsung.android.app.sharelive','com.sec.spp.push',
  # Gallery / media extras
  'com.samsung.storyservice','com.samsung.app.newtrim','com.sec.android.mimage.photoretouching',
  'com.sec.android.app.ve.vebgm','com.samsung.android.livestickers','com.samsung.android.stickercenter',
  # theming / wallpaper / sound extras
  'com.samsung.android.themecenter','com.samsung.android.dynamiclock','com.sec.android.app.soundalive',
  'com.samsung.android.secsoundpicker','com.samsung.android.app.soundpicker',
  # Edge panels
  'com.samsung.android.app.appsedge','com.samsung.android.app.clipboardedge',
  'com.samsung.android.app.cocktailbarservice','com.sec.android.app.chromecustomizations'
)

$Tier3 = @(
  # your call: heavy apps you might actually use
  'com.google.android.googlequicksearchbox','com.google.android.youtube','com.google.android.apps.maps',
  'com.google.android.gm','com.google.android.syncadapters.calendar','com.google.android.syncadapters.contacts',
  'com.samsung.android.calendar','com.samsung.android.app.contacts','com.samsung.android.dialer',
  'com.samsung.android.app.galaxyfinder','com.android.autoinstalls.config.samsung'
)

function Need-Adb {
  if (-not (Get-Command $Adb -ErrorAction SilentlyContinue)) {
    Die "adb not found ('$Adb'). Run: winget install Google.PlatformTools  then reopen the terminal."
  }
}
function Need-Device {
  Need-Adb
  $out = & $Adb devices 2>&1 | Out-String
  if ($out -notmatch "\tdevice") {
    Die "no authorized device. Enable Developer options > USB debugging, plug in, accept the RSA prompt. adb devices says:`n$out"
  }
}
function Get-Installed {
  (& $Adb shell pm list packages 2>$null) -replace "`r",'' -replace '^package:','' |
    Where-Object { $_ } | Sort-Object -Unique
}
function Select-Tier([string]$t) {
  switch ($t) {
    'tier1' { ,$Tier1 }
    'tier2' { ,($Tier1 + $Tier2) }
    'tier3' { ,($Tier1 + $Tier2 + $Tier3) }
    default { Die "unknown tier: $t (use tier1|tier2)" }
  }
}

switch ($Command) {
  'check' {
    Need-Adb
    (& $Adb version | Select-Object -First 1)
    "state : " + (& $Adb get-state 2>&1 | Select-Object -First 1)
    foreach ($p in 'ro.product.model','ro.build.version.release','ro.build.display.id','ro.serialno') {
      "$p : " + ((& $Adb shell getprop $p) -replace "`r",'')
    }
  }
  'dump' {
    Need-Device
    $serial = ((& $Adb shell getprop ro.serialno) -replace "`r",'').Trim()
    $out = Join-Path $Here ("packages-{0}.txt" -f $serial)
    Get-Installed | Set-Content -Encoding ASCII $out
    "{0} packages -> {1}" -f (Get-Content $out).Count, $out
  }
  'list' {
    Need-Device
    $tier = if ($Rest) { $Rest[0] } else { 'tier1' }
    $pkgs = Select-Tier $tier
    $have = Get-Installed
    $hit = 0; $miss = 0
    foreach ($p in $pkgs) {
      if ($have -contains $p) {
        if ($Protected -contains $p) { "  SKIP (protected) $p" }
        else { "  REMOVE $p"; $hit++ }
      } else { $miss++ }
    }
    "-- would remove: $hit   not present on this build: $miss"
  }
  'apply' {
    Need-Device
    $tier = if ($Rest) { $Rest[0] } else { 'tier1' }
    $pkgs = Select-Tier $tier
    $have = Get-Installed
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $rf = Join-Path $Here "restore-$ts.ps1"
    $ok = 0; $fail = 0
    $removed = New-Object System.Collections.Generic.List[string]
    foreach ($p in $pkgs) {
      if (-not ($have -contains $p)) { continue }
      if ($Protected -contains $p) { "SKIP protected $p"; continue }
      $res = (& $Adb shell pm uninstall -k --user 0 $p 2>&1 | Out-String)
      if ($res -match 'Success') {
        "removed  $p"; $ok++; $removed.Add($p)
      } else {
        $res2 = (& $Adb shell pm disable-user --user 0 $p 2>&1 | Out-String)
        if ($res2 -match 'disabled') { "disabled $p"; $ok++; $removed.Add($p) }
        else { "FAILED   $p"; $fail++ }
      }
    }
    # --- verify removals stuck: some Samsung packages self-heal within ~30s ---
    $now = Get-Installed
    $bounced = @($removed | Where-Object { $now -contains $_ })
    if ($bounced.Count -gt 0) {
      "-- {0} package(s) came back; retrying with disable-user" -f $bounced.Count
      foreach ($p in $bounced) { & $Adb shell pm disable-user --user 0 $p | Out-Null }
      Start-Sleep -Seconds 20
      $now2 = Get-Installed
      $dis = (& $Adb shell pm list packages -d) -replace "`r",'' -replace '^package:',''
      foreach ($p in $bounced) {
        if ($dis -contains $p) { "disabled (sticky)            $p" }
        elseif ($now2 -contains $p) { "REVERTED - cannot be removed: $p" }
        else { "removed on 2nd pass          $p" }
      }
    }
    $body = @(
      "# restore file generated $ts - run: .\debloat.ps1 restore .\$([IO.Path]::GetFileName($rf))",
      "`$ErrorActionPreference = 'Continue'",
      "`$Adb = if (`$env:ADB) { `$env:ADB } else { 'adb' }",
      "`$pkgs = @("
    ) + ($removed | ForEach-Object { "  '$_'" }) + @(
      ")",
      "foreach (`$p in `$pkgs) {",
      "  Write-Host ""restoring `$p""",
      "  & `$Adb shell cmd package install-existing `$p",
      "  & `$Adb shell pm enable `$p",
      "}"
    )
    $body -join "`r`n" | Set-Content -Encoding ASCII $rf
    "-- removed/disabled: $ok  failed: $fail"
    "-- restore script: $rf"
    "-- power-cycle the tablet now:  adb reboot"
  }
  'restore' {
    Need-Device
    $f = if ($Rest) { $Rest[0] } else { Die 'usage: restore .\restore-<ts>.ps1' }
    if (-not (Test-Path $f)) { Die "no such restore file: $f" }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $f
    & $Adb reboot
  }
  'verify' {
    Need-Device
    $f = if ($Rest) { $Rest[0] } else { Die 'usage: verify .\restore-<ts>.ps1' }
    if (-not (Test-Path $f -PathType Leaf)) { Die "no such restore file: $f" }
    $want = Select-String -Path $f -Pattern "^\s*'([^']+)'" -AllMatches |
      ForEach-Object { $_.Matches[0].Groups[1].Value }
    $have = Get-Installed
    $dis = (& $Adb shell pm list packages -d) -replace "`r",'' -replace '^package:',''
    $back = @($want | Where-Object { $have -contains $_ })
    "checked {0} packages from {1}" -f $want.Count, (Split-Path -Leaf $f)
    "still removed : {0}" -f ($want.Count - $back.Count)
    "back on device: {0}" -f $back.Count
    foreach ($p in $back) {
      if ($dis -contains $p) { "  disabled (inert) $p" } else { "  ACTIVE AGAIN    $p" }
    }
  }
  'enable' {
    Need-Device
    if (-not $Rest) { Die 'usage: enable <pkg> [<pkg>...]' }
    foreach ($p in $Rest) {
      "restoring $p"
      & $Adb shell cmd package install-existing $p
      & $Adb shell pm enable $p
    }
  }
  default {
    Get-Content $MyInvocation.MyCommand.Path | Select-Object -First 15
  }
}
