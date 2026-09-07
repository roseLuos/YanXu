# 研序 YanXu

<p align="center">
  <img src="Resources/AppIcon-source.png" width="128" alt="研序图标">
</p>

<p align="center">
  一款为科研工作设计的简洁原生 macOS 效率管理工具。
</p>

研序把任务、周/月日历、科研时长、习惯和论文 DDL 放在同一个全屏工作台中。应用完全本地运行，不需要账号，不收集遥测数据；如需在 iPhone 查看日程，可选择单向同步到自己的 iCloud 日历。

![Apple 日历同步界面](calendar-sync-preview.png)

## 功能

- 一页总览：顶部数据看板、今天、周/月日历以及科研辅助信息
- 任务计划：待安排、某天、具体时间和日期范围
- 快速输入：识别“今天”“明天”“下周五”“9 月 10 日”“下午 2 点”等中文日期时间
- 任务操作：完成、编辑、删除、延后一天以及拖拽安排
- 重复任务：每天、每周和每月
- 科研打卡：每天可多次到达与离开，自动统计科研时长
- 习惯打卡：每周目标、同一天多次记录以及撤销
- DDL：个人 DDL，以及来自 [CCFDDL](https://ccfddl.com/) 的人工智能类 CCF A 会议
- 系统提醒：全天任务当天 09:00、固定任务提前 10 分钟
- Apple 日历：启动和日程变化后自动增量同步
- 桌面小组件：今天计划、本周计划和最近 DDL

## 快速输入规则

| 输入示例 | 创建结果 |
| --- | --- |
| `整理实验数据` | 进入待安排 |
| `下午2点整理报销材料` | 今天 14:00 |
| `今天整理实验数据` | 今天的全天任务 |
| `明天下午2点开会` | 明天 14:00 |
| `下周五下午2点开组会` | 下周五 14:00 |

## 环境要求

- macOS 14 或更高版本
- Swift 6 工具链
- Xcode 或 Apple Command Line Tools

## 构建

克隆仓库后，在项目根目录执行：

```bash
./scripts/build-app.sh
open dist/YanXu.app
```

脚本会生成包含 WidgetKit 扩展并经过本地临时签名的 `dist/YanXu.app`。你也可以直接运行不含完整应用包安装流程的开发版本：

```bash
swift run YanXu
```

首次使用提醒或 Apple 日历同步时，macOS 会请求相应权限。桌面空白处右键选择“编辑小组件”，搜索“研序”，即可添加小组件。

> 分发自己构建的版本前，请将 `Resources/Info.plist`、`Resources/YanXuWidgets-Info.plist` 中的 Bundle Identifier，以及相关签名配置改为你自己的标识。

## 演示数据

调试构建支持合并一组不包含真实个人信息的演示数据：

```bash
YANXU_SEED_DEMO=1 swift run YanXu
```

演示数据使用固定标识合并，不会自动清空已有内容。请勿在自己的正式数据环境中运行此命令。

## 数据与隐私

用户数据默认保存在：

```text
~/Library/Application Support/YanXu/data.json
```

- 数据不会上传到研序服务器，因为项目没有服务器。
- CCF A 截止日期从 CCFDDL 的公开 iCalendar 数据读取。
- Apple 日历同步仅写入用户自己的“研序”iCloud 日历。
- 删除应用不会自动删除数据文件或已同步的日历事项。

## 自检

```bash
swift run YanXuSelfTest
```

自检覆盖任务日期范围、中文快速输入、重复任务、多段科研打卡、个人 DDL 和 CCFDDL 时间换算。

## 参与贡献

欢迎提交 Issue 和 Pull Request。开始前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

本项目使用 [MIT License](LICENSE)。
