# State schema 2

The state file is user-local at `~/Library/Application Support/uaRO-CrossOver/state.json` and is never committed. State updates use nested merge and preserve prior evidence. Dry-run commands must not erase backups or verification fields.

Important sections:

- `installer`: ZIP/member hashes and staging state.
- `setup`: installed `setup.exe`, profile, before/after hashes, backup, and site statuses.
- `raw_input`: artifact, stock probe, overlay, after probe, and artifact status.
- `launch`: launcher path, PID, runtime route, live `ntdll.so`/`wow64win.dll` evidence, and log.
- `registration`: CrossOver `cxbottle.conf`/`cxmenu.conf`/menu plist evidence, exact shortcut and exported command paths, build match, repair attempt, and status.
- `launchers`: user-level Patcher/Settings paths, runtime route, and signature verification status.
- `e2e`: user-confirmed Patcher, login, map-load, and T-code observations.

Evidence levels remain separate from command exit codes. In particular, a stock probe may report `AFFECTED=yes` with a non-zero guest exit, while a clean after-probe is not by itself end-to-end proof.
