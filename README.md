# uaRO on Apple Silicon via CrossOver

This repository contains a CrossOver-first installation workflow for uaRO on Apple Silicon Macs.

It is intentionally separate from the Whisky workflow. CrossOver bottle management, runtime discovery, launcher execution, and per-bottle overlays use different interfaces and must not be mixed with Whisky commands.

## Current status

`0.1.0-draft`: the automation framework and safety gates are implemented. End-to-end uaRO installation and the Gepard raw-input overlay are not claimed as verified until they pass on the target machine.

The initial compatibility target is:

- Apple Silicon (`arm64`)
- CrossOver `26.3.0.39832`
- a user-supplied uaRO installer bundle
- a separately supplied, provenance-checked raw-input artifact when the probe reports the Wine bug

## CrossOver CLI

CrossOver does not require a separate CLI edition. The desktop app bundles the tools used here:

- `Contents/SharedSupport/CrossOver/bin/wine` runs Windows programs with `--bottle` and `--cx-app`.
- `Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/cxbottle` creates, inspects, and deletes private bottles.

The scripts resolve these paths from the installed CrossOver app and do not assume either `/Applications` or `~/Applications` when both are present.

## Human steps

The workflow automates local preparation, bottle setup, staging, patch validation, configuration, launcher creation, diagnostics, and rollback. It does not handle uaRO account passwords, download-wall authentication, first game login, or the final live map-load check.

## Quick start

```zsh
scripts/uaro-crossover.zsh preflight \
  --bottle uaro-crossover \
  --installer-dir "$HOME/Games/UaRO-Installer"

scripts/uaro-crossover.zsh bottle create --bottle uaro-crossover
scripts/uaro-crossover.zsh install \
  --bottle uaro-crossover \
  --installer-dir "$HOME/Games/UaRO-Installer"
```

Every state-changing command is explicit. Do not run `install`, `patch-setup`, `build-overlay`, or `build-launchers` until `preflight` passes and the required local artifacts have been supplied. `build-overlay` and `verify-overlay` are wrappers for the three-stage raw-input flow.

## Safety contract

- Never modify `/Applications/CrossOver.app`.
- Never use another person's absolute paths.
- Never apply a binary patch when the expected bytes do not match.
- Never deploy a raw-input overlay without an exact CrossOver build and SHA-256 manifest.
- Never treat a probe result as proof of successful uaRO login or map load.
- Uninstall requires an explicit level and confirmation.

## License

The repository's scripts and documentation are released under the MIT License. uaRO files, CrossOver files, and third-party Wine artifacts remain subject to their own licenses and are not included by default.
