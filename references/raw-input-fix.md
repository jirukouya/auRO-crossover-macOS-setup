# Raw-input overlay contract

The reported Wine defect affects a WoW64 raw-input thunk in some newer Wine runtimes. The reported one-line source change is:

```diff
- for (i = 0; i < *count; ++i)
+ for (i = 0; i < ret; ++i)
```

This repository does not claim that a binary is safe merely because it has that filename. A usable artifact bundle must include:

- `manifest.json`;
- a matching `wow64win.dll`;
- the matching `ntdll.so` if the runtime requires it;
- the probe executable and its provenance;
- CrossOver public version and complete build;
- SHA-256 values for all runtime anchors and supplied files;
- source revision or a clear redistribution license.

The probe must run before and after deployment. The portable acceptance rule is:

```text
before: AFFECTED=yes and clobbered entries > 0
after:  AFFECTED=no and clobbered entries = 0
```

The exact pre-fix count is machine-dependent. `lsof` is not a sufficient proof for a mapped PE DLL; use probe output and `WINEDEBUG=+loaddll` records as well.
