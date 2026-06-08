---
description: MySQL→瀚高v4.1.5 数据库改造全流程自治闭环（立项基线→测试兜底→配置切换→Schema迁移→方言适配→验收交付）
argument-hint: <工程名> [profile] [一句话范围]，例如 stream_keywords_search standard "关键词搜索库迁移" 或 propagation-billboard minimal "公告牌库迁移"
---

# `/work-cycle-auto` 数据库改造自治闭环

你正在执行本工具包**手动触发**的 MySQL → 瀚高 v4.1.5 数据库改造全流程闭环。参数：`$ARGUMENTS`

本命令只有在用户显式敲 `/work-cycle-auto ...` 时才会运行，绝不自动触发。执行期间遇到每一个 `STOP` 必须等待用户回复，不得擅自推进。

## 目标

"MySQL → 瀚高 v4.1.5 五段式 SOP"自治闭环

。覆盖 Stage 0（Preflight）→ Stage 1（立项基线/SOP Stage 0）→ Stage 2（测试兜底/SOP Stage 1）→ Stage 3（配置切换/SOP Stage 2）→ Stage 4（Schema 迁移/SOP Stage 3）→ Stage 5（方言适配/SOP Stage 4）→ Stage 5A（执行歧义自愈）→ Stage 6（回归与交付/SOP Stage 5）→ Stage 7（Closeout），由 `MIGRATION_PROFILE` 选择具体执行策略（standard / minimal / test-heavy）。

## 核心变量

Stage 0 必须先解析并确认以下变量，后续所有阶段只使用变量，不再硬编码：

| 变量 | 含义 | 示例 |
|---|---|---|
| `PROJECT_NAME` | 下游工程名 | `stream_keywords_search`、`propagation-billboard` |
| `PROJECT_PATH` | 工程仓库绝对路径 | `/Users/cy/MyWorkFactory/workspace/my-j2se/yq-sender` |
| `MIGRATION_PROFILE` | 改造策略 profile | `standard`、`minimal`、`test-heavy` |
| `TITLE` | 中文范围标题 | `关键词搜索库迁移` |
| `SLUG` | ASCII kebab 标识 | `stream-keywords-search` |
| `SPEC_SOURCES` | 需求/参考来源清单 | 工具包 `docs/references/`、`docs/sop/`、`fix-issue/` |
| `TOOLKIT_PATH` | db-migration-toolkit 仓库绝对路径 | `D:\TRS\db-migration-toolkit\db-migration-toolkit` |
| `ORM_TYPE` | 持久层框架类型 | `mybatis-plus`、`jpa`、`jdbcTemplate`、`mixed` |
| `CONNECTION_POOL` | 连接池类型 | `druid`、`hikari` |
| `PAGINATION_PLUGIN` | 分页插件 | `pagehelper`、`mybatis-plus`、`none` |
| `HAS_FLYWAY` | 是否启用 Flyway | `true`、`false` |
| `HAS_STORED_PROCEDURES` | 是否有存储过程/触发器 | `true`、`false` |
| `BRANCH_NAME` | 改造分支名 | `feature/db-migration-highgo` |
| `WORKTREE_PATH` | 可选隔离 worktree | `../yq-sender-work-<project>` |
| `VERIFY_PROFILE` | 验证组合 | `java-integration`、`backend-only` |
| `CLOSEOUT_ACTION` | 收尾动作 | `merge-worktree`、`commit-only`、`report-only` |
| `OPS_LOG` | 决策日志 | `project-docs/ops-log/migration-{PROJECT_NAME}-{YYYY-MM-DD}.md` |
| `BASELINE_PATH` | 基线文档路径 | `project-docs/facts/YYYY-MM-DD-db-migration-baseline.md` |
| `RISK_MATRIX_PATH` | 风险矩阵路径 | `project-docs/facts/YYYY-MM-DD-risk-matrix.md` |
| `TEST_GAP_PATH` | 测试缺口路径 | `project-docs/facts/YYYY-MM-DD-test-gap.md` |
| `HIGHGO_VERSION` | 目标瀚高版本 | `v4.1.5` |
| `COMPAT_SCRIPT_VERSION` | 兼容脚本版本标记 | `1.0.0-highgo-v4.1.5-vendor-2026-04-21` |
| `JDBC_DRIVER_VERSION` | 瀚高 JDBC 驱动版本 | `6.2.3` |

## Stage 0 · Preflight 与工程解析

### 0.1 解析参数

从 `$ARGUMENTS` 解析：

1. 第一个 token 作为 `PROJECT_NAME`
2. 第二个 token 如命中 profile 集合，则作为 `MIGRATION_PROFILE`
3. 剩余内容作为 `TITLE`
4. 如果 `MIGRATION_PROFILE` 或 `TITLE` 缺失，按上下文可确定则自动补齐；无法高置信确定则 `STOP`

Profile 集合：

- `standard`：完整五段式 SOP，适用于大多数 Spring Boot 工程
- `minimal`：工程无自定义 SQL、无存储过程、纯框架 CRUD，可跳过 Stage 3/4 部分子步骤
- `test-heavy`：工程测试覆盖极低，Stage 1 占主要工期

### 0.2 选择 profile

按以下优先级选择 `MIGRATION_PROFILE`：

1. 用户显式指定
2. 工程特征自动推断
3. 无法确认则默认 `standard`

推断规则：

| 条件 | `MIGRATION_PROFILE` | 说明 |
|---|---|---|
| 无自定义 SQL（无 Mapper XML、无 `@Query`） | `minimal` | 纯 MyBatis-Plus BaseMapper CRUD |
| 测试覆盖 < 10% 且 Mapper 方法 > 50 | `test-heavy` | Stage 1 工期主导 |
| 其他 | `standard` | 标准改造闭环 |

### 0.3 slug 生成

`SLUG` 生成优先级：

1. 用户显式给出 ASCII kebab slug
2. 从 `PROJECT_NAME` 自动转换为 kebab case
3. 仍无法生成则 `STOP`

### 0.4 扫描工程结构

从 `PROJECT_PATH` 扫描并填充以下变量：

1. **ORM 框架识别**：扫描 `pom.xml` 依赖，确认 `ORM_TYPE`
   - 含 `mybatis-plus` → `mybatis-plus`
   - 含 `spring-boot-starter-data-jpa` → `jpa`
   - 含 `spring-jdbc` + 无以上 → `jdbcTemplate`
   - 多种共存 → `mixed`
