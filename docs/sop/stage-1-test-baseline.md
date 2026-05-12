# Stage 1 — 测试兜底

## 目标

**硬门禁**：在 Stage 2 开始之前，与数据库交互的**关键路径**必须有测试，且在 MySQL 下全绿，作为"改造前快照"。

## 预计工期

1~3 天，取决于 `test-gap.md` 的缺口规模。

## 输入

- Stage 0 产出的 `test-gap.md`
- 现有测试代码

## 前置条件

- 本地可访问的 MySQL 实例
- `application-integration-mysql-baseline.yml` 指向该实例

## 步骤

### 1.1 确定"关键路径"范围

优先级从高到低：
1. 被多处调用的公共 DAO / Mapper
2. 涉及事务、批量操作、动态 SQL 的方法
3. 使用 MySQL 特有特性的方法（参照 `risk-matrix.md` 高风险条目）
4. 对外接口直接触达的持久层方法

一般性 CRUD 若完全走框架标准能力（MyBatis-Plus `BaseMapper`），可降级为"仅集成冒烟即可"。

### 1.2 补齐单元测试

- 框架：JUnit 5 + Mockito
- 命名：`XxxServiceTest` / `XxxMapperTest`（遵循 CLAUDE.md §2.3）
- 断言消息用中文
- **禁止 mock 被测类本身**，只 mock 外部依赖
- 覆盖：正常 1 + 边界 1 + 异常 1（最低要求）

### 1.3 补齐集成测试

- 框架：JUnit 5 + Spring Boot Test
- 命名：`XxxMapperIntegrationTest` / `XxxServiceIntegrationTest`
- **必须连本地真实 MySQL**（CLAUDE.md §2.2）
- **禁止使用 Testcontainers**（本次项目约定）
- **禁止使用 `@MockBean` 替代数据库**
- **必须使用真实 MySQL 中已存在的 schema / 表 / 字段**
- **禁止测试自行创建数据库对象**：不得在测试代码、`@Sql`、`@BeforeAll`、fixture、support helper 中执行 `CREATE DATABASE`、`CREATE SCHEMA`、`CREATE TABLE`、`CREATE TEMPORARY TABLE`、`CREATE TABLE ... LIKE ...`、`ALTER TABLE`、`DROP TABLE`、`DROP TEMPORARY TABLE`
- `@ActiveProfiles("integration-mysql-baseline")`
- 数据准备：只允许对真实 schema 中已存在的表执行 `INSERT` / `UPDATE` / `DELETE`，测试后按测试数据标识清理或回滚
- 若测试所需数据库、表或字段不存在，必须立即失败并记录为 schema 缺口 / blocker，不允许用临时库、临时表、影子表或 fixture 表绕过

### 1.4 跑绿 MySQL 基线

```bash
mvn -P integration-mysql-baseline test
# 或 IDE 内按 profile 运行
```

全部绿后，记录结果到 `project-docs/reports/YYYY-MM-DD-test-baseline-mysql.md`：
- 测试类数、方法数、覆盖率
- 运行耗时
- 关键路径覆盖清单（逐一列出）

### 1.5 快照归档

- Git 提交：`test: Stage 1 测试兜底，MySQL 下基线全绿`
- 打 tag：`stage-1-baseline-mysql-green`
- **这是回归对照基准**，Stage 5 将用相同测试集在瀚高 v4.1.5 下重跑

## 出口检查

- [ ] `test-gap.md` 中标记为"关键路径"的方法全部有测试
- [ ] 所有测试在 MySQL 下全绿
- [ ] 无 `@MockBean` 替代数据库的集成测试
- [ ] 无 Testcontainers 依赖引入
- [ ] 无测试自行创建数据库对象（无 `CREATE DATABASE` / `CREATE SCHEMA` / `CREATE TABLE` / `CREATE TEMPORARY TABLE` / `CREATE TABLE ... LIKE ...` / `ALTER TABLE` / `DROP TABLE` / `DROP TEMPORARY TABLE`）
- [ ] Mapper / DAO / SQL 引用的数据库、表、字段均已确认存在于真实 MySQL schema；缺失项已列为 blocker
- [ ] 报告已产出，tag 已打

## 产出物

- 新增 / 补齐的测试代码
- `project-docs/reports/YYYY-MM-DD-test-baseline-mysql.md`
- Git tag `stage-1-baseline-mysql-green`

## 注意事项

- **缺口大怎么办**：不要一次补全。按"高风险 + 关键路径"优先级分批补，每批独立可运行。
- **历史遗留 SQL 太脏**：记录下来，暂不重构，先保证行为等价的测试覆盖。
- **外部依赖（HBase / MQ / Redis）**：按 CLAUDE.md §2.1 可 mock（单元测试），集成测试中非 DB 外部依赖可按需 mock。**DB 必须真实**。
- **真实 schema 缺失怎么办**：立即记录 blocker 并停止用例通过判定；先确认是补 schema、移除废弃代码，还是调整迁移范围，不能通过临时建库建表让测试继续通过。

## 下一阶段

→ [Stage 2 — 依赖与配置切换](stage-2-config-switch.md)
