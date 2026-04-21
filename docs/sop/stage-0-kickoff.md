# Stage 0 — 立项与基线

## 目标

进入改造前做"入场调查"，把工程当前状态、MySQL 依赖程度、测试覆盖缺口、风险点摸清楚，作为后续阶段的决策依据。

## 预计工期

0.5 天

## 输入

- 工程源码
- 生产环境 MySQL 版本、字符集、时区
- 目标 GaussDB 版本与兼容模式（已知为 **B 兼容模式**）

## 前置条件

- 已拉改造分支 `feature/db-migration-gaussdb`
- 工程可在本地启动，连得上现有 MySQL

## 步骤

### 0.1 目标库确认

- 确认 GaussDB 版本号
- 确认兼容模式 = **B（MySQL 兼容）**
- 确认部署形态（集中式 / 分布式 / DWS）
- 记录 JDBC 驱动下载渠道与版本
- 产出：填入 `baseline.md` §1

### 0.2 持久层盘点

扫描工程 `pom.xml` 与代码：
- ORM 框架：MyBatis / MyBatis-Plus / JPA / JdbcTemplate / 原生 JDBC
- 分页插件与方言
- 连接池（Druid / HikariCP）及版本
- Flyway / Liquibase 是否启用及当前 baseline
- 是否存在存储过程、触发器、事件调用

产出：填入 `baseline.md` §2

### 0.3 MySQL 特性依赖扫描

调用 Skill `db-migration-sql-scan`，扫描：
- Mapper XML + `@Query` + 字符串 SQL
- 语法特征、函数调用、类型声明、保留字使用

产出：`risk-matrix.md`，按 **文件 × 特性 × 严重度** 三维矩阵。

### 0.4 测试基线评估

调用 Skill `db-migration-test-gap`：
- 枚举所有 DAO / Mapper 方法
- 对比现有 `*Test` / `*IntegrationTest` 覆盖
- 标记"零覆盖"与"仅单元测试无集成测试"的方法

产出：`test-gap.md`

### 0.5 SQL 仓清点

统计（Skill 自动产出，入 `baseline.md` §5）：
- Mapper XML 文件数、总行数
- 动态 SQL 片段数（`<if>` / `<choose>` / `<foreach>`）
- Native Query 方法数
- 硬编码 SQL（字符串拼接）出现位置

## 出口检查

使用 [`checklists/pre-research-checklist.md`](../checklists/pre-research-checklist.md) 逐项核对。

## 产出物

| 文件 | 位置 | 模板 |
|------|------|------|
| 基线 | `project-docs/facts/YYYY-MM-DD-db-migration-baseline.md` | `templates/baseline-template.md` |
| 风险矩阵 | `project-docs/facts/YYYY-MM-DD-risk-matrix.md` | `templates/risk-matrix-template.md` |
| 测试缺口 | `project-docs/facts/YYYY-MM-DD-test-gap.md` | `templates/test-gap-template.md` |

## 注意事项

- 三件套只记"现状事实"，不下判断、不写方案
- `fact` 类文档必须含 `updated:` 字段（遵循 CLAUDE.md §5）
- 如发现工程架构异常（如混用多套 ORM、大量存储过程），立即升级风险级别

## 下一阶段

→ [Stage 1 — 测试兜底](stage-1-test-baseline.md)
