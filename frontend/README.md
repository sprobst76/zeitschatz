# ZeitSchatz Flutter Client

- Plattformen: Android, Linux, Web (Chrome). Desktop-Support via `flutter create .` aktiviert.
- Start (Debug): `flutter run` (oder `-d android` / `-d linux` / `-d chrome` mit gesetztem Backend/CORS).
- Abhängigkeiten: siehe `pubspec.yaml`. API-Base-URL derzeit `http://192.168.0.144:8070` in `services/api_client.dart` (für andere Geräte/IP anpassen).
- CORS im Backend als JSON-Liste setzen, z. B. `CORS_ORIGINS=["http://192.168.0.144:8081"]`.