2. **连接池识别**：扫描配置文件中的 `spring.datasource.type` 或 `druid` / `hikari` 关键字
3. **分页插件识别**：扫描 `pom.xml` 中 `pagehelper` / `mybatis-plus` 分页依赖
4. **Flyway 识别**：扫描 `pom.xml` 中 `flyway-core` 依赖及 `db/migration/` 目录
5. **存储过程/触发器**：扫描 Mapper XML 中 `CALL` / `EXECUTE` 关键字、`CREATE PROCEDURE` / `CREATE TRIGGER` 语句
6. **SQL 仓统计**：
   - Mapper XML 文件数、总行数
   - `@Query` / `@Select` 注解 SQL 数
   - 动态 SQL 片段数（`<if>` / `<choose>` / `<foreach>`）
   - 代码中字符串拼接 SQL 位置

扫描完成后，生成 `BASELINE_PATH` 文档骨架（参照 `{TOOLKIT_PATH}/docs/templates/baseline-template.md`）。

### 0.5 通用 Preflight

1. `git status` 必须 clean；如果不 clean，列出脏文件并 `STOP`，除非用户明确允许在当前脏工作区继续
2. `git branch --show-current` 必须在允许的基线分支，默认 `main` 或 `master`
3. 如果设置了 `WORKTREE_PATH`，`git worktree list` 确认路径不存在；存在则 `STOP`
4. 粗读 `SPEC_SOURCES`：`{TOOLKIT_PATH}/docs/references/` 下所有映射表、`{TOOLKIT_PATH}/fix-issue/` 中相关记录、`{TOOLKIT_PATH}/docs/risks/known-risks-highgo.md`
5. 确认本地可访问的 MySQL 实例存在，`application-integration-mysql-baseline.yml` 指向该实例（或待创建）
6. **强制 fact 注入**：在 `OPS_LOG` 写入"必读 fact 清单"段，列出 `fix-issue/` 下与本工程相关的已知踩坑记录（按 `ORM_TYPE` / `CONNECTION_POOL` / 特征 grep 筛选）。每个相关文件必须用 Read 工具实际读一次，并在 `OPS_LOG` 写下"已读 + 关键 takeaway 一句话"。未完成此步骤不得进入 Stage 1。
7. 创建或追加 `OPS_LOG`，记录解析出的全部核心变量和 preflight 结果

### 0.6 变量确认表

所有变量解析完成后，向用户呈现变量确认表：

```
PROJECT_NAME:         <值>
MIGRATION_PROFILE:    <值>
TITLE:                <值>
SLUG:                 <值>
SPEC_SOURCES:         <值>
TOOLKIT_PATH:         <值>
ORM_TYPE:             <值>
CONNECTION_POOL:       <值>
PAGINATION_PLUGIN:     <值>
HAS_FLYWAY:           <值>
HAS_STORED_PROCEDURES: <值>
BRANCH_NAME:          <值>
WORKTREE_PATH:        <值>
VERIFY_PROFILE:       <值>
CLOSEOUT_ACTION:      <值>
OPS_LOG:              <值>
BASELINE_PATH:        <值>
RISK_MATRIX_PATH:     <值>
TEST_GAP_PATH:        <值>
HIGHGO_VERSION:       <值>
COMPAT_SCRIPT_VERSION: <值>
JDBC_DRIVER_VERSION:  <值>
```

用户确认后进 Stage 1；用户有修改则更新变量重新呈现。

## Stage 1 · 立项基线（SOP Stage 0）

**Profile 条件分支**：
- `minimal`：仅执行 1.1 扫描 + 1.4 出口检查；1.2 风险矩阵和 1.3 测试缺口可简化为"确认无自定义 SQL"
- `standard` / `test-heavy`：全部执行

### 1.1 MySQL 特性依赖扫描

调用工具包 Skill `db-migration-sql-scan`（如已安装）或手动扫描：

1. Mapper XML + `@Query` + 字符串 SQL 全量扫描
2. 语法特征：反引号、`LIMIT m,n`、`ON DUPLICATE KEY UPDATE`、`REPLACE INTO`、`UPDATE ... JOIN`、`LOCK IN SHARE MODE`
3. 函数调用：`IFNULL`、`IF()`、`DATE_FORMAT`、`FIND_IN_SET`、`TRUNCATE`、`GROUP_CONCAT`、JSON 函数族
4. 类型声明：`TINYINT(1)`、`ENUM`、`SET`、`JSON`、`MEDIUMTEXT`/`LONGTEXT`
5. 保留字使用：`user`、`type`、`order`、`role`、`group`、`key`
6. 隐式类型转换：`int_col LIKE '%x%'`、`LEFT(int_col,2)`、`string=int_col`

### 1.2 生成风险矩阵

产出 `RISK_MATRIX_PATH`，按**文件 × 特性 × 严重度**三维矩阵组织。参照 `{TOOLKIT_PATH}/docs/templates/risk-matrix-template.md`。

每条风险必须包含：
- 文件路径 + 行号范围
- 特征描述（MySQL 特有语法/函数/类型）
- 严重度：🔴 高（阻塞/数据错误）/ 🟡 中（需改造）/ 🟢 低（注意即可）
- 建议动作（改写方案、替代函数、兼容脚本覆盖状态）
- 关联工具包风险编号（R-001 ~ R-021）

### 1.3 测试覆盖缺口分析

产出 `TEST_GAP_PATH`：

1. 枚举所有 DAO / Mapper 方法
2. 对比现有 `*Test` / `*IntegrationTest` 覆盖
3. 标记"零覆盖"与"仅单元测试无集成测试"的方法
4. 按优先级排序：高风险 + 关键路径优先

### 1.4 出口检查

使用 `{TOOLKIT_PATH}/docs/checklists/pre-research-checklist.md` 逐项核对。**任何一项未通过不得进入 Stage 2。**

硬检查项：

- [ ] `BASELINE_PATH` 已产出，含 `updated:` 字段
- [ ] `RISK_MATRIX_PATH` 已产出，每条有文件/特性/严重度/建议动作
- [ ] `TEST_GAP_PATH` 已产出，关键路径已圈定
- [ ] 高风险项已上浮，有沟通记录
- [ ] `OPS_LOG` 已记录本阶段全部决策

`STOP` 条件：
- 发现存储过程/触发器且无法上移 Java 层 → `STOP`，升级沟通
- 发现分库分表 / 读写分离 → `STOP`，超出改造范围
- 风险矩阵中有 🔴 级阻塞项且无缓解方案 → `STOP`

### 1.5 基线审计（plan-auditor）

派一个只读 Agent，不开 worktree。Prompt 模板：

