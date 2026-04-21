---
name: db-migration-sql-scan
description: 扫描工程中所有 SQL 片段（Mapper XML、注解 SQL、字符串拼接 SQL），识别 MySQL 特性用法，按类别与严重度产出风险矩阵。在 Stage 0 的 baseline 之后、Stage 4 改造之前使用。
---

# db-migration-sql-scan

## 触发场景

- Stage 0 baseline 已产出，需要生成风险矩阵
- 随时想重新扫描一次确认风险清单
- Stage 4 改造前的最终风险确认

## 前置条件

- 已执行 `db-migration-baseline`
- `project-docs/facts/` 已有 baseline

## 扫描范围

遍历以下来源，按行提取 SQL：

1. `src/main/resources/mapper/**/*.xml` 与 `src/main/resources/**/mapper/*.xml`
2. `@Select` / `@Insert` / `@Update` / `@Delete` / `@Query` 注解字符串
3. 代码中 `"SELECT ...` / `"INSERT ...` / `"UPDATE ...` / `"DELETE ...` 字符串字面量
4. Flyway 脚本 `db/migration/mysql/*.sql`
5. 其他 `.sql` 文件（`scripts/` 等）

## 检测特性清单

按照 `docs/references/mysql-to-gaussdb-{syntax,function,type}-mapping.md` 标注为 ⚠️ 或 🔄 的项，分类检测：

### 语法类
- 反引号 `` ` `` 标识符
- `LIMIT m,n`（B 模式兼容，仍标记供审计）
- `ON DUPLICATE KEY UPDATE`
- `REPLACE INTO`
- `INSERT IGNORE`
- `UPDATE ... LIMIT n` / `DELETE ... LIMIT n`
- 多表 `UPDATE t1 JOIN t2 SET`
- `STRAIGHT_JOIN`、`USE INDEX`、`FORCE INDEX` Hint

### 函数类
- `GROUP_CONCAT`
- `IFNULL`、`IF()`
- `DATE_FORMAT`、`STR_TO_DATE`
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
对常见保留字（`user`、`type`、`role`、`desc`、`order`、`group`、`level`、`status`）在列名位置的出现做标注。

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

## 执行步骤

1. 遍历扫描范围，每个文件逐行匹配特性
2. 对每个命中构造一条记录：`文件 / 行号 / 上下文 / 命中特性 / 类别 / 严重度 / references 链接`
3. 去重（同文件同行多次匹配合并）
4. 按"类别"分组，分块写入矩阵
5. 输出到 `<project>/project-docs/facts/YYYY-MM-DD-risk-matrix.md`（模板：`templates/risk-matrix-template.md`）
6. 同时产出一份"命中统计"摘要写入 baseline.md 第 5 节

## 输出

- `<project>/project-docs/facts/YYYY-MM-DD-risk-matrix.md`
- 控制台摘要：命中总数、按严重度分布、高风险 Top 10

## 约束

- **不自动改码**
- 不修改已有 baseline.md，只追加第 5 节统计
- 扫描要覆盖动态 SQL 片段中的特性（注意 `<if>` / `<foreach>` 内部 SQL）
- 正则匹配假阳性时，在矩阵中标 `需人工复核` 字段

## 人工复核清单

Skill 产出后，人工必须复核：
1. 高风险条目是否有遗漏
2. 保留字误报（业务词本身就叫 "user"、"type" 但不是保留字场景）
3. 动态 SQL 拼接产生的隐式特性（如字符串拼接出 `LIMIT m,n`）

## 后续步骤

→ 人工 review 矩阵
→ Stage 1 测试兜底（`db-migration-test-gap` 可辅助）
