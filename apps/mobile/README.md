# Coffee Management Mobile

Flutter mobile/tablet scaffold with Android, iOS, and web targets. See the [root setup guide](../../README.md#run-flutter) and [architecture rules](../../docs/architecture/README.md).

`main.dart` boots `app.dart`. The app contains only a neutral startup screen. `AppConfig.apiBaseUrl` reads the public `API_BASE_URL` build-time define; no network client or authentication flow is implemented.

Each feature has `data`, `domain`, and `presentation` placeholders. Add concrete subdirectories and dependencies only when implementing a feature. `core` is technical infrastructure, `shared` is reusable UI, and `config` contains app configuration.

Run formatting, `flutter analyze`, and `flutter test` before submitting changes. Android builds use the generated provisional identifier and debug signing; configure production signing before publishing. iOS validation requires macOS/Xcode.
