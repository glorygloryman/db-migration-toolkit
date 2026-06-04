# Changelog

## v0.3.4 — 2026-06-04

**移除 `db-migration-schema-convert` Skill：Schema 转换由瀚高官方迁移工具承担**

### 变更
- 移除 `skills/db-migration-schema-convert/`：实际改造中 Schema 转换均使用瀚高官方数据库迁移工具完成，该 Skill 已无实际价值
- `CLAUDE.md`：Skill 数量 8→7，架构树移除该条目
- `README.md`：Skills 清单表与软链命令移除该条目
- `docs/2026-04-18-master-plan.md`：配套 Skills 表移除该行
- `docs/sop/stage-3-schema-migration.md`：§3.2 工具辅助转换整段删除，后续步骤重编号
- `skills/work-cycle-auto/SKILL.md`：Stage 4.2 工具辅助转换整段删除，后续步骤重编号
- `project-docs/plans/2026-04-21-pilot-smoke-test.md`：软链循环与计数同步更新
- `project-docs/plans/2026-04-21-pivot-to-highgo.md`：Task 14 文件列表、Step 14.3、软链循环、commit message 与计数同步更新
- `project-docs/domain/2026-04-21-瀚高国产化改造标准业务流程.md`：Skill 计数同步更新

## v0.3.3 — 2026-06-01

**Pilot 知识回灌（event_server）：String/Date 隐式比较、GeneratedKeyHolder 多列、HikariCP 方言**

### fix-issue
- 新增 `fix-issue/2026-05-29-pg-string-date-implicit-comparison.md`：PostgreSQL 拒绝 String 与 date/timestamp 隐式比较，需加 `::date` 或 `::timestamp` 显式转换
- 新增 `fix-issue/2026-05-29-generated-key-holder-multi-column.md`：JdbcTemplate `GeneratedKeyHolder` 在 PostgreSQL 下返回多列（含所有 GENERATED 列），须指定具体列名数组替代 `RETURN_GENERATED_KEYS`
- 新增 `fix-issue/2026-05-29-hikari-connection-init-sql-dialect.md`：HikariCP `connection-init-sql` MySQL/PostgreSQL 语法互不兼容，须按 profile 隔离
- `fix-issue/README.md`：索引从 14 条扩展到 17 条

## v0.3.2 — 2026-06-01

**集成测试 Profile 切换机制标准化：`@ActiveProfiles` → Maven Profile `systemPropertyVariables`**

### 变更
- 集成测试不再使用 `@ActiveProfiles("integration-mysql-baseline")`，改为 Maven Profile 通过 `maven-surefire-plugin` 的 `systemPropertyVariables` 注入 `spring.profiles.active`，Spring Boot Test 自动拾取
- 效果：同一套测试代码，`mvn -P integration-mysql-baseline test` 跑 MySQL，`mvn -P integration-highgo test` 跑瀚高，零代码修改

### 文档
- `CLAUDE.md`：不可动摇的前提假设新增第 8 条（集成测试不写 `@ActiveProfiles`）
- `docs/sop/stage-1-test-baseline.md`：§1.3 集成测试配置改为 Maven Profile 注入说明
- `docs/sop/stage-2-config-switch.md`：§2.2 新增 pom.xml profile `systemPropertyVariables` 配置模板
- `docs/sop/stage-5-verify-deliver.md`：§5.1 补充零代码切换说明
- `docs/templates/test-gap-plan-template.md`：2 处验收标准模板更新

### Skill
- `skills/db-migration-test-plan/SKILL.md`：验收标准更新
- `skills/db-migration-test-execute/SKILL.md`：集成测试步骤 + 复核要点更新
- `skills/work-cycle-auto/SKILL.md`：6 处 `@ActiveProfiles` 引用全部替换

## v0.3.1 — 2026-05-25

**Pilot 知识回灌（bigv_data_receive）：db-sdk 兼容性验证 + 集成测试 DataSource 硬编码**

### fix-issue
- 新增 `fix-issue/2026-05-25-db-sdk-highgo-compat-verified.md`：db-sdk (trs-db-sdk) 1.4.11 在瀚高环境下验证通过，当前使用模式（AbsBeanRepository + Hybase 搜索操作）不涉及关系型 SQL 生成，R-008 可降级为 🟢
- 新增 `fix-issue/2026-05-25-test-datasource-hardcoded-not-switchable.md`：集成测试 DataSource 硬编码导致 Maven profile 切换无效（`@SpringBootConfiguration` 绕过 Spring 属性绑定，需用 `System.getProperty()` + surefire `systemPropertyVariables` 桥接）

## v0.3.0 — 2026-05-12

**Baseline template 内容完善**

