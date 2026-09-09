# 研序 YanXu

<p align="center">
  <img src="Resources/AppIcon-source.png" width="148" alt="研序图标">
</p>

<p align="center">
  <strong>把科研计划、时间投入与论文 DDL，收进一张安静好用的工作台。</strong>
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-111827?logo=apple&logoColor=white">
  <img alt="SwiftUI" src="https://img.shields.io/badge/SwiftUI-native-2563EB?logo=swift&logoColor=white">
  <img alt="Local first" src="https://img.shields.io/badge/data-local--first-10B981">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-8B5CF6"></a>
</p>

研序是一款面向博士生与科研工作者的原生 macOS 效率管理工具。它把任务、周/月日历、科研时长、习惯与论文 DDL 放在同一个全屏页面中，并通过桌面小组件和顶部灵动岛减少窗口切换。

应用不需要账号，没有自建服务器，也不收集遥测数据。数据默认只保存在本机；如果希望在 iPhone 查看日程，可以选择单向同步到自己的 iCloud 日历。

## 界面预览

![研序工作台总览](docs/images/workspace-overview.png)

## 灵动岛演示

https://github.com/user-attachments/assets/8c54cb19-5008-457c-a7a7-d6eda9e11995

收起时，灵动岛展示今日科研时长与任务完成情况；展开后可以直接浏览本周计划、勾选任务和快速新增任务。

## 为什么做研序

研序最初来自一个很具体的博士生日常：普通待办工具可以记录任务，却很难在一个页面同时回答下面这些问题：

- 今天要做什么，未来一周有哪些课程、组会和实验安排？
- 距离论文 DDL 还有多久？
- 这周读了几次论文，习惯目标是否完成？
- 今天在实验室投入了多长时间，中途离开如何记录？
- 全屏工作时，能否一眼看完所有信息，尽量少切换页面？

因此，研序不追求复杂的团队协作和项目管理，而是聚焦个人科研中高频、长期存在的几件事：计划、执行、投入时间、习惯和截止日期。

## 一张工作台完成主要操作

| 分区 | 主要用途 |
| --- | --- |
| 顶部数据看板 | 查看本周科研时长、任务完成情况与习惯进度 |
| 左侧“今天” | 汇总逾期、今天、待安排和已完成任务，支持自然语言快速添加 |
| 中间日历 | 使用周视图或月视图浏览、拖放与安排任务，不使用时间轴 |
| 待安排抽屉 | 保存还没有决定日期的任务，之后再拖到日历中 |
| 右侧科研信息 | 完成实验室到达/离开打卡、习惯打卡，查看个人和 CCF A DDL |

完整界面说明请查看 [使用指南](docs/USER_GUIDE.md)。

## 核心功能

### 任务与日历

- 支持待安排、某一天、具体时间与日期范围四种计划方式。
- 支持日常任务、课程、组会、实验安排和跨多日可完成事项。
- 任务可完成、编辑、删除、延后一天，也可以拖动到日历重新安排。
- 支持每天、每周和每月重复。
- 全天任务默认当天 09:00 提醒，固定时间任务默认提前 10 分钟提醒。

### 中文快速输入

任务输入框会自动识别常见中文日期与时间。没有写日期或时间时，任务进入“待安排”。

| 输入示例 | 创建结果 |
| --- | --- |
| `整理实验数据` | 进入待安排 |
| `下午2点整理报销材料` | 今天 14:00 |
| `今天整理实验数据` | 今天的全天任务 |
| `明天下午2点开会` | 明天 14:00 |
| `下周五下午2点开组会` | 下周五 14:00 |

### 科研时长与习惯

- 每天可以多次记录到达和离开实验室，自动累计科研时长。
- 支持中途离开后再次打卡。
- 单次连续科研超过 8 小时时会提示检查，并允许手动修正离开时间。
- 习惯按周设定目标，同一天可以多次打卡，也可以撤销误操作。

### DDL 与手机查看

