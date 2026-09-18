# Skill 优化方案（2026-09-18 试错）

本文件是下一轮改 `SKILL.md` / 脚本的清单。正本是 Discord 大佬包 `gepard-crossover-fix`（README、SKILL.md、SHARE-PROMPT.md、`wow64win.dll.crossover-26.3.0`、`patch_opensetup_rosetta.py`）。仓库 skill 是衍生安装器，部署规则不得盖过大佬包。

证据：`~/my-agent/000_Agent/memory/daily/2026-09-18.md`。用户已确认游戏能启动。启动成功路径是 **Option A 换 CrossOver.app 的 DLL + OpenSetup 写 Gravity + 官方 wine --cx-app**，不是 overlay Patcher.app。

---

## 原则（改 skill 时先写进 SKILL.md 开头）

1. 大佬包说 Wine 从 **已加载的 ntdll.so 同目录** 解析 builtin `wow64win.dll`。只拷 overlay、启动仍走官方 ntdll → 补丁被静默忽略。
2. SHARE-PROMPT 默认部署是 **Option A**（换 app 内 DLL，先备份 `.orig`）。Option B overlay 仅在用户拒绝改 bundle 时用，且必须写 `cxbottle.conf` 的 `BinPath`/`LibPath`。
3. 全新安装 **先 OpenSetup**：没有 `HKCU\Software\Gravity\RagnarokOnline` 时第一次启动是 `setup.exe`，不是游戏。只写 `OptionInfo.lua` 不够。
4. 完成门：活着的 `uaRO.exe` 超过约 12 秒 + `lsof` 打出部署路径的 `wow64win.dll` + 用户能到登录画面。overlay probe 单独 PASS 不能当游戏能开。
5. 人读 DLL 名 `wow64win.dll.crossover-26.3.0` 保留；import 时再变成缓存里的 `wow64win.dll`。

---

## P0 — 这次直接导致「打不开」

### 1. 部署默认改成 Option A

**踩坑：** skill 写「不要把 DLL 拷进 CrossOver.app」。overlay probe `AFFECTED=no`，Play 后没有 `uaRO.exe`。Option A 之后官方 wine 的 probe 也是 `AFFECTED=no`，`lsof` 打到 app 内 DLL，用户确认能开。

**改法：**

- `SKILL.md` Phase D/E：affected 时默认 Option A（备份 `wow64win.dll.orig`，拷入匹配 build 的预编译 DLL）。
- 删掉/改写 troubleshooting 里「不要拷进 app bundle」——改成「Option A 会改已签名 bundle；更新 CrossOver 后要再套一次」。
- `references/raw-input-fix.md`、`runtime-routing.md` 同步。
- 增加 `scripts/` 子命令（建议 `runtime deploy-app`）：校验 build、备份、拷贝、hash 对照。
- Option B 保留为可选，必须写 `cxbottle.conf` BinPath/LibPath；当前 overlay **没有**写这两项，launcher 用 Perl `bin/wine --cx-app`，与大佬 Option B 不一致。

### 2. OpenSetup / Gravity 注册表作为硬关卡

**踩坑：** 只 `configure` lua 分辨率。`user.reg` 无 Gravity。Play 不像进游戏。大佬脚本 + 官方 wine 开 `setup.exe`，点 OK 后出现 Gravity 键，随后 `uaRO.exe` 才起来。

**改法：**

- Step 6 后新增 Step：用大佬 `patch_opensetup_rosetta.py`（或现有 hash-locked patch-setup，两者应对同一 SHA）。
- 用人控 GUI：官方 `wine --bottle … --workdir <GAME_WIN> --cx-app <GAME_WIN>\setup.exe`，用户选分辨率点 OK。
- 回读 `user.reg` 必须有 `[Software\\Gravity\\RagnarokOnline]` 才进入 Play。
- 可把 `patch_opensetup_rosetta.py` 收进 `scripts/` 并标明上游是大佬包。

### 3. 启动命令改用官方 CrossOver wine

**踩坑：** 自制 `UaRO CrossOver Patcher.app`：`overlay/bin/wine`（Perl）`&` + `wait`。Dock 显示 Running in Background，无 `uaRO.exe`。成功路径：

```text
wine --bottle uaro-crossover --workdir <GAME_WIN> --cx-app <GAME_WIN>\UaRo Patcher.exe
```

