---
name: db-migration-baseline
description: MySQL → 瀚高 改造的 Stage 0 基线调研 Skill。扫描当前工程，产出前置调研三件套（baseline / risk-matrix / test-gap）骨架。在任何工程进入数据库改造前使用。
---

# db-migration-baseline

## 触发场景

- 接到"把 X 工程从 MySQL 改造到 瀚高"任务
- 进入改造分支后第一步
- Stage 0 立项阶段

## 前置条件

- 当前工作目录是目标工程根目录
- 工程可编译（至少能 `mvn compile`）
- 已读 `db-migration-toolkit/docs/2026-04-18-master-plan.md`

## 执行步骤

### 1. 识别工程基本信息

- 读 `pom.xml`：工程名、Spring Boot 版本、ORM 依赖、连接池依赖、数据库驱动、Flyway/Liquibase
- 读 `application.yml` / `application-*.yml`：数据源、字符集、时区、连接池参数
- 读 `CLAUDE.md`（如有）：工程特有约定

### 2. 识别持久层

- 扫描 `@Mapper` / `@Repository` / `@Entity` 注解
- 统计 Mapper XML 文件数量与总行数
- 识别动态 SQL 片段（`<if>` / `<choose>` / `<foreach>`）
- 统计 `@Query` / `@Select` / `@Insert` 注解 SQL
- 扫描代码中字符串拼接 SQL（`String sql = "..."` 模式）

### 3. 识别 Schema 来源

- 是否有 Flyway / Liquibase 脚本目录
- 是否有 `schema.sql` / `data.sql`
- 是否依赖运行时 ORM 自动建表（强烈反对，需立项整改）
- 获取真实 MySQL schema 导出或只读连接信息，用于核对代码引用的数据库、表、字段
- 从 Mapper XML、注解 SQL、字符串 SQL、实体映射中提取静态数据库对象引用，并与真实 MySQL schema 对比
- 若发现代码引用的数据库、表或字段在真实 MySQL schema 中不存在，立即记录为 blocker；不得用临时库、临时表、影子表或 fixture 表补齐测试

### 4. 识别存储过程 / 触发器

- 在 Flyway 脚本中 grep `CREATE PROCEDURE|CREATE TRIGGER|CREATE EVENT`
- 代码中 grep `callableStatement|@Procedure|{ call`

### 5. 识别测试现状

- 计数 `*Test.java`、`*IntegrationTest.java`
- 扫描 `@MockBean`、`@Testcontainers` 使用点
- 扫描测试代码、`@Sql`、测试 support helper 中的数据库对象 DDL：`CREATE DATABASE`、`CREATE SCHEMA`、`CREATE TABLE`、`CREATE TEMPORARY TABLE`、`CREATE TABLE ... LIKE ...`、`ALTER TABLE`、`DROP TABLE`、`DROP TEMPORARY TABLE`
- 识别是否有 `application-test.yml` / `application-integration-*.yml`
- 若发现集成测试自行创建数据库对象，标记为测试基础设施 blocker；该测试不得计为真实 schema 集成测试覆盖

### 6. 产出 baseline.md 骨架

使用 `db-migration-toolkit/docs/templates/baseline-template.md` 作为模板，填入扫描到的事实，写到 `<project>/project-docs/facts/YYYY-MM-DD-db-migration-baseline.md`。

未知字段留 `<待填>`，人工补充。

### 7. 产出 test-gap.md 骨架

使用 `templates/test-gap-template.md` 模板：
- 列出所有 Mapper / DAO 方法
- 标注"已有单测 / 已有集测"状态
- 优先级暂留空，人工与 Skill 协作判定

写入 `<project>/project-docs/facts/YYYY-MM-DD-test-gap.md`

### 8. 调用关联 Skill

建议用户紧接着调用：
- `db-migration-sql-scan`（产出 risk-matrix）

## 输出

- `<project>/project-docs/facts/YYYY-MM-DD-db-migration-baseline.md`
- `<project>/project-docs/facts/YYYY-MM-DD-test-gap.md`
- 简短报告：关键发现（高风险信号、阻塞项）

## 约束

- **不改任何代码**，只产出文档
- **真实 schema 硬门禁**：数据库集成测试必须使用真实 MySQL 中已存在的库、表、字段；禁止任何测试自行创建数据库对象进行验证
- **早期暴露硬门禁**：缺失数据库、表、字段必须在 Stage 0 / Stage 1 记录为 blocker，禁止拖到 Stage 4 才首次提出
- 事实未知时留 `<待填>`，不臆测
- 所有产出中文
- 每份文档含 `updated:` 字段

## 后续步骤

→ 调用 `db-migration-sql-scan` 产出风险矩阵
→ 人工 review 三件套
→ 进入 Stage 1（测试兜底）
