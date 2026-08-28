# Hinweise zu Drittanbieter-Komponenten

WeckPilot ist unter der MIT-Lizenz veröffentlicht. Die Anwendung verwendet
darüber hinaus unveränderte Open-Source-Komponenten unter kompatiblen
Lizenzbedingungen.

## Lizenzprüfung für Version 1.1.5

Geprüft wurden die tatsächlich für `aarch64-apple-darwin` aufgelösten normalen
und Build-Abhängigkeiten aus `src-tauri/Cargo.lock` sowie die installierten
NPM-Abhängigkeiten aus `package-lock.json`.

- Tauri und die Tauri CLI: MIT oder Apache-2.0
- Rust-Bibliotheken: überwiegend MIT, Apache-2.0 oder eine Wahlmöglichkeit aus
  beiden; außerdem BSD-2-Clause, BSD-3-Clause, Zlib, 0BSD, Unlicense, CC0 und
  Unicode-3.0
- `cssparser`, `cssparser-macros`, `dtoa-short`, `option-ext` und `selectors`:
  MPL-2.0. Diese Komponenten werden unverändert verwendet. Die MPL gilt
  weiterhin für deren eigene Quelldateien; der eigenständige WeckPilot-Code
  bleibt MIT-lizenziert.
- Orbitron: SIL Open Font License 1.1. Die Schrift wird zur Laufzeit über
  Google Fonts geladen und nicht als Schriftdatei mit der App ausgeliefert.

Es wurden keine GPL- oder AGPL-Abhängigkeiten im macOS-Build festgestellt.
Die vollständigen Paketversionen sind reproduzierbar in `src-tauri/Cargo.lock`
und `package-lock.json` festgehalten. Die jeweiligen Lizenztexte und
Urheberhinweise der Bibliotheken bleiben Bestandteil ihrer Quellpakete.

Diese Übersicht ist eine technische Lizenzprüfung und keine Rechtsberatung.

## Quellen

- Tauri: <https://github.com/tauri-apps/tauri>
- Mozilla Public License 2.0: <https://www.mozilla.org/MPL/2.0/>
- Unicode License v3: <https://www.unicode.org/license.txt>
- Orbitron: <https://github.com/googlefonts/orbitron-vf>
- SIL Open Font License 1.1: <https://openfontlicense.org/>
