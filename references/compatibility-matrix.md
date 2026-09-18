# Compatibility matrix

| Host | CrossOver | Raw-input artifact | Status |
|---|---|---|---|
| Apple Silicon macOS | 26.3.0 line (`26.3` / `26.3.0`, build `26.3.0.*`) | `wow64win.dll.crossover-26.3.0` schema-2 package | Scripts allow this family. Full in-game confirmation: maintainer Mac on `26.3.0.39832` only. Other 26.3.0.* patch numbers need stock + after probe PASS. |
| Apple Silicon macOS | 26.2, 26.4, 27.x, or unread version | Any prebuilt | Blocked |
| Intel macOS | Any | Any | Not supported |

Do not treat a successful probe on one 26.3.0 patch as proof every later 26.3.0 patch will load the game. If after-deploy probe stays AFFECTED=yes, stop.
