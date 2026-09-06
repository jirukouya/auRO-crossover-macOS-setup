# Evidence log

## 2026-09-06

- `gh 2.88.1` is installed and authenticated as `jirukouya`.
- Existing reference repo is `jirukouya/auRO-whisky-macOS-setup`.
- CrossOver local bundle reports `26.3.0.39832`.
- CrossOver contains `bin/wine` and `CrossOver-Hosted Application/cxbottle`.
- The local machine has no visible uaRO CrossOver bottle at preflight time.
- The supplied `gepard-crossover-fix` directory is available under the user's iCloud Downloads path; its community DLL, probe, source, and source patch hashes were recorded during import validation. The package's source revision, binary signature, and redistribution license remain unconfirmed.
- Candidate hashes observed during local read-only validation: `wow64win.dll` `c2cc2d3a25b9b74bd2269b209debfbaaaafcf28c40def18ada05993aab80d701`; probe `5e829ee8b1338fa208c55d080ce6e0bbb827322e7b9883446c611708c180cae5`; source patch `03c6b0bdf3440317603308d3e767a15e4eb4ff53f50658eaf1f84eace2523fb6`; probe source `800e87aff61357c76f9cda2d27311116454548484a60a5f96249851705714c25`.
- The external package's `/Users/jax/...` paths are examples from another computer and are not repository defaults.

These facts describe the maintainer machine at the time recorded and are not universal defaults.

## Local A/B runtime evidence — 2026-09-06

- CrossOver: Apple Silicon, `/Applications/CrossOver.app`, public version `26.3`, build `26.3.0.39832`; bottle `uaro-crossover`.
- Stock route: the CrossOver built-in uaRO shortcut loaded the stock runtime and produced `Gepard::T Code: 3::110::12`.
- Stock probe: `AFFECTED=yes`, devices returned `2`, clobbered entries `238`; log: `~/Library/Application Support/uaRO-CrossOver/logs/rawinput-before-20260906-142454.log`.
- Overlay route: `UaRO CrossOver Patcher.app` loaded `.../uaRO-CrossOver-overlay/lib/wine/x86_64-unix/ntdll.so` and `.../uaRO-CrossOver-overlay/lib/wine/x86_64-windows/wow64win.dll`.
- After probe: `AFFECTED=no`, clobbered entries `0`; log: `~/Library/Application Support/uaRO-CrossOver/logs/rawinput-after-20260906-142549.log`.
- The patched `wow64win.dll` SHA-256 was `c2cc2d3a25b9b74bd2269b209debfbaaaafcf28c40def18ada05993aab80d701`; the overlay was approximately 869 MB.
- User-confirmed outcome: Patcher opened, login succeeded, character selection succeeded, map loaded, and the T-code was not observed on the overlay route.
- Long-duration stability, behavior on other CrossOver builds, and whether the DLL resolves every possible Gepard crash remain unconfirmed.
