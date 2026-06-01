---
updated: YYYY-MM-DD
project: <工程名>
source: <引用的 test-gap 文档路径>
stage: 1-test-foundation
---

# <工程名> 测试补测执行计划

> 由 `/db-migration-test-plan` 自动生成，配合 `/db-migration-test-execute <Task编号>` 逐条执行。

## 0. 总览

| 指标 | 数值 |
|------|------|
| Task 总数 | |
| 高优先级 Task 数 | |
| 中优先级 Task 数 | |
| 涉及 Mapper/DAO 类数 | |
| 预估总工时 | |

**已完成：0 / <N>**

### 并行化策略

无依赖关系的 Task 可在不同会话中并行执行。依赖关系如下：

```
（由 Skill 根据模块依赖自动生成依赖图）
```

**可并行的 Task 组：**
- 组 A：T-XX, T-XX, ...（无依赖，可同时开始）
- 组 B：T-XX, T-XX, ...（依赖组 A 中的部分 Task）

### 阻塞项

> test-gap 文档中标注为"需人工确认"的条目，需优先解决后才能开始执行。

| 条目 | 来源 | 状态 |
|------|------|------|
| | | ⚠️ 待确认 |

---

## 1. 高优先级任务

### Task T-01: <Mapper 类名> — 单元测试（高优先级）

- [ ] **涉及方法：**

| 方法 | MySQL 特性 | 被调用方 |
|------|-----------|---------|
| | | |

**源文件路径：** `<Mapper 源文件路径>`

**已有测试文件：** `<路径>` 或 `无`

**验收标准：**
- [ ] 所有涉及方法均有对应单元测试
- [ ] 每个方法至少覆盖正常路径 + 边界条件 + 异常路径（最低三条）
- [ ] 断言消息使用中文
- [ ] 禁止 mock 被测类本身，只 mock 外部依赖
- [ ] 测试通过 `mvn test -Dtest=<TestClass>`
- [ ] 含 MySQL 特性的方法在测试中有注释标注

---

### Task T-02: <Mapper 类名> — 集成测试（高优先级）

- [ ] **涉及方法：**

| 方法 | MySQL 特性 | 测试要点 |
|------|-----------|---------|
| | | |

**源文件路径：** `<Mapper 源文件路径>`

**已有测试文件：** `<路径>` 或 `无`

**验收标准：**
- [ ] 所有涉及方法均有对应集成测试
- [ ] `pom.xml` 已配置 Maven Profile `systemPropertyVariables` 注入 `spring.profiles.active`，集成测试不写 `@ActiveProfiles`
- [ ] 测试连接真实 MySQL 数据库（禁止 `@MockBean` 替代数据库，禁止 Testcontainers）
- [ ] 测试使用真实 MySQL schema 中已存在的库、表、字段
- [ ] 测试未自行创建数据库对象（无 `CREATE DATABASE` / `CREATE SCHEMA` / `CREATE TABLE` / `CREATE TEMPORARY TABLE` / `CREATE TABLE ... LIKE ...` / `ALTER TABLE` / `DROP TABLE` / `DROP TEMPORARY TABLE`）
- [ ] 测试数据只通过 `INSERT` / `UPDATE` / `DELETE` 准备，并有清理机制
- [ ] 若真实 schema 缺失库、表或字段，已标记为 blocker，未用临时库、临时表、影子表或 fixture 表绕过
- [ ] 断言消息使用中文
- [ ] 测试通过 `mvn test -Dtest=<TestClass>`

---

## 2. 中优先级任务

### Task T-XX: <Mapper 类名> — 补测（中优先级）

- [ ] **涉及方法：**

| 方法 | 已有覆盖 | 需补充 |
|------|---------|--------|
| | | |

**源文件路径：** `<路径>`

**验收标准：**
- [ ] 缺失的测试已补齐
- [ ] 每个方法至少覆盖正常路径 + 边界条件 + 异常路径（最低三条）
- [ ] 断言消息使用中文
- [ ] 单元测试禁止 mock 被测类本身
- [ ] 集成测试不写 `@ActiveProfiles`，通过 Maven Profile `systemPropertyVariables` 注入 profile，连接真实 MySQL，禁止 `@MockBean` 和 Testcontainers
- [ ] 集成测试使用真实 MySQL schema 中已存在的库、表、字段
- [ ] 集成测试未自行创建数据库对象
- [ ] 集成测试只通过 `INSERT` / `UPDATE` / `DELETE` 准备测试数据，并有清理机制
- [ ] 测试通过

---

## 3. 进度追踪表

| Task | 模块 | 测试类型 | 优先级 | 状态 | 完成日期 |
|------|------|---------|--------|------|---------|
| T-01 | | 单元测试 | 高 | ⬜ 待执行 | |
| T-02 | | 集成测试 | 高 | ⬜ 待执行 | |
| ... | | | | | |

---

## 4. 出口标准

Stage 1 补测完成条件：
- [ ] 所有关键路径 Task（高优先级）已完成
- [ ] 中优先级 Task 已完成或已标记为"按需"
- [ ] test-gap 文档覆盖状态已全部更新
- [ ] `mvn test` 在 MySQL 下全绿
- [ ] 无 `@MockBean` 替代数据库的集成测试
- [ ] 无 Testcontainers 依赖引入
- [ ] 无测试自行创建数据库对象
- [ ] 无通过临时库、临时表、影子表或 fixture 表绕过真实 schema 的集成测试
- [ ] Mapper / DAO / SQL 引用的数据库、表、字段均已确认存在于真实 MySQL schema；缺失项已列为 blocker
- [ ] 基线报告已产出：`project-docs/reports/YYYY-MM-DD-test-baseline-mysql.md`
- [ ] Git tag `stage-1-baseline-mysql-green` 已打
