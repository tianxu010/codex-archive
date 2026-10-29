# 在新机器上复用这些技能

## 1. 还原自研技能

把 `skills/codex/` 下的目录整体复制到目标机器的技能目录：

- Windows：`%USERPROFILE%\.codex\skills\`
- macOS / Linux：`~/.codex/skills/`

```powershell
Copy-Item -Path .\skills\codex\* -Destination "$env:USERPROFILE\.codex\skills\" -Recurse -Force
```

`_shared` 是其他技能的共享资源目录，请一并复制。

## 2. 恢复配置

`config/config.redacted.toml` 是本机 `~/.codex/config.toml` 的脱敏副本。
**不要**直接覆盖目标机器的配置——里面的模型、provider 与 MCP 服务器设置是本机专属的。

正确的做法是把需要的片段摘出来合并：

```powershell
# 对照查看差异
git diff --no-index "$env:USERPROFILE\.codex\config.toml" .\config\config.redacted.toml
```

密钥需自行填写，本仓库不提供。

## 3. 填回家庭设备参数

见 [`PRIVACY.md`](PRIVACY.md) 的「使用前需填回的值」。

## 4. 第三方技能

`skills.agents.json` 只是索引，不含源码。用技能安装器重新拉取：

```powershell
# 使用 Codex 内置的 skill-installer 技能，或按上游说明手动安装
```

## 5. 校验

重新运行导出脚本，确认当前机器的状态：

```powershell
pwsh tools/export-archive.ps1
```

脚本会重新采集并脱敏。运行前请先 `git stash` 或在干净工作区执行，避免覆盖你手动做的修改。

---

## Linux / macOS 一键还原（2026-10-29 补充）

新装的机器上，直接跑仓库里的 `tools/sync.sh`：

```bash
git clone https://github.com/tianxu010/codex-archive.git
cd codex-archive
tools/sync.sh            # 拉取 + 装自研技能 + 还原第三方技能
tools/sync.sh --rebuild  # 同上，但第三方技能全部重装一遍
```

脚本做了三件事：

1. `git pull` 档案仓库
2. 把 `skills/codex/` 下的自研技能复制到 `~/.codex/skills/`（`_shared` 是共享资源目录，也一并复制）
3. 调用 `tools/restore-skills.py`，按 `skills.agents.json` 索引把第三方技能从上游仓库拉回来

### 第三方技能是怎么找回来的

档案里只存了第三方技能的名字、描述、文件数和体积（`skills.agents.json`），源码不在仓库里。
`tools/restore-skills.py` 的还原流程：

1. 用 [skills.sh](https://skills.sh) 公共注册表按名字解析候选仓库（`owner/repo` + 技能路径）
2. 每个仓库只下载一次 tarball，在里面定位 `SKILL.md` 目录并安装
3. 名字对不上的，改用**描述精确匹配**再扫一遍候选仓库

安装目标同时写两处：`~/.codex/skills/`（Codex 直接可用）和 `~/.agents/skills/`（第三方技能原本的存放位置）。

> 少数技能是个人私有技能（索引里有、公开上游没有），脚本会列在最后的「仍缺失」里。
> 这些需要从私有仓库拉，把 `GITHUB_TOKEN` 环境变量设好再跑即可。

### 重新导出（本机 → 档案）

Windows 用原来的 PowerShell 版；Linux/macOS 用新增的 Python 版：

```bash
python3 tools/export-archive.py            # 采集 ~/.codex/skills 与 ~/.agents/skills，重建索引
python3 tools/export-archive.py --dry-run  # 只看会改什么，不落盘
```

脱敏规则与 PowerShell 版一致：64 位十六进制串、家庭设备技能的 `192.168.1.x`、配置里的密钥。
