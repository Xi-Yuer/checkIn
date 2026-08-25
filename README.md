<div align="center">

| 主界面 | 任务列表 | 任务详情 | 统计数据 | 提醒设置 |
|:---:|:---:|:---:|:---:|:---:|
| ![主界面](https://github.com/user-attachments/assets/b3d27b03-c921-4ec0-9c53-42f533302ead) | ![任务列表](https://github.com/user-attachments/assets/d4ff2674-ccb7-44e4-82f4-7a92b6b8a191) | ![任务详情](https://github.com/user-attachments/assets/ad37d521-b1b0-43b4-9c50-914799b3f34d) | ![统计数据](https://github.com/user-attachments/assets/5cb0b754-7b90-4411-8387-99c47fd53f36) | ![提醒设置](https://github.com/user-attachments/assets/99f96be8-0a99-469a-9bd3-63b3fe35a7c9) |

</div>

# 打卡小星球

一款面向 iOS 16+ 的本地优先习惯打卡应用。任务、打卡历史和统计只保存在设备上；桌面小组件通过 App Group 中的轻量 JSON 快照读取今日状态。

## 技术基线

- SwiftUI、Core Data、Swift Charts
- UserNotifications、WidgetKit、AppIntents
- iPhone 与 iPad，简体中文，Light/Dark Mode
- App：`com.xiaoyuer.checkIn`
- Widget：`com.xiaoyuer.checkIn.widget`
- App Group：`group.com.xiaoyuer.checkIn`
- URL Scheme：`checkin://today`、`checkin://task/<UUID>`

## 本地运行

1. 使用 Xcode 26.3 或兼容版本打开 `checkIn.xcodeproj`。
2. 在 App 与 Widget target 的 Signing & Capabilities 中确认同一开发团队，并在 Apple Developer Portal 注册上面的 App Group。
3. 选择 `checkIn` shared scheme 和 iOS 16+ 模拟器或设备运行。

命令行构建：

```sh
xcodebuild -project checkIn.xcodeproj \
  -scheme checkIn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  build
```

运行测试：

```sh
xcodebuild -project checkIn.xcodeproj \
  -scheme checkIn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test
```

## 数据与隐私

- 不包含账号、云同步、广告、分析 SDK 或业务网络请求。
- Core Data 主库位于 App 的 Application Support，不向 Widget 暴露。
- Widget 只读取 `widget_snapshot_v1.json`；快照是派生数据，失败不会回滚主数据。
- 任务标题和备注不会写入持久日志。
- 通知权限只在用户首次启用任务提醒时请求。

## 插画资产

项目支持用透明 PNG 替换原生 `MascotView`。生成资产时只从本机环境变量读取 `OPENAI_API_KEY`，不要将密钥写入源码、脚本、配置文件或聊天记录。
