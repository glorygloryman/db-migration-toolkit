---
updated: 2026-04-28
source: 实际改造经验（propagation-billboard）
related-risk: R-021
severity: 🟡
category: 函数
---

# 聚合除法除零异常 + ROUND 函数签名不匹配

## 现象

按 `scene_type` 维度分组统计均值时，原 MySQL SQL 直接运行报错：

```
ERROR: division by zero
```

或

```
ERROR: function round(double precision, integer) does not exist
```

典型 SQL 模式：

```sql
-- 原始 MySQL 写法
ROUND(SUM(IF(a.scene_type = 'app', a.ceiindex, 0.0)) / SUM(IF(a.scene_type = 'app', 1, 0)), 2) as appCeiindex
```

## 根因

**双问题同时存在**：

1. **除零异常**：MySQL 中 `x / 0` 返回 NULL（不报错）；瀚高（PG 系）中 `x / 0` 直接抛 `division by zero` 异常。当某 `scene_type` 在结果集中不存在时，`SUM(CASE WHEN a.scene_type = 'xxx' THEN 1 ELSE 0 END)` 为 0，触发除零。

2. **ROUND 签名不匹配**：MySQL 的 `ROUND(double precision, int)` 可正常工作；PG 的 `ROUND` 只接受 `(numeric, int)` 或 `(double precision)`（无精度参数）。`SUM()` 返回 `numeric` 类型，但 `numeric / integer` 的结果类型取决于操作数，当类型推断为 `double precision` 时触发签名不匹配。

## 修复动作 / 规避准则

**改写模板**（三处修改）：

```sql
-- 修复后瀚高写法
ROUND(
  SUM(CASE WHEN a.scene_type = 'app' THEN a.ceiindex ELSE 0.0 END)::numeric
  / NULLIF(SUM(CASE WHEN a.scene_type = 'app' THEN 1 ELSE 0 END), 0),
  2
) as appCeiindex
```

改动要点：
1. `IF(cond, a, b)` → `CASE WHEN cond THEN a ELSE b END`（脚本类型重载不全，见 R-015）
2. 分母包 `NULLIF(..., 0)` — 除零时返回 NULL，与 MySQL 行为一致
3. 分子加 `::numeric` — 确保 ROUND 签名匹配

**通用改写公式**：

```
ROUND(SUM(CASE WHEN ... THEN val ELSE 0 END)::numeric / NULLIF(SUM(CASE WHEN ... THEN 1 ELSE 0 END), 0), n)
```

**扫描规则**：Stage 4 搜索以下模式，全部需排查：
- `SUM(` 后跟 `/ SUM(` — 聚合除法，检查分母是否可能为零
- `ROUND(` 包裹除法表达式 — 检查 ROUND 参数类型是否为 numeric

## 影响范围

所有按枚举维度（`scene_type` / `status` / `type` 等）分组统计均值、占比的聚合 SQL。数据稀疏场景（某些维度值在查询范围内不存在）必现除零。

涉及函数：`ROUND`、`TRUNCATE`（同理需 `::numeric`）、聚合 `/` 除法。

## 来源

- 工程：propagation-billboard（实际改造）
- 日期：2026-04-28
- 记录人：吴少辉

## 参考

- 相关 reference：`docs/references/mysql-to-highgo-function-mapping.md`（ROUND 条目、`/` 除法条目）
- 相关 risk：R-021
- 相关 risk：R-020（PG 严格类型检查）
- 相关 risk：R-015（脚本重载类型缺口）
