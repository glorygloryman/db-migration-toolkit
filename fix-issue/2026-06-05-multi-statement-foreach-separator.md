---
updated: 2026-06-05
source: xz-alertsens-receive/commit:473c02e
related-risk: R-004
severity: 🟡
category: 语法
---

# MyBatis foreach separator=";" 多条 SQL 在 PG 中不执行

## 现象

MyBatis Mapper 中使用 `<foreach separator=";">` 生成多条 UPDATE 语句：

```xml
<update id="updateBatch">
    <foreach collection="list" item="item" separator=";">
        update table_name set col=#{item.val} where id=#{item.id}
    </foreach>
</update>
```

MySQL 下依赖 `allowMultiQueries=true` 正常执行，HighGo/PG 报语法错误或只执行第一条。

## 根因

1. PostgreSQL 不支持在单条语句中用分号分隔执行多条 SQL
2. MySQL 的 `allowMultiQueries=true` 是 JDBC 驱动特有行为，非 SQL 标准
3. MyBatis 的 `separator` 只是简单拼接字符串，不感知数据库方言

## 修复动作

**方案 A（推荐）**：改为单条 UPDATE + Service 层循环

```java
// DAO 新增单条方法
void updateSingle(Item item);

// Service 层循环调用
for (Item item : list) {
    dao.updateSingle(item);
}
```

**方案 B**：使用 PG CTE（WITH 子句）合并，但动态 SQL 复杂度高，不推荐。

## 影响范围

- 所有使用 `<foreach separator=";">` 执行多条 INSERT/UPDATE/DELETE 的 Mapper
- 本工程涉及 `updateMonitorAlertBatch`（1 处）

## 来源

- 工程：xz-alertsens-receive
- Commit：473c02e
- 日期：2026-06-05
- 记录人：Claude Code

## 参考

- 相关 risk：R-004
