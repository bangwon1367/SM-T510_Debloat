@echo off
rem stub adb.cmd - offline testing for debloat.ps1, no device needed.
rem package list mirrors the packages the tier globals actually name:
rem   tier1 dqagent, sec.factory, dsi.ant.server, microsoft.skydrive
rem   tier2 appsedge, scloud, game.gos (self-healing)
rem   tier3 google.android.youtube   protected: launcher, vending, gms
if "%1"=="devices" (
  echo List of devices attached
  echo ABC123	device
  exit /b 0
)
if "%1"=="version" (
  echo Android Debug Bridge version 1.0.41
  echo Version 37.0.1
  exit /b 0
)
if "%1"=="get-state" (
  echo device
  exit /b 0
)
if "%1"=="reb" (
  echo [fake] power-cycle requested
  exit /b 0
)
if "%1"=="rebo" (
  echo [fake] power-cycle requested
  exit /b 0
)
if "%1"=="reboo" (
  echo [fake] power-cycle requested
  exit /b 0
)
if "%1"=="reboot" (
  echo [fake] power-cycle requested
  exit /b 0
)
if "%1"=="shell" (
  if "%2"=="getprop" (
    echo fake-value
    exit /b 0
  )
  if "%2"=="am" (
    echo 40
    exit /b 0
  )
  if "%2"=="pm" (
    if "%3"=="list" (
      echo package:com.samsung.android.dqagent
      echo package:com.sec.factory
      echo package:com.dsi.ant.server
      echo package:com.microsoft.skydrive
      echo package:com.samsung.android.app.appsedge
      echo package:com.samsung.android.scloud
      echo package:com.samsung.android.game.gos
      echo package:com.google.android.youtube
      echo package:com.sec.android.app.launcher
      echo package:com.android.vending
      echo package:com.google.android.gms
      exit /b 0
    )
    if "%3"=="uninstall" (
      echo Success
      exit /b 0
    )
    if "%3"=="enable" (
      echo Package enabled
      exit /b 0
    )
    if "%3"=="disable-user" (
      echo new state: disabled
      exit /b 0
    )
  )
  if "%2"=="cmd" (
    echo Package installed
    exit /b 0
  )
)
exit /b 0
