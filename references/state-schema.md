# State schema 2

The state file is user-local at `~/Library/Application Support/uaRO-CrossOver/state.json` and is never committed. State updates use nested merge and preserve prior evidence. Dry-run commands must not erase backups or verification fields.

Important sections:

- `installer`: ZIP/member hashes and staging state.
- `setup`: installed `setup.exe`, profile, before/after hashes, backup, and site statuses.
- `raw_input`: artifact, stock probe, overlay, after probe, and artifact status. Probe status is semantic: `pass` means `AFFECTED=no` with clobbered entries `0`, `affected` means `AFFECTED=yes` with a positive clobbered count, and `unconfirmed` means the output is incomplete or contradictory. The top-level status must not say `affected` for a clean stock probe.
- `launch`: launcher path, PID, runtime route, live `ntdll.so`/`wow64win.dll` evidence, and log.
- `registration`: CrossOver `cxbottle.conf`/`cxmenu.conf`/menu plist evidence, exact shortcut and exported command paths, `cxmenu --query` return code and `CXMenuMacOSX` match count, build match, repair attempt, and status.
- `launchers`: actual Patcher/Settings Applications directory (normally `/Applications`, with a reported `~/Applications` fallback), runtime route, and signature verification status.
- `e2e`: user-confirmed Patcher, login, map-load, and T-code observations.

Evidence levels remain separate from command exit codes. In particular, a stock probe may report `AFFECTED=yes` with a non-zero guest exit, while a clean after-probe is not by itself end-to-end proof.

When the artifact came from the public Release route, `raw_input.release` records the
repository, exact tag, asset name and URL, downloaded archive SHA-256, the digest source
(`github_release_api`), and whether the inner `SHA256SUMS` passed. A release record proves
which bytes were fetched; it does not prove that the community binary is signed or
licensed for redistribution.
