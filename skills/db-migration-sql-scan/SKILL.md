---
name: db-migration-sql-scan
description: 扫描工程中所有 SQL 片段（Mapper XML、注解 SQL、字符串拼接 SQL），识别 MySQL 特性用法（相对于瀚高 PG 目标库），按类别与严重度产出风险矩阵。在 Stage 0 的 baseline 之后、Stage 4 改造之前使用。
---

# db-migration-sql-scan

## 触发场景

- Stage 0 baseline 已产出，需要生成风险矩阵
- 随时想重新扫描一次确认风险清单
- Stage 4 改造前的最终风险确认

## 前置条件

- 已执行 `db-migration-baseline`
- `project-docs/facts/` 已有 baseline
- 已获取真实 MySQL schema 导出或只读连接信息；若无法获取，必须把"无法核对真实 schema"列为 blocker，不能继续宣称 Stage 0 完成

## 扫描范围

遍历以下来源，按行提取 SQL：

1. `src/main/resources/mapper/**/*.xml` 与 `src/main/resources/**/mapper/*.xml`
2. `@Select` / `@Insert` / `@Update` / `@Delete` / `@Query` 注解字符串
3. 代码中 `"SELECT ...` / `"INSERT ...` / `"UPDATE ...` / `"DELETE ...` 字符串字面量
4. Flyway 脚本 `db/migration/mysql/*.sql`
5. 其他 `.sql` 文件（`scripts/` 等）

## 检测特性清单

按照 `docs/references/mysql-to-highgo-{syntax,function,type}-mapping.md` 标注为 ⚠️ 或 🔄 的项，分类检测：

### 语法类
- 反引号 `` ` `` 标识符 → **高风险，PG 不支持**，必须改写为双引号或去引号
- `LIMIT m,n` → **高风险，必须改写**（PG 使用 `LIMIT n OFFSET m`）
- `ON DUPLICATE KEY UPDATE` → **高风险，必须改写**（PG 使用 `INSERT ... ON CONFLICT ... DO UPDATE`）
- `REPLACE INTO` → **高风险**（PG 无原生等价，需 `INSERT ... ON CONFLICT` 或改业务逻辑）
- `INSERT IGNORE` → **高风险**（PG 使用 `INSERT ... ON CONFLICT DO NOTHING`）
- `UPDATE ... LIMIT n` / `DELETE ... LIMIT n`
- 多表 `UPDATE t1 JOIN t2 SET`
- `STRAIGHT_JOIN`、`USE INDEX`、`FORCE INDEX` Hint

### 函数类
- `GROUP_CONCAT` → 视瀚高兼容脚本覆盖情况判定，未覆盖时改 `STRING_AGG`
- `IFNULL(a, b)` → 检查实参类型，若非脚本覆盖重载需改写为 `COALESCE(a, b)`
- `IF(cond, a, b)` → 检查实参类型，若非脚本覆盖重载需改写为 `CASE WHEN cond THEN a ELSE b END`
- `DATE_FORMAT(...)` → **高风险，Pilot 首验证项（R-002）**，格式占位符差异大，兼容脚本覆盖有限
- `STR_TO_DATE`
- `UNIX_TIMESTAMP`、`FROM_UNIXTIME`
- `FIND_IN_SET`
- `REGEXP` / `RLIKE`
- JSON 相关：`JSON_EXTRACT`、`->`、`->>`、`JSON_UNQUOTE`、`JSON_CONTAINS`、`JSON_OBJECT`、`JSON_ARRAY`
- `PASSWORD`、`AES_ENCRYPT`

### 类型类
- DDL 中 `TINYINT(1)`、`ENUM`、`SET`、`MEDIUMTEXT`、`LONGTEXT`、`DATETIME`、`TIMESTAMP`
- `AUTO_INCREMENT`
- `ENGINE=InnoDB`、`DEFAULT CHARSET`
- 前缀索引 `KEY x(col(10))`

### 保留字类
对常见保留字（`user`、`type`、`role`、`desc`、`order`、`group`、`level`、`status`）在列名位置的出现做标注（瀚高基于 PG，保留字集与 MySQL 不完全相同，需以 PG 清单为准）。

### 真实 schema 对齐类
- 从 Mapper XML、注解 SQL、字符串 SQL、实体映射、Flyway / Liquibase 脚本中提取静态数据库对象引用
- 与真实 MySQL schema 中的数据库、表、字段清单对比
- 代码引用但真实 schema 中不存在的数据库、表、字段一律标记为 🔴 高风险 blocker
- 动态分表、动态库名、外部库访问必须单独列为 `需人工确认`，不得默认当作存在
- 禁止把测试自行创建的临时库、临时表、影子表或 fixture 表作为真实 schema 存在证据

### 事务与锁
- `SELECT ... FOR UPDATE`
- `LOCK IN SHARE MODE`
- 显式 `SET TRANSACTION ISOLATION LEVEL`

### 存储过程 / 触发器
- `CREATE PROCEDURE`、`CREATE FUNCTION`、`CREATE TRIGGER`、`CREATE EVENT`
- `DELIMITER //`

