---
updated: 2026-06-01
source: event_server/EventPointMapper.xml
related-risk: 无
severity: 🟡
category: 类型
---

# PostgreSQL 拒绝 string 与 date 的隐式比较

## 现象

MyBatis Mapper XML 中将 Java String 参数直接与数据库 date/timestamp 列比较，MySQL 自动隐式转换，PostgreSQL 报类型不匹配错误：

```
ERROR: operator does not exist: timestamp without time zone >= character varying
```

涉及文件：EventPointMapper.xml、EventEvolutionResultMapper.xml 等。

## 根因

MySQL 对 `WHERE create_time >= #{startTime}` 会自动将 String 参数转为 date 类型。PostgreSQL 严格要求类型匹配，String 不能隐式与 date/timestamp 比较。

## 修复动作 / 规避准则

在 Mapper XML 中使用 PostgreSQL 显式类型转换：

```xml
<!-- 修复前 -->
WHERE create_time >= #{startTime}

<!-- 修复后 -->
WHERE create_time >= #{startTime}::date
```

- 所有 String 参数与 date/timestamp 列的比较，必须加 `::date` 或 `::timestamp` 显式转换
- 扫描方法：`rg '#{.*}.*[><=].*\b(date|time|timestamp)' --glob '*.xml'`

## 影响范围

所有 MyBatis Mapper 中将 Java String 参数直接与 date/timestamp 列做比较的场景。使用 JPA 的 `@Query` 同样受影响，但需用 `CAST(? AS date)` 替代 `::date`（见 [Hibernate 原生查询 `::` 被解析为命名参数](2026-05-14-hibernate-native-query-pg-cast-colon.md)）。

## 来源

- 工程：event_server
- 文件：EventPointMapper.xml、EventEvolutionResultMapper.xml
- 阶段：Stage 4 方言适配
- 日期：2026-05-29
- 记录人：wushaohui

## 参考

- 相关 fix-issue：[Hibernate 原生查询中 PostgreSQL `::` 类型转换被解析为命名参数](2026-05-14-hibernate-native-query-pg-cast-colon.md)
