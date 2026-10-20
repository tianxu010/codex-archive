---
name: 功放
description: >
  控制 Yamaha TSR-700 AV 接收机的 Skill。
  触发条件：用户说"功放"、"AV功放"、"雅马哈功放"，或任何与功放控制相关的请求。
  自动记忆设备 IP（192.168.1.<YAMAHA>）和 API 端点（YamahaExtendedControl/v1）。
  
  支持功能：
  - 电源控制：开机、待机
  - 音量调节：绝对值、相对增减、静音
  - 输入源切换：HDMI 1~6、TV、AV1/2、AUX、USB、蓝牙
  - 音效场景切换：电影、游戏、音乐、立体声等
  - 状态查询：实时读取功放状态
  
  API 格式：GET 请求 + query 参数，无需认证。
  基础 URL：http://192.168.1.<YAMAHA>/YamahaExtendedControl/v1
---

# 功放控制 — Yamaha TSR-700

## 设备信息

- **型号**：Yamaha TSR-700
- **IP**：192.168.1.<YAMAHA>
- **协议**：YamahaExtendedControl API (HTTP GET)
- **状态端点**：/main/getStatus
- **控制端点前缀**：/main/setXXX

## API 一览

| 功能 | 端点 | 参数 |
|------|------|------|
| 获取状态 | GET /main/getStatus | - |
| 开机 | GET /main/setPower | power=on |
| 待机 | GET /main/setPower | power=standby |
| 音量调节 | GET /main/setVolume | volume=0~161 |
| 静音 | GET /main/setMute | enable=true/false |
| 输入切换 | GET /main/setInput | input=hdmi1/tv/av1/aux/usb/bluetooth... |
| 音效场景 | GET /main/setSoundProgram | program=movie/game/music/straight... |

## 执行流程

1. 用户发出控制请求（如"把功放音量调低"）
2. 组装 API URL：`http://192.168.1.<YAMAHA>/YamahaExtendedControl/v1/main/setVolume?volume=80`
3. 发送 GET 请求
4. 验证 response_code=0
5. 读取 /main/getStatus 确认最新状态
6. 向用户报告结果

## 状态字段说明

- volume: 0~161（161 为最大）
- actual_volume_db: 实际分贝值，如 -24.5 dB
- power: "on" 或 "standby"
- input: hdmi1~hdmi6, tv, av1, av2, aux, usb, bluetooth, ...
- mute: true/false
- sound_program: sci-fi, movie, game, music, straight, pure_direct, ...

## 注意事项

- 每次控制后等待 300ms 再查询状态
- 功放处于待机时部分命令可能失败（response_code 非 0）
- 如遇 400/500 错误，检查 response_code 并报告给用户