```text
你是本项目的 baseline-auditor。刚生成的基线产出物需要你按固定 rubric 审计，决定是否进入执行阶段。

Working Directory: {PROJECT_PATH}
工程: {PROJECT_NAME} / ORM: {ORM_TYPE} / PROFILE: {MIGRATION_PROFILE}

产出物:
- 基线文档: {BASELINE_PATH}
- 风险矩阵: {RISK_MATRIX_PATH}
- 测试缺口: {TEST_GAP_PATH}

必须按需读取:
- {TOOLKIT_PATH}/fix-issue/ 相关记录
- {TOOLKIT_PATH}/docs/risks/known-risks-highgo.md
- {TOOLKIT_PATH}/docs/references/ 中与 {ORM_TYPE} 相关的映射表

Rubric（每项必须给证据，不许打感觉分）:

R1. 扫描覆盖度 —— SQL 仓统计中 Mapper XML + 注解 SQL + 脚本 SQL + 字符串拼接 SQL 是否全量覆盖。缺项列出。
R2. 风险矩阵完整性 —— 每条风险有文件路径 + 行号 + 严重度 + 建议动作 + 关联工具包风险编号。缺项列出。
R3. 测试缺口准确性 —— 关键路径方法（被多处调用的公共 DAO、涉及事务/动态 SQL 的方法）无遗漏。
R4. 历史风险引用 —— 引用了 {TOOLKIT_PATH}/fix-issue/ 中与本工程 ORM_TYPE / CONNECTION_POOL 匹配的记录。
R5. 变量一致性 —— BASELINE_PATH / RISK_MATRIX_PATH / TEST_GAP_PATH 中的信息与 Stage 0 变量确认表一致。

输出（严格按此格式，不要散文）:

DECISION: APPROVE | REVISE | ESCALATE
CONFIDENCE: 1-10
R1: PASS | FAIL - <一行证据>
R2: PASS | FAIL - <一行证据>
R3: PASS | FAIL - <一行证据>
R4: PASS | FAIL - <一行证据>
R5: PASS | FAIL - <一行证据>
REVISE_ITEMS: <DECISION=REVISE 时列出缺口；APPROVE 留空；ESCALATE 写原因>
RATIONALE: 2-3 句总结
```

Controller 处理：
- `APPROVE` + `CONFIDENCE >= 8` + R1-R5 全 PASS → 追加 `OPS_LOG`，进 Stage 2
- `REVISE` → 按 `REVISE_ITEMS` 自修 1 轮，再跑一次 1.5；仍不通过则 `STOP`
- `ESCALATE` → `STOP`，呈现 auditor 报告和原因
- `APPROVE` 但 `CONFIDENCE < 8` → `STOP`，让用户决定是否接受

## Stage 2 · 测试兜底（SOP Stage 1）

### 2.1 确定"关键路径"范围

优先级从高到低：

1. 被多处调用的公共 DAO / Mapper
2. 涉及事务、批量操作、动态 SQL 的方法
3. 使用 MySQL 特有特性的方法（参照 `RISK_MATRIX_PATH` 高风险条目）
4. 对外接口直接触达的持久层方法

一般性 CRUD 若完全走框架标准能力（MyBatis-Plus `BaseMapper`），可降级为"仅集成冒烟即可"。

### 2.2 补齐测试

按 `TEST_GAP_PATH` 中标记的关键路径，逐模块补齐：

- 单元测试：JUnit 5 + Mockito，覆盖 正常 1 + 边界 1 + 异常 1（最低要求）
- 集成测试：JUnit 5 + Spring Boot Test，**必须连本地真实 MySQL**
- 不写 `@ActiveProfiles`，数据库 profile 由 Maven Profile 的 `systemPropertyVariables` 注入
- **禁止 mock 被测类本身**，只 mock 外部依赖
- **禁止使用 `@MockBean` 替代数据库**
- **禁止使用 Testcontainers**

**验收标准（10 条，逐条写入 subagent prompt，禁止跳过任何一条）**：

1. 对应方法是否有测试用例
2. 测试用例是否覆盖正常路径 + 边界条件 + 异常路径（最低三条，缺一不可）
3. 断言消息使用中文
4. 单元测试禁止 mock 被测类本身，只 mock 外部依赖；DB 必须真实，非 DB 外部依赖可 mock
5. 集成测试不写 `@ActiveProfiles`，数据库 profile 由 Maven Profile 的 `systemPropertyVariables` 注入，连接真实 MySQL，禁止 `@MockBean` 替代数据库，禁止 Testcontainers
6. 集成测试必须使用真实 MySQL schema 中已存在的库、表、字段
7. 集成测试禁止自行创建数据库对象：不得使用 CREATE DATABASE、CREATE SCHEMA、CREATE TABLE、CREATE TEMPORARY TABLE、CREATE TABLE ... LIKE ...、ALTER TABLE、DROP TABLE、DROP TEMPORARY TABLE
8. 集成测试数据准备只允许对已存在的真实表执行 INSERT / UPDATE / DELETE，并具备清理机制（回滚 / cleanup）
9. 若测试所需库、表或字段缺失，必须标记为 schema blocker，不得通过临时库、临时表、影子表或 fixture 表绕过
10. 在当前 MySQL 环境下测试是否通过

可并行执行的模块，派 subagent 并行补测。每个 subagent prompt 必须包含：

