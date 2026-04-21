---
name: db-migration-schema-convert
description: 把 MySQL Schema 转换为 GaussDB B 兼容模式 DDL 初稿，标注保留字与类型冲突。Stage 3 Schema 迁移使用。
---

# db-migration-schema-convert

## 触发场景

- Stage 3 开始，已有 MySQL Schema 导出
- 需要生成 GaussDB Flyway 脚本初稿

## 前置条件

- 已有 MySQL Schema 导出文件（`mysqldump --no-data` 或手写 DDL）
- 已完成 Stage 0（baseline + risk-matrix）
- 已读 `docs/references/mysql-to-gaussdb-type-mapping.md`

## 输入

- MySQL Schema SQL 文件路径
- 目标输出路径（`<project>/src/main/resources/db/migration/gaussdb/`）
- 本工程的类型映射决策（若已有）

## 执行步骤

### 1. 解析 MySQL DDL

- 按 `CREATE TABLE ... ;` 分段
- 提取每表：列定义、索引、约束、表选项

### 2. 表级改写

- 去除 `ENGINE=InnoDB`、`DEFAULT CHARSET=xxx`、`COLLATE=xxx`（或按决策保留）
- `AUTO_INCREMENT=100` 起始值：B 模式支持，保留
- 表注释 `COMMENT='...'`：保留
- 添加 `IF NOT EXISTS`（CLAUDE.md §3.6）

### 3. 列级改写

按 `references/mysql-to-gaussdb-type-mapping.md` 映射：
- `MEDIUMINT` → `INTEGER`
- `TINYTEXT` → `VARCHAR(255)`
- `MEDIUMTEXT` → `TEXT`
- `ENUM` → `VARCHAR(n) + CHECK` 约束（附带注释说明原枚举值）
- `SET` → 标记待人工决策（拆关联表 或 VARCHAR）
- `UNSIGNED` → 升格
- 其他按表保留

列注释 `COMMENT '...'`：保留。

### 4. 保留字处理

检测列名是否命中 GaussDB 保留字清单：
- 命中 → 加双引号（`"user"`）或建议改名（加注释 `-- TODO: 原列名冲突保留字，建议改名为 xxx`）
- 默认策略：加双引号（改名影响代码面，决策风险大）

### 5. 索引处理

- 普通 `KEY idx (col)` → `CREATE INDEX IF NOT EXISTS idx_x ON t(col)`
- `UNIQUE KEY` → `UNIQUE` 约束或 `CREATE UNIQUE INDEX`
- **前缀索引 `KEY idx (col(10))`**：标记 TODO，建议改为函数索引或去前缀
- `FULLTEXT INDEX`：标记 TODO，单独评估
- 索引名保持一致

### 6. 外键与约束

- 保留 `FOREIGN KEY ... ON DELETE / ON UPDATE`
- `CHECK` 约束保留

### 7. 大小写规范化

- 所有表名、列名、索引名统一小写
- 若原 Schema 有大写字母，输出中统一转小写并加警告注释

### 8. 分文件写入

- 所有表 DDL → `V{timestamp}__gaussdb_init_schema.sql`
- 如果表很多（> 50），拆成多个版本号递增的脚本（按模块聚合）
- 索引单独 → `V{timestamp+1}__gaussdb_init_indexes.sql`（可选）

### 9. 输出转换报告

另写 `project-docs/reports/YYYY-MM-DD-schema-convert-report.md`：
- 每表转换摘要
- 所有 TODO 项清单（保留字、前缀索引、ENUM、SET、FULLTEXT）
- 类型改写统计
- 需人工决策项

## 输出

- `<project>/src/main/resources/db/migration/gaussdb/V*.sql`
- `<project>/project-docs/reports/YYYY-MM-DD-schema-convert-report.md`

## 约束

- **不自动修改 `db/migration/mysql/` 任何脚本**
- 输出脚本必须含 `IF NOT EXISTS` 防护
- 无 `DROP` / `TRUNCATE`
- TODO 项必须显式注释，不暗改

## 人工复核要点

- 每个 TODO 项必须给出决策（改写 / 保留 / 推迟）
- 类型映射决策记录到 `project-docs/decisions/YYYY-MM-DD-type-mapping-strategy.md`
- 在 GaussDB 测试环境执行一次 Flyway migrate 验证

## 后续步骤

→ Schema 对比验证
→ 进入 Stage 4 方言适配
