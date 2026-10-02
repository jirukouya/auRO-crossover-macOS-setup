# CrossOver runtime routing

Wine loads builtin `wow64win.dll` from the directory of the `ntdll.so` that was actually loaded, not from `WINEDLLPATH`. A directory that only holds a replacement DLL is ignored.

```text
Option A: official CrossOver bin/wine --bottle --cx-app
  -> CrossOver.app ntdll.so
  -> CrossOver.app wow64win.dll
  -> deploy-app replaces that wow64win.dll after a .orig backup

Option B: generated launcher -> per-bottle overlay/bin/wine
  -> overlay ntdll.so
  -> overlay wow64win.dll
  -> the paired runtime loads the overlay DLL
  -> manifest, after-probe, and live lsof checks remain mandatory
```

Valid branches after the stock probe:

| Baseline | Deploy | Live success |
|---|---|---|
| AFFECTED=no, clobbered entries = 0 | None | `runtime=stock` `status=pass` |
| AFFECTED=yes, clobbered entries > 0 | **Option A** `deploy-app --confirm-app-change` (default after explicit user confirmation) | `uaRO.exe` ≥15s; lsof = CrossOver.app DLL; hash = artifact |
| Same affected baseline | Option B `overlay build` + `overlay verify` + generated launcher using overlay `bin/wine` | `runtime=overlay` `status=pass`; lsof = overlay DLL |

Clobbered **entry count** 238 is the expected broken thunk on this Mac. It is not the contamination flag `CLOBBERED=1`.

The current Option B implementation does not edit `cxbottle.conf`; it pairs the generated launcher with the copied overlay `bin/wine`. Do not launch an Option B installation through the official CrossOver wrapper, or the process may load stock `ntdll.so` instead.

Use `scripts/uaro-crossover.zsh verify-live-runtime --bottle NAME --json` while uaRO is running, plus `lsof` on `uaRO.exe`. A process that is not running is `unconfirmed`. Overlay probe PASS alone is not proof the game starts.
