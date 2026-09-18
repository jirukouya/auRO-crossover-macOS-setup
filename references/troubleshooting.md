# Troubleshooting decision tree

## Settings or `setup.exe` crash

Inspect the installed `setup.exe`, not `UaRO_Setup.exe`. Confirm its full SHA-256 matches a registered OpenSetup profile, then apply the three context-checked sites. An unknown hash blocks the patch.

## `Gepard::T Code: 3::110::12` after map load

Inspect live `uaRO.exe` with `lsof` for `wow64win.dll`. After Option A, the path must be inside CrossOver.app and the hash must match `deploy-app`. If lsof still shows the stock `.orig` file, re-run `deploy-app`. Overlay probe PASS with no live process is not a fix. If the baseline was never affected, a remaining T-code is not proof that a DLL overlay is needed. Do not patch Gepard itself.

## Game never starts / Dock “Running in Background”

Confirm Gravity registry exists; if not, `launch-setup` and click OK. Launch with `launch-patcher` (official wine), not `/Applications/uaRO/` and not a Game.app. Generated `.app` bundles have no custom icon; that is normal. `repair` PASS does not mean the game starts.

## Other Gepard errors

The raw-input fix may not explain every crash or anti-cheat result. Keep the cause `未确认` until the exact runtime, error, and reproducible evidence are available.
