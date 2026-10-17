param(
  [string]$OutputDir = "dist"
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

if (Test-Path $buildDir) {
  Remove-Item -Recurse -Force $buildDir
}
New-Item -ItemType Directory -Force -Path $buildDir, $outDir | Out-Null

& $javac -d $buildDir (Join-Path $srcDir "duckdns.java")
if ($LASTEXITCODE -ne 0) {
  throw "compile failed"
}

Copy-Item (Join-Path $srcDir "logo.png") (Join-Path $buildDir "logo.png") -Force

$outJar = Join-Path $outDir "DuckDNS-Updater.jar"
& $jarExe --create --file $outJar --main-class duckdns -C $buildDir .
if ($LASTEXITCODE -ne 0) {
  throw "jar packaging failed"
}

Write-Host "built $outJar"
Write-Host "run it with: java -jar `"$outJar`""
