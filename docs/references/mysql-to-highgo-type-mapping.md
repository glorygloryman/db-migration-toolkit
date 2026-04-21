# 类型映射表（MySQL → 瀚高 v4.1.5）

> 本映射表基于 **PostgreSQL 内核类型系统** 重新判定，适用于瀚高数据库 v4.1.5。
> 与 GaussDB B 模式（兼容 MySQL 语法）不同，瀚高基于原生 PG 类型体系，大量 MySQL 专有类型需要显式改写。
>
> **状态图例**：
> - ✅ **原样保留**：PG 原生支持或语义等价，可直接迁移
> - 🔄 **建议改写**：PG 无此类型或语义差异较大，需替换为等价 PG 类型
> - ⚠️ **需验证**：语义/存储/索引行为存在差异，必须通过专项测试确认

---

## 1. 整数类型

| MySQL 类型 | 瀚高（PG）映射 | 状态 | 说明 |
|---|---|---|---|
| `TINYINT` | `SMALLINT` | 🔄 | PG 无 TINYINT，统一升格为 2 字节 SMALLINT |
| `TINYINT(1)` | `BOOLEAN` | 🔄 | MySQL 习惯用 TINYINT(1) 表达布尔，PG 原生支持 BOOLEAN，语义更清晰 |
| `SMALLINT` | `SMALLINT` | ✅ | 等价 |
| `MEDIUMINT` | `INTEGER` | 🔄 | PG 无 3 字节整型，升格为 4 字节 INTEGER |
| `INT` / `INTEGER` | `INTEGER` | ✅ | 等价 |
| `BIGINT` | `BIGINT` | ✅ | 等价 |
| `INT UNSIGNED` | `BIGINT` | 🔄 | PG 无 UNSIGNED，升格到更大有符号类型以容纳取值范围 |
| `BIGINT UNSIGNED` | `NUMERIC(20)` | 🔄 | BIGINT 无法容纳 UNSIGNED 上限（2^64-1），须使用 NUMERIC；如确认业务值不会越过 2^63-1，也可退化为 BIGINT |

---

## 2. 浮点与精确数值

| MySQL 类型 | 瀚高（PG）映射 | 状态 | 说明 |
|---|---|---|---|
| `FLOAT` | `REAL`（即 `FLOAT4`） | 🔄 | 4 字节单精度；注意 MySQL 的 `FLOAT(p)` 当 p>24 时会升级为 DOUBLE，迁移时须按实际精度判断 |
| `DOUBLE` / `DOUBLE PRECISION` | `DOUBLE PRECISION`（即 `FLOAT8`） | 🔄 | 语法写法需改写为 PG 标准名 |
| `DECIMAL(p,s)` / `NUMERIC(p,s)` | `NUMERIC(p,s)` | ✅ | 精确数值，语义一致 |
| `BIT(n)` | `BIT(n)` 或 `BOOLEAN`（n=1 时） | ⚠️ | PG 有 BIT 类型但字面量与索引行为与 MySQL 不同，涉及位运算需专项验证 |

---

## 3. 字符类型

| MySQL 类型 | 瀚高（PG）映射 | 状态 | 说明 |
|---|---|---|---|
| `CHAR(n)` | `CHAR(n)` | ✅ | PG 的 CHAR 会右侧补空格，与 MySQL 一致 |
| `VARCHAR(n)` | `VARCHAR(n)` | ✅ | 等价；注意 PG 的 n 为字符数，与 MySQL 默认一致（utf8mb4） |
| `TINYTEXT` | `TEXT` | 🔄 | PG 无 TINYTEXT |
| `TEXT` | `TEXT` | ✅ | 等价 |
| `MEDIUMTEXT` | `TEXT` | 🔄 | PG TEXT 无长度上限（受行限制约 1GB），覆盖 MEDIUMTEXT 范围 |
| `LONGTEXT` | `TEXT` | 🔄 | 同上 |

---

## 4. 二进制类型

| MySQL 类型 | 瀚高（PG）映射 | 状态 | 说明 |
|---|---|---|---|
| `BINARY(n)` | `BYTEA` | 🔄 | PG 无定长二进制，统一用 BYTEA；若需严格定长需通过 CHECK 约束 |
| `VARBINARY(n)` | `BYTEA` | 🔄 | 同上 |
| `TINYBLOB` / `BLOB` / `MEDIUMBLOB` / `LONGBLOB` | `BYTEA` | 🔄 | PG 统一用 BYTEA；如涉及大对象流式访问可考虑 `LARGE OBJECT`（OID），需专项评估 |

---

## 5. 日期与时间

