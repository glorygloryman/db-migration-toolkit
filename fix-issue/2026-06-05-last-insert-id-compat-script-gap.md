---
updated: 2026-06-05
source: xz-alertsens-receive/commit:e6ffb8f
related-risk: R-007
severity: 🔴
category: 函数
---

# LAST_INSERT_ID() 不在兼容脚本覆盖范围内，selectKey 必须移除

## 现象

MyBatis Mapper 中的 `<selectKey>SELECT LAST_INSERT_ID()</selectKey>` 在 HighGo 中执行时报错：

```
错误: 函数 last_insert_id() 不存在
```

所有使用 `insert` / `insertBatch` / `insertSelective` 的 DAO 方法均受影响。

## 根因

1. `LAST_INSERT_ID()` 是 MySQL 会话级函数，不在厂家兼容脚本的 14 个覆盖函数中
2. MyBatis Generator 模板自动为所有表添加 `<selectKey>`，但实际项目中主键可能由应用层生成或由数据库序列生成
3. 如果主键列已有 `DEFAULT nextval('xxx_seq')`（HighGo 迁移工具自动创建），则 `selectKey` 是冗余的

## 修复动作

1. 确认 HighGo 中目标表的主键列是否有 `DEFAULT nextval('xxx_seq')`
2. 如有，直接移除 `<selectKey>` 块，保留 `useGeneratedKeys="true"`（PG JDBC 自动使用 `RETURNING`）
3. 如无，需先创建序列并设置 default，再移除 selectKey

```diff
  <insert id="insert" parameterType="...">
-     <selectKey keyProperty="id" order="AFTER" resultType="java.lang.Integer">
-         SELECT LAST_INSERT_ID()
-     </selectKey>
      insert into table_name (id, ...) values (#{id}, ...)
  </insert>
```

## 影响范围

- 所有使用 MyBatis Generator 生成的 Mapper（含 `<selectKey>` + `LAST_INSERT_ID()`）
- 所有主键非自增但 MBG 模板添加了 selectKey 的表
- 本工程涉及 8 个表、16 处 selectKey

## 来源

- 工程：xz-alertsens-receive
- Commit：e6ffb8f
- 日期：2026-06-05
- 记录人：Claude Code

## 参考

- 相关 reference：`docs/references/highgo-v4.1.5-mysql-compat-functions.md`（LAST_INSERT_ID 不在覆盖清单）
- 相关 risk：R-007
