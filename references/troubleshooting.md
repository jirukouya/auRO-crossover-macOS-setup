# Troubleshooting decision tree

## Settings or `setup.exe` crash

Inspect the installed `setup.exe`, not `UaRO_Setup.exe`. Confirm its full SHA-256 matches a registered OpenSetup profile, then apply the three context-checked sites. An unknown hash blocks the patch.

## `Gepard::T Code: 3::110::12` after map load

Inspect live `uaRO.exe` with `lsof` for `wow64win.dll`. After Option A, the path must be inside CrossOver.app and the hash must match `deploy-app`. If lsof still shows the stock `.orig` file, review the shared-app impact and re-run `deploy-app --confirm-app-change`. Overlay probe PASS with no live process is not a fix. If the baseline was never affected, a remaining T-code is not proof that a DLL overlay is needed. Do not patch Gepard itself.

## Game never starts / macOS says “App Running in Background”

Show the user the Settings SOP: 2560×1600, DirectX 9, and Restrict mouse to window off. The skill does not inspect `user.reg` or claim those choices were machine-verified. Rebuild the Patcher/Settings launchers with current `build-launchers.zsh`; they must use CrossOver `--wait-children`, include `LSUIElement=true`, and exit when the requested Windows program exits. Do not paste an `.icns` into an already-signed app without rebuilding. A lingering background notice indicates an old launcher bundle or detached Wine process; check `/Applications/UaRO CrossOver *.app` (or the reported `~/Applications` fallback) and run `repair`. `repair` PASS does not mean the game starts.

## Installer or Settings window is not visible

The installer launch path asks macOS to bring CrossOver to the foreground before starting the Windows installer. If the window is still on another Space, use Cmd-Tab or select CrossOver manually; the Skill does not use desktop coordinates or automatic clicks. Keep the terminal command running until the GUI closes, then rerun `bottle status` and `verify-registration --repair`.

After `build-launchers`, always rerun `verify-registration`. Launcher export can refresh CrossOver's menu files, so the follow-up query is the evidence that `CXMenuMacOSX` still contains uaRO.

## Other Gepard errors

The raw-input fix may not explain every crash or anti-cheat result. Keep the cause `未确认` until the exact runtime, error, and reproducible evidence are available.
