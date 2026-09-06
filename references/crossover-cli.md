# CrossOver CLI contract

## Local evidence

On the maintainer Mac, CrossOver reports public version `26.3.0` and product build `26.3.0.39832`.

The desktop bundle exposes:

```text
Contents/SharedSupport/CrossOver/bin/wine
Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/cxbottle
```

`wine --help` confirms `--bottle`, `--cx-app`, `--workdir`, `--wait`, and `--no-update`. `cxbottle --help` confirms `--bottle`, `--create`, `--template`, `--status`, and `--delete`.

The tools are not assumed to be on PATH. The resolver derives both paths from the selected CrossOver app and rejects ambiguous installations.

## Runtime rules

- Use the CrossOver `bin/wine` wrapper for ordinary bottle operations.
- Pass the bottle explicitly on every invocation.
- Use `--cx-app` for Windows executables.
- Use a per-bottle overlay only after the raw-input artifact contract has passed.
- For registry-only keyboard mapping, stop the selected bottle's Wine server first, then use the resolved CrossOver `bin/wine --bottle ... --cx-app` wrapper to invoke `reg.exe`; do not assume `reg.exe` or `wineserver` is on PATH.
- Do not use a different Wine manager's environment or metadata files.