```text
你是本项目的测试编写 executor。为 {PROJECT_NAME} 的 {模块名} 补齐数据库交互测试。

Working Directory: {PROJECT_PATH}
目标模块: {模块路径}
完整步骤: 按 {TEST_GAP_PATH} 中本模块的每个缺口方法逐一编写测试，覆盖正常 1 + 边界 1 + 异常 1（最低）
关键路径方法:
{方法清单}

相关历史风险:
- {TOOLKIT_PATH}/fix-issue/ 中与本模块 ORM_TYPE 匹配的条目（执行前必须 grep 确认）

验收标准（10 条，逐条确认后才可报告 DONE，不得跳过任何一条）:
1. 对应方法是否有测试用例
2. 测试用例是否覆盖正常路径 + 边界条件 + 异常路径（最低三条，缺一不可）
3. 断言消息使用中文
4. 单元测试禁止 mock 被测类本身，只 mock 外部依赖；DB 必须真实，非 DB 外部依赖可 mock
5. 集成测试不写 @ActiveProfiles，数据库 profile 由 Maven Profile 的 systemPropertyVariables 注入，连接真实 MySQL，禁止 @MockBean 替代数据库，禁止 Testcontainers
6. 集成测试必须使用真实 MySQL schema 中已存在的库、表、字段
7. 集成测试禁止自行创建数据库对象：不得使用 CREATE DATABASE、CREATE SCHEMA、CREATE TABLE、CREATE TEMPORARY TABLE、CREATE TABLE ... LIKE ...、ALTER TABLE、DROP TABLE、DROP TEMPORARY TABLE
8. 集成测试数据准备只允许对已存在的真实表执行 INSERT / UPDATE / DELETE，并具备清理机制（回滚 / cleanup）
9. 若测试所需库、表或字段缺失，必须标记为 schema blocker，不得通过临时库、临时表、影子表或 fixture 表绕过
10. 在当前 MySQL 环境下测试是否通过

命名约束:
- 单元测试命名: XxxServiceTest / XxxMapperTest
- 集成测试命名: XxxMapperIntegrationTest / XxxServiceIntegrationTest
- 断言消息用中文
- 集成测试不写 @ActiveProfiles，数据库 profile 由 Maven Profile 注入

禁止项:
- 禁止 @MockBean 替代数据库，禁止 Testcontainers
- 禁止 mock 被测类本身，只 mock 外部依赖
- 禁止自行创建数据库对象（CREATE DATABASE / CREATE SCHEMA / CREATE TABLE / CREATE TEMPORARY TABLE / CREATE TABLE ... LIKE ... / ALTER TABLE / DROP TABLE / DROP TEMPORARY TABLE）
- 禁止使用临时库、临时表、影子表、fixture 表绕过 schema 缺口

允许修改的文件范围:
- src/test/java/ 下对应的测试类
- 如需测试数据，使用 @Sql 或 @BeforeAll 造数，只对已存在的真实表 INSERT / UPDATE / DELETE，必须有 cleanup 清理机制

关键路径方法覆盖完整性校验（必须逐条核对 TEST_GAP_PATH，缺失即补充，不得以"已有类似测试"跳过）:
- 列出 TEST_GAP_PATH 中本模块的所有关键路径方法
- 对每一条确认：有测试 → 打勾；无测试 → 立即补写
- 不得以"该方法已间接覆盖"或"框架自带"为由跳过缺失方法

schema blocker 判定:
- 若测试所需的库、表或字段在真实 MySQL schema 中不存在，立即标记为 schema blocker 并报告，不得自行创建对应对象绕过
- 报告格式: SCHEMA_BLOCKER: <缺失对象> - <所属模块> - <引用该对象的测试方法>

窄验证命令:
mvn test -Dtest={测试类名} -pl {模块}

出异常必须 BLOCKED 报告，不得猜。
```

### 2.3 跑绿 MySQL 基线

```bash
mvn -P integration-mysql-baseline test
```

全部绿后，记录结果到 `project-docs/reports/YYYY-MM-DD-test-baseline-mysql.md`。

### 2.4 快照归档

- Git 提交：`test: SOP Stage 1 测试兜底，MySQL 下基线全绿`
- 打 tag：`sop-stage-1-baseline-mysql-green`
- **这是回归对照基准**，Stage 6 将用相同测试集在瀚高 v4.1.5 下重跑

### 2.5 出口检查

- [ ] `TEST_GAP_PATH` 中标记为"关键路径"的方法全部有测试
- [ ] 所有测试在 MySQL 下全绿
- [ ] `grep -r "@MockBean" src/test/` 无命中（或命中项均为非数据库 mock）
- [ ] 无 Testcontainers 依赖引入
- [ ] 报告已产出，tag 已打

**逐条验收标准核对（新增，每条必须有证据）**：

1. **方法有测试**：关键路径方法逐条在测试代码中有对应测试方法（按 `TEST_GAP_PATH` 列表人工读代码核）
2. **三条覆盖**：每测试类中断言数量 ≥ 3（正常 + 边界 + 异常各至少一条）
3. **中文断言**：断言消息含中文字符（`assertThat(...).as("中文...")` 或 `assertEquals(..., "中文消息")`）
4. **禁止 mock 被测类**：单元测试中若出现被测类 mock，立即红（如 `when(mockXxxMapper.selectById(...))`）
5. **真实 MySQL 连接**：集成测试不写 `@ActiveProfiles`，通过 Maven Profile `systemPropertyVariables` 注入 profile，无 `@MockBean`/`Testcontainers`
6. **真实 schema**：集成测试的 `@Sql`/`@BeforeAll`/fixture 只对已存在的表做 DML，无 CREATE/DROP/ALTER
7. **无 DDL 脚本**：测试代码和 support helper 中无 `CREATE DATABASE`/`CREATE SCHEMA`/`CREATE TABLE`/`DROP TABLE` 等关键字
8. **cleanup 机制**：每个集成测试有 `@After`/`@AfterEach` 或 `@Sql` 回滚机制清理测试数据
9. **schema blocker 上报**：若发现测试引用了真实 schema 中不存在的库/表/字段，已标记并记入 `OPS_LOG`，不得绕过
10. **MySQL 基线全绿**：`mvn -P integration-mysql-baseline test` 全部 PASS

任一未通过 → `STOP`，不得进入 Stage 3。

## Stage 3 · 依赖与配置切换（SOP Stage 2）

### 3.x · 工作树启动硬约束（Bash CWD 不可暴露失败给用户）

**硬约束**（违反即 STOP，不允许擅自向后台抛失败命令暴露给用户）：

1. `git worktree add` 之后**第一条 Bash 命令**必须是：
   ```bash
   cd <绝对路径>/.worktrees/<slug> && pwd
   ```
   绝对路径，不是相对。`pwd` 输出必须确认 cwd 已锚定到 worktree 根。
2. 进入 worktree 后任何后续命令**不再**写 `.worktrees/<slug>` 前缀。子目录用相对路径或基于 worktree 根的绝对路径，**两种风格不混用**。
3. 后台命令（`run_in_background: true`）启动**前**必须先用一条前台 `pwd` 或 `ls <目标路径>` 验证目标存在。
4. 在 cycle 任意阶段如果 Bash 命令报 `No such file or directory`，必须立即停止并 `pwd` 自检，不得在不验证路径的前提下重试或派后台任务。

### 3.1 JDBC 驱动替换

`pom.xml`：

- **保留** `mysql-connector-java`（Stage 6 之前需要继续跑 MySQL 基线做双轨验证）
- **新增** 瀚高 JDBC 驱动：

```xml
<dependency>
  <groupId>com.highgo</groupId>
  <artifactId>HgdbJdbc</artifactId>
  <version>{JDBC_DRIVER_VERSION}</version>
</dependency>
```

驱动类名：`com.highgo.jdbc.Driver`

注意：瀚高驱动通常不在 Maven 中央仓库，需通过公司内部 Nexus 或 `mvn install:install-file` 装入本地仓库。如遇阻塞，记录到 `fix-issue/`。

### 3.2 多 profile 配置

在 `src/main/resources/` 下保持两份 profile 并存：

- `application-integration-mysql-baseline.yml`（Stage 2 已用，保留不动）
- `application-integration-highgo.yml`（本阶段新建）

瀚高侧示例：

```yaml
spring:
  datasource:
    driver-class-name: com.highgo.jdbc.Driver
    url: jdbc:highgo://host:port/db?currentSchema=schema_name
    username: xxx
    password: xxx
```

