---
updated: 2026-05-09
source: tmy-decision-center/ChannelHotpointListRepository
related-risk: 无
severity: 🟢
category: 语法
---

# DISTINCT ON → ROW_NUMBER() 窗口函数改写方案

## 现象

`ChannelHotpointListRepository.getAreaHeatRank` 原使用 `DISTINCT ON (cluster_code)` 子查询包裹实现"按列去重取首行"。虽然 DISTINCT ON 在瀚高下可正常工作，但存在可移植性和表达力方面的改进空间。

## 根因

`DISTINCT ON` 是 PostgreSQL 专有语法。当去重逻辑需要更复杂的排序条件（如多列排序取首行）时，窗口函数更灵活。使用标准 SQL 的 `ROW_NUMBER()` 可提升 SQL 可移植性。

## 修复动作 / 规避准则

使用 `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)` 替代 `DISTINCT ON`：

```sql
-- DISTINCT ON 子查询
SELECT * FROM (
  SELECT DISTINCT ON (c.cluster_code) c.title, c.cluster_code, c.cluster_nums
  FROM channel_hotpoint c WHERE ...
  ORDER BY c.cluster_code, c.cluster_nums DESC
) ranked ORDER BY cluster_nums DESC

-- ROW_NUMBER() 窗口函数
SELECT x.title, x.cluster_code, x.cluster_nums
FROM (
    SELECT c.title, c.cluster_code, c.cluster_nums,
           ROW_NUMBER() OVER (PARTITION BY c.cluster_code ORDER BY c.cluster_nums DESC) rn
    FROM channel_hotpoint c WHERE ...
) x WHERE x.rn = 1
ORDER BY x.cluster_nums DESC
```

规避准则：
1. 优先使用 `ROW_NUMBER()` 作为"按列去重取首行"的标准方案
2. `DISTINCT ON` 仅在确认永远绑定 PostgreSQL 时使用
3. 窗口函数方案无需子查询外层再排序，`WHERE rn = 1` 结果可直接 ORDER BY

## 影响范围

所有使用 `DISTINCT ON` 实现"按列去重取首行"语义的查询。建议新改写统一使用 ROW_NUMBER()。

## 来源

- 工程：tmy-decision-center
- 源文件：`ChannelHotpointListRepository.java` → `getAreaHeatRank`
- 日期：2026-05-09
- 记录人：吴少辉

## 参考

- 关联 fix-issue：`2026-05-08-weibo-bomb-distinct-on-ordering.md`（DISTINCT ON 排序约束场景）
