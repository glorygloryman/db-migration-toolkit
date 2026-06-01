---
updated: 2026-06-01
source: event_server/IEventMapperAnalysisIntegrationTest
related-risk: 无
severity: 🟡
category: 其他
---

# GeneratedKeyHolder 在 PostgreSQL 下返回多列

## 现象

使用 JdbcTemplate 的 `update()` + `GeneratedKeyHolder` 获取自增主键时，MySQL 返回单列，PostgreSQL 返回多列（包含所有 GENERATED 列），导致 `getKey()` 或 `getKeys()` 行为不一致。

报错类似：

```
GeneratedKeyHolder contains multiple keys
```

或取到的 key 不是预期的主键值。

## 根因

MySQL 的 `RETURN_GENERATED_KEYS` 只返回自增主键列。PostgreSQL 的 `RETURNING *` 可能返回多个 GENERATED 列（如 IDENTITY 列 + 默认值列），`GeneratedKeyHolder` 无法区分。

## 修复动作 / 规避准则

指定具体的列名数组，而非使用 `RETURN_GENERATED_KEYS`：

```java
// 修复前
KeyHolder keyHolder = new GeneratedKeyHolder();
jdbcTemplate.update(con -> {
    PreparedStatement ps = con.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
    // ...
    return ps;
}, keyHolder);

// 修复后
jdbcTemplate.update(con -> {
    PreparedStatement ps = con.prepareStatement(sql, new String[]{"id"});
    // ...
    return ps;
}, keyHolder);
```

- 所有使用 `GeneratedKeyHolder` 的地方，必须指定具体列名数组（`new String[]{"id"}`），不能用 `Statement.RETURN_GENERATED_KEYS`
- 扫描方法：`rg 'RETURN_GENERATED_KEYS' --glob '*.java'`

## 影响范围

所有使用 JdbcTemplate + `GeneratedKeyHolder` 并依赖 `Statement.RETURN_GENERATED_KEYS` 获取自增主键的场景。涉及 `INSERT` 后需要回填主键 ID 的业务逻辑。

## 来源

- 工程：event_server
- 阶段：Stage 4 方言适配
- 测试：IEventMapperAnalysisIntegrationTest
- 日期：2026-05-29
- 记录人：wushaohui
