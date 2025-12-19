# Datenschutz & Fotos – ZeitSchatz

- Zweck: Fotos dienen ausschließlich als Nachweis für erledigte Aufgaben innerhalb der Familie.
- Speicherort: Lokal auf dem Server (`/data/photos/...`) oder optional MinIO (self-hosted). Keine Weitergabe an Drittanbieter außer FCM für Push (ohne Fotos).
- Aufbewahrung: Fotos werden automatisch nach 14 Tagen gelöscht (Retention-Job). Backups enthalten Fotos nicht langfristig.
- Zugriff: Nur angemeldete Eltern und das zugehörige Kind dürfen ein Foto abrufen. Kein Teilen via öffentlicher Links.
- Minimierung: Pro Submission maximal ein Foto (MVP). Dateigröße wird komprimiert, Metadaten werden entfernt, Overlay enthält Task/Name/Zeitstempel.
- Protokollierung: Logs enthalten keine Foto-URLs im Klartext. Fehlerlogs anonymisieren Benutzer-IDs, wo möglich.
- Rechte: Löschen auf Wunsch jederzeit möglich, unabhängig vom 14-Tage-Autodelete.
- Sicherheit: Transport nur über HTTPS empfohlen; Serverzugriff beschränkt; PIN/Token-basiert, kein Social Login.
