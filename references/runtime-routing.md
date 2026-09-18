# CrossOver runtime routing

Wine loads builtin `wow64win.dll` from the directory of the `ntdll.so` that was actually loaded, not from `WINEDLLPATH`. A directory that only holds a replacement DLL is ignored.

```text
Official CrossOver bin/wine --bottle --cx-app
  -> CrossOver.app ntdll.so
  -> CrossOver.app wow64win.dll
  -> Option A must replace that wow64win.dll (after .orig backup)

Generated overlay Patcher.app without cxbottle BinPath/LibPath
  -> often still stock ntdll
  -> patched overlay DLL never loads
  -> probe-on-overlay can pass while Play still dies
```

Valid branches after the stock probe:

| Baseline | Deploy | Live success |
|---|---|---|
| AFFECTED=no, clobbered entries = 0 | None | `runtime=stock` `status=pass` |
| AFFECTED=yes, clobbered entries > 0 | **Option A** `deploy-app` (default) | `uaRO.exe` ≥15s; lsof = CrossOver.app DLL; hash = artifact |
| Same affected baseline | Option B overlay **and** `cxbottle.conf` BinPath/LibPath | `runtime=overlay` `status=pass` |

Clobbered **entry count** 238 is the expected broken thunk on this Mac. It is not the contamination flag `CLOBBERED=1`.

Use `scripts/uaro-crossover.zsh verify-live-runtime --bottle NAME --json` while uaRO is running, plus `lsof` on `uaRO.exe`. A process that is not running is `unconfirmed`. Overlay probe PASS alone is not proof the game starts.
