# juwenalia_app

Flutter app for Juwenalia #WrocławRazem.

## Build-time data sync

The bundled `assets/data/data.json` is the offline-first fallback shown
when the user is offline on **first launch** (before the in-app cache has
ever been populated). To make sure shipped binaries contain a fresh
snapshot, run the sync script before any release build:

```bash
dart run tool/sync_data.dart
flutter build apk --release         # or ios / web / etc.
```

CI / fastlane setups should chain `dart run tool/sync_data.dart` ahead of
the `flutter build` step. The script is dependency-free — no `pub get`
needed.

## Runtime data flow

1. On launch, the app **always** tries the network first
   (`fetchData` in `lib/services/data_service.dart`).
2. On a successful fetch, the JSON is written to `SharedPreferences` and
   every image URL referenced in the payload is preloaded into the
   `cached_network_image` disk cache (`precacheAppImages`). Once that's
   done the app works fully offline.
3. If the network fails, we fall back to the `SharedPreferences` cache,
   then to the bundled `assets/data/data.json` snapshot.