- 个人 DDL 简洁展示剩余天数，不额外提醒。
- 自动读取 [CCFDDL](https://ccfddl.com/) 人工智能类别中的 CCF A 会议。
- 可将任务和个人 DDL 自动增量同步到 Apple 日历，在 iPhone 上查看。

### 桌面小组件

研序提供三种 macOS 桌面小组件：今天计划、本周计划和最近 DDL。

### 顶部灵动岛

- **收起状态：** 展示今日科研时长和今日任务完成数。
- **展开状态：** 展示本周七日计划，可直接勾选任务。
- **快速新增：** 在极简文本框输入任务并按回车，使用与主 App 相同的中文日期解析规则。
- **跳转 App：** 点击顶部日期范围或任意一天的日期，直接打开研序主窗口。
- **外部收起：** 点击灵动岛之外的任意位置，或点击向上箭头即可收起。
- **随时关闭：** 展开后可彻底关闭灵动岛，并可从研序顶部随时重新显示。
- **主题模式：** 支持白天与黑夜模式，并自动记住选择。
- **自由定位：** 支持跨显示器拖动，自动保存目标显示器和位置。
- **安全回位：** 右键选择“回到屏幕顶部”，可恢复默认位置。
- **不挡操作：** 灵动岛轮廓外的透明区域不会拦截鼠标点击。

灵动岛的顶部悬浮交互受 [CodexIsland](https://github.com/sk-yan/codex-island/tree/feature/remote-claude-life-ledger) 启发；研序使用自己的任务数据模型、周计划和科研统计重新实现。

## 安装与构建

### 环境要求

- macOS 14 或更高版本；
- Xcode 或 Apple Command Line Tools；
- Swift 6 工具链。

### 从源码运行

```bash
git clone https://github.com/roseLuos/YanXu.git
cd YanXu
./scripts/build-app.sh
open dist/YanXu.app
```

`build-app.sh` 会生成包含 WidgetKit 扩展、经过本地临时签名的 `dist/YanXu.app`。若要长期使用并让系统稳定识别小组件，建议把构建结果复制到“应用程序”目录：

```bash
ditto dist/YanXu.app /Applications/研序.app
open /Applications/研序.app
```

首次使用提醒或 Apple 日历同步时，macOS 会请求相应权限。桌面空白处右键选择“编辑小组件”，搜索“研序”即可添加。

> 当前开源构建使用本地临时签名，不是通过 Apple Developer ID 公证的发行版。首次在其他 Mac 打开时，可能需要在“系统设置 → 隐私与安全性”中允许运行。

## 演示数据

调试构建可以使用一组不包含真实个人信息的演示数据：

```bash
YANXU_DATA_PATH=/tmp/yanxu-demo/data.json \
YANXU_SEED_DEMO=1 \
swift run YanXu
```

演示数据会写入指定的隔离文件，不会修改正式数据。

## 数据与隐私

默认数据文件位于：

```text
~/Library/Application Support/YanXu/data.json
```

- 没有研序服务器，也没有账号系统、遥测或第三方分析 SDK。
- 任务、习惯和打卡记录默认只保存在用户电脑上。
- CCF A 截止日期从 CCFDDL 的公开 iCalendar 数据读取。
- Apple 日历同步只写入用户自己的“研序”日历。
- 删除 App 不会自动删除数据文件或已经同步的日历事项。

## 技术实现

- **界面：** SwiftUI；
- **灵动岛窗口：** AppKit + SwiftUI；
- **桌面小组件：** WidgetKit；
- **手机日程同步：** EventKit / Apple 日历；
- **本地存储：** JSON；
- **依赖：** Swift Package Manager，无第三方运行时依赖。

```text
.
├── Sources/
│   ├── YanXuApp/          # macOS 主应用、灵动岛与业务状态
│   ├── YanXuCore/         # 数据模型、日期区间、解析与小组件快照
│   ├── YanXuWidgets/      # WidgetKit 扩展
│   └── YanXuSelfTest/     # 核心逻辑自检
├── Resources/             # 图标、Info.plist 与小组件配置
├── docs/                  # 使用指南、截图和演示媒体
└── scripts/               # 构建脚本
```

## 自检

```bash
swift run YanXuSelfTest
```

自检覆盖任务日期、中文快速输入、重复任务、多段科研打卡、个人 DDL 和 CCFDDL 时间换算。

## 参与贡献

欢迎提交 Issue 和 Pull Request。开始前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

如果你正在读博、做科研，或者有相似的个人工作流，也欢迎分享真实使用场景。研序更希望从具体问题出发，而不是不断堆叠功能。

## 致谢

- [CCFDDL](https://ccfddl.com/) 提供公开的会议截止日期数据；
- [CodexIsland](https://github.com/sk-yan/codex-island/tree/feature/remote-claude-life-ledger) 为顶部悬浮交互与演示方式提供灵感。

## 许可证

本项目使用 [MIT License](LICENSE)。
