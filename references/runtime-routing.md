# CrossOver runtime routing

The overlay is only effective when the live Wine process loads it.

```text
CrossOver UI shortcut
  -> CrossOver stock bin/wine
  -> stock ntdll.so + stock wow64win.dll
  -> raw-input overflow remains possible

UaRO CrossOver Patcher.app
  -> per-bottle overlay/bin/wine
  -> local ntdll.so + patched wow64win.dll
  -> after-probe/runtime anchor required
```

Use `scripts/uaro-crossover.zsh verify-live-runtime --bottle NAME --json` while uaRO is running. `lsof` is supplementary; `vmmap`, `WINEDEBUG=+loaddll`, the overlay manifest, and the live path anchor are the primary evidence. A process that is not running is `unconfirmed`, not proof that the fix failed.

