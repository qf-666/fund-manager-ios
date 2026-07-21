# 修复：估算收益 `--` / 今日收益 `¥0.00`

日期：2026-07-21

## 现象

- 指数正常（上证 / 沪深 300）
- 持仓市值、持有收益、涨跌幅正常
- **今日收益固定 `¥0.00`**
- **估算收益显示 `--`**
- 列表右上角日期仍可能显示（或刷新时间正常）

## 根因

对齐插件 [x2rr/funds](https://github.com/x2rr/funds) 使用的天天基金接口：

```
GET https://fundmobapi.eastmoney.com/FundMNewApi/FundMNFInfo?...&Fcodes=...
```

当前返回形态（2026-07-21 实测）：

```json
{
  "Datas": [{
    "FCODE": "018125",
    "NAV": "1.7931",
    "NAVCHGRT": "-4.30",
    "PDATE": "2026-07-20",
    "GSZ": null,
    "GSZZL": null,
    "GZTIME": null
  }],
  "Expansion": {
    "GZTIME": "2026-07-21",
    "FSRQ": "2026-07-20"
  }
}
```

同时旧兜底接口：

```
https://fundgz.1234567.com.cn/js/{code}.js
```

已整体 404（返回东方财富「页面未找到」HTML）。

### 客户端逻辑 bug

`EastMoneyAPI.fetchSnapshots` 在单条 `GZTIME` 为空时，会把 **`Expansion.GZTIME`（仅日期「今天」）** 写进 `estimatedTime`。

于是 `RemoteFundSnapshot`：

- `reportDay = 2026-07-20`
- `estimatedDay = 2026-07-21`
- `prefersOfficialSnapshot = false`（误判为「盘中估值中」）
- 但 `estimatedNav / estimatedChangePercent` 实际为 `nil`

`dailyPnLPerUnit` 在「估值中」分支要求 `estimatedNav` 与 `nav` 同时存在，结果恒为 `nil`：

- 单行 **估算收益 → `--`**
- 汇总 `dailyPnL(for:) ?? 0` → **今日收益 `¥0.00`**

## 修复

### 1. `Models.swift` — `RemoteFundSnapshot`

- 新增 `hasLiveEstimate`：仅当 `GSZ` 或 `GSZZL` 有值才算有估值
- `prefersOfficialSnapshot`：无估值时强制走正式净值口径
- `dailyPnLPerUnit`：
  - 有盘中估值：`gsz - nav`
  - 估值日 == 净值日：用 `NAVCHGRT` 反推（对齐插件 `hasReplace`）
  - **无估值：返回 `nil`**（不再把昨日涨跌当成今日收益）
- `merged`：只有兜底真正补到估值时才写入 `estimatedTime`

### 2. `EastMoneyAPI.swift`

- 无 `GSZ/GSZZL` 时 **不再** 用 `Expansion.GZTIME` 填充 `estimatedTime`
- `fundgz` 兜底识别 HTML 404，直接放弃
- 新增 **重仓股加权估值** 兜底：
  - 调 `FundMNInverstPosition` + `push2` 行情
  - 按 `JZBL` 加权 `f3` 涨跌幅
  - 覆盖仓位 ≥ 30% 才采用
  - 精度受季报仓位滞后影响，但在官方 `GSZ` 全空时可用

## 验证方式

1. 重新编译运行 App，下拉刷新
2. 若官方 `GSZ` 仍为空但重仓股行情可用：
   - 估算净值 / 涨跌幅 / 估算收益 应有近似值
   - 今日收益不再恒为 0
3. 若持仓接口也失败：
   - 估算收益仍为 `--`，今日收益 `¥0.00`（诚实降级，不再误判）
   - 持有额 / 持有收益 / 已确认涨跌幅仍正常

## 与 choose.funds v3.4.4（商店 CRX）的关系

公开 GitHub 源码 tag 仅改 README；**商店安装包 3.4.4**（已解包分析）才是真修复：

### 主接口仍是

```
FundMNewApi/FundMNFInfo
```

### 无 GSZ 时的新逻辑（popup.js）

1. `useCalc = true`
2. `getCalcGszzl(code)`：
   - `FundMNInverstPosition` 取重仓
   - `push2 ulist` 取 `f3`
   - `calcFundEstimateChange`：`Σ (JZBL/totalJZBL * f3)` → 估算涨跌幅 %
3. `calcGsz = dwjz * (1 + 0.01 * calcGszzl)`
4. `gains = amount * calcGszzl * 0.01`（在非 hasReplace 时覆盖 gains）

### background 额外批量源

```
https://stock.finance.sina.com.cn/fundInfo/api/openapi.php/FdFundService.getEstimateNetworthPic?symbol={code}
```

返回 `worth` / `worth_rate`（小数）/ `worth_date`。

### rules.json

对 `fundmobapi.eastmoney.com` 强制移动 Safari UA。

### 本 App 对齐方式

| 插件 3.4.4 | iOS App |
|-----------|---------|
| FundMNFInfo 主路径 | 同 |
| 空 GZTIME 不误判 | `hasLiveEstimate` |
| getCalcGszzl 加权 | `fetchPositionWeightedEstimate`（归一公式） |
| 新浪 getEstimateNetworthPic | `fetchSinaEstimate` |
| 移动 UA | `makeRequest` |

## 相关文件

- `src/core/Models.swift`
- `src/core/EastMoneyAPI.swift`