## 严重度判定

按 `references/` 状态位：

| references 状态 | 默认严重度 |
|-----------------|-----------|
| ✅ 原生兼容 | 🟢 低（审计通过即可） |
| ⚠️ 需验证 | 🟡 中（必须写专项测） |
| 🔄 建议改写 | 🟡 中 或 🔴 高（按改写成本） |
| 存储过程 / 触发器 | 🔴 高 |
| 真实 schema 缺失库、表、字段 | 🔴 高（blocker，必须在 Stage 0 / Stage 1 处理） |

## 执行步骤

1. 遍历扫描范围，每个文件逐行匹配特性
2. 对每个命中构造一条记录：`文件 / 行号 / 上下文 / 命中特性 / 类别 / 严重度 / references 链接`
3. 提取静态数据库对象引用，与真实 MySQL schema 对比，缺失库、表、字段写入 `真实 schema 对齐类` blocker
4. 扫描测试代码与测试 SQL 中的对象 DDL，若发现 `CREATE DATABASE` / `CREATE SCHEMA` / `CREATE TABLE` / `CREATE TEMPORARY TABLE` / `CREATE TABLE ... LIKE ...` / `ALTER TABLE` / `DROP TABLE` / `DROP TEMPORARY TABLE`，标记为测试基线 blocker
5. 去重（同文件同行多次匹配合并）
6. 按"类别"分组，分块写入矩阵
7. 输出到 `<project>/project-docs/facts/YYYY-MM-DD-risk-matrix.md`（模板：`templates/risk-matrix-template.md`）
8. 同时产出一份"命中统计"摘要写入 baseline.md 第 5 节

## 输出

- `<project>/project-docs/facts/YYYY-MM-DD-risk-matrix.md`
- 控制台摘要：命中总数、按严重度分布、高风险 Top 10、真实 schema 缺口数、测试自行创建数据库对象位置数

## 约束

- **不自动改码**
- 不修改已有 baseline.md，只追加第 5 节统计
- 扫描要覆盖动态 SQL 片段中的特性（注意 `<if>` / `<foreach>` 内部 SQL）
- 正则匹配假阳性时，在矩阵中标 `需人工复核` 字段
- 缺失真实 schema 对象必须在 Stage 0 / Stage 1 暴露，不得留到 Stage 4 首次提出
- 任何测试自行创建数据库对象的用例不得作为真实 schema 集成测试通过证据

## 人工复核清单

Skill 产出后，人工必须复核：
1. 高风险条目是否有遗漏
2. 保留字误报（业务词本身就叫 "user"、"type" 但不是保留字场景）
3. 动态 SQL 拼接产生的隐式特性（如字符串拼接出 `LIMIT m,n`）
4. 代码引用但真实 MySQL schema 中不存在的数据库、表、字段是否全部进入 blocker
5. 是否存在通过临时库、临时表、影子表或 fixture 表绕过真实 schema 的测试

## 后续步骤

→ 人工 review 矩阵
→ Stage 1 测试兜底（`db-migration-test-gap` 可辅助）
