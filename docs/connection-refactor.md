# ViewStage 手机端连接模块改动说明

## 改动背景

原方案使用 QR 码扫描连接，存在以下问题：
- 依赖摄像头权限，隐私敏感
- 扫码体验不够流畅
- 需要用户手动对准二维码

新方案参考 [闪电藤](https://github.com/cmlanche/lightningvine-docs) 的局域网发现算法，采用 **UDP 多播自动发现**，实现零操作连接。

---

## 改动内容

### 1. 移除 QR 码扫描

**删除文件依赖：**
- 移除 `mobile_scanner` 包
- 移除 `flutter_scankit` 包（之前已替换）
- 移除 `AndroidManifest.xml` 中的摄像头权限

**删除代码：**
- `connect_screen.dart` 中的 `ScanKitWidget` / `MobileScanner` 组件
- 扫码结果处理逻辑 `_handleScanResult`
- 扫码冷却机制 `_scanCooldown`

### 2. 新增 UDP 多播发现服务

**新增文件：** `lib/services/discovery_service.dart`

```dart
class DiscoveryService {
  // 多播地址：224.0.0.167（LocalSend 协议默认）
  // 多播端口：53317
  static const String _multicastGroup = '224.0.0.167';
  static const int _multicastPort = 53317;
}
```

**核心功能：**
- 监听 UDP 多播消息
- 解析 JSON 格式的设备广播
- 维护已发现设备列表（自动清理超时设备）
- 通过 `Stream` 实时推送设备更新

**广播消息格式（预期桌面端发送）：**
```json
{
  "alias": "ViewStage",
  "version": "2.0",
  "deviceModel": "Windows PC",
  "deviceType": "desktop",
  "fingerprint": "random-string",
  "port": 53317,
  "protocol": "http",
  "announce": true,
  "token": "ABCD1234"
}
```

### 3. 重写连接界面

**改动文件：** `lib/screens/connect_screen.dart`

**新 UI 结构：**
```
┌─────────────────────────────────┐
│          连接 ViewStage         │  ← AppBar
├─────────────────────────────────┤
│                                 │
│    🖥 ViewStage (Windows PC)    │  ← 设备卡片
│    192.168.1.100:53317          │
│                        [连接]   │
│                                 │
│    📱 ViewStage (MacBook)       │
│    192.168.1.101:53317          │
│                        [连接]   │
│                                 │
├─────────────────────────────────┤
│  正在搜索 ViewStage 电脑...     │  ← 空状态
│  请确保电脑端已打开「手机互联」  │
└─────────────────────────────────┘
```

**交互流程：**
1. 打开 app → 自动开始监听多播
2. 发现设备 → 实时显示在列表中
3. 点击连接 → 使用广播中的 token 自动连接
4. 连接成功 → 跳转遥控器界面

### 4. 权限变更

**移除：**
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.autofocus" />
```

**新增：**
```xml
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
```

---

## 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `pubspec.yaml` | 修改 | 移除 mobile_scanner 依赖 |
| `android/app/src/main/AndroidManifest.xml` | 修改 | 替换权限配置 |
| `lib/services/discovery_service.dart` | 新增 | UDP 多播发现服务 |
| `lib/screens/connect_screen.dart` | 重写 | 设备列表 UI |
| `lib/widgets/manual_input_form.dart` | 保留 | 手动输入作为备选方案 |

---

## 待桌面端配合

手机端已完成，桌面端需要实现 **UDP 多播广播**：

```rust
// connect.rs 中添加
use std::net::UdpSocket;

fn start_multicast_broadcast(ip: &str, port: u16, token: &str) {
    let socket = UdpSocket::bind("0.0.0.0:0").unwrap();
    socket.join_multicast_v4(
        &Ipv4Addr::new(224, 0, 0, 167),
        &Ipv4Addr::UNSPECIFIED
    ).unwrap();

    let message = serde_json::json!({
        "alias": "ViewStage",
        "version": "2.0",
        "deviceModel": "Windows",
        "deviceType": "desktop",
        "fingerprint": uuid::Uuid::new_v4().to_string(),
        "port": port,
        "protocol": "http",
        "announce": true,
        "token": token
    });

    loop {
        socket.send_to(
            message.to_string().as_bytes(),
            "224.0.0.167:53317"
        ).unwrap();
        std::thread::sleep(Duration::from_secs(5));
    }
}
```

---

## 测试方法

1. 启动桌面端 ViewStage，打开「手机互联」面板
2. 手机连接同一 WiFi
3. 打开手机 app，应自动显示桌面端设备
4. 点击设备卡片上的「连接」按钮
5. 连接成功后跳转遥控器界面

---

## 优势对比

| 特性 | QR 码方案 | UDP 多播方案 |
|------|----------|--------------|
| 操作步骤 | 扫码 → 等待 | 打开即连 |
| 摄像头权限 | 需要 | 不需要 |
| 连接速度 | 取决于扫码 | 1-2 秒 |
| 多设备支持 | 一次一个 | 同时显示多个 |
| 用户体验 | 需要对准 | 全自动 |
