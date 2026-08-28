# WeckPilot

WeckPilot ist eine moderne, native Wecker-Anwendung für macOS. Mehrere
Weckzeiten, Wochenpläne und eine sanft ansteigende Lautstärke lassen sich in
einer kompakten Oberfläche verwalten.

## Funktionen

- beliebig viele einmalige oder wiederkehrende Alarme
- individuelle Wochentage und Beschriftungen
- Snooze-Funktion und progressiv ansteigende Lautstärke
- lokale Speicherung der Einstellungen
- deutsche und englische Oberfläche mit automatischer Systemspracherkennung
  und manueller Sprachwahl
- optionaler Wake-Helper, der den Mac für einen Alarm aufwecken kann
- native, signierte und von Apple notarisierte macOS-App

## Download

Die aktuelle signierte Version steht unter
[Releases](https://github.com/nojan01/WeckPilot/releases/latest) als DMG bereit.

Voraussetzung ist ein Mac mit Apple Silicon. Für den optionalen Wake-Helper
werden Administratorrechte und die Xcode Command Line Tools benötigt, weil der
mitgelieferte Swift-Quelltext lokal kompiliert und als LaunchDaemon installiert
wird.

## Entwicklung

Benötigt werden Node.js, Rust und die Tauri-Voraussetzungen für macOS.

```bash
npm ci
npm run tauri:dev
```

Einen Release-Build erstellt:

```bash
npm run tauri:build
```

Der vollständige signierte und notarisierte Release-Prozess verwendet die im
macOS-Schlüsselbund hinterlegte Developer-ID und das Notarisierungsprofil
`DesktopProfileManager`:

```bash
./release-macos.sh
```

Die Web-Oberfläche liegt in `dist/`, der native Tauri-Code in `src-tauri/`.

## Datenschutz

Alarme und Einstellungen werden lokal auf dem Gerät gespeichert. Die Oberfläche
lädt die Schrift Orbitron zur Laufzeit von Google Fonts; dabei kann eine
Verbindung zu Google-Servern entstehen.

## Lizenz

Copyright © 2026 Norbert Jander

WeckPilot ist unter der [MIT-Lizenz](LICENSE) veröffentlicht. Hinweise zu den
verwendeten Open-Source-Komponenten stehen in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Die interne Bundle-ID bleibt für die Update-Kompatibilität mit bereits
installierten Versionen unverändert. Bestehende Alarme und ein vorhandener
Wake-Helper werden von WeckPilot weiterverwendet.