两份文件除 `spring.datasource` / `spring.flyway.locations` 之外其他尽量一致。

### 3.3 连接池方言适配

**Druid**：
- `db-type` 设为 `postgresql`
- `filters` 初期移除 `wall`，仅保留 `stat`
- `validation-query` 改为 `SELECT 1`

**HikariCP**：
- `maximum-pool-size` 视实际压测下调 30%~50%
- `connection-test-query` 设 `SELECT 1`

### 3.4 分页插件方言

**PageHelper**：`helper-dialect: postgresql`（必须显式配置，`fromJdbcUrl()` 无法识别 `jdbc:highgo://`）

**MyBatis-Plus**：推荐按 JDBC URL 动态识别：

```java
private DbType resolveDbType(Environment env) {
    String url = env.getProperty("spring.datasource.url", "");
    if (url.contains("highgo") || url.contains("postgresql")) {
        return DbType.POSTGRE_SQL;
    }
    return DbType.MYSQL;
}
```

Pilot 踩坑（见 `{TOOLKIT_PATH}/fix-issue/2026-04-22-trs-basemybatis-repository-compat.md`）：TRS 公共依赖 `media_base_web_mybatis` 的 `TrsMybatisPlusConfig` 硬编码 `DbType.MYSQL`，必须在工程本地覆盖该 Bean。

### 3.5 Flyway 目录切分

```
src/main/resources/db/migration/
├── mysql/           # 原有脚本，保留不动
└── highgo/          # 新建，Stage 4 填充业务 Schema
    └── .gitkeep
```

`application-integration-highgo.yml`：

```yaml
spring:
  flyway:
    locations: classpath:db/migration/highgo
    baseline-on-migrate: true
    baseline-version: 0
```

**严禁**修改 `db/migration/mysql/` 下任何历史脚本。

### 3.6 注入厂家 MySQL 兼容脚本

两种方式（选一或组合）：

- **方式 A**：DBA 手动 psql 注入（首次落地推荐）
- **方式 B**：Flyway `V0_0_1__mysql_compat_functions.sql` 自动化（CI/新环境推荐）

注入后必测冒烟 SQL（5 正向 + 2 反向）：

```sql
-- 正向可用性测试（5 条，必须全部通过）
SELECT DATE_FORMAT(NOW(), '%Y-%m-%d');
SELECT DATE_FORMAT('2025-01-01'::timestamptz, '%Y%m');
SELECT IFNULL(NULL::integer, 0);
SELECT FIND_IN_SET('b', 'a,b,c');
SELECT TRUNCATE(100 / 3::numeric, 2);
SELECT mysql_compat_version();                    -- 期望返回 {COMPAT_SCRIPT_VERSION}

-- 反向缺口验证（2 条，必须按预期报错）
SELECT IFNULL(NULL::timestamp, NOW());           -- 期望 ERROR: function ifnull(timestamp, timestamp) does not exist
SELECT IF(true, 1, 2);                           -- 期望 ERROR: function if(boolean, integer, integer) does not exist
```

任一"正向"测试失败或"反向"测试意外通过，立即记录到 `fix-issue/`。

### 3.7 启动冒烟

```bash
mvn -P integration-highgo spring-boot:run
```

目标：应用启动成功，DataSource 能初始化、Flyway 能连上目标库。

### 3.8 出口检查

- [ ] `pom.xml` 同时含 MySQL 与瀚高驱动
- [ ] 两份 `application-integration-*.yml` 可独立运行
- [ ] Druid / HikariCP / PageHelper / MyBatis-Plus 方言参数已切到 `postgresql`
- [ ] `db/migration/highgo/` 目录已创建，历史 `db/migration/mysql/` 脚本未动
- [ ] 兼容脚本已注入，5 项正向冒烟 SQL 全通过，2 项反向冒烟 SQL 全按预期报错，`mysql_compat_version()` 返回值与 `COMPAT_SCRIPT_VERSION` 一致
- [ ] `mvn -P integration-highgo spring-boot:run` 启动无致命错

任一未通过 → `STOP`。

## Stage 4 · Schema 迁移（SOP Stage 3）

### 4.1 导出 MySQL Schema

```bash
mysqldump -h <host> -u <user> -p \
  --no-data --routines --triggers --events \
  <db_name> > mysql-schema.sql
```

### 4.2 人工 review（必须）

按以下清单逐表 review：

**类型映射**（详表见 `{TOOLKIT_PATH}/docs/references/mysql-to-highgo-type-mapping.md`）：
- `DATETIME` vs `TIMESTAMP` 语义确认
- `JSON` → `JSONB` 查询函数名完全不同
- `ENUM` → `VARCHAR + CHECK` 约束
- 自增策略：推荐 `GENERATED BY DEFAULT AS IDENTITY`

**保留字**（详表见 `{TOOLKIT_PATH}/docs/references/mysql-to-highgo-syntax-mapping.md`）：
- 冲突列名统一加双引号或改名

**字符集与排序**：
- `utf8mb4_general_ci` 大小写不敏感比较 → 瀚高需显式 `COLLATE` 或 `LOWER()`

**索引与约束**：
- 外键 `ON DELETE CASCADE` 依赖确认
- `ON UPDATE CURRENT_TIMESTAMP` → PG 不原生支持，需触发器或应用层

### 4.3 产出 Flyway 脚本

命名：`V{YYYYMMDDHHmm}__highgo_init_schema.sql`

放置：`src/main/resources/db/migration/highgo/`

脚本规范：
- 所有 `CREATE TABLE` 带 `IF NOT EXISTS`
- 所有 `CREATE INDEX` 带 `IF NOT EXISTS`
- 不含 `DROP DATABASE` / `TRUNCATE`
- 大变更拆多个 `V` 脚本

### 4.4 DDL 防护语法冒烟（R-018）

在目标库执行防护语法冒烟测试，确认 `CREATE TABLE IF NOT EXISTS` / `DROP TABLE IF EXISTS` / `CREATE INDEX IF NOT EXISTS` / `ALTER TABLE ADD COLUMN IF NOT EXISTS` 均可用。`ADD CONSTRAINT IF NOT EXISTS` **PG 不支持**，用 `DO $$ BEGIN ... END $$;` 模拟。

### 4.5 Flyway 执行验证

```bash
mvn -P integration-highgo flyway:migrate
```

验证：
- 所有脚本执行无错
- `flyway_schema_history` 表有记录
- 表、索引、约束对齐预期

### 4.6 Schema 对比校验

产出 `project-docs/reports/YYYY-MM-DD-schema-diff.md`，对比项：表数量、每表列数/列名/类型、索引名与列组合、外键关系。

### 4.7 回写风险矩阵

