---
name: 扫地机器人
description: >
  控制 Midea M7 扫地机器人（192.168.1.<ROBOT>）的 Skill。
  触发条件：用户说"扫地机器人"、"美的M7"、"M7"、"启动扫地"、"停止扫地"等任何扫地机相关请求。
  
  设备信息：
  - 设备ID: <DEVICE_ID>
  - IP: 192.168.1.<ROBOT>
  - MAC: 54:b8:74:b9:1e:60
  - 协议：Midea Aurora v3 LAN protocol
  - 发现端口: UDP 6445
  - 控制端口: TCP 6444
  
  本地密钥：<LOCAL_KEY_32HEX>
  
  注意：扫地机在待机时（充电模式）会关闭网络服务，
  必须先物理唤醒（按电源键或清洁键），才能执行控制命令。
---

# 美的 M7 扫地机器人控制

## 设备信息

| 项目 | 值 |
|------|-----|
| 品牌 | 美的 Midea |
| 型号 | M7 |
| 设备 ID | <DEVICE_ID> |
| SN | B8511000VR5PR42244100516DDD |
| IP 地址 | 192.168.1.<ROBOT> |
| MAC | 54:b8:74:b9:1e:60 |
| WiFi SSID | midea_b8_0516 |

## 协议信息

- **API**: Midea Aurora v3 / MSmart LAN
- **发现端口**: UDP 6445（广播发现）
- **控制端口**: TCP 6444
- **加密**: AES-CBC (本地密钥)

## API 操作流程

### 步骤1：发现设备
```python
# UDP 广播到 6445 端口获取设备信息和 token
import socket
from msmart.const import BROADCAST_MSG

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
sock.settimeout(3)
sock.sendto(bytes(BROADCAST_MSG), ("192.168.1.<ROBOT>", 6445))
data, addr = sock.recvfrom(4096)
```

### 步骤2：解密响应获取 token
- 加密数据位置: bytes 40 到 -16
- 解密密钥: local_key（32字节十六进制）
- Token 通常在前 32 字节

### 步骤3：建立 LAN 连接
```python
from msmart.lan import lan
l = lan("192.168.1.<ROBOT>", "<DEVICE_ID>", 6444)
token = bytearray.fromhex("提取的token")
key = bytearray.fromhex("<LOCAL_KEY_32HEX>")
l.authenticate(token, key)
```

### 步骤4：发送控制命令
```python
# 命令通过 appliance_transparent_send 发送
# 0x0001 = 启动清洁
# 0x0002 = 暂停
# 0x0003 = 继续
# 0x0004 = 回充电桩
# 等等
l.appliance_transparent_send(0x0001, b"")
```

## 注意事项

⚠️ **必须先物理唤醒设备！** 美的 M7 在以下情况会关闭网络服务：
- 充电待机时
- 长时间未活动时
- 电量过低时

用户需要按下扫地机器人上的电源键或清洁键唤醒设备，
唤醒后约10秒内网络服务会激活。

## 已发现的其他 Midea 设备

| IP | 设备 ID | 设备类型 |
|----|---------|---------|
| 192.168.1.<ROBOT_GATEWAY> | 3a06040000bf | 未知（可能是冰箱、洗衣机等） |

## 保存的凭据

| 项目 | 值 |
|------|-----|
| local_key | <LOCAL_KEY_32HEX> |
| uid | <DEVICE_UID_32HEX> |
