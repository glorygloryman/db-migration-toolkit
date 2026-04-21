# MySQL → GaussDB 通用改造母方案

- **版本**：v0.1.0
- **日期**：2026-04-18
- **状态**：DRAFT（骨架版，待 Pilot 验证）
- **适用范围**：`xz-source/` 下所有使用 MySQL 的 Java / Spring Boot 工程
- **目标数据库**：GaussDB，**B 兼容模式（MySQL 兼容）**

---

## 1. 总体思路

采用 **"调研 → 测试兜底 → 静态扫描 → 分层改造 → 验证交付"** 五段式 SOP。

### 1.1 核心原则

1. **TDD 兜底**：无测试的模块先补测试再改造（遵循 `~/.claude/CLAUDE.md` §2、§3.1）
2. **不改架构，只做方言适配**：保留 MyBatis / JPA / JdbcTemplate 原结构
3. **Flyway 新建迁移**，禁止改历史脚本（遵循 CLAUDE.md §3.6）
4. **集成测试用真实数据库**，禁用 Mock / Testcontainers（遵循 CLAUDE.md §2.2）
5. **按工程独立推进**，每个工程产出同构的验收报告
6. **踩坑即回灌**：每次 Pilot 发现问题，同步写入 `fix-issue/` 与相关 references

### 1.2 B 兼容模式下的改造量预估

因 GaussDB B 模式原生兼容大量 MySQL 语法（反引号、`LIMIT m,n`、`ON DUPLICATE KEY UPDATE`、`AUTO_INCREMENT`、`GROUP_CONCAT`、`IFNULL`、`DATE_FORMAT`、`TINYINT(1)` 等），Stage 4（方言适配）工作量较 PG 模式下降 60%~80%。

**但仍需验证的差异点**（详见 `references/gaussdb-compatibility-modes.md`）：
- JDBC 驱动（`gaussdbjdbc`，非 `mysql-connector`）
- 连接池 SQL Parser（Druid `dbType`）
- 字符集与排序规则
- 时区处理与 `TIMESTAMP` 语义
- 保留字清单（与 MySQL 有差异）
- 部分边缘函数行为
- 存储过程 / 触发器语法（若工程使用）
- 执行计划与性能特征

---

## 2. 五段式 SOP 概览

| 阶段 | 名称 | 预计工期 | 主要产出 | 详细手册 |
|------|------|---------|---------|---------|
| Stage 0 | 立项与基线 | 0.5 天 | 前置调研三件套 | [`sop/stage-0-kickoff.md`](sop/stage-0-kickoff.md) |
| Stage 1 | 测试兜底 | 1~3 天 | 关键路径测试覆盖 + MySQL 下基线快照 | [`sop/stage-1-test-baseline.md`](sop/stage-1-test-baseline.md) |
| Stage 2 | 依赖与配置切换 | 0.5 天 | 驱动 / 连接池 / 方言 / Flyway 配置切换 | [`sop/stage-2-config-switch.md`](sop/stage-2-config-switch.md) |
| Stage 3 | Schema 迁移 | 1~2 天 | Flyway 新建 gaussdb 目录 + DDL 脚本 | [`sop/stage-3-schema-migration.md`](sop/stage-3-schema-migration.md) |
| Stage 4 | SQL 方言适配 | 按扫描报告排期 | 分类别 commit，每类测试绿 | [`sop/stage-4-dialect-adapt.md`](sop/stage-4-dialect-adapt.md) |
| Stage 5 | 回归与交付 | 0.5~1 天 | GaussDB 下全绿 + 验收报告 | [`sop/stage-5-verify-deliver.md`](sop/stage-5-verify-deliver.md) |

---

## 3. 前置调研三件套

每个工程进入 Stage 0 必须产出，存于该工程 `project-docs/facts/` 目录：

| 产出物 | 文件名 | 模板 |
|--------|--------|------|
| 基线现状 | `YYYY-MM-DD-db-migration-baseline.md` | [`templates/baseline-template.md`](templates/baseline-template.md) |
| 风险矩阵 | `YYYY-MM-DD-risk-matrix.md` | [`templates/risk-matrix-template.md`](templates/risk-matrix-template.md) |
| 测试缺口 | `YYYY-MM-DD-test-gap.md` | [`templates/test-gap-template.md`](templates/test-gap-template.md) |

---

## 4. 配套 Skills

| Skill | 对应阶段 | 核心作用 |
|-------|---------|---------|
| `db-migration-baseline` | Stage 0 | 扫描工程，生成前置调研三件套骨架 |
| `db-migration-sql-scan` | Stage 0 | 基于正则 + 人工 review 扫描 MySQL 特性用法 |
| `db-migration-test-gap` | Stage 1 | 对比 Mapper 方法与测试覆盖，输出补测清单 |
| `db-migration-schema-convert` | Stage 3 | 生成 GaussDB DDL 对照稿 |
| `db-migration-dialect-rewrite` | Stage 4 | 针对差异点给出建议改写 diff（不自动改码） |
| `db-migration-verify` | Stage 5 | 跑测试 + 生成验收报告骨架 |

软链引用方式见 `README.md`。

---

## 5. 通用检查清单

- [前置调研清单](checklists/pre-research-checklist.md) — Stage 0 出口检查
- [改造 PR 清单](checklists/migration-pr-checklist.md) — 贴入每个 PR 模板
- [验收清单](checklists/acceptance-checklist.md) — Stage 5 出口检查

---

## 6. 对照参考库

- [类型映射表](references/mysql-to-gaussdb-type-mapping.md)
- [语法映射表](references/mysql-to-gaussdb-syntax-mapping.md)
- [函数映射表](references/mysql-to-gaussdb-function-mapping.md)
- [兼容模式详解](references/gaussdb-compatibility-modes.md)

---

## 7. 风险库

- [GaussDB 已知风险](risks/known-risks-gaussdb.md)
- 各工程 Pilot 发现的新风险 → 同步回灌到 `fix-issue/`

---

## 8. Pilot 流程与迭代机制

### 8.1 Pilot 工程
首批：`stream_keywords_search`

### 8.2 Pilot 输出
- 完整执行一次五段式 SOP
- 每个阶段结束后填写"SOP 反馈表"（`templates/` 后续补齐）
- 发现的问题 / 盲点 / 可优化项 → 提 issue 到本仓库

### 8.3 框架演进
- Pilot 中集中修改本仓库内容
- 每次修改走 PR，CHANGELOG 记录
- Pilot 结束后评审，发布 v1.0.0
- 后续工程按 v1.0.0 执行，非必要不再改框架

---

## 9. 命名约定

- 日期前缀：所有工程文档 `YYYY-MM-DD-*.md`（遵循 CLAUDE.md §4）
- Flyway 脚本：`V{timestamp}__gaussdb_{description}.sql`，置于 `db/migration/gaussdb/`
- 改造分支：`feature/db-migration-gaussdb`
- 集成测试 profile：`integration-gaussdb` / `integration-mysql-baseline`

---

## 10. 不在范围内（显式排除）

- ❌ 数据迁移（DML 数据搬运、双写、回滚）
- ❌ 架构重构（分库分表、读写分离调整）
- ❌ 性能调优（执行计划优化、索引重设计）
- ❌ 灰度切换（双写双读、流量切分）

如 Pilot 发现上述问题**不可回避**，记录到 `risks/` 并上升沟通，不在本方案 SOP 内自行处理。