随后出现 `uaRO.exe 1rag1`。

**改法：**

- Step 11 默认启动器改为官方 wine 包装（或 CrossOver 自己的 shortcut），`--workdir` 必须是游戏目录。
- 可保留 .app，但 exec 必须是官方 `CrossOver.bin/wine`（Option A 后）或大佬 Option B 的 unix wine，禁止 `&`+`wait` 把 Patcher 当父进程等到退出。
- 明确可执行文件名是 `UaRo Patcher.exe` / `uaRO.exe`，不要写 `Patcher.exe` / `Ragexe.exe`。
- 禁止生成 `UaRO CrossOver Game.app`；也禁止使用 `/Applications/uaRO/` 下旧 Whisky 实验启动器。

### 4. Live 验证对齐大佬三门，而不是「overlay 就算过」

**踩坑：** `verify-live-runtime` 无进程就 `unconfirmed`；脚本还依赖本机没有的 `rg`，并给 zsh 只读变量 `status` 赋值，游戏真在跑也会炸。成功时 Gate 1 是 `lsof -p <uaRO.exe pid>`。

**改法：**

- `rg` → `grep -i`。
- `status=` 改名 `runtime_status=`。
- Option A 完成态：`runtime=stock`（app 内已打补丁）且 lsof 路径是 `CrossOver.app/.../wow64win.dll`，hash 等于预编译包。不要把「stock」一律 BLOCKED。
- 进程存活：取样 ≥15s（大佬：坏的约 12s 死）。
- probe 表：`AFFECTED=yes` 且 clobbered **条目数** 238 是预期坏基线，不是 `CLOBBERED=1` 污染旗。SKILL 解释表要改，否则 AI 会停错。

---

## P1 — 脚本/文档自相矛盾（会让下一场 AI 再踩）

| 问题 | 改法 |
|---|---|
| `overlay.zsh` 在 `mv staging` 前对最终 `OVERLAY_DIR` 做 digest（本机已修） | 提交该修复；hash 用 `$STAGING_DIR` |
| SKILL Step 2 只写 `wow64win.dll` | 写明接受 `wow64win.dll.crossover-<ver>`，禁止改用户包文件名 |
| 把 `UaRO-CrossOver-artifacts`（含 manifest.json）当 `--rawinput-source-dir` | 文档：source = 大佬文件夹；cache = 非 iCloud 的 artifact dir |
| iCloud 可作 source，cache 必须非 iCloud | 写进 preflight 规则 |
| `repair` PASS ≠ 游戏能开 | repair 范围写死：只查 launcher 脚本/签名，不报「install healthy」 |
| 无 .icns 是生成物常态 | README：占位图标正常；不要让 AI 去改 icon |
| `patch-setup` JSON `states=pending` 同时 `patched=[…]` | 修 JSON 或 skill 写「以 patched 列表和 after_sha256 为准」 |
| 卸载后旧 `winedevice` 仍占 overlay inode | uninstall 后 `wineserver -k`（仅该 bottle） |

---

## P2 — 体验/防混用

- 进度表增加：OpenSetup GUI、Gravity 注册表、Option A hash、lsof Gate 1、进程存活 ≥15s。
- 完成报告：写清走的是 Option A 还是 B；launcher 路径；「无 Game.app」。
- README 人话：启动用官方 wine / 生成的 Patcher（若仍保留）；Dock 后台跳动不是游戏在跑。
- CrossOver 更新后：检测 app 内 DLL hash 是否仍等于预编译包，否则再套 Option A。
- 不要把 Whisky 目录、`~/Games/UaRO World of Your Dream`、`/Applications/uaRO/` 当 CrossOver 目标。

---

## 建议改文件顺序（下一轮动手）

1. `scripts/verify-live-runtime.zsh`（rg + status）
2. 提交已有 `overlay.zsh` staging hash 修复
3. 新 `runtime deploy-app`（Option A）
4. `SKILL.md` Phase D/E + OpenSetup 关卡 + 启动命令 + 完成门
5. `references/raw-input-fix.md`、`runtime-routing.md`、`troubleshooting.md`、README
6. 可选：收编 `patch_opensetup_rosetta.py`；Option B 补 `cxbottle.conf`

本轮 **不** 改 AzzyAI 流程。
