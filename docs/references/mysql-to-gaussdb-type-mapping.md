# 类型映射表（MySQL → GaussDB B 兼容模式）

> 本表记录**建议映射**。B 模式下大多数 MySQL 类型可直接保留，仅在有明确收益时改写。
> 状态说明：✅ 原样保留 / 🔄 建议改写 / ⚠️ 需验证

## 整数

| MySQL | GaussDB B 模式 | 状态 | 备注 |
|-------|----------------|------|------|
| `TINYINT` | `TINYINT` | ✅ | |
| `TINYINT(1)` | `TINYINT(1)` 或 `BOOLEAN` | ⚠️ | JDBC 映射是否成 `Boolean` 需验证，若应用依赖 `Boolean` 映射需测 |
| `SMALLINT` | `SMALLINT` | ✅ | |
| `MEDIUMINT` | `INTEGER` | 🔄 | GaussDB 无 MEDIUMINT，升为 INTEGER |
| `INT` / `INTEGER` | `INTEGER` | ✅ | |
| `BIGINT` | `BIGINT` | ✅ | |
| `INT UNSIGNED` | `BIGINT` | 🔄 | GaussDB 无 UNSIGNED，升格避免溢出 |
| `BIGINT UNSIGNED` | `NUMERIC(20)` | 🔄 | 同上，无对应整型 |

## 浮点与精确数

| MySQL | GaussDB B 模式 | 状态 | 备注 |
|-------|----------------|------|------|
| `FLOAT` | `REAL` 或 `FLOAT4` | ⚠️ | B 模式可能兼容 FLOAT，按实测 |
| `DOUBLE` | `DOUBLE PRECISION` 或 `FLOAT8` | ⚠️ | 同上 |
| `DECIMAL(p,s)` | `NUMERIC(p,s)` | ✅ | B 模式 `DECIMAL` 等价 `NUMERIC` |

## 字符

| MySQL | GaussDB B 模式 | 状态 | 备注 |
|-------|----------------|------|------|
| `CHAR(n)` | `CHAR(n)` | ✅ | 尾空格处理需验证 |
| `VARCHAR(n)` | `VARCHAR(n)` | ✅ | |
| `TEXT` | `TEXT` | ✅ | |
| `MEDIUMTEXT` | `TEXT` | 🔄 | 无对应中等长度，统一 TEXT |
| `LONGTEXT` | `TEXT` 或 `CLOB` | ⚠️ | 最大长度按 GaussDB 配置 |
| `TINYTEXT` | `VARCHAR(255)` | 🔄 | |

## 二进制

| MySQL | GaussDB B 模式 | 状态 | 备注 |
|-------|----------------|------|------|
| `BINARY(n)` | `BYTEA` 或 `RAW(n)` | ⚠️ | 按使用场景 |
| `VARBINARY(n)` | `BYTEA` | 🔄 | |
| `BLOB` / `MEDIUMBLOB` / `LONGBLOB` | `BYTEA` 或 `BLOB` | ⚠️ | 有 BLOB 类型则保留 |

## 日期时间

| MySQL | GaussDB B 模式 | 状态 | 备注 |
|-------|----------------|------|------|
| `DATE` | `DATE` | ✅ | |
| `TIME` | `TIME` | ✅ | |
| `DATETIME` | `DATETIME` 或 `TIMESTAMP WITHOUT TIME ZONE` | ⚠️ | B 模式通常保留 DATETIME |
| `TIMESTAMP` | `TIMESTAMP` | ⚠️ | **时区语义可能不同**，专项测 |
| `YEAR` | `SMALLINT` 或 `YEAR` | ⚠️ | B 模式可能支持 YEAR |

**重点**：`TIMESTAMP` 在 MySQL 中自动做时区转换（存 UTC，取时转会话时区），GaussDB 行为需在 Pilot 中实测确认。

## 布尔

| MySQL | GaussDB B 模式 | 状态 | 备注 |
|-------|----------------|------|------|
| `BOOL` / `BOOLEAN` (= `TINYINT(1)`) | `BOOLEAN` 或 `TINYINT(1)` | ⚠️ | 工程应统一一种表达，Stage 3 决策 |

## 枚举与集合

| MySQL | GaussDB B 模式 | 状态 | 备注 |
|-------|----------------|------|------|
| `ENUM('a','b')` | `VARCHAR + CHECK` 约束 | 🔄 | 强烈建议改写；B 模式虽有兼容但生态差 |
| `SET('a','b')` | 关联表 或 `VARCHAR` + 应用层拆分 | 🔄 | 同上 |

## JSON

| MySQL | GaussDB B 模式 | 状态 | 备注 |
|-------|----------------|------|------|
| `JSON` | `JSON` 或 `JSONB` | ⚠️ | B 模式支持 JSON；查询函数名可能差异 |

## 几何

| MySQL | GaussDB B 模式 | 状态 | 备注 |
|-------|----------------|------|------|
| `POINT` / `POLYGON` 等 | GaussDB 空间扩展 | ⚠️ | 如工程使用，专项评估 |

## 映射策略声明

每个工程在 Stage 3 必须在 `project-docs/decisions/YYYY-MM-DD-type-mapping-strategy.md` 中声明：

- `TINYINT(1)` 是保留还是改 `BOOLEAN`？
- `DATETIME` 保留还是改 `TIMESTAMP`？
- `ENUM` 是否改写？
- 其他不明确项的选择

**策略一旦定，本工程所有表统一**，不混用。
