---
name: 芝杜
description: >
  控制 Zidoo Z9 媒体播放器（192.168.1.<ZIDOO>）的 Skill。
  触发条件：用户说"芝杜"、"Zidoo"、"Z9"、"播放器"，或任何与芝杜控制相关的请求。
  自动记忆设备 IP（192.168.1.<ZIDOO>）和 HTTP 控制 API。
  
  支持功能：
  - 电源控制：PowerOn/PowerOff
  - 媒体播放：播放/暂停/停止/上下曲/截屏/录制
  - 音量控制：音量+/-、静音
  - 方向导航：上/下/左/右/OK/Back/Home/Menu
  - 数字键：0-9
  - 应用切换：电影/音乐/图片/文件
  - 海报墙浏览：所有电影列表、电影详情
  
  API 格式：HTTP GET + JSONP 请求，无需认证。
  基础 URL：http://192.168.1.<ZIDOO>:9529
---

# 芝杜控制 — Zidoo Z9

## 设备信息

- **型号**：Zidoo Z9
- **IP**：192.168.1.<ZIDOO>
- **协议**：HTTP GET + JSONP（callback=jsoncallback）
- **Web 入口**：http://192.168.1.<ZIDOO>:9528/ （海报墙）
- **控制 API 端口**：9529

## API 一览

### 遥控按键（HTTP JSONP）

| 功能 | URL |
|------|-----|
| 发送按键 | `GET /ZidooControlCenter/RemoteControl/sendkey?key=Key.{动作}&jsoncallback=cb` |

**常用 Key 列表：**

- **电源**：`Key.PowerOn`、`Key.PowerOff`
- **导航**：`Key.Up`、`Key.Down`、`Key.Left`、`Key.Right`、`Key.Ok`、`Key.Back`、`Key.Home`、`Key.Menu`、`Key.PopMenu`、`Key.Display`、`Key.Dash`
- **数字**：`Key.Number_0` 到 `Key.Number_9`
- **音量**：`Key.VolumeUp`、`Key.VolumeDown`、`Key.Mute`
- **媒体**：`Key.MediaPlay`、`Key.MediaPause`、`Key.MediaStop`、`Key.MediaNext`、`Key.MediaPrev`、`Key.Screenshot`、`Key.Record`
- **应用**：`Key.movie`、`Key.music`、`Key.photo`、`Key.file`、`Key.APP.Switch`

### 海报墙 API（GET）

| 功能 | URL |
|------|-----|
| 电影列表 | `GET /ZidooPoster/getVideoList?page=1&pagesize=50&type=1` |
| 电影详情 | `GET /Poster/v2/getPoster?id={id}&w=290&h=434` |
| 全部合集 | `GET /Poster/v2/getAggregations?type=1&start=0&count=50` |
| 海报图 | `GET /Poster/v2/getPoster?id={id}&w=290&h=434` |
| 背景图 | `GET /ZidooPoster/getFile/getBackdrop?id={id}&w=1080&h=720` |

### 系统 API

| 功能 | URL |
|------|-----|
| 设备密码 | `GET /ZidooControlCenter/getpassword` |
| 播放状态 | `GET /ZidooVideoPlay/getPlayStatus`（设备需播放中才有数据）|

## 执行流程

1. 用户发出控制请求（如"芝杜暂停"）
2. 组装 API URL：`http://192.168.1.<ZIDOO>:9529/ZidooControlCenter/RemoteControl/sendkey?key=Key.MediaPause&jsoncallback=cb`
3. 发送 GET 请求
4. 验证响应包含 `{"status":200}`
5. 报告结果给用户

## 状态字段说明

- API 成功响应：`{"status":200}`
- API 失败响应：`{"status":804,"msg":"Url error"}` 等错误码
- 海报列表包含：id, name, voteAverage, type, isBluRay, is3D, is4K, isHDR 等

## 注意事项

- 所有 API 请求必须带 `jsoncallback=xxx` 参数（JSONP 协议）
- 海报墙需登录后才能访问，控制 API 不需要登录
- Zidoo 控制 API 与 Web 海报墙在不同端口：控制=9529，Web=9528
