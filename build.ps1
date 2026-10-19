param(
  [string]$OutputDir = "dist",
  [switch]$Bundle,
  [switch]$Installer,
  [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"

$srcDir = Join-Path $PSScriptRoot "DuckDNSClient\src"
$buildDir = Join-Path $PSScriptRoot "DuckDNSClient\build"
$outDir = Join-Path $PSScriptRoot $OutputDir

function Find-JdkBin {
  # prefer an explicit JAVA_HOME
  if ($env:JAVA_HOME) {
    $candidate = Join-Path $env:JAVA_HOME "bin"
    if ((Test-Path (Join-Path $candidate "javac.exe")) -and (Test-Path (Join-Path $candidate "jar.exe"))) {
      return $candidate
    }
  }

  # ask the java launcher where its jdk lives (handles oracle javapath stubs)
  $javaCmd = (Get-Command java -ErrorAction SilentlyContinue).Source
  if ($javaCmd) {
    $props = (& $javaCmd -XshowSettings:properties -version 2>&1) | Out-String
    if ($props -match 'java\.home\s*=\s*(.+)') {
      $candidate = Join-Path $Matches[1].Trim() "bin"
      if ((Test-Path (Join-Path $candidate "javac.exe")) -and (Test-Path (Join-Path $candidate "jar.exe"))) {
        return $candidate
      }
    }
  }

  # fall back to javac on PATH
  $javac = (Get-Command javac -ErrorAction SilentlyContinue).Source
  if ($javac) {
    return Split-Path $javac
  }

  throw "no JDK found. Install a JDK (11 or newer) or set JAVA_HOME."
}

function Find-WixBin {
  $candle = Get-Command candle.exe -ErrorAction SilentlyContinue
  if ($candle) {
    return Split-Path $candle.Source
  }
  $wixDirs = @()
  foreach ($pattern in @("C:\Program Files (x86)\WiX Toolset v3.*\bin", "C:\Program Files\WiX Toolset v3.*\bin")) {
    $wixDirs += Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue
  }
  foreach ($dir in ($wixDirs | Sort-Object FullName -Descending)) {
    if (Test-Path (Join-Path $dir.FullName "candle.exe")) {
      return $dir.FullName
    }
  }
  return $null
}

$javaBin = Find-JdkBin
$javac = Join-Path $javaBin "javac.exe"
if (-not (Test-Path $javac)) {
  $javac = Join-Path $javaBin "javac"
}
$jarExe = Join-Path $javaBin "jar.exe"
if (-not (Test-Path $jarExe)) {
  $jarExe = Join-Path $javaBin "jar"
}
if (-not (Test-Path $jarExe)) {
  throw "jar tool not found in '$javaBin'."
}

$jpackage = $null
if ($Bundle -or $Installer) {
  $jpackage = Join-Path $javaBin "jpackage.exe"
  if (-not (Test-Path $jpackage)) {
    $jpackage = Join-Path $javaBin "jpackage"
  }
  if (-not (Test-Path $jpackage)) {
    throw "jpackage not found in '$javaBin' (JDK 14 or newer required)."
  }
}

if (Test-Path $buildDir) {
  Remove-Item -Recurse -Force $buildDir
}
New-Item -ItemType Directory -Force -Path $buildDir, $outDir | Out-Null

& $javac -d $buildDir (Join-Path $srcDir "duckdns.java")
if ($LASTEXITCODE -ne 0) {
  throw "compile failed"
}

Copy-Item (Join-Path $srcDir "logo.png") (Join-Path $buildDir "logo.png") -Force

$outJar = Join-Path $outDir "DuckDNS-Windows-GUI.jar"
& $jarExe --create --file $outJar --main-class duckdns -C $buildDir .
if ($LASTEXITCODE -ne 0) {
  throw "jar packaging failed"
}

Write-Host "built $outJar"
Write-Host "run it with: java -jar `"$outJar`""

$iconPath = Join-Path $srcDir "..\DuckDnsInstaller\logo.ico"
$addModules = "java.base,java.desktop,java.prefs,java.logging,jdk.crypto.ec"

if ($Bundle) {
  Get-ChildItem $outDir -File | Where-Object { $_.Extension -in ".zip", ".exe" } | Remove-Item -Force

  $bundleDir = Join-Path $PSScriptRoot "bundle"
  if (Test-Path $bundleDir) {
    Remove-Item -Recurse -Force $bundleDir
  }
  New-Item -ItemType Directory -Force -Path $bundleDir | Out-Null

  $jpackageArgs = @(
    "--type", "app-image",
    "--name", "DuckDNS-Windows-GUI",
    "--input", $outDir,
    "--main-jar", "DuckDNS-Windows-GUI.jar",
    "--main-class", "duckdns",
    "--dest", $bundleDir,
    "--app-version", $Version,
    "--add-modules", $addModules
  )
  if (Test-Path $iconPath) {
    $jpackageArgs += @("--icon", $iconPath)
  } else {
    Write-Warning "icon not found at $iconPath, building without one"
  }

  & $jpackage @jpackageArgs
  if ($LASTEXITCODE -ne 0) {
    throw "jpackage failed"
  }

  $zipPath = Join-Path $outDir "DuckDNS-Windows-GUI.zip"
  Compress-Archive -Path (Join-Path $bundleDir "*") -DestinationPath $zipPath
  Write-Host "bundled $zipPath"
}

if ($Installer) {
  $wixBin = Find-WixBin
  if (-not $wixBin) {
    throw "WiX Toolset 3.x not found (candle.exe). Install it with: choco install wixtoolset -y"
  }
  $env:PATH = "$wixBin;$env:PATH"

  $stageDir = Join-Path $PSScriptRoot "stage"
  if (Test-Path $stageDir) {
    Remove-Item -Recurse -Force $stageDir
  }
  New-Item -ItemType Directory -Force -Path $stageDir | Out-Null
  Copy-Item $outJar -Destination $stageDir

  $installerDir = Join-Path $PSScriptRoot "installer"
  if (Test-Path $installerDir) {
    Remove-Item -Recurse -Force $installerDir
  }
  New-Item -ItemType Directory -Force -Path $installerDir | Out-Null

  $installerArgs = @(
    "--type", "exe",
    "--name", "DuckDNS-Windows-GUI",
    "--input", $stageDir,
    "--main-jar", "DuckDNS-Windows-GUI.jar",
    "--main-class", "duckdns",
    "--dest", $installerDir,
    "--app-version", $Version,
    "--vendor", "anthfgreco",
    "--add-modules", $addModules,
    "--win-per-user-install",
    "--win-menu",
    "--win-menu-group", "DuckDNS",
    "--win-shortcut",
    "--win-dir-chooser",
    "--win-upgrade-uuid", "7a1c4f0e-8b3d-4a52-9c6e-1f2b5d8a9c30"
  )
  if (Test-Path $iconPath) {
    $installerArgs += @("--icon", $iconPath)
  } else {
    Write-Warning "icon not found at $iconPath, building without one"
  }

  & $jpackage @installerArgs
  if ($LASTEXITCODE -ne 0) {
    throw "jpackage failed to build the installer"
  }

  $builtExe = Join-Path $installerDir "DuckDNS-Windows-GUI-$Version.exe"
  if (-not (Test-Path $builtExe)) {
    throw "installer not found at $builtExe"
  }
  $setupExe = Join-Path $outDir "DuckDNS-Windows-GUI-Setup.exe"
  Copy-Item $builtExe -Destination $setupExe -Force
  Write-Host "built $setupExe"
}
