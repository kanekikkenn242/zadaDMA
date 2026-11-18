# Static Analysis Report — `X-v5.2.0-b124.ipa`

**Analyst method:** static only (no execution). Tools: REA archive/bundle inspection, Python 3.13 `plistlib`, custom Mach-O/symbol/string parsers, `Assets.car` carutil-style introspection.
**Date:** 2026-11-14
**Target:** `C:\Users\User\Downloads\X-v5.2.0-b124.ipa`

---

## 1. Executive summary

The file is **not** an official X (Twitter) client and has nothing to do with X Corp. It is a **sideloaded iOS game-cheat / device-tweaking utility internally called "Project X"** (developer handle `bnxyung7`, Telegram `hole30601`). It is distributed as an unsigned, already-decrypted IPA that must be re-signed (enterprise certificate) before installation.

Its core capabilities are:

| Area | What it does |
|---|---|
| Game cheating | Downloads and installs modified asset/data packs for **Free Fire** and **Free Fire MAX** (`com.dts.freefireth`, `com.dts.freefiremax`) — aimbot variants, chams, mod skins, location spoof, FPS unlock |
| Device-wide file access | Kernel exploit + sandbox escape to read/write **any app container** on iOS |
| "Nugget"-style tweaks | MobileGestalt capability editor (iPadOS mode, Apple Intelligence eligibility, region-lock removal, etc.) |
| Wallpapers | Installs `.tendies` PosterBoard wallpaper packages |
| Maintenance | Cache/tmp cleaner, ZIP browser/editor over app data |
| Remote writes | Pairing/AFC/ATC "airlift" stack to write files to a device over a tunnel |
| Licensing | Online key licensing + product catalogue served from a Render-hosted API |

Two things make it high-risk beyond the cheating itself: it ships a **publicly documented kernel exploit port (`kexploit_opa334`)** and a **sandbox-escape primitive (`bad_query`)**, and it **spoofs Apple's bundle identifier** `com.apple.mobile.MobileHouseArrest`.

---

## 2. Package identity

