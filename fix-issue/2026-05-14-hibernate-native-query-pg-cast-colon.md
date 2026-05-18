---
updated: 2026-05-14
source: mcb_dicttool/NavigationInfoRepository
related-risk: R-020
severity: 🟡
category: JPA
---

# Hibernate 原生查询中 PostgreSQL `::` 类型转换被解析为命名参数

## 现象

JPA `@Query(nativeQuery = true)` 中使用 PostgreSQL 的 `::` 类型转换语法（如 `id::text`），运行时抛出语法错误。

**错误信息**：
```
错误: 语法错误 在 ":" 附近
```

## 根因

Hibernate 的 native query 解析器将 `:` 识别为 JPQL 命名参数前缀。`id::text` 被解析为 `id` + 命名参数 `:text`，导致 PG 收到截断的 SQL。

## 修复/规避

使用标准 SQL `CAST` 函数替代 `::` 类型转换：

```java
// 错误
@Query(value = "SELECT STRING_AGG(id::text || '_' || name, ',') ...", nativeQuery = true)

// 正确
@Query(value = "SELECT STRING_AGG(CAST(id AS text) || '_' || name, ',') ...", nativeQuery = true)
```

## 来源

mcb_dicttool 改造 Stage 5 真库验证时发现并修复。
