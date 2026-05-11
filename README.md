# Flutter Chat Starter

Intentionally rough chat-app baseline. Improve this. Do not rebuild it.

## Setup

Tested on Flutter stable `3.41.x` (Dart `3.11.x`). Run `flutter --version` to check your channel.

```sh
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure   # against YOUR Firebase project — regenerates lib/firebase_options.dart
flutter run
```

## Firebase setup

1. Create a Firebase project at <https://console.firebase.google.com>.
2. Enable **Authentication → Sign-in method → Email/Password**.
3. Create **Cloud Firestore** in production mode.
4. Paste the contents of `firestore.rules` into the Firestore Rules tab and publish.
5. Create a **Storage** bucket (default location is fine).
6. Run `flutterfire configure` from the project root. Pick the Firebase project you created. This regenerates `lib/firebase_options.dart` with real values.

### Firestore schema

```
users/{uid}                                  { uid, email, displayName, createdAt }
conversations/{convId}                       { participants: [uid], lastMessage, lastMessageAt }
conversations/{convId}/messages/{msgId}      { senderId, text, createdAt }
```

The starter never writes to `users/{uid}` and provides no UI to create conversations — see "What's missing" below.

## What's missing (deliberate rough edges)

These are the gaps you're expected to close. The starter ships with all of them on purpose. Do not file these as bugs against the starter; fix them in your fork.

1. No `CircularProgressIndicator` during `ConnectionState.waiting` — screens render blank while loading.
2. No error UI on `snapshot.hasError`.
3. No empty states — empty lists show a blank screen.
4. No manual scroll-to-latest on new message; no keyboard-avoidance tuning beyond Scaffold defaults.
5. No auth route guard — `Navigator.pushNamed('/chats')` works even when signed out.
6. All state held in `StatefulWidget` `setState` — no Riverpod / Bloc / Provider / GetIt.
7. Firestore streams set up directly in widget `build` methods (not in `initState`, not in a repository).
8. No input validation on login / signup.
9. No `try/catch` around Firebase calls — wrong password throws an uncaught exception.
10. No offline persistence configured beyond Firestore mobile defaults.
11. No user profile creation — `users/{uid}` doc is never written. You add it.
12. No way to start a new conversation from the UI. You build it.
13. No `dispose()` cleanup of streams beyond what `StreamBuilder` handles automatically.

## Notes

- `lib/firebase_options.dart` is a placeholder stub. The app will fail at runtime until you run `flutterfire configure`. The file is committed (not gitignored) so the project compiles out of the box; replace it locally and decide for your fork whether to commit your real config.
- See the project brief for grading criteria and submission instructions.
