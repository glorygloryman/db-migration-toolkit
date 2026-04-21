# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 仓库性质

这是一个**方法论工具包**，不是应用代码仓库。没有编译/构建/测试命令——全部内容是 Markdown 文档与 Claude Code Skills 定义。修改即"发布"，通过软链被下游工程消费。

- **消费方**：`xz-source/` 下 20+ 个 Java/Spring Boot 工程
- **消费方式**：每个工程在 `.claude/skills/` 下软链到本仓库的 `skills/<name>`，所以**本仓库一处改动、所有工程立即生效**——修改 Skill 或文档时必须考虑跨工程影响
- **版本管理**：`VERSION` + `CHANGELOG.md`，SemVer。骨架期 v0.x，Pilot 稳定后升 v1.0.0

## 核心架构

五段式 SOP 驱动的双层结构：**文档层（`docs/`）定义流程，Skill 层（`skills/`）自动化执行**。两者一一对应，改一边通常要同步另一边。

```
docs/2026-04-18-master-plan.md   ← 入口总方案，先读这份
├── sop/stage-{0..5}-*.md        ← 每阶段操作手册（与 Skill 对应）
├── checklists/                  ← 阶段出口检查清单
├── references/                  ← MySQL↔瀚高 类型/语法/函数/兼容模式/兼容脚本对照
├── risks/known-risks-highgo.md  ← 已知风险库
└── templates/                   ← 下游工程产出文档的骨架模板

skills/                          ← 6 个 Claude Code Skills，对应 Stage 0/0/1/3/4/5
├── db-migration-baseline        ← Stage 0: 产出前置调研三件套骨架
├── db-migration-sql-scan        ← Stage 0: 扫描 MySQL 特性，出风险矩阵
├── db-migration-test-gap        ← Stage 1: Mapper vs 测试覆盖对比
├── db-migration-schema-convert  ← Stage 3: 生成瀚高 DDL 对照稿
├── db-migration-dialect-rewrite ← Stage 4: 方言差异建议改写（不自动改码）
└── db-migration-verify          ← Stage 5: 跑测试 + 生成验收报告

fix-issue/                       ← 跨工程共享踩坑库（Pilot 后回灌）
```

**关键耦合点**：Skill 的 `SKILL.md` 里会引用 `docs/templates/*.md` 和 `docs/references/*.md`。重命名或移动文档时，必须 grep 所有 Skill 确保引用同步更新。

## 不可动摇的前提假设

改任何文档/Skill 前先确认仍然成立，否则要升级到总方案层面讨论：

1. **目标库是瀚高 v4.1.5**（PostgreSQL 系），方言基础按 PG，MySQL 函数借厂家兼容脚本抹平——决策见 `project-docs/decisions/2026-04-21-target-db-highgo-v4.md` 与 `project-docs/decisions/2026-04-21-use-vendor-mysql-compat-functions.md`
2. **不做数据迁移**，只做程序适配——任何涉及双写/DML 搬运/灰度切换的建议都属于 `master-plan.md §10` 明确排除项
3. **不改架构**：保留 MyBatis / JPA / JdbcTemplate 原结构，不重构分库分表/读写分离
4. **集成测试必须用真实数据库**：禁用 Testcontainers 与 `@MockBean`（与全局 `~/.claude/CLAUDE.md §2.2` 一致）
5. **Flyway 严禁改历史脚本**，新建 `db/migration/highgo/` 目录（与全局 §3.6 一致）

## Skill 写作约定

每个 `skills/<name>/SKILL.md` 顶部是 YAML frontmatter（`name` + `description`），被 Claude Code 解析用于分发触发。**`description` 字段决定 Skill 能否被正确触发**，修改时务必保留"触发场景 + 关键动词"。

Skill 统一结构：触发场景 → 前置条件 → 执行步骤 → 输出 → 约束 → 后续步骤。骨架期步骤多为大纲，Pilot 后精化为可执行指令。所有 Skill 产出**只写文档、不改代码**（`db-migration-dialect-rewrite` 也只出 diff 建议，由人工 apply）。

## 文档命名与落盘

- 本仓库内文档：`YYYY-MM-DD-<slug>.md` 日期前缀（`master-plan` 已遵循）
- Skill 产出到下游工程时，一律落到 `<project>/project-docs/facts/YYYY-MM-DD-*.md`（facts 目录因含 `updated:` 字段、会过期——见全局 §5 文档治理协议）
- `fix-issue/` 准入四要素：**现象 + 根因 + 修复/规避 + 真实来源**，缺一按 §5 分流到 fact/playbook/decision/faq

## 迭代机制

- **Pilot 工程**：`stream_keywords_search`（首批验证）
- Pilot 中发现的问题 → 回灌到 `fix-issue/` 和对应 `references/` / `risks/`，同步更新 `CHANGELOG.md`
- 框架非必要不在 Pilot 结束后再大改，优先让下游工程按既有版本执行

## 工具包自身的元治理：`project-docs/`

与交付给下游的 `docs/` 区分，本仓库**自身**的计划/决策/事实落在 `project-docs/`：

- `project-docs/plans/` — 路线图（例：v1.0.0 出口条件）
- `project-docs/decisions/` — 架构决策记录（例：目标库瀚高 v4.1.5、使用厂家兼容脚本、软链分发）
- `project-docs/facts/` — 会过期的事实（例：消费方工程清单），含 `updated:` 字段，超 30 天需重核
- `project-docs/_meta/doc-catalog.yaml` — 索引，新增文档需同步登记（遵循全局 §5 文档治理协议）

**判别口径**：修改是"交付给下游"的内容 → 改 `docs/`；是"工具包维护者自己的记录" → 改 `project-docs/`。

## 常见操作

- 查总方案与阶段分工：`docs/2026-04-18-master-plan.md`
- 查兼容脚本说明与缺口清单：`docs/references/highgo-v4.1.5-mysql-compat-functions.md`
- 查当前路线图与 Pilot 状态：`project-docs/plans/2026-04-21-v1.0.0-roadmap.md`
- 查消费方工程清单与接入状态：`project-docs/facts/2026-04-21-consumer-projects-inventory.md`
- 修改某阶段 SOP：同步检查对应 Skill 的步骤列表是否需要调整
- 新增一条踩坑：先判断是否通用（其他 MySQL 工程也会遇到）再放入根目录 `fix-issue/`（产品侧踩坑库），否则留工程本地
- 新增对照表条目：同步在相关 Skill 的"后续步骤"里建立引用
- 新增 `project-docs/` 下的文档：同步更新 `project-docs/_meta/doc-catalog.yaml`