| MySQL 类型 | 瀚高（PG）映射 | 状态 | 说明 |
|---|---|---|---|
| `DATE` | `DATE` | ✅ | 等价 |
| `TIME` | `TIME WITHOUT TIME ZONE` | ✅ | 等价；MySQL TIME 支持 `-838:59:59 ~ 838:59:59`，PG TIME 仅支持 `00:00:00 ~ 24:00:00`，如业务用 TIME 表达时间差须改用 `INTERVAL` |
| `DATETIME` | `TIMESTAMP WITHOUT TIME ZONE` | 🔄 | 无时区，存储本地时间字面量 |
| `TIMESTAMP` | `TIMESTAMP WITH TIME ZONE`（`TIMESTAMPTZ`） | 🔄 | **语义需专项测试**：MySQL TIMESTAMP 会做 session time_zone 转换，PG TIMESTAMPTZ 存储 UTC 并按 session timezone 返回，行为近似但需验证 `NOW()`、默认值、`ON UPDATE` 等细节 |
| `YEAR` | `SMALLINT` | 🔄 | PG 无 YEAR 类型，用 SMALLINT 存储；如需约束范围配 CHECK |

---

## 6. 布尔

| MySQL 类型 | 瀚高（PG）映射 | 状态 | 说明 |
|---|---|---|---|
| `BOOL` / `BOOLEAN`（= TINYINT(1)） | `BOOLEAN` | 🔄 | PG 原生 BOOLEAN；MySQL 实际存的是 0/1，迁移数据时需将 0/1 转 false/true |

---

## 7. 枚举与集合

| MySQL 类型 | 瀚高（PG）映射 | 状态 | 说明 |
|---|---|---|---|
| `ENUM(...)` | `VARCHAR(n) + CHECK (col IN (...))` | 🔄 | PG 亦提供 `CREATE TYPE ... AS ENUM`，但变更枚举值需 `ALTER TYPE`，不如 CHECK 灵活；**本工具默认推荐 VARCHAR + CHECK**，在 Stage 3 决策文档中统一声明 |
| `SET(...)` | `TEXT[]` 或 关联表 | ⚠️ | PG 无 SET；小集合可用数组 + GIN 索引，大集合建议改为关联表。须评估业务查询模式 |

---

## 8. JSON

| MySQL 类型 | 瀚高（PG）映射 | 状态 | 说明 |
|---|---|---|---|
| `JSON` | `JSONB`（推荐）或 `JSON` | ⚠️ | **推荐 JSONB**：二进制存储、支持 GIN 索引、路径查询高效；若业务依赖保留原始文本顺序和空白，则用 JSON。**函数/操作符语法差异较大**（MySQL `JSON_EXTRACT` vs PG `->` / `->>` / `jsonb_path_query`），迁移时需配合 dialect-rewrite skill |

---

## 9. 几何类型

| MySQL 类型 | 瀚高（PG）映射 | 状态 | 说明 |
|---|---|---|---|
| `GEOMETRY` / `POINT` / `LINESTRING` / `POLYGON` | PostGIS 扩展（`geometry`） 或 PG 内置 `point` / `line` / `polygon` | ⚠️ | 瀚高默认是否集成 PostGIS 需现场确认；内置几何类型函数族与 MySQL/OpenGIS 不一致，空间索引（GiST）用法不同，必须专项验证 |
| `JSON` 存几何 | `geometry` + `ST_GeomFromGeoJSON` | ⚠️ | 如业务以 GeoJSON 方式存储，迁移后建议落到 PostGIS geometry 列 |

---

## 10. 映射策略声明

- 本表是**类型层面的候选建议**，不是自动落盘方案。
- 工程在 **Stage 3（schema 迁移）** 阶段，必须在 `project-docs/decisions/YYYY-MM-DD-type-mapping-strategy.md` 中落盘本项目的**统一映射策略**，包括：
  1. 对 🔄 类目的**最终选择**（如 `TINYINT` 是否一律升格 SMALLINT、`TIMESTAMP` 是否一律映射 TIMESTAMPTZ）；
  2. 对 ⚠️ 类目的**验证结论**（JSON 是否用 JSONB、ENUM 用 CHECK 还是原生 enum、TIMESTAMP 时区语义测试结果）；
  3. **例外清单**：偏离统一策略的表/列及其原因；
  4. **数据迁移侧的转换规则**（0/1 → boolean、UNSIGNED 越界处理、BLOB → BYTEA 编码等）。
- 未落盘前，任何 DDL 改写须在 PR 中显式说明映射依据，避免同一 MySQL 类型在不同表出现不一致的 PG 映射。
