# m³ DevOps Workstation — Roadmap

Stand: 11. November 2026 · Zielplattform: **Fedora Workstation (DNF)**

> Diese Roadmap hält die Befunde des Code-Reviews fest. Sie ist eine **Arbeitsplanung**, keine Behauptung, dass alle Risiken bereits durch Laufzeittests reproduziert wurden. Vor jedem Merge: Änderungen testen und verifizieren.

## Ziel

m³ soll eine zuverlässige, sichere und flackerfreie DevOps-Terminaloberfläche für Fedora sein. Bestehende Funktionen stabilisieren, bevor neue Funktionen hinzukommen.

## Phase 0 — Sicherheits- und Funktionsprüfung (P0)

- [ ] **Remote-Installer:** Hermes-/Codex-Installationsskripte auf Herkunft, Integrität und vertrauenswürdige Ausführung prüfen. `bash -n` prüft nur Syntax, keine Sicherheit. Wo verfügbar, feste Versionen und verifizierte Checksums/Signaturen verwenden; sonst Restrisiko transparent machen.
- [ ] **ChatGPT-RPM:** Quelle/Authentizität zusätzlich zu Paketname und Architektur verifizieren; Installationspfad für Fedora 45 explizit prüfen.
- [ ] **Installationsabläufe:** Fehlgeschlagene Downloads, Abbrüche, fehlende Abhängigkeiten und Teilinstallationen testen. Keine irreführenden Erfolgsmeldungen.
- [ ] **GitHub CI:** Bash-Syntaxprüfung erhalten; ShellCheck und Tests für zentrale Installationsfunktionen ergänzen.

**Abnahme:** Keine unbegründet als sicher bezeichneten Remote-Skripte; definierte Fehlerfälle enden mit verständlichen Meldungen und korrektem Exit-Status; CI läuft nachweislich grün.

## Phase 1 — Terminal-UI stabilisieren (P1)

- [ ] **Gemeinsame UI-Engine:** Tastatureingabe, ESC/Arrow-Sequenzen, Cursor, Bildschirmgröße und Render-Funktionen zentralisieren.
- [ ] **Kein Flackern:** Bei Navigation nur betroffene Zeilen aktualisieren; kein unkontrolliertes Neuzeichnen durch zusätzliche Newlines.
- [ ] **Responsive Layout:** 80×24, schmale Terminals, lange Toolnamen und Statusmeldungen testen; ANSI-Escape-Codes bei Breitenberechnung berücksichtigen.
- [ ] **Nerd Fonts:** Fallback auf Classic-Symbole; Fontinstallation nicht mit tatsächlicher Terminal-Fontauswahl verwechseln.
- [ ] **Kitty-Grafiklogo:** Protokollunterstützung belastbar erkennen, Renderfehler behandeln und immer einen sichtbaren Textfallback anbieten.
- [ ] **Startseite:** Hermes, Codex, VSCodium und ChatGPT von der Startseite aus starten; bei fehlender Installation hilfreiche Hinweise anzeigen.

**Abnahme:** Keine Zeilenüberläufe, keine verschwundenen Menüs und kein sichtbares Navigationsflackern in den getesteten Terminalgrößen.

## Phase 2 — Fedora-Migration vollständig abschließen (P1)

- [ ] Bluefin-/bootc-/rpm-ostree-Alttexte und falsche Standardannahmen in `setup-check.sh`, `update-check.sh`, `docker-check.sh` und Installer-Hinweisen bereinigen.
- [ ] Fedora-DNF-basierte Paket- und Update-Erkennung ergänzen; Flatpak und manuell installierte CLI-Tools getrennt ausweisen.
- [ ] Launcher-Installation idempotent machen: bestehenden `~/.local/bin/m3` prüfen und bei Bedarf sicher aktualisieren.
- [ ] Toolstatus differenzieren: **gefunden**, **installiert**, **startbar**, **konfiguriert**, **einsatzbereit**.
- [ ] Docker/Podman/Compose und kind mit den tatsächlichen Fedora-Pfaden und Voraussetzungen testen.

**Abnahme:** Fedora Workstation ist in Oberfläche, Dokumentation und Update-Checks die konsistente Zielplattform; erneute Einrichtung ist ohne unnötige Fehler möglich.

## Phase 3 — Qualität und Wartbarkeit (P1/P2)

- [ ] Bash-Funktionstests mit gemockten Befehlen (`dnf`, `sudo`, `curl`, `git`, `flatpak`); keine echten Installationen in CI.
- [ ] TUI-Tests für Navigation, App-Auswahl, Terminalgrößen, Exit- und Fehlerpfade.
- [ ] Projekt-Scan begrenzen bzw. Fortschritt/Abbruch anbieten; Git-Status-Abfragen mit Timeouts und klaren Fehlerzuständen.
- [ ] Einheitliche Exit-Codes, Logmeldungen und Fehlerbehandlung.
- [ ] Dokumentation mit tatsächlichem Verhalten abgleichen; alte `INSTALL`-Hinweise entfernen, wo der Nutzer keine Eingabe mehr machen muss.

**Abnahme:** Tests decken kritische Nutzerpfade ab; dokumentierte Schritte sind auf einer regulären Fedora-Installation nachvollziehbar.

## Reihenfolge und Meilensteine

1. **M0: Sicher installierbar** — Phase 0 abgeschlossen.
2. **M1: Stabil bedienbar** — Phase 1 abgeschlossen.
3. **M2: Fedora-native** — Phase 2 abgeschlossen.
4. **M3: Wartbar und testbar** — Phase 3 abgeschlossen.

### Arbeitsregeln

- Änderungen in kleinen, nachvollziehbaren Pull Requests.
- Vor Merge: relevante Tests und Syntaxprüfung ausführen; nicht verifizierte Tests ausdrücklich benennen.
- Nur nach erfolgreicher Verifikation nach `main` mergen.
- Keine neuen Funktionen auf Kosten von Stabilität oder Sicherheit.
- P0 = zuerst prüfen/beheben; P1 = hohe Priorität; P2 = nachgelagerte Verbesserung.

## Review-Hinweis

Ausgangspunkt ist das Code-Review vom 11.11.2026. Die Prioritäten beschreiben Risiken und Entwicklungsbedarf, **keine bestätigten Exploits**. Die Roadmap darf nach reproduzierbaren Tests angepasst werden.
