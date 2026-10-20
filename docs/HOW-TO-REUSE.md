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
