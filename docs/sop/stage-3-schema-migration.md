# Stage 3 — Schema 迁移（瀚高 v4.1.5）

## 目标

把 MySQL 的表结构、索引、约束、序列、视图在瀚高 v4.1.5 上重建，产出 Flyway 迁移脚本，不涉及数据搬运。

## 预计工期

1~2 天，取决于表数量与复杂度。

## 输入

- MySQL 当前生产 Schema（由 DBA 或 `mysqldump --no-data` 导出）
- 目标瀚高版本（已确认为 **v4.1.5**，基于 PostgreSQL 内核）
- Stage 2 的 `db/migration/highgo/` 目录

## 步骤

### 3.1 导出 MySQL Schema

```bash
mysqldump -h <host> -u <user> -p \
  --no-data --routines --triggers --events \
  <db_name> > mysql-schema.sql
```

### 3.2 工具辅助转换（Skill `db-migration-schema-convert`）

调用 Skill，产出初稿 `highgo-schema-draft.sql`。

Skill 会自动处理的常见差异：
- `AUTO_INCREMENT` → `GENERATED ALWAYS AS IDENTITY` 或 `BIGSERIAL`
- `ENGINE=InnoDB` / `DEFAULT CHARSET=utf8mb4` → 瀚高对应 `WITH` 子句或移除
- `COMMENT` 子句语法（列注释）
- `DATETIME` / `TIMESTAMP` 保留或转换
- 索引语法
- 保留字列名自动加引号

### 3.3 人工 review（必须）

按以下清单逐表 review：

**类型映射**（详表见 `references/mysql-to-highgo-type-mapping.md`）：
- `TINYINT(1)` → 改 `BOOLEAN`（PG 无 TINYINT 类型，统一策略并记录）
- `DATETIME` vs `TIMESTAMP`：PG 无 DATETIME，前者建议改 `TIMESTAMP WITHOUT TIME ZONE`；后者推荐 `TIMESTAMPTZ`
- `TEXT` / `MEDIUMTEXT` / `LONGTEXT` → 统一 `TEXT`（PG TEXT 无长度限制）
- `JSON` → 推荐 `JSONB`；查询函数名完全不同，见 function-mapping
- `ENUM` → 改 `VARCHAR + CHECK` 约束
- `SET` → 改关联表 或 `VARCHAR` + 应用层拆分

**字符集与排序**：
- MySQL `utf8mb4_general_ci` 大小写不敏感的比较，瀚高需注意排序规则（collation）配置
- 若有大小写不敏感比较依赖，显式加 `COLLATE` 或应用层处理

**保留字**：
- 详见 `references/mysql-to-highgo-syntax-mapping.md`
- 冲突列名统一加双引号，或改名（改名需同步改代码，成本高）

**索引与约束**：
- 外键约束：检查是否被 `ON DELETE CASCADE` 依赖
- 唯一索引：NULL 值行为差异（MySQL 允许多个 NULL，瀚高同样允许）
- 前缀索引 `KEY idx(col(10))`：瀚高不支持，改用 `SUBSTR(col, 1, 10)` 函数索引或去前缀

**自增与序列**：
- `AUTO_INCREMENT` → `GENERATED ALWAYS AS IDENTITY`（PG 10+ 推荐）或 `BIGSERIAL`
- 代码端 `useGeneratedKeys="true"` 与 `RETURNING id` 配合，行为确认
- 工程首选方案一次性决定，记录到 `project-docs/decisions/YYYY-MM-DD-type-mapping-strategy.md`

**默认值与函数**：
- `DEFAULT CURRENT_TIMESTAMP` → 支持
- `ON UPDATE CURRENT_TIMESTAMP` → **PG 不原生支持**，需触发器模拟 或 应用层赋值
- `DEFAULT (UUID())` → PG 用 `gen_random_uuid()`（pgcrypto 扩展）

### 3.4 产出 Flyway 脚本

命名：`V{YYYYMMDDHHmm}__highgo_init_schema.sql`

放置：`src/main/resources/db/migration/highgo/`

脚本规范（CLAUDE.md §3.6）：
- 所有 `CREATE TABLE` 带 `IF NOT EXISTS`
- 所有 `CREATE INDEX` 带 `IF NOT EXISTS`
- 不含 `DROP DATABASE` / `TRUNCATE`
- 大变更拆多个 `V` 脚本，不堆叠一个巨型文件

### 3.5 基础数据与配置

若 MySQL 侧有业务初始化数据（字典表、菜单权限等）：
- 使用 `R__highgo_seed_dictionary.sql`（repeatable）或 `V{n}__highgo_seed_xxx.sql`
- 或通过 Stage 1 的集成测试 `@Sql` 注入

### 3.6 Flyway 执行验证

```bash
mvn -P integration-highgo flyway:migrate
```

验证：
- 所有脚本执行无错
- 瀚高中 `flyway_schema_history` 表有记录
- 表、索引、约束对齐预期

### 3.7 Schema 对比校验

工具：`liquibase diff` 或手写 SQL 对比脚本

