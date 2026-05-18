---
updated: 2026-05-14
source: mcb_dicttool/NavigationInfoRepository
related-risk: R-020
severity: 🟡
category: 类型
---

# PostgreSQL 原生查询 null 参数被 Hibernate 推断为 bytea 类型

## 现象

JPA `@Query(nativeQuery = true)` 的原生 SQL 中使用 `WHERE column = ?1`，当传入 null 参数时，瀚高报类型不匹配。

**错误信息**：
```
错误: 操作符不存在: character varying = bytea
建议：没有匹配指定名称和参数类型的函数. 您也许需要增加明确的类型转换.
```

## 根因

当 Hibernate 向 PostgreSQL 原生 SQL 绑定 null 参数时，因无法推断类型，默认使用 `bytea`。而目标列是 `varchar`，PG 不允许 `varchar = bytea` 隐式转换。

MySQL 驱动不存在此问题，MySQL 会自动处理 null 参数类型。

## 修复/规避

在原生 SQL 中对参数显式类型转换：

```java
// 错误：null 参数被推断为 bytea
@Query(value = "SELECT ... WHERE section = ?1 ...", nativeQuery = true)

// 正确：显式 CAST 告知 PG 参数类型
@Query(value = "SELECT ... WHERE section = CAST(?1 AS varchar) ...", nativeQuery = true)
```

## 来源

mcb_dicttool 改造 Stage 5 真库验证时发现并修复。
