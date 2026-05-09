---
updated: 2026-05-09
source: tmy-decision-center/Multiple Repositories
related-risk: 无
severity: 🟡
category: 函数
---

# 日期范围查询从字符串比较改为原生类型范围比较

## 现象

多个 Repository 使用 `TO_CHAR(timestamp_col, 'YYYY-MM-DD') >= ?3 AND TO_CHAR(timestamp_col, 'YYYY-MM-DD') <= ?4` 做日期过滤。

存在两个问题：

1. **性能**：对列使用函数后无法走索引（全表扫描 + 函数计算）
2. **语义模糊**：`<= '2026-05-09'` 是否包含当天 23:59:59 取决于列的精度

## 根因

原写法在 MySQL 下"能用但性能差"（MySQL 优化器有一定能力做 range 优化），PostgreSQL 下 `TO_CHAR`/`DATE_FORMAT` 包裹列**必然导致全表扫描**。

另外 `<= endDate` 的边界语义不一致：如果 endDate 传入 `'2026-05-09'`，实际意图是包含当天全部数据，但 timestamp 列存储的是精确时间点，`<= '2026-05-09'` 不等于 `<= '2026-05-09 23:59:59'`（尤其存在毫秒精度时）。

## 修复动作 / 规避准则

统一改为**左闭右开**区间 `[start, start+1day)`，将参数转换为列的类型进行比较：

| 文件 | 改写方式 |
|------|---------|
| `WeiboBombRepository`（3 个方法） | `to_timestamp(?3, 'YYYY-MM-DD')` + `< to_timestamp(?4, 'YYYY-MM-DD') + interval '1 day'` |
| `ProvinceHotpointListRepository` | `TO_DATE(?3, 'YYYYMMDD')` + `< TO_DATE(?4, 'YYYYMMDD') + INTERVAL '1 day'` |
| `ChannelHotpointListRepository.getMaxTaskIds` | `CAST(?3 AS TIMESTAMP)` + `< CAST(?4 AS TIMESTAMP) + INTERVAL '1 day'` |
| `ChannelHotpointListRepository.getAreaHeatRank` | `TO_DATE(?2, 'YYYYMMDD')` + `< TO_DATE(?3, 'YYYYMMDD') + INTERVAL '1 day'` |

规避准则：
1. **严禁对列使用函数做范围过滤**，应将参数转换为列的类型进行比较
2. 日期范围统一使用**左闭右开** `[start, start+1day)` 语义，避免边界歧义
3. 扫描模式：`TO_CHAR(col, ...)` 或 `DATE_FORMAT(col, ...)` 出现在 WHERE 条件中
4. `BETWEEN` 是闭区间，用于精确时间点比较时需确认是否需要改为 `< next_day`

## 影响范围

所有在 WHERE 条件中对 timestamp/date 列使用 `TO_CHAR()` / `DATE_FORMAT()` 包裹做范围过滤的查询。数据量大时性能差距显著。

## 来源

- 工程：tmy-decision-center
- 源文件：5 个 Repository（WeiboBomb、ProvinceHotpointList、ChannelHotpointList、AreaHotword）
- 日期：2026-05-09
- 记录人：吴少辉

## 参考

- 相关 reference：`docs/references/mysql-to-highgo-function-mapping.md`（日期函数条目）
