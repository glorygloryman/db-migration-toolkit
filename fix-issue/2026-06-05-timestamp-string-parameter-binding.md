---
updated: 2026-06-05
source: xz-alertsens-receive/commit:fccfbd8
related-risk: R-023
severity: 🟡
category: 类型
---

# JdbcTemplate 传字符串给 timestamp 列在 HighGo 中报类型不匹配

## 现象

测试代码中通过 `JdbcTemplate.update()` 插入数据时，将 timestamp 格式化为字符串传入：

```java
SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
String timeStr = sdf.format(publishTime);
jdbcTemplate.update("INSERT INTO table (create_time) VALUES (?)", timeStr);
```

HighGo 报错：

```
错误: 字段 "create_time" 的类型为 timestamp without time zone, 但表达式的类型为 character varying
```

## 根因

PostgreSQL/HighGo 的类型检查比 MySQL 严格。MySQL 允许字符串隐式转换为 timestamp，PG 拒绝隐式转换，要求显式类型匹配。

## 修复动作

将格式化后的字符串改为 `java.sql.Timestamp` 对象：

```diff
- SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
- String timeStr = sdf.format(publishTime);
- jdbcTemplate.update("INSERT INTO table (create_time) VALUES (?)", timeStr);
+ java.sql.Timestamp ts = new java.sql.Timestamp(publishTime.getTime());
+ jdbcTemplate.update("INSERT INTO table (create_time) VALUES (?)", ts);
```

同样适用于 MyBatis XML 中的参数：
```diff
- where msg_publish_time >= #{timeStr}
+ where msg_publish_time >= #{timeStr}::timestamp
```

## 影响范围

- 所有通过 JdbcTemplate 直接执行 INSERT 且传字符串给 timestamp 列的测试代码
- 所有 MyBatis XML 中 String 参数与 timestamp 列比较的 SQL
- 本工程涉及 MonitorTopicDocDAOTest 和 getDocMaxAlertIds

## 来源

- 工程：xz-alertsens-receive
- Commit：fccfbd8
- 日期：2026-06-05
- 记录人：Claude Code

## 参考

- 相关 risk：R-023（Stage 2 新发现）
