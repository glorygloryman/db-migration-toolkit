# db-migration-toolkit

MySQL → GaussDB（及其他关系型数据库）改造通用工具包。

## 目标

为 `xz-source/` 下 20+ 个 Java/Spring Boot 工程提供**一套可复用**的数据库改造方法论：
- 标准化 SOP 操作手册
- 配套 Claude Code Skills 提效
- 跨工程共享的踩坑库与对照表
- 随 Pilot 验证持续演进

## 当前版本

v0.1.0（2026-04-18 首发，骨架版，待 Pilot 验证后迭代至 v1.0.0）

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
ln -s ../../../db-migration-toolkit/skills/db-migration-dialect-rewrite .
ln -s ../../../db-migration-toolkit/skills/db-migration-schema-convert .
ln -s ../../../db-migration-toolkit/skills/db-migration-verify .
```

软链方式保证工具包一处修改、所有工程同步生效。

## Skills 清单

| Skill | 作用 | 对应 SOP 阶段 |
|-------|------|---------------|
| `db-migration-baseline` | 产出前置调研三件套 | Stage 0 |
| `db-migration-sql-scan` | 扫描 MySQL 特性用法，生成风险矩阵 | Stage 0 |
| `db-migration-test-gap` | 对比 Mapper 方法 vs 测试覆盖 | Stage 1 |
| `db-migration-schema-convert` | 生成 GaussDB DDL 对照稿 | Stage 3 |
| `db-migration-dialect-rewrite` | 方言差异建议改写（不自动改码） | Stage 4 |
| `db-migration-verify` | 跑测试 + 生成验收报告骨架 | Stage 5 |

## 前提假设

- **目标数据库**：GaussDB，**B 兼容模式（MySQL 兼容）**
- **不做数据迁移**，仅做程序适配
- **不改架构**，保留 MyBatis / JPA / JdbcTemplate 原结构
- **集成测试使用本地/共享真实数据库**，禁用 Testcontainers 与 `@MockBean`

## 迭代约定

- Pilot 工程：`stream_keywords_search`（首批验证）
- 每次 Pilot 踩坑，同步回灌到 `fix-issue/` 与相应 SOP / references
- 版本号遵循 SemVer：骨架期 v0.x，Pilot 稳定后升 v1.0.0

## 参考入口

- 总方案：[`docs/2026-04-18-master-plan.md`](docs/2026-04-18-master-plan.md)
- 兼容模式详解：[`docs/references/gaussdb-compatibility-modes.md`](docs/references/gaussdb-compatibility-modes.md)
- 已知风险：[`docs/risks/known-risks-gaussdb.md`](docs/risks/known-risks-gaussdb.md)
