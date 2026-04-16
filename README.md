# ZhihuFunds iOS

一个从零搭建的 **iOS 基金自选 / 持仓跟踪 App**，用于把 `x2rr/funds` 浏览器插件的核心体验迁移到原生移动端。

## 当前版本能力

- 基金自选列表与持仓管理
- 东方财富接口实时拉取基金净值 / 指数数据
- 本地保存持仓份额、成本价、备注、置顶状态
- 资产概览：总成本、市值、浮盈、当日变化
- 基金搜索与一键加入自选
- 单基金详情：净值曲线、基础信息、持仓编辑
- 主题切换：系统 / 浅色 / 深色
- GitHub Actions 自动构建 iOS Simulator `.app.zip`
- Tag 推送后自动创建 GitHub Release 并附带构建产物

## 技术栈

- **SwiftUI**：原生界面开发
- **Swift Concurrency**：异步网络请求与刷新
- **XcodeGen**：使用 `project.yml` 生成 Xcode 工程
- **GitHub Actions**：macOS runner 自动编译与发布 Release

## 项目结构

```text
.
├─ project.yml                     # XcodeGen 工程定义
├─ .github/workflows/build.yml     # 自动构建/发布流水线
├─ scripts/package_release.sh      # 将编译产物打包为 zip
├─ src/core                        # 模型、网络、存储、ViewModel
└─ src/zhihu                       # SwiftUI App 与页面
```

## 本地开发

### 1. 生成 Xcode 工程

```bash
brew install xcodegen
xcodegen generate
```

### 2. 用 Xcode 打开并运行

```bash
open ZhihuFunds.xcodeproj
```

默认会加载一组示例基金，并在首次打开时自动刷新行情。

## GitHub Actions 行为

### Push 到 `main`
- 自动生成 Xcode 工程
- 构建 iOS Simulator 版本
- 上传 `ZhihuFunds.app.zip` 作为 Actions artifact

### Push Tag（如 `v1.0.0`）
- 自动执行构建
- 自动创建 GitHub Release
- 自动把 `.app.zip` 挂到 Release 附件

## 数据来源说明

当前 MVP 直接请求东方财富相关接口：
- 基金搜索：`fundsuggest.eastmoney.com`
- 基金净值与基础信息：`fundmobapi.eastmoney.com`
- 指数行情：`push2.eastmoney.com`

这适合快速验证产品，但如果后续要上架、做长期稳定版本，建议增加自有后端做缓存和容错。

## 版本

当前默认版本：`v1.0.0`
