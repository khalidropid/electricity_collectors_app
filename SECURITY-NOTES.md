# Electricity collectors app — security notes

## Credential incident
A shared application secret was committed in the client source. Treat it as compromised: revoke/rotate it on the API server immediately, and review the Git history because replacing the current file does not erase earlier commits.

The client now reads a temporary build-time value using `--dart-define=APP_API_SECRET_KEY=...`. This only removes the literal from source control; it does **not** make the value secret. Values embedded in APK/IPA files can be extracted. Do not use this as the long-term security model.

The durable solution is server-issued, short-lived, user/device-scoped credentials with authorization checks on every endpoint, expiry, revocation, and rate limiting. This requires coordinated backend work and integration testing.

## Build-time compatibility (temporary only)

```bash
flutter build apk --dart-define=APP_API_SECRET_KEY=<temporary-value>
```

If the value is omitted, the app sends no shared-secret header and the server may reject sync requests. Do not place real production secrets in CI logs or public build commands.

## Data synchronization reliability

SQLite transaction errors now propagate to the outer sync handler. The last-sync cursor is therefore not advanced after a failed transaction.

## Remaining review

- Inspect `lib.zip` and `lib.rar` before deciding whether they duplicate source or contain additional credentials.
- Test login, pull, push, offline retry, and transaction rollback against a staging backend before distributing a new build.