回写 `RISK_MATRIX_PATH` 中由 Schema 迁移承接的风险项状态：
- **可关闭项**：仅限 DDL/Schema 资产风险（`AUTO_INCREMENT` 映射、`ENGINE` 移除、`COMMENT` 转换等）
- **不可关闭项**：涉及 Mapper 参数绑定的类型风险（`tinyint`/`datetime`/`longtext`）、字符集查询语义风险，保留到 Stage 5/6 真库验证后关闭

### 4.8 出口检查

- [ ] `db/migration/highgo/V*__init_schema.sql` 脚本可重复执行不报错
- [ ] 所有表、索引、约束已建立
- [ ] 类型映射、保留字、字符集策略已记录并应用
- [ ] Schema 对比报告已产出
- [ ] `RISK_MATRIX_PATH` 中 Stage 3 承接项已回写
- [ ] 未修改 `db/migration/mysql/` 任何文件

任一未通过 → `STOP`。

## Stage 5 · SQL 方言适配（SOP Stage 4）

### 5.1 按类别分组

参照 `{TOOLKIT_PATH}/docs/references/mysql-to-highgo-syntax-mapping.md` 的状态列（✅/⚠️/🔄/❌），把风险矩阵中的条目分成若干类。

**按 Stage 0 变量过滤**（以下类别仅在对应条件为真时出现）：
- `HAS_STORED_PROCEDURES=false` → 移除"存储过程/触发器"类别
- `ORM_TYPE` 不含 `jpa` → 移除"JPA Criteria.groupBy"类别
- `HAS_FLYWAY=false` → 跳过 Stage 4 中 Flyway 相关验证步骤
- `PAGINATION_PLUGIN=none` → 跳过分页方言检查

| 类别 | 典型特征 | 优先级 | 脚本覆盖 | 说明 |
|---|---|---|---|---|
| 反引号标识符 | `` `user` `` `` `order` `` | 高 | — | ❌ 改双引号或全小写 |
| `LIMIT m, n` 分页 | `LIMIT 10, 20` | 高 | — | ❌ 改 `LIMIT 20 OFFSET 10` |
| `ON DUPLICATE KEY UPDATE` | upsert 用法 | 高 | — | ❌ 改 `ON CONFLICT DO UPDATE` |
| `REPLACE INTO` / `INSERT IGNORE` | MySQL 特有 upsert | 高 | — | ❌ 改 ON CONFLICT |
| `UPDATE/DELETE ... LIMIT n` | 批量带 LIMIT | 中 | — | ❌ 改子查询 |
| `UPDATE t1 JOIN t2` | 多表 UPDATE | 中 | — | ❌ 改 `UPDATE ... FROM ...` |
| 保留字列名 | `user` / `type` / `order` | 中 | — | 加双引号或改名 |
| 隐式类型转换 | `int_col LIKE` / `string=int_col` | 中 | — | ❌ 加 `::TEXT` / `::INT` |
| 双引号字符串字面量 | `"0000"` 作为字符串值 | 中 | — | ❌ 改为单引号 |
| 函数层脚本已覆盖 | `IFNULL(int)` / `FIND_IN_SET` | 低 | ✅ | 不改，跑测试验证 |
| 函数层脚本缺口 | `IFNULL(timestamp)` / `IF(cond, int, int)` | 中 | ❌ | 改 `COALESCE` / `CASE WHEN` |
| `DATE_FORMAT` 递归风险 | 所有 `DATE_FORMAT` 调用 | 高 | ⚠️ | Stage 3 已验证则免改 |
| JSON 查询 | `j->'$.a'` / `JSON_EXTRACT` | 高 | — | 语法完全不同 |
| MySQL Hint | `STRAIGHT_JOIN` / `USE INDEX` | 中 | — | 去除 |
| `LOCK IN SHARE MODE` | MySQL 共享锁 | 低 | — | 改 `FOR SHARE` |
| 存储过程 / 触发器 | `DELIMITER //` / `CREATE PROCEDURE` | 高（如有） | — | 上移 Java 层 |
| 聚合除法除零 | `ROUND(SUM(...) / SUM(...), 2)` | 中 | — | `NULLIF(分母, 0)` + `::numeric` |
| JPA Criteria.groupBy | `cb.groupBy()` | 高 | — | 框架层 GROUP BY 路径不兼容 |
| DISTINCT ON 排序 | PostgreSQL 专有语法 | 中 | — | 考虑 ROW_NUMBER() 替代 |
| 列名大小写 | 混用大小写标识符 | 中 | — | 统一小写 snake_case |
| 日期范围查询 | 字符串比较日期 | 中 | — | 改原生类型范围比较 |

### 5.2 对每一类执行"小循环"

**小循环** = 改码 → 跑测试 → commit

1. 从风险矩阵挑出该类所有条目
2. 调用 Skill `db-migration-dialect-rewrite`（如已安装）获取建议 diff（**Skill 不自动改码**）
3. 人工 review Skill 建议
4. 应用修改
5. 跑相关测试：`mvn -P integration-highgo test -Dtest=<pattern>`
6. 全绿后 commit，消息格式：

   ```
   refactor(db): Stage 4 适配 <类别名>

   - 涉及文件 N 个
   - 风险矩阵条目：R-xx, R-yy, R-zz
   - 验证：XxxMapperIntegrationTest 全绿
   ```

7. 更新 `RISK_MATRIX_PATH` 中对应条目状态为 ✅

可并行执行的类别，派 subagent 并行改写。每个 subagent prompt 必须包含：

```text
你是本项目的 SQL 方言改写 executor。为 {PROJECT_NAME} 的 {类别名} 执行 MySQL → 瀚高 v4.1.5 改写。

Working Directory: {PROJECT_PATH}
目标类别: {类别名}
涉及文件和风险矩阵条目:
{条目清单，含文件路径、行号、原始 SQL、建议改写方案}

相关历史风险:
- {TOOLKIT_PATH}/fix-issue/ 中与本类别匹配的条目
- {TOOLKIT_PATH}/docs/risks/known-risks-highgo.md 中关联风险编号

改写约束:
- 不改业务逻辑，只做方言适配
- 参照工具包 docs/references/ 下对应映射表
- 每个改写点必须跑对应集成测试验证
- 函数层脚本已覆盖的不改，只跑测试
- 分类别独立 commit

允许修改的文件范围:
- {涉及文件清单}

禁止修改的文件范围:
- db/migration/mysql/ 下任何文件
- 非当前类别的 Mapper XML / Java 文件

窄验证命令:
mvn -P integration-highgo test -Dtest={测试类名}

出异常必须 BLOCKED 报告，不得猜。不得跳过测试。
```

### 5.3 函数层兼容脚本验证子流程

