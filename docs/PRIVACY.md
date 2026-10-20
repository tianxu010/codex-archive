# 脱敏说明

本档案从本地 `~/.codex` 导出，用于公开展示个人能力配置。导出流程中**主动移除**了以下内容。

## 已脱敏项对照

| 占位符 | 原内容类型 | 出现位置 |
| --- | --- | --- |
| `<LOCAL_KEY_32HEX>` | 扫地机器人 Aurora 协议本地解密密钥（32 字节十六进制） | `skills/codex/扫地机器人/SKILL.md` |
| `<DEVICE_UID_32HEX>` | 扫地机器人设备 UID | `skills/codex/扫地机器人/SKILL.md` |
| `<DEVICE_ID>` | 扫地机器人设备 ID | `skills/codex/扫地机器人/SKILL.md` |
| `192.168.1.<YAMAHA>` | 功放内网地址 | `skills/codex/功放/SKILL.md` |
| `192.168.1.<ZIDOO>` | 芝杜播放器内网地址 | `skills/codex/芝杜/SKILL.md` |
| `192.168.1.<ROBOT>` | 扫地机器人内网地址 | `skills/codex/扫地机器人/SKILL.md` |
| `192.168.1.<ROBOT_GATEWAY>` | 扫地机器人网关地址 | `skills/codex/扫地机器人/SKILL.md` |
| `***REDACTED***` | 配置中的 API Key / Bearer Token | `config/config.redacted.toml` |

## 未脱敏项（经确认安全）

以下内容形似密钥但经核查为公开校验值，予以保留：

- `cloudflare-deploy/references/**` 中的 MD5 值与示例网段（`10.0.0.0`、`192.168.0.0` 等）——来自上游文档的示例与校验和。
- `codex-windows-fast-patch/**` 中的 SHA-256 长串——是公开产物的二进制哈希，用于补丁版本校验。
- 第三方技能文档中出现的 `ghp_`、`api_key` 等字样——均为文档中的占位说明与变量名。

## 使用前需填回的值

若要在自己的局域网中使用家庭设备技能，请填回：

```powershell
# skills/codex/扫地机器人/SKILL.md
$deviceIp    = '192.168.1.<ROBOT>'          # 替换为实际地址
$deviceId    = '<DEVICE_ID>'                 # 替换为设备 ID
$localKey    = '<LOCAL_KEY_32HEX>'           # 替换为 32 字节十六进制密钥
```

其余两个设备技能只需把 `192.168.1.<...>` 换成实际内网地址。

---

**若你曾经把本仓库设为公开**：请注意上述密钥曾在你的**本地**文件中明文存在，
建议在设备管理端轮换一次扫地机器人本地密钥。
