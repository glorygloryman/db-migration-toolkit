---
name: db-migration-test-execute
description: 读取测试补测执行计划，执行指定 Task 的测试用例编写、验证通过后回写计划进度和 test-gap 覆盖状态。用户逐条执行补测任务时调用。
---

# db-migration-test-execute

## 触发场景

- 测试补测执行计划已由 `/db-migration-test-plan` 生成
- 用户要执行计划中的某个具体 Task

## 输入

- Task 编号（如 `T-01`），或关键词（如模块名 `PositionMapper`）
- 若未指定，列出待执行 Task 供用户选择

## 前置条件

- 存在 `<project>/project-docs/plans/YYYY-MM-DD-test-gap-plan.md`
- 对应的 test-gap 文档存在：`<project>/project-docs/facts/YYYY-MM-DD-test-gap.md`

## 执行步骤

### 1. 读取执行计划和 test-gap 文档

定位并读取最新的 `test-gap-plan.md`，以及对应的 `test-gap.md`。

### 2. 解析目标任务

- 根据用户指定的编号或关键词定位 Task
- 若 Task 已完成（已勾选 `[x]`），提示用户并确认是否重新执行
- 若该 Task 有前置依赖（同一模块的单元测试 Task 应在集成测试 Task 之前），检查依赖是否已完成，未完成则警告

### 3. 读取源码上下文

从执行计划中提取该 Task 涉及的：
- 目标 Mapper / DAO 类源码和路径
- 需要补测的方法签名列表
- 已有测试文件路径（若标注）
- MySQL 特性标记（若有）

若计划中的路径信息不完整，主动扫描项目补充：
- 定位 Mapper/DAO 源文件
- 定位对应的 MyBatis XML（若为 MyBatis 项目）
- 定位同模块已有的测试文件，了解现有测试风格和约定

### 4. 编写测试代码

根据 Task 的测试类型执行：

#### 单元测试

- 在对应测试目录下创建或追加测试类
- 类命名：`<TargetClass>Test.java`
- 测试方法命名：`test<MethodName><Scenario>()`
- 框架：JUnit 5 + Mockito
- Mock 外部依赖（其他 Mapper、远程服务等），**禁止 mock 被测 Mapper 本身**
- 覆盖：正常路径 + 边界条件 + 异常路径（最低三条，缺一不可）
- 断言消息使用中文
- 若方法含 MySQL 特性，在测试中用注释标注 `// MySQL feature: <特性名>`

#### 集成测试

- 创建或追加集成测试类
- 类命名：`<TargetClass>IntegrationTest.java`
- 框架：JUnit 5 + Spring Boot Test
- 使用 `@ActiveProfiles("integration-mysql-baseline")`
- 使用 `@Sql` 或代码方式准备测试数据
- 连接真实 MySQL 数据库（遵循 CLAUDE.md §2.2 禁用 `@MockBean` 和 Testcontainers 的约束）
- **禁止引入 Testcontainers 依赖**
- **禁止使用 `@MockBean` 替代数据库**
- 测试后清理数据（`@Sql` cleanup 或 `@Transactional` rollback）
- 验证 SQL 执行结果与预期一致
- 断言消息使用中文
- 若方法含 MySQL 特性（如 `ON DUPLICATE KEY UPDATE`、`GROUP_CONCAT`），集成测试必须覆盖该特性的行为

### 5. 运行测试验证

- 使用项目构建工具运行测试（如 `mvn test -Dtest=<TestClass>` 或 `mvn test -pl <module> -Dtest=<TestClass>`）
- **测试必须全部通过**才算完成
- 若测试失败：
  - 分析失败原因（代码错误、数据问题、环境问题）
  - 修复测试代码（不修改被测业务代码）
  - 重新运行直至通过
  - 若确认为业务代码缺陷，在进度中标注，不继续尝试修复业务代码

### 6. 回写执行计划

更新 `test-gap-plan.md`：
- 勾选已完成的 Task：`- [x]`
- 更新进度追踪表：状态改为 `✅ 完成`，填写完成日期
- 更新顶部"已完成：X / N"计数
- 若测试失败且无法解决，标注 `❌ 阻塞` 和原因

### 7. 回写 test-gap 文档

更新 `test-gap.md`：
- 在 §2 或 §3 的表格中，将对应方法的"已有单测"或"已有集测"列从 `❌` 改为 `✅`
- 更新 §1 总体统计中的覆盖数据
- 刷新 `updated:` 字段为当天日期
- 若关键路径全部补齐，在 §6 出口标准中标注进度

## 输出

- 新增或修改的测试文件
- 更新后的 `test-gap-plan.md`
- 更新后的 `test-gap.md`
- 控制台结果摘要：Task 编号、测试类名、测试方法数、通过/失败

## 约束

- **不修改被测业务代码**，只新增或修改测试代码
- 集成测试必须连真实数据库，**禁止使用 `@MockBean` 替代数据库**
- **禁止引入 Testcontainers 依赖**
- 每次只执行一个 Task
- 测试风格必须与项目现有测试保持一致（扫描已有测试类作为参考）
- 测试不通过时，允许修复测试代码本身，但不修改业务代码；若确认为业务 bug，标注后跳过
- 单元测试每个方法至少覆盖正常 + 边界 + 异常三条用例

## 人工复核要点

- 测试是否真正覆盖了关键逻辑路径（不是只写了 happy path）
- 每个方法是否至少有正常 + 边界 + 异常三条用例
- Mock 范围是否合理（不该 Mock 的没 Mock，被测类本身未被 Mock）
- 集成测试的数据准备和清理是否完整
- 集成测试是否使用了 `@ActiveProfiles("integration-mysql-baseline")`
- 断言消息是否使用中文
- 测试命名是否清晰表达意图
- 是否存在 `@MockBean` 或 Testcontainers 引入

## 后续步骤

→ 继续执行下一个 Task：`/db-migration-test-execute <下一个Task编号>`
→ 所有 Task 完成后，test-gap 文档 §6 出口标准应全部达成
→ 产出基线报告 `project-docs/reports/YYYY-MM-DD-test-baseline-mysql.md`（含测试类数、方法数、覆盖率、耗时、关键路径覆盖清单）
→ Git 提交：`test: Stage 1 测试兜底，MySQL 下基线全绿`
→ 打 tag：`stage-1-baseline-mysql-green`（这是 Stage 5 `db-migration-verify` 的回归对照基准）
→ 准备进入 Stage 2