### 兼容脚本修复
- `docs/references/highgo-v4.1.5-mysql-compat-functions.sql`：`substring(text, bigint)` 函数创建语法错误，函数名需用双引号包裹（`"substring"`）避免与 PG 内置保留关键字冲突

## v0.2.9 — 2026-05-09

**Pilot 知识回灌（tmy-decision-center）：DISTINCT ON 排序、JPA Criteria groupBy、日期范围、列名大小写、Entity 类型**

### fix-issue
- 新增 `fix-issue/2026-05-08-weibo-bomb-distinct-on-ordering.md`：DISTINCT ON 排序语义变化导致分页行为不一致（子查询包裹 + countQuery 去重方案）
- 新增 `fix-issue/2026-05-08-jpa-criteria-groupby-highgo-incompat.md`：JPA Criteria.groupBy / PageInfo.addGroupby 在瀚高方言下不兼容（框架层 GROUP BY 路径被风险矩阵遗漏）
- 新增 `fix-issue/2026-05-09-rownumber-vs-distinct-on.md`：DISTINCT ON → ROW_NUMBER() 窗口函数改写方案（标准 SQL 替代 PostgreSQL 专有语法）
- 新增 `fix-issue/2026-05-09-date-range-string-to-native-type.md`：日期范围查询从字符串比较改为原生类型范围比较（索引可用 + 左闭右开语义）
- 新增 `fix-issue/2026-05-09-pg-column-case-sensitivity.md`：PostgreSQL 列名大小写敏感导致查询失败
- 新增 `fix-issue/2026-05-09-entity-type-string-to-integer.md`：Entity 字段类型 String → Integer 修正（数据库整数列声明为 String）
- `fix-issue/README.md`：索引从 8 条扩展到 14 条

### 备注
- 排除 `2026-05-09-pg-round-numeric-cast.md`：ROUND(numeric) 类型问题已在 v0.2.3 ~ v0.2.6 的 3 条 fix-issue 中充分覆盖

## v0.2.8 — 2026-05-06

**精简 Stage 4：移除冗余 Skill，改用 superpowers 标准流程接管**

### 变更
- 移除 `skills/db-migration-stage4-plan-rewrite/`：该 Skill 产出的执行计划与 `dialect-rewrite` 清单信息高度冗余，其任务拆解能力由 superpowers `writing-plans` 替代
- 移除 `skills/db-migration-stage4-execute-task/`：逐条执行能力由 superpowers `executing-plans` 替代，"只跑对应测试、不修失败原因"等约束写入 plan 即可
- `skills/db-migration-dialect-rewrite/SKILL.md`：后续步骤改为引导使用 `superpowers:writing-plans` + `superpowers:executing-plans`，并带入迁移特定约束
- `CLAUDE.md`：Skill 数量 10→8，移除已删 Skill 描述，更新 Skill 写作约定
- `README.md`：Skills 清单表与软链命令同步精简

## v0.2.7 — 2026-04-30

**Stage 1 test-plan 验收标准明确：聚焦覆盖性，不要求瀚高环境通过**

### Skill
- `skills/db-migration-test-plan/SKILL.md`：验收标准字段从模糊描述展开为三条明确的覆盖性标准（有测试用例、覆盖关键分支、MySQL 环境通过），并注明不要求瀚高环境通过
- `skills/db-migration-test-plan/SKILL.md`：约束段新增说明 Stage 1 验收标准不包含瀚高通过，瀚高验证属于 Stage 5（`db-migration-verify`）职责

## v0.2.6 — 2026-04-29

**Pilot 知识回灌：ROUND/GROUP BY/类型不匹配/隐式聚合**

### fix-issue
- 新增 `fix-issue/2026-04-28-account-rank-round-groupby.md`：AccountRankMapper ROUND 类型与 GROUP BY 严格模式兼容性修复
- 新增 `fix-issue/2026-04-28-area-manager-in-query-type-mismatch.md`：AreaManager QueryWrapper IN 查询 integer/varchar 类型不匹配
- 新增 `fix-issue/2026-04-28-comprehensive-rank-round-groupby.md`：ComprehensiveRankMapper 无 GROUP BY 隐式聚合 + ROUND 类型 + GROUP BY 严格模式（含 `<choose>` 拆分方案与窗口函数改写）
- `fix-issue/README.md`：索引从 2 条扩展到 6 条，按日期排序；补充之前遗漏的 `trs-basemybatis-repository-compat` 索引

## v0.2.5 — 2026-04-28

**Stage 1 补测闭环：新增计划生成与逐条执行 Skill**

### Skill
- 新增 `skills/db-migration-test-plan/SKILL.md`：读取 test-gap 测试缺口清单，按模块 × 测试类型 × 优先级拆分为独立可执行的 Task 计划，产出 `test-gap-plan.md`
- 新增 `skills/db-migration-test-execute/SKILL.md`：按 Task 编号执行补测（编写测试代码 → 运行验证 → 回写计划进度 + test-gap 覆盖状态）
- `skills/db-migration-test-gap/SKILL.md`：后续步骤改为引导使用 `test-plan` → `test-execute` 流水线

