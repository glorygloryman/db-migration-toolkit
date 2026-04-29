---
updated: 2026-04-28
source: propagation-billboard/ComprehensiveRankMapper
related-risk: R-021, R-020
severity: 🟡
category: 语法
---

# ComprehensiveRankMapper 无 GROUP BY 隐式聚合 + ROUND 类型 + GROUP BY 严格模式

## 现象

集成测试在瀚高数据库上执行失败，暴露三个兼容性问题，涉及聚合函数类型转换、GROUP BY 严格模式、以及无 GROUP BY 时聚合与非聚合列混用。

影响文件：`propagation-billboard-common/src/main/resources/mapper/ComprehensiveRankMapper.xml`
涉及SQL：`findBySceneTypeAndTimeRange`、`findRegionDayDataBySceneTypeAndTimeRange`

**问题1 — ROUND 签名不匹配**：
```
错误: 函数 round(double precision, integer) 不存在
```

**问题2 — GROUP BY 列不完整**：
```
错误: 字段 "a.name" 必须出现在 GROUP BY 子句中或者在聚合函数中使用
```

**问题3 — 无 GROUP BY 时聚合与非聚合列混用**（核心难点）：同问题2报错，但出现在 `areaCode != null`（州市日榜）场景。

## 根因

**ROUND 签名**：PostgreSQL 的 `ROUND(value, precision)` 只接受 `numeric` 类型参数。MySQL 会自动隐式转换。

**GROUP BY 严格模式**：MySQL 默认 `ONLY_FULL_GROUP_BY` 关闭，允许 SELECT 中引用未在 GROUP BY 中出现且未聚合的列。PostgreSQL 严格遵循 SQL 标准。

**无 GROUP BY 隐式聚合**：原始 MySQL SQL 在 `areaCode != null` 时不写 GROUP BY，依赖 MySQL 的隐式全表分组行为——将所有匹配行聚合为一行，非聚合列取第一行的值。PostgreSQL 不允许无 GROUP BY 时 SELECT 同时包含聚合列和非聚合列。

原始业务逻辑：
- `areaCode != null`（州市日榜）：过滤地域后，所有匹配行聚合成**一行**，非聚合字段取第一条数据
- `areaCode == null`（总榜）：按 `name` 分组返回**多行**

## 修复动作 / 规避准则

**ROUND 修复**：
```sql
-- 修复前
ROUND(SUM(app_ceiindex) / COUNT(1), 2)

-- 修复后
ROUND(CAST(SUM(app_ceiindex) / COUNT(1) AS numeric), 2)
```

**GROUP BY 修复**：对非分组、非聚合字段使用 `MAX()` 包裹。

**无 GROUP BY 场景修复**（核心方案）— 使用 `<choose>` 按场景拆分为两条独立 SQL：

**areaCode != null（一行结果）**——窗口函数 + LIMIT 1：
```sql
SELECT
    name as name,
    ROUND(CAST(SUM(app_ceiindex) OVER () / COUNT(1) OVER () AS numeric), 2) as appCeiindex,
    scene_type as sceneType,
    ...
FROM pb_comprehensive_rank a
WHERE ...
ORDER BY id ASC
LIMIT 1
```

- `SUM() OVER ()` / `COUNT(1) OVER ()`：窗口函数对全部匹配行做聚合，等价于 MySQL 无 GROUP BY 的隐式聚合
- `ORDER BY id ASC LIMIT 1`：取第一行的详情字段，等价于 MySQL 取第一行数据的非标准行为
- 非聚合字段直接 SELECT，不需要 `MAX()` 包裹

**areaCode == null（多行结果）**——GROUP BY + MAX()：
```sql
SELECT
    name as name,
    ROUND(CAST(SUM(app_ceiindex) / COUNT(1) AS numeric), 2) as appCeiindex,
    MAX(scene_type) as sceneType,
    ...
FROM pb_comprehensive_rank a
WHERE ...
GROUP BY name
```

**尝试过的错误方案**：

| 方案 | 问题 |
|---|---|
| 统一 `GROUP BY name` + `MAX()` | `areaCode != null` 时可能返回多行（多个 name），违反业务要求只返回一行 |
| 全部 `MAX()` 无 GROUP BY | `areaCode == null` 时所有数据被压成一行，违反业务要求按 name 分组 |
| 统一 `MAX()` + 条件 GROUP BY | `MAX()` 取最大值而非第一行数据，非聚合字段值可能与 MySQL 不一致 |

**通用规则**：

| 场景 | MySQL 行为 | PostgreSQL 修复方案 |
|---|---|---|
| `ROUND(double_expr, n)` | 隐式转换 | `ROUND(CAST(expr AS numeric), n)` |
| GROUP BY 缺列 | 取分组内任意值 | 非分组列用 `MAX()` 包裹 |
| 无 GROUP BY + 聚合函数 | 隐式全表分组，非聚合列取第一行 | `SUM() OVER ()` + `ORDER BY ... LIMIT 1` |
| 需按条件返回不同行数 | 同一条 SQL 靠 GROUP BY 有无控制 | `<choose>` 拆分为两条 SQL |

**关键教训**：MySQL 的隐式全表分组（无 GROUP BY 时聚合所有行、非聚合列取任意值）是**非标准行为**，无法用单一标准 SQL 同时覆盖"一行"和"多行"两种场景。必须用 `<choose>` 拆分。

## 影响范围

所有存在条件分支控制 GROUP BY 有无、且 SELECT 中同时包含聚合列和非聚合列的动态 SQL。典型场景：按地域维度切换"总榜"（多行）和"地区榜"（单行）。

## 来源

- 工程：propagation-billboard
- 影响文件：`propagation-billboard-common/src/main/resources/mapper/ComprehensiveRankMapper.xml`
- 涉及SQL：`findBySceneTypeAndTimeRange`、`findRegionDayDataBySceneTypeAndTimeRange`
- 日期：2026-04-28
- 记录人：吴少辉

## 参考

- 相关 reference：`docs/references/mysql-to-highgo-function-mapping.md`（ROUND 条目）
- 相关 risk：R-021（聚合除法除零 + ROUND 签名）
- 相关 risk：R-020（PG 严格类型检查）
