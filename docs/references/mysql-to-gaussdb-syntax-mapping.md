# 语法映射表（MySQL → GaussDB B 兼容模式）

> B 模式原生兼容大量 MySQL 语法，本表重点标注**仍需注意**的差异。
> 状态：✅ 直接可用 / ⚠️ 需验证 / 🔄 建议改写

## 标识符与保留字

| MySQL | GaussDB B 模式 | 状态 | 说明 |
|-------|----------------|------|------|
| 反引号 `` `col` `` | 反引号 `` `col` `` | ✅ | B 模式支持 |
| 双引号 `"col"` | 双引号 `"col"` | ✅ | SQL 标准 |
| 保留字作列名 | 加引号 | ⚠️ | B 模式放宽部分保留字，仍有差异清单 |
| 标识符大小写 | 默认转小写（PG 行为） | ⚠️ | B 模式可能调整，需验证参数 |

**统一建议**：所有 SQL 标识符使用**全小写 + 下划线**，不依赖大小写保留。

## DML

| MySQL | GaussDB B 模式 | 状态 | 说明 |
|-------|----------------|------|------|
| `LIMIT count` | 同 | ✅ | |
| `LIMIT offset, count` | 同 | ✅ | B 模式兼容 |
| `LIMIT count OFFSET offset` | 同 | ✅ | SQL 标准，均支持 |
| `INSERT IGNORE` | 同 | ✅ | |
| `ON DUPLICATE KEY UPDATE` | 同 | ✅ | |
| `REPLACE INTO` | 同 | ✅ | |
| `INSERT ... SELECT` | 同 | ✅ | |
| 多值 `INSERT VALUES (),(),(),...` | 同 | ✅ | |
| `UPDATE ... LIMIT n` | 同 | ⚠️ | B 模式支持，PG 模式不支持 |
| `DELETE ... LIMIT n` | 同 | ⚠️ | 同上 |
| `UPDATE t1 JOIN t2 SET ...` | 同 | ⚠️ | B 模式支持多表 UPDATE |

## DDL

| MySQL | GaussDB B 模式 | 状态 | 说明 |
|-------|----------------|------|------|
| `CREATE TABLE ... ENGINE=InnoDB` | `CREATE TABLE ...` | 🔄 | ENGINE 子句建议去除 |
| `DEFAULT CHARSET=utf8mb4` | 库级字符集 | 🔄 | 表级字符集通常去除 |
| `AUTO_INCREMENT` | 同 | ✅ | B 模式原生支持 |
| `AUTO_INCREMENT=100`（表起始值） | 同 | ⚠️ | 验证 |
| `KEY idx (col(10))`（前缀索引） | 不支持 | 🔄 | 改函数索引或去前缀 |
| `UNIQUE KEY` | `UNIQUE` | ✅ | |
| `FULLTEXT INDEX` | GaussDB 全文索引方案不同 | 🔄 | 专项评估 |
| `COMMENT '...'`（列/表） | 同 | ⚠️ | B 模式支持 |
| `ON UPDATE CURRENT_TIMESTAMP` | 同 | ⚠️ | B 模式支持，行为验证 |

## 查询

| MySQL | GaussDB B 模式 | 状态 | 说明 |
|-------|----------------|------|------|
| `GROUP BY` 允许非聚合列 | 严格模式可能禁止 | ⚠️ | B 模式行为需验证，若严格需加聚合 |
| `ORDER BY RAND()` | `ORDER BY RANDOM()` 或 `ORDER BY RAND()` | ⚠️ | 函数名差异 |
| `STRAIGHT_JOIN` | — | 🔄 | 去除，让优化器决定 |
| `USE INDEX` / `FORCE INDEX` Hint | GaussDB 有自己的 Hint 语法 | 🔄 | 如使用需改写 |
| 子查询 `(SELECT ...)` | 同 | ✅ | |
| `WITH` CTE | 同 | ✅ | 均支持 |
| `LATERAL` | PG 支持，MySQL 8 支持 | ✅ | |

## 事务

| MySQL | GaussDB B 模式 | 状态 | 说明 |
|-------|----------------|------|------|
| `START TRANSACTION` / `BEGIN` / `COMMIT` / `ROLLBACK` | 同 | ✅ | |
| `SAVEPOINT` / `RELEASE SAVEPOINT` | 同 | ✅ | |
| `SELECT ... FOR UPDATE` | 同 | ⚠️ | 锁行为在 MVCC 下可能不同 |
| `SELECT ... LOCK IN SHARE MODE` | `SELECT ... FOR SHARE` | 🔄 | 建议改 FOR SHARE |
| 隔离级别 `READ COMMITTED` | 同 | ✅ | |
| 隔离级别 `REPEATABLE READ` | 同 | ⚠️ | MVCC 实现差异，幻读行为可能不同 |

## 管理与元数据

| MySQL | GaussDB B 模式 | 状态 | 说明 |
|-------|----------------|------|------|
| `SHOW TABLES` | 同 或 `\dt` | ⚠️ | B 模式支持 SHOW 系列 |
| `SHOW CREATE TABLE t` | 同 | ⚠️ | B 模式支持 |
| `DESC t` / `DESCRIBE t` | 同 | ⚠️ | |
| `information_schema.*` | 同 | ✅ | |
| `EXPLAIN` | 同（输出格式不同） | ⚠️ | 计划格式差异，不影响 SQL 本身 |

## 存储过程 / 触发器

**本方案默认不重写**，如工程依赖，单独评估。

- MySQL `DELIMITER //` 分隔符语法
- `CREATE PROCEDURE` / `CREATE TRIGGER` 语法
- 局部变量声明 `DECLARE`
- 游标、异常处理

B 模式对此类有**部分兼容**，但不完整。建议上移到 Java 层。
