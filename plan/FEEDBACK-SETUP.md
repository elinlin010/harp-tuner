# In-App Feedback — Setup & Disclosure

Anonymous in-app feedback writing to Firestore. Two entry points:
1. **Settings sheet** → "Send feedback" row (always available once Firebase is configured).
2. **Failed-session nudge** → a snackbar shown when a tuning session ends without
   ever locking a note, gated to sessions ≥ 8 s and shown at most once per app run.

Each feedback document stores: `message`, `trigger` (`settings` | `failed_session`),
`locale`, `appVersion`, `platform`, `osVersion`, `deviceModel`, `createdAt`.
No PII, no account, no tracking identifiers.

---

## 1. Provision Firebase (REQUIRED — you must do this)

The feature degrades to a silent no-op until a Firebase project is wired up. Run:

```
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart` and drops `GoogleService-Info.plist`
(iOS) and `google-services.json` (Android) into place. Until then the settings
row is hidden and the nudge never fires.

> Note: `main.dart` calls `Firebase.initializeApp()` with no explicit options and
> relies on the native config files. If you prefer `DefaultFirebaseOptions`,
> pass `options: DefaultFirebaseOptions.currentPlatform` after importing the
> generated file.

## 2. Lock down Firestore (REQUIRED — security)

An unauthenticated write endpoint is abusable. Restrict the `feedback` collection
to create-only, with a size cap. In the Firebase console → Firestore → Rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /feedback/{doc} {
      allow create: if request.resource.data.message is string
                    && request.resource.data.message.size() <= 2000;
      allow read, update, delete: if false;  // console-only
    }
  }
}
```

Strongly recommended: enable **Firebase App Check** (DeviceCheck/App Attest on
iOS, Play Integrity on Android) so only genuine app installs can write. Without
it, the endpoint is open to anyone with the project ID.

## 3. App Store privacy (DONE in code)

`ios/Runner/PrivacyInfo.xcprivacy` declares:
- `OtherUserContent` — the feedback message (AppFunctionality, not linked, not tracking)
- `OtherDiagnosticData` — app/device context (AppFunctionality, not linked, not tracking)

In App Store Connect → App Privacy, mirror this: **User Content** ("Customer
Support" / "App Functionality") and **Diagnostics**, both *not* linked to identity
and *not* used for tracking.

## 4. Google Play Data safety form

Declare under Data safety → Data collected:

| Data type | Category | Collected | Shared | Purpose | Optional |
|---|---|---|---|---|---|
| User-generated content (feedback) | Messages / Other in-app content | Yes | No | App functionality, Customer support | Yes (user-initiated) |
| Device or other IDs / Diagnostics | App info & performance | Yes | No | App functionality, Analytics | Yes |

- Data is **encrypted in transit** (Firestore uses TLS): Yes.
- Users can **request deletion**: provide your support contact; feedback is anonymous
  so there is no per-user record to auto-delete.