针对"函数层脚本已覆盖"类别：

1. 确认 Stage 3 已成功注入脚本且 5 正向 + 2 反向冒烟 SQL 全通过
2. 对每个涉及函数的 Mapper 方法，至少一条集成测试覆盖真实数据
3. 特别关注 `DATE_FORMAT` / `TRUNCATE`（除法）/ `MOD(text, int)` 这类有"已知行为差异"的函数
4. 测试失败回到 5.2 作为"脚本缺口"类别改写

### 5.4 双轨验证

Stage 5 期间每次改动后：

- 先跑 `integration-highgo` profile，确认新功能绿
- 再跑 `integration-mysql-baseline` profile，确认未破坏 MySQL 行为
- 若双轨均红 → `STOP`，报告两条红链路的根因对比，由用户决策是回滚还是继续调试

**例外**：若改动是瀚高特有（如 `databaseId` 分方言），MySQL 基线应跳过对应用例。

### 5.5 无法直接兼容的场景

若某条 SQL 在瀚高下无法原样运行：

- **策略 1 改写**：调整为瀚高 PG 方言写法（优先）
- **策略 2 分方言 Mapper**：MyBatis 使用 `databaseId`，同名 statement 区分 mysql / highgo
- **策略 3 Java 侧处理**：把部分逻辑从 SQL 抽到 Service（慎用）

每次选用策略 2 / 3 需在 `project-docs/decisions/` 记录决策与原因。

### 5.6 出口检查

- [ ] `RISK_MATRIX_PATH` 所有条目状态为 ✅ 或 `decision-deferred`
- [ ] 每类差异都有独立 commit
- [ ] 所有集成测试在瀚高下全绿
- [ ] 函数层脚本已覆盖的条目均有测试覆盖
- [ ] 未修改 `db/migration/mysql/` 任何文件
- [ ] 所有"分方言"或"架构调整"决策有 `decisions/` 记录

任一未通过 → `STOP`。

## Stage 5A · analyst 答疑（执行歧义自愈）

executor 报 `BLOCKED` 时，不直接 `STOP`；先派一个只读 `analyst` subagent，给出建议方案，让 executor 拿方案再跑一次。仍 `BLOCKED` 才升级给用户。

### 5A.1 触发条件

- executor 返回 `BLOCKED` 且 `BLOCKED.reason` 属于"执行歧义"类：SQL 改写方案不确定、命名约定二选一、找不到对应 PG 函数等
- 同一任务在本 cycle 内的 analyst 重试次数 `< 1`（每个任务最多一次自愈）

### 5A.2 硬 ESCALATE（命中任何一条直接 STOP，不许 analyst 自答）

- `BLOCKED.reason` 涉及修改已发布的 Flyway 脚本
- `BLOCKED.reason` 涉及的改动超出了当前改写类别的文件范围，需要跨类别联动改动
- 涉及删除现有测试或为让测试通过而改测试断言
- 涉及生产配置、密钥、外部服务凭证
- executor 已在本任务内重试 `>= 1` 次仍 BLOCKED
- analyst 自身置信度 < 8

### 5A.3 派 analyst subagent

派一个 general-purpose Agent，**只读权限**。Prompt 模板：

```text
你是本项目的 analyst。executor 在执行 SQL 方言改写时报了 BLOCKED，请只读地分析根因并给出可执行建议方案。你不得自己改代码。

Working Directory: {PROJECT_PATH}
工程: {PROJECT_NAME} / ORM: {ORM_TYPE}
当前改写类别与原始 SQL:
{BLOCKED_SQL_CONTEXT}

executor BLOCKED 报告:
{BLOCKED_REPORT}

可参考:
- {TOOLKIT_PATH}/docs/references/ 全部映射表
- {TOOLKIT_PATH}/fix-issue/ 全部踩坑记录
- {TOOLKIT_PATH}/docs/risks/known-risks-highgo.md
- 本仓库已存在的同类改写实现（grep 同模式）

硬 ESCALATE 条件（命中任何一条直接 ESCALATE）:
- 问题需要改已发布 Flyway 脚本
- 问题需要删除现有测试或改断言
- 问题涉及生产配置/密钥
- 你需要的事实在 references / fix-issue 里都查不到

输出（严格格式，不要散文）:

DECISION: ANSWER | ESCALATE
CONFIDENCE: 1-10
ROOT_CAUSE: <一句话根因>
EVIDENCE: <文件:行号 或 fix-issue/references 引用，至少 1 条>
PROPOSED_FIX: <executor 应执行的具体步骤，不超过 5 步>
RISK_NOTES: <方案可能引入的副作用；无则写 NONE>
RATIONALE: 2-3 句总结
```

### 5A.4 Controller 处理

- `ANSWER` + `CONFIDENCE >= 8` + 硬 ESCALATE 全未命中 → 追加 `OPS_LOG`（含 analyst 完整输出），把 `PROPOSED_FIX` 注入原 executor 的 prompt 后重派；executor 报 `DONE` → 继续；再次 `BLOCKED` → 直接 `STOP`
- `ESCALATE` 或 `CONFIDENCE < 8` → `STOP`，呈现 analyst 完整报告

## Stage 6 · 回归与交付（SOP Stage 5）

### 6.1 全量回归（瀚高 v4.1.5）

```bash
mvn -P integration-highgo clean test
```

要求：
- 所有单元测试绿
- 所有集成测试绿
- 与 Stage 2 MySQL 基线比对，用例数一致（除非有明确声明的差异）

任一红灯 → `STOP`，定位根因后修复并重跑。

### 6.2 启动冒烟 + 接口回归

- 应用启动成功
- 对外接口按现有 E2E 套跑一遍（若有）
- 关键业务场景手工回归 2~3 个

### 6.3 配置产物复查

- `application-integration-highgo.yml` 字段齐全
- Druid / HikariCP 参数合理
- Flyway `locations` 指向 `highgo` 目录
- 日志无 `WARN` / `ERROR` 堆栈
- 连接池监控指标正常

### 6.4 产出验收报告

调用 Skill `db-migration-verify`（如已安装）生成骨架，人工补全。

文件：`project-docs/reports/YYYY-MM-DD-highgo-migration-report.md`

参照模板：`{TOOLKIT_PATH}/docs/templates/migration-report-template.md`

内容包含：
- 工程基本信息
- 各阶段耗时
- 改造范围汇总（文件数、行数、commit 数）
- 风险矩阵关闭情况
- 测试对比：MySQL 基线 vs 瀚高 v4.1.5
- 未解决问题与上游依赖
- 回滚方案
- 附录：决策记录索引、踩坑记录索引

### 6.4.1 MySQL 方言遗漏自检

调用 Skill `db-migration-self-check`（如已安装），对项目 SQL 源码做 MySQL 方言遗漏扫描。

