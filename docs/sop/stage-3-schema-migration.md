# Stage 3 — Schema 迁移

## 目标

把 MySQL 的表结构、索引、约束、序列、视图在 GaussDB 上重建，产出 Flyway 迁移脚本，不涉及数据搬运。

## 预计工期

1~2 天，取决于表数量与复杂度。

## 输入

- MySQL 当前生产 Schema（由 DBA 或 `mysqldump --no-data` 导出）
- Stage 2 的 `db/migration/gaussdb/` 目录

## 步骤

### 3.1 导出 MySQL Schema

```bash
mysqldump -h <host> -u <user> -p \
  --no-data --routines --triggers --events \
  <db_name> > mysql-schema.sql
```

### 3.2 工具辅助转换（Skill `db-migration-schema-convert`）

调用 Skill，产出初稿 `gaussdb-schema-draft.sql`。

Skill 会自动处理的常见差异：
- `AUTO_INCREMENT` → `AUTO_INCREMENT`（B 模式原生支持）或 `IDENTITY`
- `ENGINE=InnoDB` / `DEFAULT CHARSET=utf8mb4` → GaussDB 对应 `WITH` 子句或移除
- `COMMENT` 子句语法（列注释）
- `DATETIME` / `TIMESTAMP` 保留或转换
- 索引语法
- 保留字列名自动加引号

### 3.3 人工 review（必须）

按以下清单逐表 review：

**类型映射**（详表见 `references/mysql-to-gaussdb-type-mapping.md`）：
- `TINYINT(1)` → 保持 `TINYINT` 或改 `BOOLEAN`？统一策略并记录
- `DATETIME` vs `TIMESTAMP`：时区语义差异
- `TEXT` / `MEDIUMTEXT` / `LONGTEXT` → B 模式兼容，确认大小上限
- `JSON` → B 模式支持，确认查询函数
- `ENUM` → 建议改为 `VARCHAR` + CHECK 约束（B 模式虽兼容但维护成本高）
- `SET` → 建议改为关联表

**字符集与排序**：
- MySQL `utf8mb4_general_ci` 大小写不敏感的比较，GaussDB 需注意排序规则（collation）配置
- 若有大小写不敏感比较依赖，显式加 `COLLATE` 或应用层处理

**保留字**：
- 详见 `references/mysql-to-gaussdb-syntax-mapping.md`
- 冲突列名统一加双引号，或改名（改名需同步改代码，成本高）

**索引与约束**：
- 外键约束：检查是否被 `ON DELETE CASCADE` 依赖
- 唯一索引：NULL 值行为差异（MySQL 允许多个 NULL，GaussDB 同样允许）
- 前缀索引 `KEY idx(col(10))`：GaussDB 不支持，改用 `SUBSTR(col, 1, 10)` 函数索引或去前缀

**自增与序列**：
- B 模式下 `AUTO_INCREMENT` 原生支持，初值与步长参数验证
- 若 Schema 转为 `IDENTITY`，代码端 `useGeneratedKeys="true"` 行为确认

**默认值与函数**：
- `DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` → B 模式支持，但行为需验证
- `DEFAULT (UUID())` → GaussDB 函数名差异

### 3.4 产出 Flyway 脚本

命名：`V{YYYYMMDDHHmm}__gaussdb_init_schema.sql`

放置：`src/main/resources/db/migration/gaussdb/`

脚本规范（CLAUDE.md §3.6）：
- 所有 `CREATE TABLE` 带 `IF NOT EXISTS`
- 所有 `CREATE INDEX` 带 `IF NOT EXISTS`
- 不含 `DROP DATABASE` / `TRUNCATE`
- 大变更拆多个 `V` 脚本，不堆叠一个巨型文件

### 3.5 基础数据与配置

若 MySQL 侧有业务初始化数据（字典表、菜单权限等）：
- 使用 `R__gaussdb_seed_dictionary.sql`（repeatable）或 `V{n}__gaussdb_seed_xxx.sql`
- 或通过 Stage 1 的集成测试 `@Sql` 注入

### 3.6 Flyway 执行验证

```bash
mvn -P integration-gaussdb flyway:migrate
```

验证：
- 所有脚本执行无错
- GaussDB 中 `flyway_schema_history` 表有记录
- 表、索引、约束对齐预期

### 3.7 Schema 对比校验

工具：`liquibase diff` 或手写 SQL 对比脚本

对比项：
- 表数量
- 每表列数、列名、类型（按映射规则）
- 索引名与列组合
- 外键关系

产出：`project-docs/reports/YYYY-MM-DD-schema-diff.md`

## 出口检查

- [ ] `db/migration/gaussdb/V*__init_schema.sql` 脚本可重复执行不报错
- [ ] 所有表、索引、约束已建立
- [ ] 类型映射、保留字、字符集策略已记录并应用
- [ ] Schema 对比报告已产出，无遗漏
- [ ] 未修改 `db/migration/mysql/` 任何文件

## 产出物

- `V*__gaussdb_init_schema.sql`（可能多个）
- `project-docs/reports/YYYY-MM-DD-schema-diff.md`
- `project-docs/decisions/YYYY-MM-DD-type-mapping-strategy.md`（本工程类型映射决策）

## 下一阶段

→ [Stage 4 — SQL 方言适配](stage-4-dialect-adapt.md)
