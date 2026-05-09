---
updated: 2026-05-09
source: tmy-decision-center/ChannelBillboardEntity
related-risk: R-020
severity: 🟡
category: 类型
---

# Entity 字段类型 String → Integer 修正（数据库整数列声明为 String）

## 现象

`ChannelBillboardEntity` 的 `fans`、`forward`、`shareLikes`、`headlineReadings` 四个字段声明为 `String` 类型，但对应数据库列为整数类型。

MySQL 下 Hibernate 宽松处理，能自动做 String 与数值的隐式转换。PostgreSQL 下严格类型匹配，可能导致：
1. 查询时类型不匹配异常
2. 聚合计算（如 SUM）结果错误
3. 排序按字典序而非数值序

## 根因

原始开发时可能因数据来源不确定（可能有 null 或非数值字符串）而使用 String 类型。MySQL + Hibernate 对 Entity 字段类型与数据库列类型不一致容错度高。迁移到 PostgreSQL 后，严格类型检查暴露了此问题。

与 `2026-04-28-area-manager-in-query-type-mismatch.md`（查询参数类型不匹配）不同，本问题是 **Entity 字段声明层面**的类型不匹配，在 SELECT / INSERT / UPDATE 全链路均有影响。

## 修复动作 / 规避准则

将 Entity 字段类型从 `String` 改为 `Integer`：

```java
// 修复前
private String fans;
private String forward;

// 修复后
private Integer fans;
private Integer forward;
```

同步修改测试代码中的 `entity.setFans("10000")` → `entity.setFans(10000)`。

使用 `Integer` 而非 `int` 以允许 null 值。

扫描模式：`private String` 字段对应数据库数值列（如 fans、count、num 后缀字段）。

## 影响范围

所有 JPA Entity 中字段类型与数据库列类型不一致的情况。需排查所有 Entity 的 String 字段是否对应数据库的整数 / 浮点列。

## 来源

- 工程：tmy-decision-center
- 源文件：`ChannelBillboardEntity.java`
- 测试文件：`ChannelBillboardEntityRepositoryIntegrationTest.java`
- 日期：2026-05-09
- 记录人：吴少辉

## 参考

- 相关 risk：R-020（PG 严格类型检查）
- 关联 fix-issue：`2026-04-28-area-manager-in-query-type-mismatch.md`（查询参数层面类型不匹配）
