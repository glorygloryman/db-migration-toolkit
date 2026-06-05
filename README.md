# db-migration-toolkit

MySQL → 瀚高（HighGo v4.1.5）改造通用工具包。

## 目标

为 `xz-source/` 下 20+ 个 Java/Spring Boot 工程提供**一套可复用**的数据库改造方法论：
- 标准化 SOP 操作手册
- 配套 Claude Code Skills 提效
- 跨工程共享的踩坑库与对照表
- 随 Pilot 验证持续演进

## 当前版本

v0.3.6（2026-06-05 新增 self-check Skill，骨架版，待 Pilot 验证）

## 目录结构

```
db-migration-toolkit/
├── docs/           # 母方案文档（SOP、清单、对照表、模板、风险库）
├── skills/         # Claude Code Skills（软链接入各工程）
├── fix-issue/      # 跨工程共享踩坑库（Pilot 后产出）
└── scripts/        # 辅助脚本（Pilot 后产出）
```

详细入口：[`docs/2026-04-18-master-plan.md`](docs/2026-04-18-master-plan.md)

## 如何在工程中使用 Skills

在目标工程根目录执行：

```bash
# 假设当前工程位于 /Users/cy/MyWorkFactory/workspace/xz-source/<project>/
mkdir -p .claude/skills
cd .claude/skills
ln -s ../../../db-migration-toolkit/skills/db-migration-baseline .
ln -s ../../../db-migration-toolkit/skills/db-migration-sql-scan .
ln -s ../../../db-migration-toolkit/skills/db-migration-test-gap .
ln -s ../../../db-migration-toolkit/skills/db-migration-test-plan .
ln -s ../../../db-migration-toolkit/skills/db-migration-test-execute .
ln -s ../../../db-migration-toolkit/skills/db-migration-dialect-rewrite .
ln -s ../../../db-migration-toolkit/skills/db-migration-verify .
ln -s ../../../db-migration-toolkit/skills/db-migration-self-check .
```

软链方式保证工具包一处修改、所有工程同步生效。

## Skills 清单

| Skill | 作用 | 对应 SOP 阶段 |
|-------|------|---------------|
| `db-migration-baseline` | 产出前置调研三件套 | Stage 0 |
| `db-migration-sql-scan` | 扫描 MySQL 特性用法，生成风险矩阵 | Stage 0 |
| `db-migration-test-gap` | 对比 Mapper 方法 vs 测试覆盖 | Stage 1 |
| `db-migration-test-plan` | 将测试缺口拆分为可执行 Task 计划 | Stage 1 |
| `db-migration-test-execute` | 按 Task 编号执行补测、验证、回写进度 | Stage 1 |
| `db-migration-dialect-rewrite` | 方言差异建议改写（不自动改码），后续由 superpowers 接管执行 | Stage 4 |
| `db-migration-verify` | 跑测试 + 生成验收报告骨架 | Stage 5 |
| `db-migration-self-check` | 验收后扫描 SQL 源码，发现遗漏的 MySQL 方言，输出报告（不阻断） | Stage 5 后 |

## 前提假设

- **目标数据库**：瀚高（HighGo）**v4.1.5**（PostgreSQL 系，非 GaussDB）
- **兼容策略**：PG 方言为基础 + 厂家 MySQL 函数兼容脚本（见 `docs/references/highgo-v4.1.5-mysql-compat-functions.md`）
- **不做数据迁移**，仅做程序适配
- **不改架构**，保留 MyBatis / JPA / JdbcTemplate 原结构
- **集成测试使用本地/共享真实数据库**，禁用 Testcontainers 与 `@MockBean`
- **集成测试必须使用真实数据库中已存在的 schema / 表 / 字段**，禁止测试自行创建数据库对象；缺失库、表、字段必须在 Stage 0 / Stage 1 作为 blocker 暴露

## 数据库测试硬门禁

- 所有数据库集成测试必须连接真实 MySQL / HighGo 数据库，并使用真实数据库中已经存在的 schema、表、字段验证。
- 禁止任何测试代码、测试脚本、测试 fixture、`@Sql`、`@BeforeAll`、测试 support helper、迁移验证工具在测试过程中自行创建或修改数据库对象，包括但不限于 `CREATE DATABASE`、`CREATE SCHEMA`、`CREATE TABLE`、`CREATE TEMPORARY TABLE`、`CREATE TABLE ... LIKE ...`、`ALTER TABLE`、`DROP TABLE`、`DROP TEMPORARY TABLE`。
- 测试数据准备只允许对真实 schema 中已存在的表执行 `INSERT` / `UPDATE` / `DELETE`，并必须具备按测试数据标识清理的 cleanup。
- 如果 Mapper / DAO / SQL 引用的数据库、表或字段在真实 schema 中不存在，必须立即失败并记录为 schema 缺口 / blocker，禁止通过临时库、临时表、影子表、fixture 表绕过。
- Stage 0 / Stage 1 必须扫描代码引用与真实 MySQL schema 的差异；Stage 4 只处理方言差异，不负责首次发现 schema 缺失问题。

## 迭代约定

- Pilot 工程：`stream_keywords_search`（首批验证）
- 每次 Pilot 踩坑，同步回灌到 `fix-issue/` 与相应 SOP / references
- 版本号遵循 SemVer：骨架期 v0.x，Pilot 稳定后升 v1.0.0

## 参考入口

- 总方案：[`docs/2026-04-18-master-plan.md`](docs/2026-04-18-master-plan.md)
- 瀚高 v4.1.5 特性详解：[`docs/references/highgo-v4-compatibility.md`](docs/references/highgo-v4-compatibility.md)
- MySQL 函数兼容脚本说明：[`docs/references/highgo-v4.1.5-mysql-compat-functions.md`](docs/references/highgo-v4.1.5-mysql-compat-functions.md)
- 已知风险：[`docs/risks/known-risks-highgo.md`](docs/risks/known-risks-highgo.md)
