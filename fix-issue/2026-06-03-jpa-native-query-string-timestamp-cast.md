---
updated: 2026-06-03
source: interaction-middleware/InteractionEntityRepository.java
related-risk: R-020
severity: 🟡
category: 类型
---

# JPA @Query 原生 SQL 中 String 参数与 timestamp 列比较需显式 CAST

## 现象

Spring Data JPA 的 `@Query(nativeQuery = true)` 中，Java String 参数直接与数据库 timestamp 列做 `>=`/`<=` 比较。MySQL 自动隐式转换通过，PostgreSQL 报错：

```
ERROR: operator does not exist: timestamp without time zone >= character varying
提示：没有任何匹配指定名称和参数类型的操作符. 你可能需要增加显式类型转换.
```

## 根因

MySQL 对 `WHERE pubtime >= '2026-01-01 00:00:00'` 会自动将字符串转为 datetime 类型。PostgreSQL 严格类型检查，`timestamp >= varchar` 不允许隐式转换。

本案例中 `findByPubtimeAndSection(String startTime, String endTime, String section)` 方法签名使用 String 接收日期参数，Hibernate 绑定参数类型为 `StringType`，PG 拒绝 `timestamp >= varchar` 比较。

## 修复动作 / 规避准则

**方案一（本次采用）**：SQL 中显式 CAST

```java
// 修复前
@Query(value = "SELECT * FROM t_interaction_entity WHERE pubtime >= ?1 and pubtime <= ?2 and section = ?3", nativeQuery = true)

// 修复后
@Query(value = "SELECT * FROM t_interaction_entity WHERE pubtime >= CAST(?1 AS timestamp) and pubtime <= CAST(?2 AS timestamp) and section = ?3", nativeQuery = true)
```

注意：`CAST(? AS timestamp)` 在 PostgreSQL 中有效，但 MySQL 不支持（MySQL 使用 `CAST(? AS DATETIME)`）。**此方案仅适用于已切换为 PG 的项目，不兼容双库**。

**方案二（推荐，双库兼容）**：改方法签名为 `java.util.Date`

```java
// 将 String 参数改为 Date，让 Hibernate 自动处理类型绑定
List<InteractionEntity> findByPubtimeAndSection(Date startTime, Date endTime, String section);
```

规避准则：
1. **JPA @Query 原生 SQL 中，String 参数不能直接与 timestamp/date 列做比较**（PG 严格类型检查）
2. 优先将方法参数类型改为与列类型匹配的 Java 类型（Date/LocalDateTime）
3. 如必须用 String，需在 SQL 中加 `CAST(? AS timestamp)`
4. 扫描方法：`rg '@Query.*nativeQuery.*true' --glob '*.java'`，检查参数类型与列类型是否匹配
5. Hibernate 原生查询中不能使用 PostgreSQL 的 `::timestamp` 语法（会被解析为命名参数），必须使用 `CAST`

## 影响范围

所有使用 Spring Data JPA `@Query(nativeQuery=true)` 且将 String 参数与 timestamp/date 列做比较的场景。MyBatis 同样受影响（见相关 fix-issue）。

## 来源

- 工程：interaction-middleware
- 文件：interaction-core/src/main/java/com/trs/interaction/core/repository/InteractionEntityRepository.java
- 阶段：Stage 4 方言适配
- 日期：2026-06-03
- 记录人：wushaohui

## 参考

- 相关 fix-issue：[PostgreSQL 拒绝 string 与 date 的隐式比较](2026-06-01-pg-string-date-implicit-comparison.md)
- 相关 fix-issue：[Hibernate 原生查询中 PostgreSQL `::` 类型转换被解析为命名参数](2026-05-14-hibernate-native-query-pg-cast-colon.md)
