---
name: db-migration-test-plan
description: 读取 test-gap 测试缺口清单，按模块 × 测试类型 × 优先级拆分为独立可执行的补测任务计划。Stage 1 补测前使用，将缺口清单转化为可逐条执行的实施方案。
---

# db-migration-test-plan

## 触发场景

- `/db-migration-test-gap` 已产出测试缺口清单
- 准备开始 Stage 1 按批次补测
- 需要将补测工作拆分为可独立执行的原子任务

## 前置条件

- 存在 `<project>/project-docs/facts/YYYY-MM-DD-test-gap.md`
- 工程源码可被扫描

## 输入

- 无需额外参数，自动定位最新的 test-gap 文档

## 执行步骤

### 1. 定位并读取 test-gap 文档

在 `<project>/project-docs/facts/` 下查找最新的 `*-test-gap.md` 文件，读取：
- §2 关键路径覆盖清单
- §3 非关键路径清单
- §5 工作量估算

### 2. 按维度聚合任务

从 test-gap 文档的表格数据中提取待补测方法，按以下维度聚合为任务单元：

**聚合规则：**
1. **模块**（Mapper / DAO 类）为第一分组键
2. **优先级**（高 > 中）为第二分组键
3. **测试类型**（单元测试、集成测试）为第三分组键

**任务粒度：**
- 每个 Task = 一个模块 × 一种测试类型
- 高优先级方法独占 Task，不与中优先级混编
- 中优先级方法可按模块合并为一个 Task

**排序：**
1. 高优先级 + 使用 MySQL 特性的模块优先
2. 高优先级 + 其他模块
3. 中优先级模块

### 3. 为每个 Task 生成上下文信息

对每个 Task，扫描源码提取：

- **目标 Mapper / DAO 类**的完整路径和源码
- **涉及方法**的方法签名
- **已有测试文件**（如存在同名 `*Test.java`，记录路径和现有测试方法名）
- **方法调用关系**（该方法被哪些 Service 调用，用于理解业务语义）
- **SQL 特征**（MyBatis XML 中的 SQL 片段、注解 SQL，标记是否含 MySQL 特有语法）

### 4. 产出执行计划

写入 `<project>/project-docs/plans/YYYY-MM-DD-test-gap-plan.md`（模板：`templates/test-gap-plan-template.md`），包括：

- **总览**：任务总数、按优先级分布、预估总工时
- **并行化策略**：哪些 Task 之间无依赖可并行
- **Task 清单**：每个 Task 包含以下字段：
  - 编号（如 `T-01`）
  - 标题（模块名 + 测试类型 + 优先级）
  - 涉及的 Mapper/DAO 类和方法列表
  - 源文件路径
  - 已有测试文件路径（若有）
  - MySQL 特性标记（若有）
  - 验收标准（聚焦测试覆盖性，要求MySQL环境通过，不要求瀚高环境通过）：
    - 对应方法是否有测试用例
    - 测试用例是否覆盖正常路径 + 边界条件 + 异常路径（最低三条，缺一不可）
    - 断言消息使用中文
    - 单元测试禁止 mock 被测类本身，只 mock 外部依赖；DB 必须真实，非 DB 外部依赖可 mock
    - 集成测试使用 `@ActiveProfiles("integration-mysql-baseline")`，连接真实 MySQL，禁止 `@MockBean` 替代数据库，禁止 Testcontainers
    - 集成测试有数据准备（`@Sql` / `@BeforeAll`）和清理机制（回滚 / cleanup）
    - 在当前 MySQL 环境下测试是否通过
  - checkbox `- [ ]` 用于跟踪进度
- **进度追踪表**：汇总所有 Task 的状态

## 输出

- `<project>/project-docs/plans/YYYY-MM-DD-test-gap-plan.md`
- 控制台摘要：Task 总数、高/中优先级分布、预估总工时、可并行 Task 数

## 约束

- **不生成测试代码**，只产出执行计划
- **验收标准不包含瀚高环境通过**：Stage 1 的目标是补齐测试覆盖率，代码尚未做瀚高方言适配（Stage 4），在瀚高环境验证属于 Stage 5（`db-migration-verify`）的职责
- Task 粒度控制在"一个会话可完成"的范围内（建议单个 Task ≤ 10 个方法）
- 高优先级方法不可遗漏，中优先级方法允许标记为"按需"
- 如果 test-gap 文档中存在 `需人工确认` 的条目，在计划中标注为阻塞项，排在最前
- 新建单元测试文件命名为 `*Test.java`，集成测试文件命名为 `*IntegrationTest.java`
- 测试用例必须包含中文注释
- **禁止引入 Testcontainers 依赖**
- **禁止使用 `@MockBean` 替代数据库**

## 人工复核要点

- Task 拆分粒度是否合理（太大或太小）
- 优先级排序是否符合实际业务重要性
- 是否有模块间依赖需要在并行化策略中考虑
- 验收标准是否充分（单元测试：正常+边界+异常至少三条；集成测试：真实 DB、有数据准备和清理）
- 是否存在 `@MockBean` 或 Testcontainers 引入的风险
- 中优先级 Task 的验收标准是否与高优先级保持同等质量要求

## 后续步骤

→ 使用 `/db-migration-test-execute <Task编号>` 逐条执行
→ 所有 Task 完成后回到 test-gap 文档刷新覆盖状态
