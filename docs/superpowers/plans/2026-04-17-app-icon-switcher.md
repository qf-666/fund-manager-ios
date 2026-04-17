# 应用图标切换实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为基金管理 iOS App 增加 3 套可切换桌面图标，并在设置页提供预览与切换入口。

**架构：** 使用 iOS Alternate App Icons（可替换应用图标）能力，将主图标与两个替换图标注册到 `Assets.xcassets`，通过 `ASSETCATALOG_COMPILER_APPICON_NAME` 与 `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` 让 Xcode 自动生成 `CFBundleIcons`。设置页读取持久化的图标枚举，调用 `UIApplication.setAlternateIconName` 切换系统桌面图标。

**技术栈：** SwiftUI、UIKit alternate icon API、XcodeGen、Python（生成 SVG/PNG 图标资源）

---

## 文件结构

- 创建：`docs/design/icons/` — 保存 3 套 SVG 源文件
- 创建：`src/zhihu/Assets.xcassets/` — 保存主图标、替换图标与设置页预览图
- 创建：`scripts/generate_app_icons.py` — 统一生成 SVG/PNG/Contents.json
- 创建：`scripts/check_app_icon_setup.py` — 静态校验图标配置是否完整
- 修改：`project.yml` — 指定主图标与替换图标构建设置
- 修改：`src/core/Models.swift` — 新增图标枚举与 `AppState` 持久化字段
- 修改：`src/core/AppViewModel.swift` — 新增切换图标逻辑与状态同步
- 修改：`src/zhihu/SettingsView.swift` — 新增图标预览卡片与切换交互
- 修改：`src/zhihu/ZhihuFundsApp.swift` — 启动时同步已保存图标

### 任务 1：先写失败检查，锁定目标文件与配置

**文件：**
- 创建：`scripts/check_app_icon_setup.py`

- [ ] **步骤 1：编写失败检查脚本**
- [ ] **步骤 2：运行检查脚本，确认当前缺少图标资产和切换逻辑**
- [ ] **步骤 3：记录失败点，作为后续回归口径**

### 任务 2：生成图标资源与资产目录

**文件：**
- 创建：`scripts/generate_app_icons.py`
- 创建：`docs/design/icons/*.svg`
- 创建：`src/zhihu/Assets.xcassets/**`

- [ ] **步骤 1：用统一配置生成 3 套 SVG 源文件**
- [ ] **步骤 2：导出 1024×1024 PNG 到 `AppIcon*.appiconset`**
- [ ] **步骤 3：导出设置页预览 PNG 到 `IconPreview*.imageset`**
- [ ] **步骤 4：生成各自 `Contents.json` 并复跑检查**

### 任务 3：接入工程与持久化状态

**文件：**
- 修改：`project.yml`
- 修改：`src/core/Models.swift`
- 修改：`src/core/AppViewModel.swift`
- 修改：`src/zhihu/ZhihuFundsApp.swift`

- [ ] **步骤 1：配置主图标与替换图标的 Xcode build settings**
- [ ] **步骤 2：新增 `AppIconOption` 枚举与 `AppState.appIcon`**
- [ ] **步骤 3：实现 `supportsAlternateIcons`、当前图标、切换与启动同步逻辑**
- [ ] **步骤 4：复跑检查脚本，确认静态条件满足**

### 任务 4：设置页 UI

**文件：**
- 修改：`src/zhihu/SettingsView.swift`

- [ ] **步骤 1：添加“应用图标”分组与 3 张预览卡片**
- [ ] **步骤 2：接入选中态、切换按钮与错误提示/说明文案**
- [ ] **步骤 3：确保当前图标状态与设置页联动**

### 任务 5：验证与提交

**文件：**
- 修改：`scripts/check_labels_and_autorefresh.py`（如需要纳入新 token）
- 测试：`scripts/check_app_icon_setup.py`

- [ ] **步骤 1：运行 `python scripts/generate_app_icons.py`**
- [ ] **步骤 2：运行 `python scripts/check_app_icon_setup.py`**
- [ ] **步骤 3：运行已有静态检查脚本，确认没破坏旧功能**
- [ ] **步骤 4：检查 git diff 后提交代码**