| Field | Value |
|---|---|
| File | `X-v5.2.0-b124.ipa` |
| Size | 38,720,948 bytes |
| SHA-256 | `B27C2F33AED16D3ED2E1ED388BEA3F1D5B851732A91450480A0229701A9FDEF6` |
| Archive | 90 zip entries; 22 files, 9 dirs |
| Bundle ID | **`com.apple.mobile.MobileHouseArrest`** (Apple's identifier — spoofed) |
| CFBundleName | `X` |
| CFBundleDisplayName | `X` |
| Short version / build | `5.2.0` / `124` |
| Minimum iOS | `16.0` |
| SDK | `iphoneos26.5` (Xcode 26.6, build `2660`, clang `17F113`) |
| Built | `main@b27d178ee 2026-11-07T02:15:45Z` |
| Device family | iPhone only (`UIDeviceFamily = 1`) |
| Platform build | `25F80` |

### Missing bundle components

| Expected | Present? | Consequence |
|---|---|---|
| `_CodeSignature/` | ❌ | Not signed → must be re-signed to install |
| `embedded.mobileprovision` | ❌ | No provisioning profile embedded |
| `Frameworks/` | ❌ | Fully static / linked-in code (no dylibs to swap) |
| `SC_Info/` | ❌ | Never App-Store-encrypted |

### Document / URL surface

- **UTI:** `com.yangjiii.3105.patch-package`, extension `3105`, MIME `application/x-3105-patch`, conforms to `public.data`, role Editor/Owner.
- **URL scheme:** `com.yangjiii.3105.patch-import` → `threeoneosfive`.
- **Queried schemes:** `freefire`, `freefiremax` (detects/launches the games).
- **Bonjour:** `_remotepairing-pairable-host._tcp`, `_aircardprobe._tcp` (Apple RemotePairing discovery).
- **Background modes:** `audio` (keeps the process alive while exploit/tunnel work runs).
- **File sharing:** `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`.

### Permission strings (user-facing)

- Documents: "X needs access to documents."
- Local network: "X uses the local network to pair this iPhone in Developer Mode."
- Photos: "X needs access to photos for wallpaper customization."

---

## 3. Bundle inventory

| Size | Path | Notes |
|---|---|---|
| 33,267,992 | `Assets.car` | 3 embedded JPEG streams + many named brand/product images (intro splash, game art, skins) |
| 15,980,120 | `X` | arm64 Mach-O executable |
| 184,382 | `activar.wav` | Integrity-checked sound |
| 158,804 | `desactivar.wav` | Integrity-checked sound |
| 151,748 | `Welcome.wav` | Integrity-checked sound |
| 63,827 | `pt.lproj/Localizable.strings` | Portuguese |
| 60,636 | `es.lproj/Localizable.strings` | Spanish |
| 52,570 | `en.lproj/Localizable.strings` | English (820 keys) |
| 7,198 | `Metadata.appintents/extract.actionsdata` | Siri/Shortcuts actions |
| 6,993 / 5,104 | `AppIcon76x76@2x~ipad.png`, `AppIcon60x60@2x.png` | Icons |
| 3,989 | `Metadata.appintents/root.ssu.yaml` | Intent definitions |
| 2,849 | `Info.plist` | |
| ~2.5 KB ×3 | `*.lproj/nlu.appintents/nlu.lzfse` | On-device NLU models |
| 52 | `Metadata.appintents/version.json` | |
| 8 | `PkgInfo` | `APPL????` |

**AppIntents:** `ActivarProductoIntent`, `DesactivarProductoIntent`, `AbrirFreeFireIntent`, `AbrirFreeFireMaxIntent` — the app exposes activation/deactivation and game launching to Siri & Shortcuts.

---

## 4. Binary structure

| Property | Value |
|---|---|
| Format | Mach-O 64-bit, `MH_EXECUTE`, `arm64` |
| Size | 15,980,120 bytes |
| Load commands | 59 |
| Symbols | 74,969 |
| Encryption | `LC_ENCRYPTION_INFO_64 cryptid = 0` → **already decrypted** (App Store encryption stripped) |
| Code signature | None in load commands |
| Hardening | `MH_PIE` (ASLR), stack canary present |
| Swift types | 232 distinct type paths, module `X` |
| Objective-C classes | ~30 |
| `__cstring` entries | 3,763 |
| All ASCII strings | 57,660 |

### Language / runtime composition

1. **Swift + SwiftUI** — all UI (`DashboardView`, `SettingsView`, `FileBrowserView`, `ProductCatalogView`, `OnboardingView`, `Theme`, `AppButtonStyle`, custom tab bar). Heavy use of `Observation`/`@Observable` state objects (`AppState`, `AppLog`, `PatchTransaction`).
2. **Objective-C / C** — glue for `MobileGestalt`, `LaunchServices` (`LSApplicationWorkspace`), `MobileInstallation`, `CoreServices`, `MCM`/containermanager, and the exploit shells.
3. **Rust** — device communication stack, visible from cargo paths and panic strings:
   - `idevice` crate (`vendor/idevice/src/remote_pairing/responder.rs`, AFC, InstallationProxy, lockdown)
   - `tokio`, `rustls`, `aws-lc-rs 1.18.1`, `aes 0.8.4`
   - Cargo registry path `/Users/builder/.cargo/registry/...` → built by user `builder` on macOS.
4. **C crypto** — `aws-lc` FIPS module (`e_aes.c`, `digest.c`), OpenSSL-compatible `EVP_*` symbols; AES-GCM/CBC primitives.

### Linked frameworks (selected)

`Foundation`, `SwiftUI`, `UIKit`, `Combine`, `Security`, `Network`, `CoreServices`, `MobileCoreServices`, `SystemConfiguration`, `AVFoundation` (audio/intro player), `PhotosUI`, `UniformTypeIdentifiers`, `QuickLook`, `AppIntents`, `CryptoKit`/`aws-lc`, `libz` (ZIP), `libsqlite3` (likely ledger/catalogue cache).

---

## 5. Architecture & module map

The Swift type inventory reads like a clean MVVM app. The most-referenced types (by symbol occurrence) are:

```
RemotePatchStore (1626)      FileBrowserView (609)      PatchTransaction (595)
ProductActivationCoordinator (521)  NotificationInbox (478)  ProductCatalogView (420)
LicenseGate (396)            PairingController (364)    SettingsView (358)
PatchPackageCodec (284)      AppUpdateChecker (210)     ThreeOneOSFiveApp (203)
ExploitSupportPolicy (200)   OnboardingView (200)       AppState (199)
AppDataBrowserView (199)     PatchProject (193)         Theme (174)
PatchRule (165)              FilesTabSwitcherView (162)  AppMusic (162)
PatchDirectory (149)         PatchLedgerEntry (145)     FileReplacementService (104)
DevicePatchService (98)      ZIPArchiveWriter/Extractor CleanerSortOrder, ContainerStore
```

### Logical layers

```
┌─────────────────────────────────────────────┐
│ UI (SwiftUI)  Dashboard / Products / Files /│
│ Cleaner / Wallpapers / Gestalt / Settings   │
├─────────────────────────────────────────────┤
│ Coordinator layer                            │
│ ProductActivationCoordinator, LicenseGate,   │
│ AuthorizationCoordinator, PatchDraftCoordinator│
├─────────────────────────────────────────────┤
│ Service layer                                │
│ RemotePatchStore, FileReplacementService,    │
│ DevicePatchService, PairingController,       │
│ AppUpdateChecker, NotificationInbox          │
├─────────────────────────────────────────────┤
│ Codec / storage                              │
│ PatchPackageCodec (.3105), PatchProjectStore,│
│ PatchLedgerEntry, ZIPArchive*, ContainerStore│
├─────────────────────────────────────────────┤
│ Platform primitives                          │
│ kexploit_opa334, bad_query sandbox escape,   │
│ MobileGestalt, LaunchServices, MCM, AFC/ATC, │
│ RemotePairing/CDTunnel, aws-lc crypto        │
└─────────────────────────────────────────────┘
```

`ThreeOneOSFiveApp` is the app root; `3105` is the project's signature number ("three one oh five" / `threeoneosfive`) used as extension and URL scheme.

---

## 6. Feature deep-dive

### 6.1 Dashboard
- Launch splash + onboarding (`IntroSplashView`, `IntroSplashModel`, `OnboardingStep`).
- Kernel-status widget: `dashboard.kernel_active` / `dashboard.kernel_inactive`.
- Dynamic feature toggles: Cleaner and Wallpapers are optional tabs, enabled from the dashboard.
- Entry to the **Gestalt editor** and **Logs**.
- Force-update gate (`ForceUpdateView`) and blocked-access states (`BlockedAccessView`, `SecurityBlockView`).

### 6.2 Free Fire / Free Fire MAX product patches
Product catalogue is server-driven; local UI copy reveals the product categories:

| Key | Product |
|---|---|
| `ff.cat.aimbot` / `AIMBOT` | Aim Head / Neck / Chest / Body / Drag / Magic / File, Aimbot Avatar, Aimbot Cache |
| `ff.cat.mod_skin` / `MOD SKIN` | Mod Skin (e.g. "Mod Skin Gojo"), weapon holograms (e.g. "Turquoise weapon hologram") |
| `freefire.chams_holo` | Chams + Purple Holo |
| `freefire.chams_no_color` | Chams No Color |
| `freefire.unlock_fps_144` | Unlock FPS 144 |
| location | "Location can be enabled before entering the game" |

Behavioural notes from strings:
- Files are fetched from `/api/products/files/<slug>` and written into the game container.
- "Enable Aim when you are in the game lobby" — i.e. it edits live game data.
- Products are gated: key must be activated, permissioned, unexpired, and not paused/blocked.
- Product sync status: `%lld products ready — %lld skipped — %lld failed`.

> This is unambiguous game-cheating/asset-modification functionality, not a legitimate "companion" app.

### 6.3 File browser / app-data editor
`FileBrowserView`, `AppDataBrowserView`, `FileQuickLookController`, `ZIPArchiveWriter/Extractor`.
- Enumerates installed app containers via `LSApplicationWorkspace` / `MobileInstallation` (`[3105] ls: extracted %lu apps (%lu with container)`).
- Full CRUD: create, rename, copy, move, delete, import, export, QuickLook, ZIP create/unzip.
- Safety rails: path-traversal checks ("malformed or contains an unsafe path"), symlink refusal, recursive-destination refusal, free-space checks, zip-slip protection.
- Can promote edited files to a **patch project** (`browser.create_patch`).

### 6.4 Cleaner
- Scans every app for `Library/Caches` + `tmp` only.
- Explicitly leaves Documents, preferences and Keychain untouched.
- Shows freed bytes, per-app selection, sort-by-size.

### 6.5 Wallpaper lab (`.tendies` / PosterBoard)
- Installs wallpaper bundles into `com.apple.PosterBoard`.
- Working dirs `.3105-wallpaper-`, `.3105-wallpaper-probe-`.
- Uses the kernel/sandbox access to write into Apple's system container.
- Technique credited to **Pocket Poster / Nugget**.

### 6.6 MobileGestalt capability editor
A "Nugget"-style plist editor over the system MobileGestalt cache, reachable only after the exploit grants sandbox access:

- Apple Intelligence eligibility, iPadOS mode, Install iPad Apps, Apple Pencil, Action Button, Camera Button, Always-On Display + AOD vibrancy, Boot Chime, Charge Limit, Crash Detection, Custom Device Name / model spoof, Device Subtype, Disable Region Lock, Internal Features, Internal Storage, Metal HUD, and more.
- Writes to the MobileGestalt cache; the UI warns: *"The Gestalt file is empty. Do not reboot this device."*
- "Grant Sandbox Access" is a hard prerequisite (`gestalt.grant_first`).

### 6.7 Pairing & remote file replacement ("airlift")
A complete Rust device-communication stack, used when the target device can't be reached through normal sandbox access:

1. Pairing file import (`PairingDocumentPicker`, `PairingFileImportError`) — parses Apple pair records (OPACK).
2. Discovery over Bonjour (`_remotepairing-pairable-host._tcp`).
3. Tunnel establishment:
   - `RemoteXPC` over RSD, fallback to **raw RPPairing**
   - `TLS-PSK + CDTunnel` handshake
   - `lockdownd` on `127.0.0.1:62078` over the tunnel
4. Services: AFC, InstallationProxy, `com.apple.atc` (AirTraffic) batch sync.
5. **"Airlift" write technique:** batch-writes files through the ATC manifest, with a file-by-file fallback, using a **Grappa token** (`grappa: successfully generated authentic Grappa token`), plus AFC relocation tricks to delete files it cannot unlink directly.

Requires a **loopback VPN** on some versions ("Ensure a loopback VPN (e.g. LocalDevVPN or SideStore WireGuard) is active") — indicating the tunnel binds a local address the app cannot otherwise reach.

---

## 7. Licensing & backend

**Base URL:** `https://xkeyapi.onrender.com/api` (Render-hosted Flask/FastAPI app; free-tier sleep likely explains timeouts).

| Endpoint | Purpose |
|---|---|
| `/api/version/check` | Forced-update / kill-switch |
| `/api/notifications/` | User notification inbox |
| `/api/notifications/active` | Show only active announcements |
| `/api/products/catalog` | Product catalogue (games, categories, slugs, filenames) |
| `/api/products/files/<slug>` | Product binary download |
| `/api/music`, `/api/music/files/` | In-app music catalogue + files |
| `/udid/web` | Device/UDID → license web page |

**License state machine** (`LicenseGate`, `AuthorizationCoordinator`):

`empty → activating → active` plus failure branches `expired`, `blocked`, `paused`, `noPermission`, `notActivated`, `refused`, `unavailable`, `bad_slug`, `banned`, `not_found`.

Server-side admin can: block a key, pause a key, block a device, block an app version (`blocked.ipa.*`), or hand out a license web page keyed to a UDID. This is a **remote kill-switch over the user's device and purchased "products."**

**Certificate pinning:** the API host is pinned with 3 SHA-256 SPKI/cert hashes; the UI allows the user to relax pinning for the current session (a support/debug affordance that also weakens security).

---

## 8. Patch package format (`.3105`)

`PatchPackageCodec` / `PatchProject` / `PatchRule` / `PatchDirectory` / `PatchLedgerEntry` / `PatchTransaction` / `RestorePayload`.

### Container
- Encrypted payload (AES-GCM; AES-CBC primitives also linked from aws-lc).
- Key wrapping: `wrappedContentKey` — content key encrypted with a password-derived key.
- Password KDF: PBKDF2 with `kdfSalt` + `kdfIterations` (explicit fields).
- Integrity: SHA-256 digests of the package and of each entry; "digest is not ours" and "remote readback digest verified" checks.
- Legacy **v1** packages supported alongside the current format.

### Semantics
- A project = ordered `PatchRule`s mapping source → destination paths inside app containers, with a `PatchLedgerEntry` per applied file.
- Transactional apply: backups go to `.3105-displaced-*` / `.3105-workspace-*`; a `RestorePayload` + `PatchRestoreReport` allows rollback.
- `PatchImportSource`: file import, URL scheme, document picker, or remote.
- Remote variant: `3105-patch-remote-*`, `3105-remote-read-*`, `3105-remote-replacement-*` for pairing-based writes.
- Validation of paths, symlinks, and conflicts happens before any write (`PatchDraftCandidate`, `FileImportConflict`).

This is effectively a **general-purpose, encrypted, transactional file-injection format for iOS app sandboxes** — far broader than "a game skin."

---

## 9. Kernel exploit & sandbox escape

Present as first-class, shipped code (not a stub). Log strings:

```
[X] kexploit: ===== STAGE 1/2: kernel r/w (kexploit_opa334) =====
[X] kexploit: ===== STAGE 2/2: sandbox escape =====
[X] kexploit: OK - kernel read/write established
[X] kexploit: OK - sandbox escaped (full R+W filesystem)
[SBX] *** SANDBOX ESCAPED (R+W) ***
```

- **Stage 1 — kernel R/W:** a port of **`kexploit_opa334`** (credited to `seo`), using `pe_v2` physical-memory primitives (`mach_vm_allocate`, `mach_vm_map`, IOSurface-backed mappings). Handles per-SoC offsets and reports "unsupported iOS build, wrong SoC offsets, or a race loss."
- **Stage 2 — sandbox escape:** `bad_query` technique (credited to `forcequit`), abusing `containermanagerd` via `dlopen`'d MCM symbols (`container_query_create`, `container_copy_sandbox_token`, `container_object_sandbox_extension_activate`, `consume_extension`) to obtain and consume a sandbox extension token for `com.apple.app-sandbox.read-write`.
- **A18/M4 special-casing:** `[+] Running on A18/M4 device` / `[+] Running on non-A18/M4 device`.
- The app auto-runs it on launch (background), can skip it if sandbox access is already active, and tells the user the device "may briefly freeze" for 10–30 s.

**Supported builds** (65 verified entries parsed from the binary) span iOS 17.0 → 26.0.x and iOS 27 betas:

`21A329/340/350/351/360`, `21B101`, `21E219/236/237`, `21G101`, `21H216/221`, `22A3354/3370`, `22C152/161`, `22E240/252`, `22G100`, `22H124/217/218/311/320/333/340/352/355/374`, `23A341/345/355`, `23D127`, `23D8133`, `23E246/254/261`, and `24A*` / `24B*` (iOS 27 betas).

---

## 10. Anti-tamper & integrity checks

The app validates its own environment before exposing features:

| Check | Detail |
|---|---|
| Simulator | Refused |
| Debugger | Refused |
| Bundle ID | Must be `com.apple.mobile.MobileHouseArrest` |
| Display name | Must be `X` |
| Executable name | Must be `X` |
| Version / release | Must match `5.2.0` / `124` |
| Brand asset | Presence check in `Assets.car` |
| Audio integrity | SHA-256 of 3 WAVs |

Pinned asset hashes:

```
Welcome.wav     571CEA7F D9EEC0B5 3E4C26B9 3EE5DB9E 41BDA891 6C50AE63 17D94832 D25B42D4
activar.wav     19650380 EEB8A9F3 A5DDA148 EB8694BD 65558CBB B7FE89A5 3673B5A4 909E4DB2
desactivar.wav  0AA8DD37 56A36E19 B99A5A3D 2B65C4BB B92137F6 AAF2E816 6336236B 26B67295
```

**Sideload-tool rejection:** strings explicitly warn that SideStore/AltStore/3uTools/LiveContainer installs are unsupported, and the UI requires a "loopback VPN (e.g. LocalDevVPN or SideStore WireGuard)" only for the tunnel path. Combined with the missing signature, this means: **re-sign with an enterprise cert**, don't install through a store-like sideloader.

---

## 11. Privacy & data handling

- **UDID/device identifiers** are sent to `/udid/web` for license binding — a persistent hardware identifier tied to a third-party server.
- **Local network** access + Bonjour pairing advertisements; can open a tunnel to a *paired* device.
- **Photos** access for wallpaper cropping.
- Full read/write of **every app container** once the exploit succeeds, including Keychain-adjacent app data (the cleaner is scoped, but the file browser is not).
- Logs are shipped/written (`airlift_transport_log.log/.txt`, `AppLog`, `LogView`) — these can contain container paths, bundle IDs, and tunnel details, and could be shared via the Support tab.

---

## 12. Risk assessment

| Severity | Finding |
|---|---|
| 🔴 Critical | Ships working **kernel exploit + sandbox escape** for iOS 17–27; compromises the entire OS security model, not just the game. |
| 🔴 Critical | **Cheat/asset injection** into Free Fire — ToS violation; accounts are commonly banned. |
| 🔴 Critical | **Spoofs Apple's bundle ID** (`com.apple.mobile.MobileHouseArrest`) — deceptive, can collide with/confuse system services expecting the real MHA. |
| 🟠 High | **Unsigned, decrypted** binary from an anonymous developer; must be enterprise-signed — enterprise certs get revoked, and you're trusting an unvetted binary with kernel access. |
| 🟠 High | **Remote kill-switch + UDID licensing** — the operator can disable your app or device at will. |
| 🟠 High | **Arbitrary file write into any container** (and PosterBoard) via an encrypted, remotely-supplied patch format — a supply-chain vector if the API is compromised. |
| 🟡 Medium | **Certificate pinning is user-disableable** — weakens the only transport protection. |
| 🟡 Medium | Third-party server is a free Render instance — availability, logging, and ownership are opaque. |
| 🟡 Medium | "airlift"/Grappa/ATC batch-write abuses Apple sync internals; can leave device state inconsistent (`relocated file is still present in AFC`). |
| 🟢 Low | ZIP handling actually has good zip-slip/symlink defenses. |
| 🟢 Low | Cleaner is properly scoped to Caches + tmp. |

**Bottom line:** treat this as **hostile software**. It is functionally a jailbreak-lite + game cheat with a remote-controlled licence backend. Running it on a personal device risks compromise, data exposure, game-account bans, and enterprise-cert revocation. If it must be examined, do it on a disposable, non-primary device with no valuable accounts, and do not sign in to anything.

---

## 13. Attribution & provenance

| Role | Handle |
|---|---|
| Developer / designer | `bnxyung7` |
| MHA-C2 / app discovery | `FilzaSlop` |
| `bad_query` exploit | `forcequit` |
| `.tendies` wallpaper method | Pocket Poster / Nugget |
| `kexploit_opa334` port | `seo` |
| Project / community | `yangjiii` (Hole30601) |

Links embedded in the binary:
- `https://github.com/bnxyung7/ProyectX`
- `https://discord.gg/wAAbwX8Dmc`
- `https://discord.gg/wpqqTnfXfc`
- `https://t.me/hole30601`
- `https://apps.apple.com/app/id6755608044` (companion App Store listing — likely the "legit" front)

Build fingerprint `main@b27d178ee`, macOS user `builder`, Swift+Cargo toolchain, 2026-11-07 — consistent with a small team building locally and shipping ad-hoc IPAs.

---

## 14. Method & limitations

**Done:** archive parsing, `Info.plist` decode, Mach-O header/load-command/section parse, full symbol-table extraction (74,969), `__cstring` extraction (3,763), all-ASCII string dump (57,660), Swift type-path reconstruction (232), localization keys (820 ×3 languages), AppIntents decode, `Assets.car` introspection, endpoint/pin/hash extraction, exploit-string analysis, build-ID enumeration.

**Limitations:**
- No native Mach-O decompiler on this host (Windows Ghidra supports PE/6502 only), so **no pseudocode** for Swift/Rust functions — behaviour is inferred from symbols, strings, and API names.
- `Assets.car` decoded only at header/stream level; no full asset rendering.
- No runtime tracing, no network capture against the live API, no dynamic verification of exploit success.
- Function-level control flow (e.g. exact `.3105` KDF parameters beyond PBKDF2 fields) not recovered.

---

*End of report.*
