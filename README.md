# DuckDNS Windows GUI

Lightweight system tray app that keeps your duckdns.org domain
pointed at your current public IP.

## Download

Get the latest release from [Releases]:

- **Setup installer** -- `DuckDNS-Windows-GUI-Setup.exe` (Windows, no Java needed)
- **Portable** -- `DuckDNS-Windows-GUI.zip` (Windows, no Java needed, extract and run)
- **Jar** -- `DuckDNS-Windows-GUI.jar` (`java -jar DuckDNS-Windows-GUI.jar`, Java 11+)

## Setup

1. Get your domain + token at duckdns.org
2. Tray icon → DuckDNS Settings → enter them, pick interval
3. Done, it only calls the API when your IP changes

## Build

`pwsh ./build.ps1` (JDK 11+). Add `-Bundle -Installer -Version 1.3.0` to also
build the portable zip and the installer exe (the installer step needs WiX 3.x).

GPL-2.0. Fork of DuckDNSClient (ETX Software), modernized:
HTTPS via the JDK http client, jsoup removed, input trimmed
and URL-encoded, no credentials in error paths.

[Releases]: https://github.com/anthfgreco/duckdns-windows-gui/releases
