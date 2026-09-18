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

The current probe command requires an imported candidate package containing the probe, source, patch, and candidate `wow64win.dll` (human name may be `wow64win.dll.crossover-26.3.0`) before the stock baseline can be measured. Do not pass the import cache (`manifest.json`) as `--rawinput-source-dir`. A clean stock result does not deploy that DLL; deployment is allowed only when the baseline reports `AFFECTED=yes` and clobbered entries > 0, plus build/source/hash gates.

Default deploy is Option A: `deploy-app --confirm-app-change` backs up `wow64win.dll.orig` and replaces CrossOver.app. Option B overlay must also set bottle `BinPath`/`LibPath`. `lsof` on a live `uaRO.exe` is Gate 1 for “the right file is loaded.”

The supplied OpenSetup patch is a separate file chain: it targets the installed game `setup.exe`, not `UaRO_Setup.exe`. The production profile is `gepard-crossover-26.3.0`; its full input and output hashes must match before any bytes are changed.
