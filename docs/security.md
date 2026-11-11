# Security Model

DocMark processes documents on the device and has no network code. This
document describes what is protected, how, and where the protection stops.

## Assets and boundaries

| Asset | Where it lives | Protection |
| --- | --- | --- |
| Document bytes | `docmark_vault/` in app documents | AES-256-GCM envelope |
| Watermark images | same vault | AES-256-GCM envelope |
| Metadata (names, page sizes, preset JSON, history configs) | SQLCipher database | SQLCipher, random 256-bit key |
| Key-encryption key (KEK) | platform keystore/keychain | OS-provided secure storage |
| App Lock verifier | encrypted lock blob in secure storage | AES-256-GCM under the KEK |
| Temporary files | OS temp directory | short-lived plaintext, swept |

The vault, the database, and the lock blob are inside the app's private
container. Other apps cannot read it on a non-rooted device.

## Envelope encryption

Each blob is self-contained:

```
magic (4) | version (1) | wrapped nonce (12) | wrapped key (32) | wrapped mac (16)
          | payload nonce (12) | payload ciphertext (n) | payload mac (16)
```

- A fresh random 256-bit data key encrypts the payload with AES-256-GCM.
- The data key is wrapped with the KEK, also AES-256-GCM, and stored in the
  same file. Deleting the file removes the ciphertext and the only wrapped
  copy of its data key.
- The KEK is created on first use and stored base64-encoded in
  `flutter_secure_storage` (Android Keystore / iOS Keychain). It is never a
  plaintext file.
- Encrypt-then-MAC is implicit in GCM: a wrong key and a tampered ciphertext
  both fail authentication. Writes go to a staging file and are renamed into
  place, so a crash mid-write cannot leave a valid-looking partial blob.

## SQLCipher

The Drift database is opened through SQLCipher. The key is a random 32-byte
value produced by `DatabaseKeyStore`, stored separately as
`docmark.key` after being encrypted with the same encryption service, and
applied as a raw key (`PRAGMA key = "x'…'"`) to skip a redundant KDF. Without
the KEK the `.sqlite` file is unreadable.

## App Lock

App Lock is optional and independent of the encryption keys: it gates the UI,
not the vault. The KEK that protects both the vault and the database key
stays in the keystore whether App Lock is on or off.

- **PIN**: six digits. A PBKDF2-HMAC-SHA256 verifier is stored, never the PIN.
  Current blobs use 600,000 iterations; each blob keeps its own recorded
  iteration count, so raising the default does not invalidate old blobs.
- **Backoff**: five misses, then a one-second cooldown that doubles per extra
  miss, capped at five minutes. The counter and deadline are persisted in the
  lock blob, so killing the app does not reset the penalty. The in-memory
  state is the authority for the current session; a failed persistence write
  cannot unlock the app.
- **Biometrics**: through `local_auth`, only when enabled and enrolled. The
  cooldown blocks biometrics as well.
- **Fail closed**: before the stored state is read, the status is `locked`.
  An unreadable or corrupt blob leaves the app locked. A transient keystore
  failure is not cached, so `initialize()` retries on the next call instead of
  pinning the lock screen forever.
- **Recovery**: `AppLockService.resetLockData(confirmed: true)` deletes the
  lock blob and settles on `disabled`. It requires explicit confirmation and
  does not touch documents, presets, or history.

## Logging

`Log` is gated on `kDebugMode`; release builds print nothing. Call sites log
exception types, not messages or stack traces, because a message can embed a
path, a document name, or stored JSON. The Riverpod observer logs provider
names only, never values.

## Plaintext outside the vault

Three plaintext surfaces are unavoidable:

1. **Exports** the user saves. They are the product.
2. **Share copies** under `<temp>/docmark_share/`. The export flow deletes
   each file in a `finally` block after `share()` returns, and the startup
   sweep removes anything older than one hour that a crash left behind.
3. **Render/normalize scratch** under `<temp>/docmark_tmp/`, swept the same
   way.

## Delete-all

"Delete all app data" (`AppDataWipe`) runs in this order:

1. One database transaction empties `asset_links`, `document_assets`,
   `document_pages`, `documents`, `preset_assets`, `presets`,
   `watermark_assets`, and `history_entries`.
2. `SecureFileVault.deleteAll()` removes every vault blob and staging file.
3. Temp and share directories are removed best-effort.

Single-item deletes use the reverse emphasis: rows commit first, then blobs.
An orphan blob is unreachable garbage, while a row with no blob is
unrecoverable metadata.

## Known limitations

- **Backups**: platform backups may copy the vault and database. The blobs
  and DB stay encrypted, but restore the KEK as well or the data is lost; and
  a backup of an unlocked device can expose the lockscreen state. Prefer
  disabling cloud backup for the app if the threat model includes device
  seizure.
- **Volume encryption**: DocMark does not add protection below the file
  system. Rely on the OS's file-based encryption and a device passcode.
- **Screenshots**: the UI can be screenshotted. This is not blocked.
- **Debug builds**: logs are verbose by design. Do not ship a debug build.
- **Exported files**: once saved or shared, the file is outside DocMark's
  control and is not encrypted.

## Release checklist

- Commit `pubspec.lock` so builds resolve the tested dependency set. It cannot
  be generated in this repository's sandbox.
- Configure release signing in `android/key.properties` (git-ignored). Without
  it a release build fails on purpose; it never falls back to the debug key.
- Run `sh tool/fetch_fonts.sh` so the bundled font assets are real files.
- Audit the dependency set before shipping; there is no runtime network stack
  to compromise, but build-time supply chain is still a risk.
