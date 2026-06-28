# Link-to-viewstage

ViewStage 桌面应用的 Android 伴侣应用，提供无线遥控、文件传输和摄像头串流功能。

## 功能特性

- **设备发现** — 通过 UDP 组播自动发现局域网内的 ViewStage 桌面端（零配置）
- **遥控控制** — 支持翻页、标注、缩放、截图、镜像、黑板、撤销、设置等 14 种操作
- **文件上传** — 从手机选择图片或文档（PDF/DOC/DOCX）上传至桌面端
- **摄像头串流** — 将手机摄像头画面以 H.264 实时串流至桌面端（硬件编码）

## 技术栈

| 类别 | 技术 |
|---|---|
| 框架 | Flutter (Dart) |
| 状态管理 | Provider |
| 网络 | HTTP REST API + WebSocket + UDP 组播 |
| 视频编码 | Android Camera2 API + MediaCodec H.264 |
| 原生代码 | Kotlin (Android) |

## 环境要求

- Flutter SDK >= 3.44.0（stable channel）
- Dart SDK >= 3.12.2
- Android SDK (compileSdk 36, Java 17)
- 手机与 ViewStage 桌面端处于同一局域网

## 快速开始

```bash
# 克隆仓库
git clone <repo-url>
cd Link-to-viewstage

# 安装依赖
flutter pub get

# 运行应用
flutter run

# 构建 APK
flutter build apk
```

## 使用方法

1. 在 PC 上打开 ViewStage 应用，进入「手机互联」面板
2. 在手机上打开 Link-to-viewstage 应用
3. 应用会自动发现局域网中的桌面端设备，点击连接
4. 或选择手动输入模式，填写 IP、端口和令牌

## 项目结构

```
lib/
├── main.dart                 # 应用入口、主题、导航
├── models/
│   └── connection_info.dart  # 连接信息数据模型
├── screens/
│   ├── connect_screen.dart   # 设备发现与连接界面
│   ├── remote_screen.dart    # 遥控器界面
│   └── upload_page.dart      # 文件上传界面
├── services/
│   ├── api_service.dart      # HTTP REST API 客户端
│   ├── camera_service.dart   # 摄像头串流服务
│   ├── connection_manager.dart # 连接状态管理
│   ├── discovery_service.dart  # UDP 设备发现
│   └── upload_service.dart   # 文件上传服务
└── widgets/
    ├── control_button.dart   # 动画遥控按钮
    ├── manual_input_form.dart # 手动输入表单
    └── status_banner.dart    # 连接状态横幅

android/app/src/main/kotlin/com/viewstage/viewstage_phone/
├── MainActivity.kt           # 主 Activity（组播锁、文件选择）
├── H264Encoder.kt            # H.264 硬件编码器
└── Fmp4Muxer.kt              # fMP4 封装器
```

## 协议说明

- **设备发现**：UDP 组播地址 `224.0.0.167:53317`
- **控制命令**：HTTP REST API（`/connect`、`/control/{action}`、`/heartbeat`、`/disconnect`）
- **文件上传**：HTTP Multipart POST（`/file/upload`，最大 50MB）
- **摄像头串流**：WebSocket + fMP4 封装的 H.264 视频流
- **认证方式**：桌面端显示 8 位令牌，手机端输入后换取 Session ID

## 权限说明

应用需要以下 Android 权限：

| 权限 | 用途 |
|---|---|
| `INTERNET` | 网络通信 |
| `ACCESS_NETWORK_STATE` | 检查网络状态 |
| `ACCESS_WIFI_STATE` | 获取 WiFi 信息 |
| `CHANGE_WIFI_MULTICAST_STATE` | UDP 组播设备发现 |
| `CAMERA` | 摄像头串流 |
| `RECORD_AUDIO` | 摄像头串流（音频） |

## 许可证

[Apache License 2.0](LICENSE)
