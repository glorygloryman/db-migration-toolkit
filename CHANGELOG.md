# Changelog

## v0.2.1 — 2026-04-22

**Pilot 知识回灌：propagation-billboard 基线调研结论**

### 风险
- R-008 增强：补充 PageHelper 5.1.4 版本验证细节（自动检测失败，必须显式配置 `helperDialect=postgresql`）
- 新增 R-019：TRS 内部 `BaseMybatisRepository`TRS 内部 BaseMybatisRepository 在瀚高下的兼容性放行规则

### fix-issue
- 新增 `fix-issue/2026-04-22-trs-basemybatis-repository-compat.md`：R-019 配套放行规则（放行条件 / 一票否决 / 自动判定），供 baseline 扫描器引用

## v0.2.0 — 2026-04-21

**重大变更：目标库切换**

### 变更
- 目标库从 GaussDB B 兼容模式改为**瀚高（HighGo）v4.1.5**（基于 PostgreSQL 内核）
- 引入厂家 MySQL 函数兼容脚本，在目标库 DB 层抹平常用 MySQL 函数
- 全部 references / SOP / Skills / templates / checklists 重写以适配新目标库
- 重命名 5 份核心文档（`gaussdb-*` → `highgo-*`）
- 新增 2 份决策（`target-db-highgo-v4` / `use-vendor-mysql-compat-functions`，后者含脚本版本管理策略）
- 废弃 1 份决策（`why-b-compat-mode`，置 superseded）
- Flyway 目录约定 `db/migration/gaussdb/` → `db/migration/highgo/`
- Profile 命名 `integration-gaussdb` → `integration-highgo`
- 改造分支约定 `feature/db-migration-gaussdb` → `feature/db-migration-highgo`

### 新增
- `docs/references/highgo-v4-compatibility.md`（瀚高 v4.1.5 特性详解）
- `docs/references/highgo-v4.1.5-mysql-compat-functions.sql`（厂家脚本 + 版本标记函数）
- `docs/references/highgo-v4.1.5-mysql-compat-functions.md`（脚本说明与缺口）
- `project-docs/plans/2026-04-21-pivot-to-highgo.md`（本整改计划）
- `project-docs/plans/2026-04-21-pilot-smoke-test.md`（Pilot 烟测清单）

### 风险
- 新增 R-017 脚本版本管理
- 新增 R-018 Flyway 防护语法在瀚高下的兼容性

### 迁移指引
- 使用 v0.1.x 的消费方工程升级路径：由本工具包 Pilot 验证后单独发布
- Tag 见 Task 19 打

## v0.1.0 — 2026-04-18

首发骨架版。

### 新增
- 母方案文档（五段式 SOP）
- 六份阶段操作手册（Stage 0 ~ Stage 5）
- 三份检查清单（前置调研 / PR / 验收）
- 四份参考对照表（类型 / 语法 / 函数 / 兼容模式）
- 四份文档模板（baseline / risk-matrix / test-gap / report）
- 一份风险库（GaussDB 已知风险）
- 六个 Skills 骨架（步骤大纲，Pilot 后精化）

### 前提
- 目标库：GaussDB B 兼容模式
- 不做数据迁移，仅程序适配
- 不改架构，保留原持久层结构
- 集成测试用本地/共享真实库

### 待办
- Pilot 工程 `stream_keywords_search` 启动
- 根据 Pilot 输出回灌 fix-issue 与 references
- 预计 Pilot 完成后发布 v1.0.0
