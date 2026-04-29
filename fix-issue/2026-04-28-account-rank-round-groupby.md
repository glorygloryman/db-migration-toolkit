---
updated: 2026-04-28
source: propagation-billboard/AccountRankMapper
related-risk: R-021, R-020
severity: 🟡
category: 函数
---

# AccountRankMapper ROUND 类型与 GROUP BY 严格模式兼容性修复

## 现象

集成测试 `test01_findByAccountSceneTypeAndTimeRange_媒体场景查询` 在瀚高数据库上执行失败，暴露两个兼容性问题：

**问题1 — ROUND 签名不匹配**：
```
错误: 函数 round(double precision, integer) 不存在
建议：没有匹配指定名称和参数类型的函数. 您也许需要增加明确的类型转换.
```

**问题2 — GROUP BY 列不完整**：
```
错误: 字段 "a.account_show_name" 必须出现在 GROUP BY 子句中或者在聚合函数中使用
```

影响文件：`propagation-billboard-common/src/main/resources/mapper/AccountRankMapper.xml`
涉及SQL：`findByAccountSceneTypeAndTimeRange`

## 根因

**ROUND 签名**：PostgreSQL 的 `ROUND(value, precision)` 只接受 `numeric` 类型参数，不接受 `double precision`。MySQL 会自动隐式转换，瀚高不会。原始 SQL `ROUND(SUM(ceiindex) / COUNT(1), 2)` 中除法结果为 `double precision`，触发签名不匹配。

**GROUP BY 严格模式**：MySQL 默认 `ONLY_FULL_GROUP_BY` 关闭，允许 SELECT 中引用未在 GROUP BY 中出现且未聚合的列（取分组内任意值）。PostgreSQL 严格遵循 SQL 标准，要求所有非聚合列必须出现在 GROUP BY 中。原始 SQL `GROUP BY account_name` 但 SELECT 中有 `account_show_name`、`scene_type`、`situation` 等十几个非聚合字段。

## 修复动作 / 规避准则

**ROUND 修复** — 必须将**整个除法表达式**转为 `numeric`：
```sql
-- 修复前
ROUND(SUM(ceiindex) / COUNT(1), 2) as ceiindex

-- 修复后
ROUND((SUM(ceiindex) / COUNT(1))::numeric, 2) as ceiindex
```

注意：仅转分母 `COUNT(1)::numeric` 不够——`SUM(double precision)` 结果仍为 `double precision`，除法结果也仍是 `double precision`。

**GROUP BY 修复** — 对所有非聚合的非分组字段使用 `MAX()` 包裹：
```sql
MAX(account_show_name) as accounShowtName,
MAX(scene_type) as sceneType,
MAX(situation) as situation,
-- ... 其余非聚合字段同理
```

选择 `MAX()` 而非扩展 GROUP BY：瀚高 / PostgreSQL 直接运行不报错；切换数据库 100% 兼容；结果永远可预测。

**通用改写规则**：

| MySQL 行为 | 瀚高(PostgreSQL) 要求 | 修复模式 |
|---|---|---|
| `ROUND(double_expr, n)` 隐式转换 | 必须显式 `::numeric` | `ROUND(expr::numeric, n)` |
| `GROUP BY` 允许 SELECT 非聚合列 | 所有非聚合列必须在 GROUP BY 中 | 用 `MAX()`/`MIN()` 包裹 |
| `FLOOR(double_expr)` 可用 | `FLOOR()` 接受 `double precision`，无问题 | 无需修改 |

## 影响范围

所有使用 ROUND 带精度参数包裹除法表达式的聚合 SQL，以及 GROUP BY 中未包含全部非聚合 SELECT 列的场景。`FLOOR()` 不受影响。

## 来源

- 工程：propagation-billboard
- 影响文件：`propagation-billboard-common/src/main/resources/mapper/AccountRankMapper.xml`
- 涉及SQL：`findByAccountSceneTypeAndTimeRange`
- 日期：2026-04-28
- 记录人：吴少辉

## 参考

- 相关 reference：`docs/references/mysql-to-highgo-function-mapping.md`（ROUND 条目）
- 相关 risk：R-021（聚合除法除零 + ROUND 签名）
- 相关 risk：R-020（PG 严格类型检查）
