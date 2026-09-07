# 参与贡献

感谢你愿意改进研序。

## 开始开发

1. Fork 并克隆仓库。
2. 确保系统为 macOS 14 或更高版本，并安装 Swift 6 工具链。
3. 运行 `swift run YanXuSelfTest` 验证核心逻辑。
4. 运行 `./scripts/build-app.sh` 构建完整应用包。

## 提交建议

- 一个 Pull Request 尽量只解决一个明确问题。
- 修改任务解析、日期计算或数据模型时，请同步补充 `YanXuSelfTest`。
- 不要提交 `~/Library/Application Support/YanXu` 中的真实用户数据。
- 涉及界面修改时，建议附上修改前后的截图。
- 提交前确认完整应用能够构建，并说明你验证过的 macOS 版本。

## 隐私与安全

Issue、日志和截图中可能包含任务名称、DDL、实验室地点或日历信息。提交前请先移除真实个人数据。
