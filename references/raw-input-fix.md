# Raw-input overlay contract

The reported Wine defect affects a WoW64 raw-input thunk in some newer Wine runtimes. The reported one-line source change is:

```diff
- for (i = 0; i < *count; ++i)
+ for (i = 0; i < ret; ++i)
```

This repository does not claim that a binary is safe merely because it has that filename. A usable artifact bundle must include:

- `manifest.json`;
- a matching `wow64win.dll`;
- the probe executable and its source/patch evidence;
- CrossOver public version and complete build;
- SHA-256 values for all supplied files;
- explicit provenance fields. Community prebuilt source revision, signature, and redistribution license remain `unconfirmed` until independently established.

The probe must run before and after deployment. The portable acceptance rule is:

```text
stock: AFFECTED=yes and clobbered entries > 0 before deployment
after: AFFECTED=no and clobbered entries = 0 after deployment
```

The current probe command requires an imported candidate package containing the probe, source, patch, and candidate `wow64win.dll` before the stock baseline can be measured. A clean stock result does not deploy that DLL; deployment is allowed only when the baseline reports `AFFECTED=yes`, `CLOBBERED=0`, and the build/source/hash gates pass. When the baseline is clean, the overlay step is `N/A` and the stock runtime is an accepted branch.

The exact pre-fix count is machine-dependent; `238` is not a portable expectation. The overlay copies the current CrossOver `ntdll.so`, never an external one, and does not modify the CrossOver app. `lsof` is not a sufficient proof for a mapped PE DLL; use probe output, `WINEDEBUG=+loaddll`, the overlay runtime anchor, and the overlay manifest.

The supplied OpenSetup patch is a separate file chain: it targets the installed game `setup.exe`, not `UaRO_Setup.exe`. The production profile is `gepard-crossover-26.3.0`; its full input and output hashes must match before any bytes are changed.
