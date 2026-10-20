# Codex 能力档案

个人 Codex 工作台的能力存档：自定义技能、配置快照与自动化脚本，按领域整理，可直接复用。

> 本仓库由本地导出脚本生成，内容反映导出当时的状态。个人凭据与内网地址已在导出前脱敏，
> 详见 [`docs/PRIVACY.md`](docs/PRIVACY.md)。

---

## 概览

| 项目 | 数量 | 说明 |
| --- | ---: | --- |
| 自研技能 | **22** | `skills/codex/`，完整源码随仓库归档 |
| 已安装第三方技能 | 135 | 仅索引于 `skills.agents.json`，由安装器从上游还原 |
| 配置快照 | 1 | `config/config.redacted.toml`，密钥已脱敏 |
| 自动化脚本 | 41+ | 主要来自 Windows 平台维护技能 |

导出时间：2026-10-20

---

## 能力地图

### 家庭 / 本地设备自动化

把常家电装进对话里，用自然语言直接控制。

| 技能 | 设备 | 控制方式 |
| --- | --- | --- |
| `功放` | Yamaha TSR-700 功放 | YamahaExtendedControl HTTP API |
| `芝杜` | Zidoo Z9 媒体播放器 | HTTP 控制 API |
| `扫地机器人` | Midea M7 | Aurora v3 LAN 协议（UDP 发现 + TCP 控制） |

> 设备地址、ID 与本地密钥已替换为占位符，填回自己的值即可使用。

### 代码质量与架构审计

基于十二本经典工程著作的六维检查套件，覆盖架构、债务、评审、测试与综合体检。

| 技能 | 作用 |
| --- | --- |
| `brooks-audit` | 绘制模块依赖图，检查分层完整性，标记结构腐化 |
| `brooks-debt` | 识别并分级技术债，产出重构路线图 |
| `brooks-review` | PR 代码评审，输出「症状 → 根源 → 后果 → 补救」结论 |
| `brooks-test` | 测试质量诊断：脆弱性、mock 滥用、覆盖假象、慢测试 |
| `brooks-health` | 四维综合健康评分看板 |
| `brooks-sweep` | 全量扫描并自动应用安全修复 |

### GitHub 协作

| 技能 | 作用 |
| --- | --- |
| `gh-fix-ci` | 定位并修复 GitHub Actions 失败任务，附带最小修复方案与审批门 |
| `gh-address-comments` | 用 `gh` 处理 PR 审查意见，先校验登录态再操作 |

### 浏览器与网页自动化

| 技能 | 作用 |
| --- | --- |
| `playwright` | 终端驱动的真实浏览器自动化：导航、填表、截图、数据提取、UI 调试 |
| `browser-automation` | OpenClaw 浏览器工具的多步流程编排，含登录态与标签管理 |
| `canvas` | 向 OpenClaw 节点画布推送 HTML，支持导航、求值与快照 |

### 部署与云

| 技能 | 作用 |
| --- | --- |
| `cloudflare-deploy` | Workers / Pages 及周边平台部署，**312 个文件**的完整参考库 |

### 设计协作

| 技能 | 作用 |
| --- | --- |
| `figma` | 通过 Figma MCP 取设计上下文、截图、变量与素材，并翻译为生产代码 |
| `xhs-markdown-card-collab` | 把 Markdown 转成小红书图文卡片，含封面规划、风格方向与视觉走查 |

### 通讯平台

| 技能 | 作用 |
| --- | --- |
| `slack` | Slack 消息读写、表情回应、置顶、线程、检索、成员管理 |
| `discord` | Discord 同类能力，含投票、媒体与组件消息 |

### 平台维护与工程化

| 技能 | 作用 |
| --- | --- |
| `codex-windows-fast-patch` | Windows Codex Desktop 升级后修复被 Statsig 隐藏的自定义模型、Fast Mode、Plugins、Goal 等开关，**41 个文件** |
| `codebase-migrate` | 大规模代码迁移与多文件重构，用 Composio CLI 协调工单、分批 PR 与 CI 验证 |

---

## 目录结构

```
.
├── README.md                      # 本文件：能力档案主页
├── INVENTORY.md                   # 技能清单表（含文件数与体积）
├── skills.codex.json              # 自研技能结构化元数据
├── skills.agents.json             # 第三方技能索引
├── config/
│   └── config.redacted.toml       # 配置快照（密钥已脱敏）
├── docs/
│   ├── PRIVACY.md                 # 脱敏说明与占位符对照
│   └── HOW-TO-REUSE.md            # 在新机器上恢复这些技能
├── skills/codex/                  # 22 个自研技能完整源码
└── tools/
    └── export-archive.ps1         # 重新导出本档案的脚本
```

---

## 重新导出

在原机器上运行：

```powershell
pwsh tools/export-archive.ps1
```

脚本会重新采集技能目录、重建元数据与清单，并对敏感值重新脱敏。

---

## 许可

个人学习与自用存档。第三方技能各自遵循其上游许可。
