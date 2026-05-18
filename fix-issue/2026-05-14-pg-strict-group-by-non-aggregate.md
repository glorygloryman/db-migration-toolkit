---
updated: 2026-05-14
source: mcb_dicttool/ProductRepository
related-risk: R-020
severity: 🟡
category: SQL
---

# PostgreSQL 严格 GROUP BY 要求非聚合 SELECT 列出现在 GROUP BY 子句中

## 现象

MySQL 下正常运行的原生 GROUP BY 查询，在瀚高上报语法错误。

**错误信息**：
```
错误: 字段 "t.media_unit" 必须出现在 GROUP BY 子句中或者在聚合函数中使用
```

## 根因

MySQL 对 GROUP BY 采用宽松模式（`ONLY_FULL_GROUP_BY` 默认关闭），允许 SELECT 列不在 GROUP BY 中。PostgreSQL 严格执行 SQL 标准，要求所有非聚合 SELECT 列必须出现在 GROUP BY 子句中。

原 SQL：
```sql
SELECT t.tenantid, t.media_unit, count(*)
FROM tb_jtcp_product t
GROUP BY t.tenantid
```

`media_unit` 不在 GROUP BY 中，MySQL 宽松通过，PG 严格拒绝。

## 修复/规避

将所有非聚合 SELECT 列加入 GROUP BY：

```sql
SELECT t.tenantid, t.media_unit, count(*)
FROM tb_jtcp_product t
GROUP BY t.tenantid, t.media_unit
```

注意：此修改可能改变结果集语义（相同 tenantid 不同 media_unit 不再合并）。需确认业务是否依赖 MySQL 的宽松行为。本工程中 `tenantid + media_unit` 组合是业务预期分组维度。

## 来源

mcb_dicttool 改造 Stage 5 真库验证时发现并修复。