对比项：
- 表数量
- 每表列数、列名、类型（按映射规则）
- 索引名与列组合
- 外键关系

产出：`project-docs/reports/YYYY-MM-DD-schema-diff.md`

### 3.8 DDL 防护语法冒烟（R-018）

全局 CLAUDE.md §3.6 要求 Flyway 脚本含防护语法。**PG 对某些防护写法支持不完整**，Stage 3 开始前必须对本工程使用的防护写法在瀚高 v4.1.5 下冒烟：

```sql
-- 冒烟（任意 schema 下执行，完后清理）

-- 1. CREATE TABLE IF NOT EXISTS（PG 9.1+ 支持）
CREATE TABLE IF NOT EXISTS _smoke_t (id INT);

-- 2. DROP TABLE IF EXISTS（PG 8.0+ 支持）
DROP TABLE IF EXISTS _smoke_t;

-- 3. CREATE INDEX IF NOT EXISTS（PG 9.5+ 支持）
CREATE TABLE _smoke_t (id INT, name VARCHAR(20));
CREATE INDEX IF NOT EXISTS idx_smoke_name ON _smoke_t (name);
DROP INDEX IF EXISTS idx_smoke_name;

-- 4. ALTER TABLE ADD COLUMN IF NOT EXISTS（PG 9.6+ 支持）
ALTER TABLE _smoke_t ADD COLUMN IF NOT EXISTS age INT;
ALTER TABLE _smoke_t DROP COLUMN IF EXISTS age;

-- 5. ADD CONSTRAINT IF NOT EXISTS（⚠️ PG 不直接支持此语法）
-- MySQL 可以：ALTER TABLE t ADD CONSTRAINT IF NOT EXISTS xxx ...
-- PG 必须通过 DO 块 + 查 pg_constraint 模拟
-- 本工具包建议：约束名固定后用"先 DROP IF EXISTS、再 ADD"的模式

-- 清理
DROP TABLE IF EXISTS _smoke_t;
```

任一冒烟失败，记录到 `project-docs/fix-issue/` 并同步更新 `docs/references/mysql-to-highgo-syntax-mapping.md` DDL 节的"状态"列。

### 3.9 回写风险矩阵中的 Stage3 承接项

Stage 3 结束前必须回写 `risk-matrix.md` 中由 Schema 迁移承接的风险项，避免 DDL / Schema 风险遗留到 Stage 5 前才补关。

可在 Stage 3 直接关闭的风险必须同时满足：

1. 风险边界仅限 DDL / Schema 资产，不依赖 Mapper / DAO 运行时行为。
2. Stage 3 已有直接证据，例如 schema convert report、目标 DDL 扫描、DDL asset test、schema diff 或 DDL guard smoke。
3. 后续阶段不会再验证该风险的核心行为。

典型可关闭项：

- `AUTO_INCREMENT` 已映射为 identity / sequence，并验证起始值策略。
- `ENGINE` / `DEFAULT CHARSET` / `COLLATE` / `ROW_FORMAT` 已从目标 DDL 移除。
- 内联 `COMMENT` / 表级 `COMMENT='...'` 已转为 `COMMENT ON TABLE/COLUMN`。
- `USING BTREE` / 内联 `KEY` 已转为目标库索引语法，并验证索引存在。

以下风险不得仅凭 Stage 3 关闭，只能在备注中记录"Stage3 DDL 部分已完成"，并保留到 Stage 4 / Stage 5 真库验证后关闭：

- `tinyint` / `jdbcType=TINYINT` 等同时涉及 Mapper 参数绑定的类型风险。
- `datetime` / `timestamp` / `jdbcType=TIMESTAMP` 等时间读写语义风险。
- `longtext` / `jdbcType=LONGVARCHAR` 等大字段读写风险。
- 字符集 / collation 移除后仍涉及大小写、排序、`LIKE` 语义的查询风险。

回写备注必须写清关闭证据，至少包含：

- Stage 3 报告或决策记录路径。
- 目标 DDL 或目标库验证结果。
- 资产测试 / schema diff / 冒烟命令及结果。

## 出口检查

- [ ] `db/migration/highgo/V*__init_schema.sql` 脚本可重复执行不报错
- [ ] 所有表、索引、约束已建立
- [ ] 类型映射、保留字、字符集策略已记录并应用
- [ ] Schema 对比报告已产出，无遗漏
- [ ] `risk-matrix.md` 中由 Stage 3 承接的 DDL / Schema 风险已回写状态与备注；跨层风险已标明 Stage 3 完成部分和后续验证阶段
- [ ] 未修改 `db/migration/mysql/` 任何文件

## 产出物

- `V*__highgo_init_schema.sql`（可能多个）
- `project-docs/reports/YYYY-MM-DD-schema-diff.md`
- `project-docs/decisions/YYYY-MM-DD-type-mapping-strategy.md`（本工程类型映射决策）
- 更新后的 `risk-matrix.md`（Stage 3 承接项状态与备注）

## 下一阶段

→ [Stage 4 — SQL 方言适配](stage-4-dialect-adapt.md)
