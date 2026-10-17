# DuckDNS Updater for Windows

Lightweight system tray app that keeps your duckdns.org domain
pointed at your current public IP.

## Download

Get DuckDNS-Updater.jar from [Releases], then run:
`java -jar DuckDNS-Updater.jar` (Java 11+, nothing else needed)

## Setup

1. Get your domain + token at duckdns.org
2. Tray icon → DuckDNS Settings → enter them, pick interval
3. Done, it only calls the API when your IP changes

## Build

`pwsh ./build.ps1` (JDK 11+)

GPL-2.0. Fork of DuckDNSClient (ETX Software), modernized:
HTTPS via the JDK http client, jsoup removed, input trimmed
and URL-encoded, no credentials in error paths.
