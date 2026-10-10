# 研序 iOS 源码

这是一套为 iPhone 准备的原生 SwiftUI 界面源码。它刻意与 macOS 版共用
`Sources/YanXuCore` 的数据模型和自然语言任务解析器，避免两端业务规则分叉。

## 当前状态

- 已提供可直接打开的 `YanXuIOS.xcodeproj`，包含 iPhone App 与 Widget Extension。
- 已实现今天、周计划、科研打卡、习惯打卡、个人里程碑等移动端界面。
- iPhone 与 Mac 可通过同一局域网、6 位配对码和 Bonjour 自动发现进行双向数据合并。
- 自动发现失败时，可以填写 Mac 设置页显示的备用地址与固定端口 `40567`。
- iOS 小组件可配置 Mac 地址和配对码，从局域网读取研序数据。

## 在 Xcode 中运行

1. 使用 Xcode 打开 `iOS/YanXuIOS.xcodeproj`。
2. 选择 `YanXuIOS` scheme 和目标 iPhone 或模拟器。
3. 真机运行时，在 Signing & Capabilities 中选择自己的开发团队。
4. 首次局域网同步时，允许研序访问本地网络。

本地数据文件名为 `yanxu-ios-data.json`。同步时两端按记录 ID 合并任务、习惯、科研时段与完成状态，Mac 仍是主要数据入口。
