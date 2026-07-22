# 列表日期停在昨日净值日（2026-07-22）

## 现象

- 今天是 7 月 22 日盘中，持仓行右上角仍显示 `07/21`
- 估算净值 = 正式净值，涨跌幅 = 昨日 NAVCHGRT
- 估算收益 ≈ 用昨日正式涨跌幅反推的「已公布替换估值」收益（x2rr `hasReplace` 分支）
- 对标 [x2rr/funds](https://github.com/x2rr/funds)：插件在有盘中估值时右上角应显示 `HH:mm`，净值日才显示 `MM-dd`

用户截图两只基金（018125 / 021302）均符合上述特征。

## 根因

`FundMNFInfo` 对这两只基金：

| 字段 | 值 |
|------|----|
| Expansion.GZTIME | `2026-07-22`（仅日期，且 Datas 无 GSZ 时不可用） |
| Datas[].GSZ / GSZZL / GZTIME | `null` |
| Datas[].NAV / NAVCHGRT / PDATE | 正式净值，`PDATE=2026-07-21` |

`fundgz.1234567.com.cn` 已 404，于是走新浪兜底：

```
FdFundService.getEstimateNetworthPic?symbol={code}
```

旧解析**优先**使用：

- `worth` / `worth_rate` / `worth_date`

但 2026-07 实测这些字段是 **已确认正式净值回显**，不是盘中估值：

| 字段 | 实测语义 |
|------|----------|
| worth / worth_rate / worth_date | 正式净值、日涨跌、净值日（≈ NAV / NAVCHGRT / PDATE） |
| networth[].pre_nav2 / growthrate2 / pre_date / min_time | **盘中估值序列** |

旧逻辑因此：

1. `estimatedNav ≈ NAV`，`estimatedChangePercent ≈ NAVCHGRT`
2. `estimatedTime = 2026-07-21`（净值日）
3. `prefersOfficialSnapshot = true`（reportDay == estimatedDay）
4. `displayTimestamp` 走 `reportDate` → UI `monthDayOrTime` 显示 `07/21`
5. `dailyPnLPerUnit` 走 hasReplace 分支，把昨日涨跌当今日估算收益

## 修复

`EastMoneyAPI.fetchSinaEstimate`：

1. **优先**取 `networth` 最后一点：`pre_nav2` + `growthrate2` + `pre_date` + `min_time`
2. 拼估值时间 `yyyy-MM-dd HH:mm`，列表右上角显示时刻（对齐 x2rr：`gztime.substr(10)`）
3. 仅当无序列时才考虑 `worth`，且若 `worth_date == PDATE` 或 `worth ≈ NAV`，判定为正式净值回显并丢弃
4. 估算结果与正式净值/涨跌完全重合时返回 `nil`，继续重仓加权兜底

## 预期结果（盘中、GSZ 为空）

- 右上角：`10:21` 一类时刻（来自新浪 `min_time`）
- 估算净值 / 涨跌幅：盘中估值，不再等于昨日正式净值
- 估算收益：`(gsz - nav) * shares`
- 净值已公布且估值日 == 净值日时，仍按 x2rr `hasReplace` 显示 `MM-dd` 与正式涨跌收益

## 关联

- `docs/fix-2026-07-21-estimate-null.md`（GSZ 为空时的 hasLiveEstimate / 不写空 GZTIME）
- 对标插件：`x2rr/funds` popup `getData` + `hasReplace` 时间展示