输出：`<project>/project-docs/reports/YYYY-MM-DD-mysql-dialect-self-check.md`

行为：**仅出报告，不阻断交付**。命中项供人工 review，如需修复回到 Stage 4。

自检报告作为验收报告附件，一并提供给 review 方。

### 6.5 踩坑回灌工具包

把本工程发现的**通用性问题**提炼为 `fix-issue` 记录，推送回 `db-migration-toolkit`：

准入口径（四要素缺一不可）：**现象 + 根因 + 修复/规避 + 真实来源**

不满足四要素的问题按文档治理协议分流：`fact` / `playbook` / `decision` / `faq`。

### 6.6 框架反馈

对本次 SOP 使用体验写一份反馈，包括：
- 哪些步骤耗时超预期？
- 哪些 checklist 项形同虚设？
- 哪些 references 缺了关键条目？

### 6.7 出口检查

使用 `{TOOLKIT_PATH}/docs/checklists/acceptance-checklist.md` 逐项核对。

硬检查项：

- [ ] 应用在瀚高 profile 下启动成功，无致命错
- [ ] 应用在 MySQL profile 下仍可启动（回滚能力保留）
- [ ] `mvn -P integration-highgo test` 全绿
- [ ] `mvn -P integration-mysql-baseline test` 全绿（或已声明的差异项除外）
- [ ] `RISK_MATRIX_PATH` 所有条目为 ✅ 或 `decision-deferred`
- [ ] 验收报告已产出
- [ ] 已向工具包 `fix-issue/` 推送通用踩坑
- [ ] 回滚方案已文档化

任一未通过 → `STOP`。

## Stage 7 · Closeout

按 `CLOSEOUT_ACTION` 收尾：

### `merge-worktree`

1. 回到项目根
2. `git checkout main`
3. `git merge --ff-only {BRANCH_NAME}`；非 ff 或冲突则 `STOP`
4. 删除 worktree：`git worktree remove {WORKTREE_PATH}`；失败则 `STOP`，提示用户手动清理
5. 删除本地分支：`git branch -d {BRANCH_NAME}`

### `commit-only`

1. 确认所有计划内文件已提交
2. 输出提交、验证结果和剩余风险

### `report-only`

1. 报告落盘到 `project-docs/reports/YYYY-MM-DD-{PROJECT_NAME}-migration-report.md`
2. 输出结论、证据、未解决问题和下一步建议

### 交付物打包

- 改造分支 PR（引用母方案 `{TOOLKIT_PATH}/docs/2026-04-18-master-plan.md`）
- PR 描述贴 `{TOOLKIT_PATH}/docs/checklists/migration-pr-checklist.md` 的勾选结果
- Git tag `sop-stage-5-highgo-migration-done-v1.0.0`

最终必须打印：

- `PROJECT_NAME` / `MIGRATION_PROFILE`
- 改造起止日期
- `BASELINE_PATH` / `RISK_MATRIX_PATH` / `OPS_LOG` 路径
- 最终验证命令和结果
- merge/commit/report 结果
- 未解决风险和下一步建议

## 非负义务

- 本命令只能由用户手动 `/work-cycle-auto ...` 触发，任何时候不得自主调用
- **严禁修改 `db/migration/mysql/` 下任何历史脚本**——违反即 STOP，不允许例外
- 每个阶段的出口检查必须逐项核对，不得跳过
- 集成测试必须连真实数据库，**禁止 `@MockBean` 替代数据库、禁止 Testcontainers**
- Flyway 新建脚本必须带 `IF NOT EXISTS` / `IF EXISTS` 防护，**严禁 `DROP DATABASE` / `TRUNCATE`**
- `analyst` 只读，禁止 Edit/Write；同一任务自愈最多 1 次；二次 BLOCKED 必须 `STOP`
- 验证红灯、merge 冲突都必须 `STOP`（Stage 5 BLOCKED 由 Stage 5A 兜底）
- 不做数据迁移、不做架构重构、不做性能调优、不做灰度切换——这些超出改造范围，发现即升级
- **DATE_FORMAT 递归风险（R-002）**：Stage 3 兼容脚本注入后必须对高频 `DATE_FORMAT` 调用路径做递归深度观测；若确认递归，立即改写为 `to_char` 原生调用，不得保留有递归风险的兼容函数
- **TIMESTAMP 时区语义（R-004）**：所有 `TIMESTAMP` 字段必须明确声明为 `timestamp` 或 `timestamptz`，不得依赖 MySQL 的"存 UTC 取本地"隐式行为
- **瀚高中文报错（R-005）**：集成测试中匹配报错信息时，必须同时兼容中英文（如 `doesn't exist` + `关系.*不存在`）
- **字符集 collation 大小写敏感（R-012）**：Stage 5 改写时，所有依赖大小写不敏感匹配的查询必须显式加 `LOWER()` 或 `citext`，不得依赖瀚高默认 collation
- **兼容脚本版本漂移（R-017）**：Stage 3 注入后必须调用 `mysql_compat_version()` 并与 `COMPAT_SCRIPT_VERSION` 核对；不一致则 STOP
- **多 profile 测试隔离**（per fix-issue 2026-04-29）：`integration-mysql-baseline` 和 `integration-highgo` 必须**隔离执行**，禁止在同一 test run 中混合两个 profile
- 中文提交信息
- 工程文档落盘到 `project-docs/` 时必须含 `updated:` 字段
- `fix-issue/` 准入口径：四要素（现象 + 根因 + 修复/规避 + 来源）缺一不得放入
- 分页插件方言**必须显式配置**为 `postgresql`，不可依赖自动检测（`jdbc:highgo://` 无法被 PageHelper `fromJdbcUrl()` 识别）
- 涉及存储过程/触发器 → 默认上移 Java 层，不可在数据库层重写 PL/pgSQL
- 聚合除法必须用 `NULLIF(分母, 0)` 包裹 + `::numeric` 转型，避免除零异常和 ROUND 签名不匹配
- `analyst` 不得"为让 BLOCKED 消失而绕过测试"（如建议跳过失败测试、注释代码、放宽断言 → 视为 ESCALATE）
- **不得让 AI 自身的低级失误（路径错误、selector 错误、CWD 误判等）通过 `run_in_background` 命令的 task failure notification 暴露给用户**。后台命令启动前，目标路径必须用前台 `pwd` / `ls` 验证存在。
- **Stage 3 启动 worktree 后第一条 Bash 命令必须是 `cd <绝对路径>/.worktrees/<slug> && pwd`**，输出验证 cwd 锚定到 worktree 根。后续命令一律基于此锚点的相对子路径或绝对路径，不再写 `.worktrees/<slug>` 前缀。
