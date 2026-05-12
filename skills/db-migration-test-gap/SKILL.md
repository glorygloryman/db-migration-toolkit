---
name: db-migration-test-gap
description: 对比 Mapper / DAO 方法与现有测试覆盖，输出"测试缺口清单"。Stage 1 测试兜底前使用，帮助确定哪些方法必须补测。
---

# db-migration-test-gap

## 触发场景

- Stage 0 产出 baseline 后
- Stage 1 测试兜底开始前
- 疑问"这个方法有没有测试"时

## 前置条件

- 已执行 `db-migration-baseline`
- 工程源码可被扫描

## 执行步骤

### 1. 枚举所有持久层方法

扫描：
- `@Mapper` 接口的所有方法
- `@Repository` 类的 public 方法
- `XxxDao` / `XxxRepository` 命名约定类的 public 方法
- JPA `Repository<T, ID>` 及其自定义方法

产出完整方法清单：`<类名>#<方法名>`

### 2. 枚举所有测试方法

扫描：
- `*Test.java` 中的 `@Test` 方法
- `*IntegrationTest.java` 中的 `@Test` 方法
- 记录每个测试方法调用到的 Mapper / DAO 类与方法（通过简单静态分析，或方法名约定反推）

### 3. 建立覆盖映射

对每个持久层方法，判定：
- 有单元测试覆盖吗？
- 有集成测试覆盖吗？
- 集成测试是否连真实 DB（非 `@MockBean`、非 Testcontainers）？
- 集成测试是否使用真实 schema 中已存在的库、表、字段？
- 测试代码、`@Sql`、`@BeforeAll`、测试 support helper 是否包含 `CREATE DATABASE` / `CREATE SCHEMA` / `CREATE TABLE` / `CREATE TEMPORARY TABLE` / `CREATE TABLE ... LIKE ...` / `ALTER TABLE` / `DROP TABLE` / `DROP TEMPORARY TABLE`？

判定规则：
- 精确方法引用优先
- 名称相似（`insertUser` ↔ `testInsertUser`）次之
- 只要集成测试自行创建数据库对象，该覆盖不得计为真实 schema 集成测试覆盖，必须标记为 `无效覆盖 / 需改造`
- 无法判定时标记 `需人工确认`

### 4. 打优先级标签

每个方法按以下维度打分：
- **公共性**（被多个 Service 调用）：+2
- **事务 / 批量**：+2
- **使用 MySQL 特性**（查 risk-matrix）：+3
- **对外接口直达**：+2

总分 ≥ 5 → 优先级"高"（关键路径）
总分 3~4 → 优先级"中"
总分 ≤ 2 → 优先级"低"

### 5. 产出 test-gap.md

写入 `<project>/project-docs/facts/YYYY-MM-DD-test-gap.md`（模板：`templates/test-gap-template.md`），包括：
- 总体统计
- 关键路径清单（优先级"高"的所有方法）
- 非关键路径清单
- 测试基础设施缺口
- 真实 schema 缺口与无效覆盖清单（代码引用缺失库、表、字段；测试自行建库建表）
- 工作量估算（按每方法平均 30 分钟单测 / 45 分钟集测）

### 6. 输出建议的补测顺序

按优先级 × 类聚合，给出批次建议：
- 第 1 批：高优先级 + 使用 MySQL 特性的 Mapper
- 第 2 批：高优先级 + 其他
- 第 3 批：中优先级
- 低优先级暂缓（Stage 1 不强制）

## 输出

- `<project>/project-docs/facts/YYYY-MM-DD-test-gap.md`
- 控制台摘要：总方法数、零覆盖数、关键路径缺口数、预估补测工时

## 约束

- **不生成测试代码**，只输出清单
- **禁止把自行创建数据库对象的测试计为有效集成测试覆盖**
- 发现 Mapper / DAO / SQL 引用的数据库、表、字段不存在于真实 MySQL schema 时，必须记录为 blocker
- 静态分析能力有限，结果必须人工 review
- 不评估测试质量（是否 mock 了不该 mock 的东西），那是 review 层面的事

## 人工复核要点

- 关键路径是否有遗漏
- 优先级判定是否合理
- 是否有方法应在"关键"而被判为"非关键"
- 是否存在测试通过但依赖临时库、临时表、影子表或 fixture 表的无效覆盖
- 是否存在代码引用真实 schema 中不存在的库、表、字段
- 是否有已过时、可删除的测试

## 后续步骤

→ 使用 `/db-migration-test-plan` 生成可执行的补测计划
→ 使用 `/db-migration-test-execute <Task编号>` 逐条执行补测
→ MySQL 下全绿后打 tag，进入 Stage 2
