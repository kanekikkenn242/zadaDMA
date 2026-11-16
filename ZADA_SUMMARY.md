[Zada]

Full Developer Mode + Remote Pairing + Git Push implementation for iOS.

RUST LIBRARY ( zdma_crypto ):
- zdma_generate_pin: Generates 6-digit PIN (000000-999999) via getentropy
- zdma_start_pairing_host: Initiates IDEVICE host pairing, prompts iOS for PIN verification
- zdma_afc_connect_with_pairing_file: Opens AFC tunnel over pairing file (port 49152)
- zdma_afc_write: Writes files via AFC (e.g., .3105 aim configs)
- zdma_afc_close: Closes AFC client
- Core crypto: SHA256, PBKDF2-HMAC-SHA256, AES-256-GCM encrypt/decrypt

SWIFT PAIRING CONTROLLER:
- loadSymbols: dlsym resolution for all idevice_ffi functions at launch
- generatePin(): Calls Rust zdma_generate_pin, returns 6-char code
- startPairing(pin:): Sends PIN to iOS Developer Mode, creates pairing.plist
- injectFile(localPath:remotePath:): Establishes LocalDevVPN-like tunnel (127.0.0.1:49152), writes via AFC
- writeAimFile(remoteDir:filename:localData:): Writes .3105 aim config files to container
- gitPush(to:branch:completion:): Full git push to GitHub repo via AFC tunnel
- importPairingFile(url:): Import existing pairing.plist from backup

AFC CLIENT ( Motor/AFCClient.m ):
- Standard Apple File Conduit operations: open/write/close/remove/rename/mkdir/read-dir
- CFA6LPAA protocol handling

FLOW:
1. App launches → dlsym resolves idevice functions from libidevice_ffi
2. User enables Developer Mode in iOS Settings → iOS discovers Bonjour/mDNS server
3. User enters 6-digit PIN from app in Developer Mode prompt
4. idevice_start_pairing_host verifies PIN → pairing.plist saved to Documents
5. Tunnel established on port 49152 (127.0.0.1 → LocalDevVPN logic)
6. AFC connection via idevice_afc_connect_with_pairing_file
7. .3105 files or project data written via AFC write
8. gitPush executes push to GitHub via established tunnel

Code: Rust/Staticlib + Swift 5.9 / iOS 16.0 / libidevice_ffi + libimobiledevice