### 文档
- 新增 `docs/templates/test-gap-plan-template.md`：执行计划产出模板
- `CLAUDE.md`：Skill 列表补充 `stage4-plan-rewrite`、`stage4-execute-task`（之前遗漏），新增 `test-plan`、`test-execute`；Skill 写作约定补充会修改代码的 Skill 例外说明
- `README.md`：Skills 清单表新增两个 Skill，软链命令同步补充

## v0.2.4 — 2026-04-28

**Stage 4 改写闭环：新增执行计划与逐条执行 Skill**

### Skill
- 新增 `skills/db-migration-stage4-plan-rewrite/SKILL.md`：读取 stage4 改写清单文档，拆解为原子任务执行计划，生成标准化执行提示词模板，产出 `stage4-execution-plan.md`
- 新增 `skills/db-migration-stage4-execute-task/SKILL.md`：按任务编号逐条执行改写，运行对应集成测试方法，回写执行计划进度
- `skills/db-migration-dialect-rewrite/SKILL.md`：后续步骤新增提示，引导用户在清单生成后依次调用 `/db-migration-stage4-plan-rewrite` 和 `/db-migration-stage4-execute-task`

### 文档
- `README.md`：Skills 清单表新增两个 Skill，软链命令同步补充

## v0.2.3 — 2026-04-28

**Pilot 知识回灌：聚合除法除零 + ROUND 类型签名问题**

### 风险
- 新增 R-021 🟡：聚合除法除零 + ROUND 签名双问题（`x / 0` 在 PG 抛异常而非返回 NULL；`ROUND(double, int)` 签名不存在）

### 函数映射
- `docs/references/mysql-to-highgo-function-mapping.md` 数值节：`ROUND` 从 ✅ 修正为 ⚠️，补充 `::numeric` 转型规则与签名差异说明
- `docs/references/mysql-to-highgo-function-mapping.md` 数值节：新增 `/` 除法运算符条目，标注除零行为差异与 `NULLIF` 改写规则

### fix-issue
- 新增 `fix-issue/2026-04-28-aggregate-division-round-type-error.md`：聚合除法除零异常 + ROUND 签名不匹配踩坑记录，含改写模板

## v0.2.2 — 2026-04-27

**Pilot 知识回灌：propagation-billboard 方言适配阶段发现**

### 风险
- 新增 R-020 🟡：PG 严格类型检查导致隐式转型失效（`int LIKE`/`LEFT(int)`/`string=int` 等跨类型操作报错，约 10+ 处）
- R-005 增强：补充瀚高中文 locale 下报错信息为中文（如 `关系 "xxx" 不存在`），集成测试 safeQuery 需兼容中英文匹配

### 语法映射
- `docs/references/mysql-to-highgo-syntax-mapping.md` §1 新增：双引号字符串字面量（`"0000"` / `"%"`）在 PG 中被当标识符，必须改单引号
- `docs/references/mysql-to-highgo-syntax-mapping.md` §4 新增：隐式类型转换（MySQL 自动转型 vs PG 严格检查），含 `::TEXT` / `::INT` 改写策略

### Skill
- `skills/db-migration-dialect-rewrite/SKILL.md` §C 组追加：双引号字符串字面量条目
- `skills/db-migration-dialect-rewrite/SKILL.md` §D 组追加：隐式转型缺失条目（含 R-020 引用与排查方法）

### SOP
- `docs/sop/stage-4-dialect-adapt.md` 4.1 分类表新增两行：隐式类型转换（R-020）、双引号字符串字面量
- `docs/sop/stage-2-config-switch.md` §2.1 回填 JDBC 驱动坐标（`com.highgo:HgdbJdbc:6.2.3`，本地测试版本，项目最终版本待指定）
- `docs/sop/stage-2-config-switch.md` §2.2 回填驱动类名 `com.highgo.jdbc.Driver`、JDBC URL 格式、properties 格式示例
- `docs/sop/stage-2-config-switch.md` §2.4 补充 PageHelper properties 格式示例
- `docs/sop/stage-2-config-switch.md` §2.4 MybatisPlus 分页方言改为 Pilot 验证的动态识别方案（`resolveDbType`），标注 `media_base_web_mybatis` 硬编码 `DbType.MYSQL` 的踩坑
- `docs/sop/stage-2-config-switch.md` 移除全部 `<待确认-...>` 占位符，出口检查措辞同步更新

### fix-issue
- 新增 `fix-issue/2026-04-27-highgo-chinese-error-safequery.md`：瀚高中文报错导致集成测试 safeQuery 跳过逻辑失效，含修复代码示例

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
