---
updated: 2026-05-08
source: tmy-decision-center/WeiboBombRepository
related-risk: 无
severity: 🟡
category: 语法
---

# DISTINCT ON 排序语义变化导致分页行为不一致

## 现象

JPQL 中 `GROUP BY t.content` 迁移后改写为 `DISTINCT ON (t.content)`。DISTINCT ON 语法要求 `ORDER BY` 首列必须为 DISTINCT ON 列，导致结果排序从**全局按 pub_time 降序**变为**按 content 分组后组内 pub_time 降序**。

分页查询的 `countQuery` 使用 `SELECT COUNT(*)` 统计去重前总行数，导致分页总数虚高（如 10 条不同 content 各有多条重复，count 返回 100 而非 10）。

## 根因

MySQL 下 `GROUP BY t.content` 配合 `ORDER BY pub_time DESC` 可独立工作，MySQL 不约束 ORDER BY 必须包含 GROUP BY 列。PostgreSQL 的 `DISTINCT ON` 要求 `ORDER BY` 首列为 DISTINCT ON 表达式，改变了全局排序语义。

countQuery 未同步去重逻辑，统计的是原始行数而非去重后的行数。

## 修复动作 / 规避准则

使用子查询包裹保持全局排序 + countQuery 去重：

```sql
-- 修复后
SELECT * FROM (
  SELECT DISTINCT ON (t.content) t.*
  FROM weibo_bomb t
  WHERE ...
  ORDER BY t.content, t.pub_time DESC
) sub ORDER BY sub.pub_time DESC
```

countQuery 使用 `SELECT COUNT(*) FROM (SELECT DISTINCT t.content FROM ... WHERE ...) sub` 避免总数虚高。

规避准则：
1. DISTINCT ON 改写时必须检查原查询是否有全局 ORDER BY → 如有，用子查询包裹保持排序
2. 返回 `Page<T>` 时 countQuery 需与去重语义一致
3. LIMIT/OFFSET 应作用于子查询外层（Spring Data JPA 自动追加到 @Query value）

## 影响范围

所有 `GROUP BY 单列` 被改写为 `DISTINCT ON` 且原查询有全局 ORDER BY 的分页场景。涉及 JPA 原生 SQL 查询、MyBatis XML 查询。

## 来源

- 工程：tmy-decision-center
- 源文件：`WeiboBombRepository.java`（5 个 `findListBySite` 方法）
- 测试文件：`WeiboBombRepositoryIntegrationTest.java`
- 日期：2026-05-08
- 记录人：吴少辉

## 参考

- 关联 fix-issue：`2026-05-09-rownumber-vs-distinct-on.md`（ROW_NUMBER() 替代方案）
