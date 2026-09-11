# Troubleshooting decision tree

## Settings or `setup.exe` crash

Inspect the installed `setup.exe`, not `UaRO_Setup.exe`. Confirm its full SHA-256 matches a registered OpenSetup profile, then apply the three context-checked sites. An unknown hash blocks the patch.

## `Gepard::T Code: 3::110::12` after map load

First inspect the live launch route. If the baseline was affected and the process uses stock or mixed CrossOver paths, close it and relaunch with `UaRO CrossOver Patcher.app`. If the route is overlay, compare the loaded DLL hash with the artifact manifest and inspect stock/after probe logs. If the baseline was clean, a stock route is expected and an overlay is not evidence-based. Do not replace uaRO game DLLs based on this T-code alone.

## Other Gepard errors

The raw-input fix may not explain every crash or anti-cheat result. Keep the cause `未确认` until the exact runtime, error, and reproducible evidence are available.
