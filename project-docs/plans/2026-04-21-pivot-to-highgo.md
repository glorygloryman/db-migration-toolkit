# 目标库切换（GaussDB → 瀚高 v4.1.5）文档整改实施方案 v2

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 db-migration-toolkit 的全部文档、Skill、元数据从 "MySQL → GaussDB B 兼容模式" 切换到 "MySQL → 瀚高（HighGo）v4.1.5 + 厂家 MySQL 函数兼容脚本" 的新目标，使 Pilot 可在真实目标库上按新 SOP 推进。

**Architecture:** 认定"瀚高 v4.1.5 = PostgreSQL 内核 + 企业特性 + 厂家函数兼容 shim"。放弃原先"目标库原生兼容 MySQL"的假设；PG 方言成为主基调；MySQL **函数**由厂家兼容脚本在目标库一次性预装抹平，MySQL **语法**（反引号、`LIMIT m,n`、`ON DUPLICATE KEY UPDATE` 等）需在应用层改写——Stage 4 工作量重估回 PG 级别，但函数层有成熟 shim 可依赖。

**Tech Stack:** 纯 Markdown/YAML 文档工具包；shell 批量 rename；Grep 残留校验；git 逐任务提交。无代码编译。

---

## v2 变更记录（相对 v1）

v1 经 `/plan-eng-review` 审查发现 19 条 findings（A1–A5 / C1–C7 / T1–T4 / P1–P3），v2 全部采纳：

| Finding | 采纳方式 | 所在位置 |
|---------|---------|---------|
| A1 脚本命名丢版本号 | 脚本改名为 `highgo-v4.1.5-mysql-compat-functions.{sql,md}`，说明文档随之 | §1 映射表 / Task 1 |
| A2 rename 与引用更新次序危险 | 每个重命名类 Task 的 rename + 引用更新 + 内容重写**合并为单一 commit** | Task 3–7 |
| A3 残留扫描误报 superseded 决策 | grep 加 `--exclude=2026-04-21-why-b-compat-mode.md` | Task 17 |
| A4 兼容脚本版本管理缺失 | 脚本注入 `mysql_compat_version()` 函数；compat 决策含版本管理子节；新增风险 R-017 | Task 1 / 7 |
| A5 改造量数字无依据 | master-plan 的"30~50%"改为 `⚠️ 待 Pilot 校准` 占位 | Task 2 |
| C1 Task 17 DRY 倾斜 | Task 17 拆为 Task 12 (templates) + Task 13 (checklists)，逐文件列具体 line-level 替换 | Task 12 / 13 |
| C2 SOP Task 违反 No Placeholders | Task 10 (stage-4) 给完整重写草案；Task 11 给每份 SOP 关键段落 before/after | Task 10 / 11 |
| C3 Edit 多行匹配脆弱 | Task 1 里 superseded frontmatter 拆两次 Edit | Task 1 |
| C4 CHANGELOG/tag 时序 | Task 19 最终 tag 改**必选**；CHANGELOG 条目注"tag 见 Task 19" | Task 15 / 19 |
| C5 术语表与正文不一致 | 术语表条目改为"改写为'函数层节省 30~50%（⚠️ 待 Pilot 校准）'" | §1 |
| C6 Flyway 防护语法盲点 | Task 7 新增 R-018；Task 9 新增 DDL 防护语法验证步骤 | Task 7 / 9 |
| C7 缺 R-017 | 合并到 A4 | Task 7 |
| T1 冒烟 SQL 覆盖不足 | Task 8 冒烟清单扩至 7 条，含正反向 | Task 8 |
| T2 残留 regex 不全 | Task 17 regex 扩展为 7 个 pattern | Task 17 |
| T3 无内部链接验证 | Task 17 新增链接可达性与 doc-catalog.yaml path 校验 | Task 17 |
| T4 缺 Pilot 烟测清单 | 新增 Task 18，产出 `project-docs/plans/2026-04-21-pilot-smoke-test.md` | Task 18 |
| P1 提交粒度不均 | 原 Task 11/12/16 合并为一个 Task 11（stage 0/1/5 批量替换） | Task 11 |
| P2 并行化未体现 | 新增 §4"并行化策略"，列依赖图与 Lane 划分 | §4 |
| P3 Task 1–4 原子性 | 原 4 个 Task 合并为 Task 1（单一逻辑步，保留 4 子 commit） | Task 1 |

Task 总数：21 → 19（减少 2，但内容质量显著增强）。

---

## 0. 澄清事项（C1–C10，执行时统一核实）

执行者遇到以下项按"按用户声明优先"原则暂定，并在各文档里显式标 `⚠️ 待 Pilot 核实`：

| # | 待确认项 | 当前暂定 | 位置 |
|---|---------|---------|------|
| C1 | 版本号：用户文字 "v4.1.5" vs 文件名 "v45" | **v4.1.5**（已编码进所有文件名） | 所有文档 |
| C2 | 瀚高 JDBC 驱动 Maven 坐标 | `<待确认-瀚高-jdbc-坐标>` 占位符 | stage-2, baseline-template |
| C3 | JDBC URL scheme | `jdbc:highgo://` | stage-2 |
| C4 | Druid `dbType` | `postgresql` | stage-2, risks |
| C5 | 瀚高 v4.1.5 是否支持反引号标识符 | **不支持**（PG 原生） | syntax-mapping |
| C6 | 瀚高 v4.1.5 是否支持 `LIMIT m,n` | **不支持** | syntax-mapping |
| C7 | 瀚高 v4.1.5 是否支持 `ON DUPLICATE KEY UPDATE` | **不支持** | syntax-mapping |
| C8 | 兼容脚本版权/分发限制 | 内部使用，脚本可归档本仓库 | Task 1 |
| C9 | 兼容脚本注入所需权限 | 建库 owner，在公共 schema 执行 | Task 8 |
| C10 | 兼容脚本适用版本范围 | 仅 v4.1.5 实测，其他版本须验证 | Task 1 说明文档 |

Task 17 会汇总所有 `⚠️ 待 Pilot 核实` 与 `<待确认-*>` 出现点，形成 Pilot 首日核实清单。

---

## 1. 文件映射总表

**重命名（7 条，全部 rename + 内容改写合并单 commit per A2）：**

| 旧路径 | 新路径 | 处理 Task |
|--------|--------|----------|
| `project-docs/decisions/v45mysql兼容函数.sql` | `docs/references/highgo-v4.1.5-mysql-compat-functions.sql` | Task 1 |
| `docs/references/gaussdb-compatibility-modes.md` | `docs/references/highgo-v4-compatibility.md` | Task 3 |
| `docs/references/mysql-to-gaussdb-type-mapping.md` | `docs/references/mysql-to-highgo-type-mapping.md` | Task 4 |
| `docs/references/mysql-to-gaussdb-syntax-mapping.md` | `docs/references/mysql-to-highgo-syntax-mapping.md` | Task 5 |
| `docs/references/mysql-to-gaussdb-function-mapping.md` | `docs/references/mysql-to-highgo-function-mapping.md` | Task 6 |
| `docs/risks/known-risks-gaussdb.md` | `docs/risks/known-risks-highgo.md` | Task 7 |
| `docs/2026-04-18-master-plan.md` | 文件名保留，内容整体改写 | Task 2 |

**新增（3 条）：**
- `project-docs/decisions/2026-04-21-target-db-highgo-v4.md`（Task 1）
- `project-docs/decisions/2026-04-21-use-vendor-mysql-compat-functions.md`（Task 1，含脚本版本管理章节）
- `docs/references/highgo-v4.1.5-mysql-compat-functions.md`（Task 1，脚本说明文档）
- `project-docs/plans/2026-04-21-pilot-smoke-test.md`（Task 18，Pilot 烟测清单）

**状态变更（1 条）：**
- `project-docs/decisions/2026-04-21-why-b-compat-mode.md` → `status: superseded`（Task 1）

**内容改写（已有文件，不改名）：**
- `README.md` / `CLAUDE.md` / `CHANGELOG.md` / `VERSION`（Task 15）
- `project-docs/README.md` / `project-docs/_meta/doc-catalog.yaml` / `project-docs/plans/2026-04-21-v1.0.0-roadmap.md` / `project-docs/facts/2026-04-21-consumer-projects-inventory.md`（Task 16）
- `docs/2026-04-18-master-plan.md`（Task 2）
- 6 份 SOP（Task 8 / 9 / 10 / 11 涵盖 stage-0 至 5）
- 4 份 templates（Task 12）
- 3 份 checklists（Task 13）
- 6 份 Skill（Task 14）
- `fix-issue/README.md`（Task 15）

**术语统一表：**

| 旧 | 新 |
|----|----|
| GaussDB | 瀚高（HighGo） |
| gaussdb | highgo |
| "B 兼容模式" / "B 模式" | 删除；按上下文改为 "瀚高 v4.1.5" 或 "瀚高 v4.1.5 PG 方言 + 厂家 MySQL 函数 shim" |
| `com.huawei.gaussdb:gaussdbjdbc` / `com.huawei.gauss200.jdbc.Driver` | `<待确认-瀚高-jdbc-坐标>` / `<待确认-瀚高-驱动类>`（C2） |
| `jdbc:gaussdb://` | `jdbc:highgo://`（C3） |
| `db/migration/gaussdb/` | `db/migration/highgo/` |
| `integration-gaussdb` profile | `integration-highgo` profile |
| `application-integration-gaussdb.yml` | `application-integration-highgo.yml` |
| `stage-5-gaussdb-migration-done-vX.Y.Z` tag | `stage-5-highgo-migration-done-vX.Y.Z` tag |
| "改造量下降 60~80%" / "B 模式下改造量下降 60~80%" | **改写为**"函数层节省 30~50%（⚠️ 待 Pilot 校准），语法层仍按 PG 方言逐条改写" |

---

## 2. 预计工期

约 1.5 ~ 2 天人工（或 1 个 subagent-driven 会话，含 review）。含 Task 18 的 Pilot 烟测清单编写。

---

## 3. Prerequisite

本计划**与 fix-issue 目录搬迁（根 `fix-issue/` → `project-docs/fix-issue/`）相互独立**。两者都会改 `docs/` 下多份文件的路径引用。

- 若合并：在 Task 11 / 12 / 13 / 14 / 15 / 16 中同时替换 `fix-issue/` → `project-docs/fix-issue/`，commit message 加 `(含 fix-issue 搬迁)` 后缀
- 若不合并：本计划只改 GaussDB → 瀚高，保留 fix-issue 在根目录

**默认不合并**（减少本计划复杂度）。启动时由执行者或用户重新确认。

---

## 4. 并行化策略（per P2）

### 4.1 依赖图

```
                  ┌──────────────┐
                  │  Task 1      │  兼容脚本 + 3 决策（基线）
                  │  (atomic)    │
                  └──────┬───────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
     Task 3          Task 4          Task 5
   compatibility   type-mapping   syntax-mapping
         │               │               │
         └───────┬───────┴───────┬───────┘
                 ▼               ▼
             Task 6           Task 7
         function-mapping   known-risks（含 R-017/R-018）
                 │               │
                 └───────┬───────┘
                         ▼
                     Task 2
                   master-plan
                  （引用全部 references）
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
     Task 8          Task 9          Task 10
     Stage 2         Stage 3         Stage 4
                         │
                         ▼
                    Task 11
                 SOP Stage 0/1/5
                  批量术语替换
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
     Task 12         Task 13         Task 14
     templates      checklists        Skills
                         │
                         ▼
                    Task 15
                  根元文档
                         │
                         ▼
                    Task 16
                project-docs 元数据
                         │
                         ▼
                    Task 17
                  残留扫描 + 链接校验
                         │
                         ▼
                    Task 18
                  Pilot 烟测清单
                         │
                         ▼
                    Task 19
                    最终 tag
```

### 4.2 并行 Lane 划分

| Lane | 任务 | 说明 |
|------|------|------|
| **Lane R（references）** | Task 3 / 4 / 5 并行 → Task 6 / 7 并行 | 5 份 references 互独立；6 / 7 可与 3/4/5 部分并行（6 引用 3 / 7 引用 3+7） |
| **Lane S（SOP Stage 2-4）** | Task 8 / 9 / 10 并行 | 三份 SOP 互独立，只引用 references（Lane R 已完成） |
| **Lane T（templates / checklists / skills）** | Task 12 / 13 / 14 并行 | 三组互独立 |
| **串行关键路径** | Task 1 → Lane R → Task 2 → Lane S → Task 11 → Lane T → Task 15 → Task 16 → Task 17 → Task 18 → Task 19 | Task 2 / 11 / 15 / 16 必须串行 |

### 4.3 subagent-driven 派发建议

使用 `superpowers:dispatching-parallel-agents` 时，按 Lane 批量派发。每 Lane 完成后 review 一次。

**阶段 1**：Task 1（单 agent）
**阶段 2**：Task 3 + 4 + 5 并行派发（3 agents）→ review
**阶段 3**：Task 6 + 7 并行派发（2 agents）→ review
**阶段 4**：Task 2（单 agent）→ review
**阶段 5**：Task 8 + 9 + 10 并行派发（3 agents）→ review
**阶段 6**：Task 11（单 agent）
**阶段 7**：Task 12 + 13 + 14 并行派发（3 agents）→ review
**阶段 8**：Task 15 → 16 → 17 → 18 → 19（串行）

共 8 阶段，减少约 40% 等待时间。

### 4.4 冲突风险

- Task 3 / 4 / 5 / 6 / 7 只修改各自独立文件，**零冲突**
- Task 8 / 9 / 10 只修改各自 SOP 文件，**零冲突**
- Task 12 / 13 / 14 只修改各自子目录（templates / checklists / skills），**零冲突**
- 所有并行 Lane 使用 git 各自 commit，合并时**无文件级冲突**

---

## 5. 任务分解

### Task 1: 基线建立——脚本迁移 + 3 份决策文档（原子逻辑步）

> **per P3：**原 Task 1 / 2 / 3 / 4 合并为一个逻辑步，保留 4 子 commit，但必须一次性完成不中断。
> **per A1：**脚本命名编码精确版本 `v4.1.5`。
> **per A4：**脚本注入 `mysql_compat_version()`；compat 决策含版本管理章节；known-risks 新增 R-017（Task 7 落地）。
> **per C3：**superseded frontmatter 拆两次 Edit。

**Files:**
- Rename: `project-docs/decisions/v45mysql兼容函数.sql` → `docs/references/highgo-v4.1.5-mysql-compat-functions.sql`
- Create: `docs/references/highgo-v4.1.5-mysql-compat-functions.md`
- Create: `project-docs/decisions/2026-04-21-target-db-highgo-v4.md`
- Create: `project-docs/decisions/2026-04-21-use-vendor-mysql-compat-functions.md`
- Modify: `project-docs/decisions/2026-04-21-why-b-compat-mode.md`（frontmatter + banner）

- [ ] **Step 1.1：git mv 脚本到 references 目录**

```bash
cd /Users/cy/MyWorkFactory/workspace/xz-source/db-migration-toolkit
git mv project-docs/decisions/v45mysql兼容函数.sql \
       docs/references/highgo-v4.1.5-mysql-compat-functions.sql
```

- [ ] **Step 1.2：在脚本末尾追加版本标记函数**

用 Edit 工具，把脚本的最末行后追加：

```sql


-- =============================================================
-- 工具包版本标记（per db-migration-toolkit v0.2.0）
-- Pilot 注入后 `SELECT mysql_compat_version()` 确认版本
-- =============================================================
CREATE OR REPLACE FUNCTION mysql_compat_version()
RETURNS text AS $$ SELECT '1.0.0-highgo-v4.1.5-vendor-2026-04-21' $$
LANGUAGE sql IMMUTABLE;
```

- [ ] **Step 1.3：写脚本说明文档**

Write `docs/references/highgo-v4.1.5-mysql-compat-functions.md`：

```markdown
# 瀚高 v4.1.5 MySQL 函数兼容脚本说明

> **脚本位置**：`docs/references/highgo-v4.1.5-mysql-compat-functions.sql`
> **来源**：瀚高厂家提供（C10：适用版本范围 ⚠️ 待 Pilot 核实）
> **版权**：⚠️ 待 Pilot 核实（C8）
> **注入时机**：Stage 2（目标库一次性预装，先于 Schema 迁移）
> **注入权限**：⚠️ 待 Pilot 核实（C9，暂按建库 owner 权限）
> **版本标记**：脚本末尾 `mysql_compat_version()` 返回形如 `1.0.0-highgo-v4.1.5-vendor-2026-04-21`

## 覆盖的 MySQL 函数清单

| MySQL 函数 | 脚本内函数签名 | 用途 | 注意 |
|-----------|---------------|------|------|
| `MOD(text, int)` | `mod(text_val text, mod_val integer) → integer` | 文本转整数后取模 | 转换失败或除零返回 NULL（不抛错，与 MySQL 行为略异） |
| `IFNULL(a, b)` | 4 个重载：integer / numeric / varchar / text | NULL 兜底 | **不含 timestamp/date 重载**，时间类型需显式 `COALESCE` |
| `SUBSTRING(text, bigint)` | `substring(pi_1 text, pi_2 bigint) → text` | 大整数偏移量支持 | 内部转 int 调用原生 substring |
| `CURDATE()` | `curdate() → date` | 当前日期 | 等价 `CURRENT_DATE` |
| `IF(cond, true_val, false_val)` | 3 个重载：DATE / TIMESTAMPTZ / BOOLEAN | 三目表达式 | **不含 numeric/text/int 重载**，需补齐或改 `CASE WHEN` |
| `DATE_FORMAT(timestamptz, text)` | `date_format(date_val, format_str) → text` | MySQL 格式符日期格式化 | **⚠️ 内部递归调用 DATE_FORMAT**，需确认瀚高是否已原生支持；若否此函数会栈溢出 |
| `YEAR(timestamptz)` | `year(inDate) → int4` | 取年份 | 等价 `EXTRACT(YEAR FROM ...)` |
| `MONTH(timestamptz)` | `month(inDate) → integer` | 取月份 | 等价 `EXTRACT(MONTH FROM ...)` |
| `FIND_IN_SET(text, text)` | `find_in_set(target, strlist) → integer` | 逗号分隔列表查找 | 基于 `string_to_array` 实现 |
| `STR_TO_DATE(text, text)` | `str_to_date(create_time, format_pattern) → timestamp` | MySQL 格式符解析时间 | 含 MySQL→PG 格式符转换与异常兜底 |
| `LAST_DAY(date)` | `last_day(p_date) → date` | 月末日期 | |
| `TRUNCATE(numeric, int)` | `truncate(p_number, p_decimals) → numeric` | 截断到指定小数位 | 调用 PG 原生 `TRUNC`；⚠️ 除法场景须显式 `::numeric` |
| `DAYOFYEAR(timestamptz)` | `dayofyear(p_date) → integer` | 年内第几天 | 等价 `EXTRACT(DOY FROM ...)` |
| `TO_DAYS(timestamp/date)` | 2 个重载 | MySQL 自公元起天数 | 实测有微小偏差，财务/审计勿依赖 |

## 使用注意

1. **函数仅覆盖，不覆盖语法**：反引号、`LIMIT m,n`、`ON DUPLICATE KEY UPDATE` 等语法**仍需应用层改写**
2. **`DATE_FORMAT` 递归风险**：脚本内 `date_format` 实现调用了大写 `DATE_FORMAT(...)`。若瀚高 v4.1.5 未原生提供 `DATE_FORMAT`，将无限递归栈溢出。**Pilot 首验证项**（见 R-002）
3. **`IF` 函数类型缺口**：仅 DATE/TIMESTAMPTZ/BOOLEAN 三个重载。工程使用 `IF(cond, int, int)` / `IF(cond, text, text)` 必须改写为 `CASE WHEN`
4. **`IFNULL` 类型缺口**：无 timestamp/date 重载。时间类型改 `COALESCE`
5. **`MOD` 与原生行为**：脚本版本吞 NULL 返回而非抛错，与 MySQL 严格模式行为不一致
6. **幂等注入**：脚本全部 `CREATE OR REPLACE FUNCTION`，重复执行安全

## 版本管理（per decision）

- 脚本末尾 `mysql_compat_version()` 返回版本字符串
- 下游工程 Stage 2 注入完成后执行 `SELECT mysql_compat_version()` 记录到 baseline
- 脚本任何改动（修 bug、补重载）须 bump 版本号并记 CHANGELOG
- Pilot 工程发现厂家有更新版本，先 PR 到本仓库、bump 版本标记、再下发

## 何时不需要使用

- 瀚高后续版本原生提供全部 MySQL 函数 → 本脚本退役
- 改造策略选择"全部 MySQL 函数在应用层替换为 PG 等价调用" → 不注入（工作量显著增大，不推荐）

## 关联决策

- [`project-docs/decisions/2026-04-21-use-vendor-mysql-compat-functions.md`](../../project-docs/decisions/2026-04-21-use-vendor-mysql-compat-functions.md)
- [`project-docs/decisions/2026-04-21-target-db-highgo-v4.md`](../../project-docs/decisions/2026-04-21-target-db-highgo-v4.md)

## 关联风险

- R-002 🔴 DATE_FORMAT 递归风险
- R-015 🟡 脚本重载类型缺口
- R-017 🟡 兼容脚本版本管理
```

- [ ] **Step 1.4：提交脚本迁移 commit**

```bash
git add docs/references/highgo-v4.1.5-mysql-compat-functions.sql \
        docs/references/highgo-v4.1.5-mysql-compat-functions.md
# 如果旧位置还在，git mv 已处理；否则显式删除
git status  # 确认 v45mysql兼容函数.sql 已从旧位置消失
git commit -m "docs: 迁移瀚高厂家 MySQL 兼容脚本至 docs/references/，补充用法说明与版本标记"
```

- [ ] **Step 1.5：写 target-db-highgo-v4 决策**

Write `project-docs/decisions/2026-04-21-target-db-highgo-v4.md`：

```markdown
---
type: decision
title: 目标库改为瀚高（HighGo）v4.1.5
created: 2026-04-21
updated: 2026-04-21
status: accepted
supersedes: project-docs/decisions/2026-04-21-why-b-compat-mode.md
---

# 目标库改为瀚高（HighGo）v4.1.5

## 背景

项目启动时假定目标库为 GaussDB B 兼容模式（见已废弃决策 `why-b-compat-mode.md`）。2026-04-21 根据最新实施环境信息，目标库确认为**瀚高数据库 v4.1.5**，非 GaussDB。需要调整工具包的全部假设、SOP、对照表、Skills。

## 新的事实

1. 瀚高 v4.1.5 基于 **PostgreSQL 内核**，非 GaussDB
2. 瀚高**不提供** GaussDB 式的 "B 兼容模式" —— 方言层接近原生 PG
3. 厂家提供 **MySQL 函数兼容脚本**（`docs/references/highgo-v4.1.5-mysql-compat-functions.sql`），覆盖常用 MySQL 函数（IFNULL / DATE_FORMAT / FIND_IN_SET / IF / STR_TO_DATE 等）
4. 脚本仅覆盖**函数**，不覆盖**语法**（反引号、LIMIT m,n、ON DUPLICATE KEY UPDATE 等仍需改写）

## 决策

- **目标库统一为瀚高 v4.1.5**，不再面向 GaussDB
- **基础方言按 PostgreSQL** 处理
- **MySQL 函数优先依赖厂家兼容脚本**抹平；无法覆盖的再走 Stage 4 逐条改写
- 改造量预估重新校准（见 `docs/2026-04-18-master-plan.md §1.2`）

## 后果

- 工具包全部文档、对照表、SOP、Skills 需整改
- Stage 4 工作量比"GaussDB B 模式"假设下显著增加（语法层无法偷懒），但比"纯 PG 无兼容脚本"假设下显著减少（函数层全免改）
- `references/` 新增"瀚高 v4.1.5 特性详解"与"兼容脚本说明"两份资产
- 旧决策 `why-b-compat-mode.md` 保留但状态置 `superseded`

## 何时重新评估

- 瀚高后续版本原生提供 MySQL 语法兼容
- 消费方被要求切换到其他 PG 系数据库（openGauss / KingbaseES / 达梦 PG 模式等），评估本工具包能否通用
```

- [ ] **Step 1.6：提交 target-db 决策**

```bash
git add project-docs/decisions/2026-04-21-target-db-highgo-v4.md
git commit -m "docs(decision): 新增决策—目标库改为瀚高 v4.1.5，废弃 GaussDB B 模式假设"
```

- [ ] **Step 1.7：写 use-vendor-mysql-compat-functions 决策（含版本管理章节 per A4）**

Write `project-docs/decisions/2026-04-21-use-vendor-mysql-compat-functions.md`：

```markdown
---
type: decision
title: 使用厂家 MySQL 函数兼容脚本而非逐条改写
created: 2026-04-21
updated: 2026-04-21
status: accepted
supersedes: 无
---

# 使用厂家 MySQL 函数兼容脚本而非逐条改写

## 背景

瀚高 v4.1.5 作为 PG 系数据库，不原生支持 MySQL 函数（`IFNULL` / `DATE_FORMAT` / `FIND_IN_SET` / `IF()` / `STR_TO_DATE` / `TO_DAYS` / `LAST_DAY` / `DAYOFYEAR` / `TRUNCATE` / `CURDATE` / `MONTH` / `YEAR` 等）。工程中这些函数广泛散布于 Mapper XML、`@Query` 注解、字符串拼接 SQL。

厂家提供 [`highgo-v4.1.5-mysql-compat-functions.sql`](../../docs/references/highgo-v4.1.5-mysql-compat-functions.sql)，通过 `CREATE OR REPLACE FUNCTION` 在目标库 DB 层一次性注入兼容函数。

## 候选方案

### 方案 A：注入厂家脚本 ✅ 采纳

**优点**：
- 应用层 SQL 几乎不改（函数调用保持原样）
- 一次注入、全库通用，多工程共享
- 脚本 `CREATE OR REPLACE`，幂等可重放

**代价**：
- DB 层多一层非原生函数，升级/迁移时需同步处理
- 兼容不完整：部分类型重载缺失（`IFNULL` 无 timestamp，`IF` 无 int/text）
- `DATE_FORMAT` 实现存在递归调用自身风险
- 版本兼容性仅验证了 v4.1.5，其他版本 ⚠️

### 方案 B：应用层逐条改写 ❌ 拒绝

工作量巨大；破坏测试基线；违背"不改架构"原则。

### 方案 C：JDBC / MyBatis Interceptor 动态改写 ❌ 拒绝

需要自研 shim；调试困难、性能损耗；与拦截器链冲突。

## 决策

**采用方案 A（注入厂家脚本）**。

## 约束与后果

- **Stage 2 新增动作**：环境搭建时必须先在目标库注入脚本
- **Stage 4 改造指引**：函数层冲突**首选**依赖脚本，不满足时改写 SQL 或上移 Java 层
- **脚本缺口必须记录**：发现某个 MySQL 函数调用不被脚本覆盖，在 `mysql-to-highgo-function-mapping.md` 的"脚本缺口"列追加说明
- **Pilot 验证项**：首要验证 `DATE_FORMAT` 不死循环、`IF()` 类型覆盖、`IFNULL` 时间类型是否降级到 `COALESCE`

## 脚本版本管理（per A4）

**背景**：脚本是 DB 层外挂资产，需要版本追踪机制防止工具包、厂家、下游工程之间漂移。

**机制**：

1. **脚本自带版本函数**：脚本末尾注入
   ```sql
   CREATE OR REPLACE FUNCTION mysql_compat_version()
   RETURNS text AS $$ SELECT '1.0.0-highgo-v4.1.5-vendor-2026-04-21' $$
   LANGUAGE sql IMMUTABLE;
   ```

2. **版本命名约定**：`<工具包封装版本>-highgo-<瀚高版本>-<来源>-<日期>`
   - 工具包封装版本：语义化版本（含本地修改时 bump patch）
   - 来源：`vendor` / `vendor-patched` / `community`

3. **Pilot 注入验证**：
   ```sql
   SELECT mysql_compat_version();
   ```
   结果记录到工程 baseline.md §1"目标库信息"章节。

4. **升级流程**：
   - 厂家发布新版本 → PR 到本仓库，bump 版本号、更新 CHANGELOG
   - 本地发现 Bug 修复 → PR 到本仓库，改 `vendor` 为 `vendor-patched`，bump patch
   - 下游工程发现版本落后 → Stage 2 重新注入新版本脚本

5. **已知风险**：R-017（脚本版本管理在多工程间漂移），见 `known-risks-highgo.md`

## 何时重新评估

- 瀚高后续版本原生提供全部 MySQL 函数
- 兼容脚本发现致命缺陷无法规避
- 新目标库加入，评估是否有类似 shim
```

- [ ] **Step 1.8：提交 compat 决策**

```bash
git add project-docs/decisions/2026-04-21-use-vendor-mysql-compat-functions.md
git commit -m "docs(decision): 新增决策—使用厂家 MySQL 函数兼容脚本，含版本管理策略"
```

- [ ] **Step 1.9：废弃 why-b-compat-mode 决策（两次 Edit per C3）**

第一次 Edit（只改 frontmatter）：

```
old_string:
---
type: decision
title: 为什么选 GaussDB B 兼容模式而非 PG 模式
created: 2026-04-21
updated: 2026-04-21
status: accepted
supersedes: 无
---

new_string:
---
type: decision
title: 为什么选 GaussDB B 兼容模式而非 PG 模式
created: 2026-04-21
updated: 2026-04-21
status: superseded
superseded_by: project-docs/decisions/2026-04-21-target-db-highgo-v4.md
---
```

第二次 Edit（在 `# 为什么选 GaussDB B 兼容模式而非 PG 模式` 下方插入 banner）：

```
old_string:
# 为什么选 GaussDB B 兼容模式而非 PG 模式

## 背景

new_string:
# 为什么选 GaussDB B 兼容模式而非 PG 模式

> ⚠️ **本决策已废弃**（2026-04-21）。项目真实目标库为瀚高 v4.1.5，非 GaussDB。
> 见替代决策：[`2026-04-21-target-db-highgo-v4.md`](./2026-04-21-target-db-highgo-v4.md)。
> 本文件保留用于记录思维演化，**不再作为行动指引**。

## 背景
```

- [ ] **Step 1.10：提交 superseded**

```bash
git add project-docs/decisions/2026-04-21-why-b-compat-mode.md
git commit -m "docs(decision): 标记 why-b-compat-mode 为 superseded"
```

---

### Task 2: 重写 master-plan.md

> **per A5：**"下降 60~80%" 改为 `⚠️ 待 Pilot 校准`。
> **per C5：**术语表修正。

**Files:**
- Modify: `docs/2026-04-18-master-plan.md`

- [ ] **Step 2.1：替换顶部元信息**

Edit，第 1-8 行：

```
old_string:
# MySQL → GaussDB 通用改造母方案

- **版本**：v0.1.0
- **日期**：2026-04-18
- **状态**：DRAFT（骨架版，待 Pilot 验证）
- **适用范围**：`xz-source/` 下所有使用 MySQL 的 Java / Spring Boot 工程
- **目标数据库**：GaussDB，**B 兼容模式（MySQL 兼容）**

new_string:
# MySQL → 瀚高 v4.1.5 通用改造母方案

- **版本**：v0.2.0（2026-04-21 目标库切换版）
- **首发日期**：2026-04-18
- **状态**：DRAFT（骨架版，待 Pilot 验证）
- **适用范围**：`xz-source/` 下所有使用 MySQL 的 Java / Spring Boot 工程
- **目标数据库**：**瀚高（HighGo）v4.1.5**（PostgreSQL 系，非 GaussDB）
- **兼容策略**：PG 方言为基础 + 厂家 MySQL 函数兼容脚本（见 [`references/highgo-v4.1.5-mysql-compat-functions.md`](references/highgo-v4.1.5-mysql-compat-functions.md)）
- **目标切换说明**：原目标库 GaussDB B 兼容模式已废弃，详见 [`project-docs/decisions/2026-04-21-target-db-highgo-v4.md`](../project-docs/decisions/2026-04-21-target-db-highgo-v4.md)
```

- [ ] **Step 2.2：重写 §1.2 改造量预估**

Edit，原 §1.2 标题到该节结束（line 25 左右到 36 左右）整段替换为：

```
old_string:
### 1.2 B 兼容模式下的改造量预估

因 GaussDB B 模式原生兼容大量 MySQL 语法（反引号、`LIMIT m,n`、`ON DUPLICATE KEY UPDATE`、`AUTO_INCREMENT`、`GROUP_CONCAT`、`IFNULL`、`DATE_FORMAT`、`TINYINT(1)` 等），Stage 4（方言适配）工作量较 PG 模式下降 60%~80%。

**但仍需验证的差异点**（详见 `references/gaussdb-compatibility-modes.md`）：
- JDBC 驱动（`gaussdbjdbc`，非 `mysql-connector`）
- 连接池 SQL Parser（Druid `dbType`）
- 字符集与排序规则
- 时区处理与 `TIMESTAMP` 语义
- 保留字清单（与 MySQL 有差异）
- 部分边缘函数行为
- 存储过程 / 触发器语法（若工程使用）
- 执行计划与性能特征

new_string:
### 1.2 改造量预估

瀚高 v4.1.5 基于 PostgreSQL 内核，**方言层接近原生 PG**。改造量分两部分：

**A. 函数层（多数可免改）**：厂家提供 MySQL 函数兼容脚本，一次性注入目标库后，以下 MySQL 函数可保持原样不改：
`IFNULL` / `IF()` / `DATE_FORMAT` / `STR_TO_DATE` / `FIND_IN_SET` / `CURDATE` / `YEAR` / `MONTH` / `DAYOFYEAR` / `LAST_DAY` / `TRUNCATE` / `TO_DAYS` 等（清单见 [`references/highgo-v4.1.5-mysql-compat-functions.md`](references/highgo-v4.1.5-mysql-compat-functions.md)）。
⚠️ **已知缺口**：`IFNULL` 无 timestamp 重载、`IF` 无 int/text 重载、`DATE_FORMAT` 实现存在递归风险（Pilot 必验）。

**B. 语法层（必须逐条改写）**：脚本无能为力的部分，Stage 4 工作量集中于此：
- 标识符反引号 `` `col` `` → 双引号 `"col"` 或全小写无歧义
- `LIMIT offset, count` → `LIMIT count OFFSET offset`
- `ON DUPLICATE KEY UPDATE` → `INSERT ... ON CONFLICT ... DO UPDATE`
- `REPLACE INTO` → `INSERT ... ON CONFLICT ... DO UPDATE` 或 `DELETE + INSERT`
- `UPDATE/DELETE ... LIMIT n`（PG 不支持，需改写）
- `UPDATE t1 JOIN t2 SET ...`（PG 用 `UPDATE ... FROM ...`）
- MySQL Hint（`STRAIGHT_JOIN` / `USE INDEX`）→ 去除，让 PG 优化器决定
- 存储过程 / 触发器（如使用）→ 优先上移 Java 层

**C. 其他必验证项**（见 [`references/highgo-v4-compatibility.md`](references/highgo-v4-compatibility.md)）：JDBC 驱动坐标、JDBC URL scheme、Druid `dbType`、字符集、时区 `TIMESTAMP` 语义、保留字清单、大小写行为、MVCC 下 `FOR UPDATE` 行为、执行计划差异。

**改造量数字**：⚠️ **待 Pilot 校准**。定性估计——相较"假想的 GaussDB B 模式"路径，真实瀚高路径的 Stage 4 工作量显著增加；但相较"完全无兼容 shim 的纯 PG"路径，函数层的全量免改仍能节省改写量。具体百分比由 Pilot 实测回填本节。
```

- [ ] **Step 2.3：替换引用路径（7 条 Edit）**

逐条：

```
old: `[类型映射表](references/mysql-to-gaussdb-type-mapping.md)`
new: `[类型映射表](references/mysql-to-highgo-type-mapping.md)`

old: `[语法映射表](references/mysql-to-gaussdb-syntax-mapping.md)`
new: `[语法映射表](references/mysql-to-highgo-syntax-mapping.md)`

old: `[函数映射表](references/mysql-to-gaussdb-function-mapping.md)`
new: `[函数映射表](references/mysql-to-highgo-function-mapping.md)`

old: `[兼容模式详解](references/gaussdb-compatibility-modes.md)`
new: `[瀚高 v4.1.5 特性详解](references/highgo-v4-compatibility.md)
- [MySQL 函数兼容脚本说明](references/highgo-v4.1.5-mysql-compat-functions.md)`

old: `[GaussDB 已知风险](risks/known-risks-gaussdb.md)`
new: `[瀚高 v4.1.5 已知风险](risks/known-risks-highgo.md)`

old: `Flyway 脚本：`V{timestamp}__gaussdb_{description}.sql`，置于 `db/migration/gaussdb/``
new: `Flyway 脚本：`V{timestamp}__highgo_{description}.sql`，置于 `db/migration/highgo/``

old: `集成测试 profile：`integration-gaussdb` / `integration-mysql-baseline``
new: `集成测试 profile：`integration-highgo` / `integration-mysql-baseline``
```

- [ ] **Step 2.4：残留扫描 + 提交**

```bash
grep -n -E "GaussDB|gaussdb|B 兼容模式|B 模式|B模式|gaussdbjdbc" docs/2026-04-18-master-plan.md
# Expected: 无输出

git add docs/2026-04-18-master-plan.md
git commit -m "docs(master-plan): 目标库切换到瀚高 v4.1.5，重写改造量预估与引用"
```

---

### Task 3: 重写 highgo-v4-compatibility.md（rename + 重写单 commit per A2）

**Files:**
- Rename + Rewrite: `docs/references/gaussdb-compatibility-modes.md` → `docs/references/highgo-v4-compatibility.md`

- [ ] **Step 3.1：git mv**

```bash
git mv docs/references/gaussdb-compatibility-modes.md docs/references/highgo-v4-compatibility.md
```

- [ ] **Step 3.2：整篇 Write 覆盖**

内容如 v1 计划 Task 6 Step 6.2（此处引用，不重复——以 v1 计划为准，但替换 `highgo-v4-mysql-compat-functions` → `highgo-v4.1.5-mysql-compat-functions`）。

关键段落略；完整内容见 v1 plan Task 6 Step 6.2，但脚本文件引用一律改为 `highgo-v4.1.5-mysql-compat-functions.{sql,md}`。

- [ ] **Step 3.3：一个 commit 完成 rename + 重写（per A2）**

```bash
git add docs/references/highgo-v4-compatibility.md
git commit -m "docs(references): 重写 highgo-v4-compatibility（原 gaussdb-compatibility-modes，rename + 完整重写）"
```

---

### Task 4: 重写 mysql-to-highgo-type-mapping.md

**Files:**
- Rename + Rewrite: `docs/references/mysql-to-gaussdb-type-mapping.md` → `docs/references/mysql-to-highgo-type-mapping.md`

- [ ] **Step 4.1：git mv**

```bash
git mv docs/references/mysql-to-gaussdb-type-mapping.md \
       docs/references/mysql-to-highgo-type-mapping.md
```

- [ ] **Step 4.2：整篇 Write 覆盖**

完整内容见 v1 plan Task 7 Step 7.2。

- [ ] **Step 4.3：单 commit**

```bash
git add docs/references/mysql-to-highgo-type-mapping.md
git commit -m "docs(references): 重写 mysql-to-highgo-type-mapping（按 PG 类型系统重判）"
```

---

### Task 5: 重写 mysql-to-highgo-syntax-mapping.md

**Files:**
- Rename + Rewrite: `docs/references/mysql-to-gaussdb-syntax-mapping.md` → `docs/references/mysql-to-highgo-syntax-mapping.md`

- [ ] **Step 5.1：git mv**

```bash
git mv docs/references/mysql-to-gaussdb-syntax-mapping.md \
       docs/references/mysql-to-highgo-syntax-mapping.md
```

- [ ] **Step 5.2：整篇 Write 覆盖**

完整内容见 v1 plan Task 8 Step 8.2。

- [ ] **Step 5.3：单 commit**

```bash
git add docs/references/mysql-to-highgo-syntax-mapping.md
git commit -m "docs(references): 重写 mysql-to-highgo-syntax-mapping（按 PG 方言重判）"
```

---

### Task 6: 重写 mysql-to-highgo-function-mapping.md

**Files:**
- Rename + Rewrite: `docs/references/mysql-to-gaussdb-function-mapping.md` → `docs/references/mysql-to-highgo-function-mapping.md`

- [ ] **Step 6.1：git mv**

```bash
git mv docs/references/mysql-to-gaussdb-function-mapping.md \
       docs/references/mysql-to-highgo-function-mapping.md
```

- [ ] **Step 6.2：整篇 Write 覆盖**

完整内容见 v1 plan Task 9 Step 9.2，但脚本引用一律改为 `highgo-v4.1.5-mysql-compat-functions.md`。

- [ ] **Step 6.3：单 commit**

```bash
git add docs/references/mysql-to-highgo-function-mapping.md
git commit -m "docs(references): 重写 mysql-to-highgo-function-mapping（新增脚本覆盖列与缺口明细）"
```

---

### Task 7: 重写 known-risks-highgo.md（含 R-017/R-018 per A4/C6）

**Files:**
- Rename + Rewrite: `docs/risks/known-risks-gaussdb.md` → `docs/risks/known-risks-highgo.md`

- [ ] **Step 7.1：git mv**

```bash
git mv docs/risks/known-risks-gaussdb.md docs/risks/known-risks-highgo.md
```

- [ ] **Step 7.2：整篇 Write 覆盖**

内容同 v1 plan Task 10 Step 10.2（R-001 至 R-016），但在末尾追加 R-017 和 R-018：

```markdown
## R-017 🟡 兼容脚本版本管理漂移（per A4）

**风险**：兼容脚本是 DB 层外挂资产，多工程共享时可能出现版本漂移——Pilot 工程修复了一个 Bug 但其他工程的目标库没同步；或厂家发布新版本但没人更新工具包内嵌副本。

**影响**：同一个 MySQL 函数在不同工程的目标库下行为不一致，难排查。

**缓解**：
- 脚本末尾注入 `mysql_compat_version()` 函数，返回形如 `1.0.0-highgo-v4.1.5-vendor-2026-04-21`
- Pilot 注入完成后执行 `SELECT mysql_compat_version()`，记录到 baseline.md
- 脚本任何改动须 PR 到工具包，bump 版本号，更新 CHANGELOG
- Stage 5 验收清单加一项"版本标记与工具包一致"

## R-018 🟡 Flyway 防护语法在瀚高下的兼容性（per C6）

**风险**：全局 `~/.claude/CLAUDE.md §3.6` 要求 Flyway 脚本含 `IF NOT EXISTS` / `IF EXISTS` 防护语法。MySQL 8.0+ 支持 `CREATE TABLE IF NOT EXISTS` / `ALTER TABLE ADD COLUMN IF NOT EXISTS`；**PG 对后者支持从 9.6 起、且某些列约束不能这样写**。瀚高 v4.1.5 基于 PG 某版本，实际支持情况待核实。

**影响**：按母方案约束产出的 Flyway 脚本，在瀚高下可能报语法错。

**缓解**：
- Stage 3 DDL 验证步骤加一项："防护语法冒烟"，对每种语法至少写一条测试 SQL 在目标库实测
- 不可用的语法在 `mysql-to-highgo-syntax-mapping.md` DDL 节标注为 🔄 或 ❌
- 实测失败记录到 `project-docs/fix-issue/`
```

同时在"新增风险提交模板"之前。

- [ ] **Step 7.3：单 commit**

```bash
git add docs/risks/known-risks-highgo.md
git commit -m "docs(risks): 重写为 known-risks-highgo（含 R-017 脚本版本管理、R-018 Flyway 防护语法）"
```

---

### Task 8: SOP Stage 2（关键：注入脚本 + 扩展冒烟 per T1）

**Files:**
- Modify: `docs/sop/stage-2-config-switch.md`

- [ ] **Step 8.1：整篇 Write 覆盖**

内容如 v1 plan Task 13 Step 13.1，但 §2.6 的冒烟 SQL 扩展为 **7 条正反向混合**：

```markdown
**注入后必测**（Pilot 首验证项，R-002 / R-015）：

```sql
-- === 正向可用性测试（4 条）===

-- 1. DATE_FORMAT 不递归栈溢出（R-002 关键）
SELECT DATE_FORMAT(NOW(), '%Y-%m-%d');          -- 期望返回形如 '2026-04-21'
SELECT DATE_FORMAT('2025-01-01'::timestamptz, '%Y%m');  -- 期望 '202501'

-- 2. IFNULL integer 重载可用
SELECT IFNULL(NULL::integer, 0);                -- 期望 0

-- 3. FIND_IN_SET 可用
SELECT FIND_IN_SET('b', 'a,b,c');               -- 期望 2

-- 4. TRUNCATE 可用（含除法场景）
SELECT TRUNCATE(100 / 3::numeric, 2);           -- 期望 33.33（不是 33.00）

-- === 反向缺口验证（3 条，用于确认 Stage 0 SQL 扫描必须标记的调用）===

-- 5. IFNULL 无 timestamp 重载（预期报错）
SELECT IFNULL(NULL::timestamp, NOW());          -- 期望：ERROR function ifnull(timestamp, timestamp) does not exist

-- 6. IF 无 int 重载（预期报错）
SELECT IF(true, 1, 2);                          -- 期望：ERROR function if(boolean, integer, integer) does not exist

-- 7. 版本标记函数返回值（R-017）
SELECT mysql_compat_version();                  -- 期望：'1.0.0-highgo-v4.1.5-vendor-2026-04-21'
```

任一"正向"测试失败或"反向"测试意外通过，立即记录到 `project-docs/fix-issue/`，评估是否修改脚本实现。反向测试意外通过说明脚本被私自扩展过重载，需同步更新 function-mapping 文档的"脚本覆盖"列。
```

其余章节（2.1–2.5, 2.7, 2.8）内容见 v1 plan Task 13 Step 13.1。

- [ ] **Step 8.2：残留扫描 + 提交**

```bash
grep -n -E "GaussDB|gaussdb|B 兼容模式|B 模式|B模式" docs/sop/stage-2-config-switch.md
git add docs/sop/stage-2-config-switch.md
git commit -m "docs(sop): stage-2-config-switch 切换到瀚高 v4.1.5，新增脚本注入步骤与 7 条冒烟 SQL"
```

---

### Task 9: SOP Stage 3 + DDL 防护语法验证（per C6）

**Files:**
- Modify: `docs/sop/stage-3-schema-migration.md`

- [ ] **Step 9.1：术语替换（5 条 Edit）**

逐条替换：

```
old: # Stage 3 — Schema 迁移
new: # Stage 3 — Schema 迁移（瀚高 v4.1.5）

old: 把 MySQL 的表结构、索引、约束、序列、视图在 GaussDB 上重建
new: 把 MySQL 的表结构、索引、约束、序列、视图在瀚高 v4.1.5 上重建

old: - 目标 GaussDB 版本与兼容模式（已知为 **B 兼容模式**）
     - Stage 2 的 `db/migration/gaussdb/` 目录
new: - 目标瀚高版本（已确认为 **v4.1.5**，基于 PostgreSQL 内核）
     - Stage 2 的 `db/migration/highgo/` 目录

old: 调用 Skill，产出初稿 `gaussdb-schema-draft.sql`。
new: 调用 Skill，产出初稿 `highgo-schema-draft.sql`。

old: **类型映射**（详表见 `references/mysql-to-gaussdb-type-mapping.md`）：
- `TINYINT(1)` → 保持 `TINYINT` 或改 `BOOLEAN`？统一策略并记录
- `DATETIME` vs `TIMESTAMP`：时区语义差异
- `TEXT` / `MEDIUMTEXT` / `LONGTEXT` → B 模式兼容，确认大小上限
- `JSON` → B 模式支持，确认查询函数
- `ENUM` → 建议改为 `VARCHAR` + CHECK 约束（B 模式虽兼容但维护成本高）
- `SET` → 建议改为关联表
new: **类型映射**（详表见 `references/mysql-to-highgo-type-mapping.md`）：
- `TINYINT(1)` → 改 `BOOLEAN`（PG 无 TINYINT 类型，统一策略并记录）
- `DATETIME` vs `TIMESTAMP`：PG 无 DATETIME，前者建议改 `TIMESTAMP WITHOUT TIME ZONE`；后者推荐 `TIMESTAMPTZ`
- `TEXT` / `MEDIUMTEXT` / `LONGTEXT` → 统一 `TEXT`（PG TEXT 无长度限制）
- `JSON` → 推荐 `JSONB`；查询函数名完全不同，见 function-mapping
- `ENUM` → 改 `VARCHAR + CHECK` 约束
- `SET` → 改关联表 或 `VARCHAR` + 应用层拆分
```

继续：

```
old: - 详见 `references/mysql-to-gaussdb-syntax-mapping.md`
new: - 详见 `references/mysql-to-highgo-syntax-mapping.md`

old: **自增与序列**：
- B 模式下 `AUTO_INCREMENT` 原生支持，初值与步长参数验证
- 若 Schema 转为 `IDENTITY`，代码端 `useGeneratedKeys="true"` 行为确认
new: **自增与序列**：
- `AUTO_INCREMENT` → `GENERATED ALWAYS AS IDENTITY`（PG 10+ 推荐）或 `BIGSERIAL`
- 代码端 `useGeneratedKeys="true"` 与 `RETURNING id` 配合，行为确认
- 工程首选方案一次性决定，记录到 `project-docs/decisions/YYYY-MM-DD-type-mapping-strategy.md`

old: - `DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` → B 模式支持，但行为需验证
- `DEFAULT (UUID())` → GaussDB 函数名差异
new: - `DEFAULT CURRENT_TIMESTAMP` → 支持
- `ON UPDATE CURRENT_TIMESTAMP` → **PG 不原生支持**，需触发器模拟 或 应用层赋值
- `DEFAULT (UUID())` → PG 用 `gen_random_uuid()`（pgcrypto 扩展）

old: 命名：`V{YYYYMMDDHHmm}__gaussdb_init_schema.sql`

放置：`src/main/resources/db/migration/gaussdb/`
new: 命名：`V{YYYYMMDDHHmm}__highgo_init_schema.sql`

放置：`src/main/resources/db/migration/highgo/`

old: 使用 `R__gaussdb_seed_dictionary.sql`（repeatable）或 `V{n}__gaussdb_seed_xxx.sql`
new: 使用 `R__highgo_seed_dictionary.sql`（repeatable）或 `V{n}__highgo_seed_xxx.sql`

old: mvn -P integration-gaussdb flyway:migrate
new: mvn -P integration-highgo flyway:migrate

old: - GaussDB 中 `flyway_schema_history` 表有记录
new: - 瀚高中 `flyway_schema_history` 表有记录

old: - [ ] `db/migration/gaussdb/V*__init_schema.sql` 脚本可重复执行不报错
new: - [ ] `db/migration/highgo/V*__init_schema.sql` 脚本可重复执行不报错

old: - `V*__gaussdb_init_schema.sql`（可能多个）
new: - `V*__highgo_init_schema.sql`（可能多个）
```

- [ ] **Step 9.2：新增 §3.8 DDL 防护语法验证步骤（per C6）**

在 §3.7 之后、"## 出口检查"之前 Insert：

```markdown
### 3.8 DDL 防护语法冒烟（R-018）

全局 CLAUDE.md §3.6 要求 Flyway 脚本含防护语法。**PG 对某些防护写法支持不完整**，Stage 3 开始前必须对本工程使用的防护写法在瀚高 v4.1.5 下冒烟：

```sql
-- 冒烟（任意 schema 下执行，完后清理）

-- 1. CREATE TABLE IF NOT EXISTS（PG 9.1+ 支持）
CREATE TABLE IF NOT EXISTS _smoke_t (id INT);

-- 2. DROP TABLE IF EXISTS（PG 8.0+ 支持）
DROP TABLE IF EXISTS _smoke_t;

-- 3. CREATE INDEX IF NOT EXISTS（PG 9.5+ 支持）
CREATE TABLE _smoke_t (id INT, name VARCHAR(20));
CREATE INDEX IF NOT EXISTS idx_smoke_name ON _smoke_t (name);
DROP INDEX IF EXISTS idx_smoke_name;

-- 4. ALTER TABLE ADD COLUMN IF NOT EXISTS（PG 9.6+ 支持）
ALTER TABLE _smoke_t ADD COLUMN IF NOT EXISTS age INT;
ALTER TABLE _smoke_t DROP COLUMN IF EXISTS age;

-- 5. ADD CONSTRAINT IF NOT EXISTS（⚠️ PG 不直接支持此语法）
-- MySQL 可以：ALTER TABLE t ADD CONSTRAINT IF NOT EXISTS xxx ...
-- PG 必须通过 DO 块 + 查 pg_constraint 模拟
-- 本工具包建议：约束名固定后用"先 DROP IF EXISTS、再 ADD"的模式

-- 清理
DROP TABLE IF EXISTS _smoke_t;
```

任一冒烟失败，记录到 `project-docs/fix-issue/` 并同步更新 `docs/references/mysql-to-highgo-syntax-mapping.md` DDL 节的"状态"列。
```

- [ ] **Step 9.3：残留扫描 + 提交**

```bash
grep -n -E "GaussDB|gaussdb|B 兼容模式|B 模式|B模式" docs/sop/stage-3-schema-migration.md
git add docs/sop/stage-3-schema-migration.md
git commit -m "docs(sop): stage-3-schema-migration 切换到瀚高 v4.1.5，新增 DDL 防护语法冒烟"
```

---

### Task 10: SOP Stage 4 完整重写（per C2）

**Files:**
- Modify: `docs/sop/stage-4-dialect-adapt.md`

> Stage 4 原文基于 "B 模式原生兼容 MySQL" 假设，现实是 PG 方言需逐条改写。整篇重写。

- [ ] **Step 10.1：整篇 Write 覆盖**

```markdown
# Stage 4 — SQL 方言适配（瀚高 v4.1.5）

## 目标

按 Stage 0 产出的风险矩阵，**分类别、分批**修改 SQL / 代码，使其在瀚高 v4.1.5 下可正确执行。与旧假设（GaussDB B 模式下多数 MySQL 语法原生兼容）不同，瀚高基于 PG 方言，**函数层由 Stage 2 注入的厂家脚本抹平**，**语法层必须逐条改写**。

## 预计工期

按风险矩阵行数估算。工作量分布：

- **函数层冲突**（脚本已覆盖）：5 分钟/条（仅需验证 + 跑测试）
- **函数层缺口**（脚本未覆盖或缺重载）：15~30 分钟/条（改写 SQL）
- **语法层（反引号 / LIMIT / ON DUPLICATE / UPDATE JOIN）**：15~30 分钟/条
- **JSON 查询**：30~60 分钟/条（语法差异大）
- **存储过程/触发器**（如存在）：按专项决议，默认上移 Java 层

## 输入

- `risk-matrix.md`（Stage 0 产出）
- `references/mysql-to-highgo-type-mapping.md`
- `references/mysql-to-highgo-syntax-mapping.md`
- `references/mysql-to-highgo-function-mapping.md`（特别关注"脚本覆盖"列）
- `references/highgo-v4.1.5-mysql-compat-functions.md`（兼容脚本说明）
- Stage 1 测试集

## 核心约束

1. **函数层冲突优先查兼容脚本**：脚本已覆盖 → 不改 SQL，跑测试验证；脚本未覆盖或缺重载 → 改写
2. **语法层必须改**：反引号 / `LIMIT m,n` / `ON DUPLICATE KEY UPDATE` 等 PG 不支持，不能跳过
3. **分类别 commit**：每类差异一个 commit，便于回滚与 review
4. **每个 commit 后测试跑绿**再进入下一类
5. **改码 + 改测试分开提交**：若需调整断言，单独 commit 说明原因

## 步骤

### 4.1 按类别分组

参考 `references/mysql-to-highgo-syntax-mapping.md` 的状态列（✅/⚠️/🔄/❌），把风险矩阵中的条目分成若干类：

| 类别 | 典型特征 | 优先级 | 脚本覆盖 | 说明 |
|------|---------|--------|---------|------|
| JDBC URL / 连接参数 | `jdbc:gaussdb:` 残留 | 高 | — | Stage 2 已处理，本阶段复查 |
| 字符集 / 排序规则 | `utf8mb4_general_ci` | 高 | — | 影响比较、排序、索引选择 |
| 时区 / 时间类型语义 | `DATETIME` / `TIMESTAMP` | 高 | 部分 | 易隐蔽，需专项测 |
| 反引号标识符 | `` `user` `` `` `order` `` | 高 | — | ❌ PG 不支持；改双引号或全小写 |
| `LIMIT m, n` 分页 | `LIMIT 10, 20` | 高 | — | ❌ 改 `LIMIT 20 OFFSET 10` |
| `ON DUPLICATE KEY UPDATE` | upsert 用法 | 高 | — | ❌ 改 `INSERT ... ON CONFLICT DO UPDATE` |
| `REPLACE INTO` / `INSERT IGNORE` | mysql 特有 upsert 变种 | 高 | — | ❌ 改 ON CONFLICT |
| `UPDATE/DELETE ... LIMIT n` | 批量带 LIMIT | 中 | — | ❌ 改子查询 `WHERE pk IN (SELECT ... LIMIT n)` |
| `UPDATE t1 JOIN t2` | 多表 UPDATE | 中 | — | ❌ 改 `UPDATE t1 SET ... FROM t2 WHERE ...` |
| 保留字列名 | `user` / `type` / `order` | 中 | — | 加双引号或改名 |
| 函数层脚本已覆盖 | `IFNULL(int, int)` / `FIND_IN_SET` | 低 | ✅ 🛡️ | 不改，跑测试验证 |
| 函数层脚本缺口 | `IFNULL(timestamp, timestamp)` / `IF(cond, int, int)` | 中 | ❌ | 改 `COALESCE` / `CASE WHEN` |
| `DATE_FORMAT` 递归风险 | 所有 `DATE_FORMAT` 调用 | 高 | ⚠️ | Stage 2 已验证通过则免改；未通过需改写 `TO_CHAR` |
| JSON 查询 | `j->'$.a'` / `JSON_EXTRACT` | 高 | — | 语法完全不同，见 function-mapping |
| MySQL Hint | `STRAIGHT_JOIN` / `USE INDEX` | 中 | — | 去除，让优化器决定 |
| `LOCK IN SHARE MODE` | MySQL 共享锁 | 低 | — | 改 `FOR SHARE` |
| 存储过程 / 触发器 | `DELIMITER //` / `CREATE PROCEDURE` | 高（如有） | — | 默认上移 Java 层 |

### 4.2 对每一类执行"小循环"

**小循环** = 改码 → 跑测试 → 修测试 → commit

1. 从风险矩阵挑出该类所有条目
2. 统一改写（调用 Skill `db-migration-dialect-rewrite` 获取建议 diff，**Skill 不自动改码**）
3. **人工 review** Skill 建议
4. 应用修改
5. 跑相关测试：`mvn -P integration-highgo test -Dtest=<pattern>`
6. 全绿后 commit，消息格式：

   ```
   refactor(db): Stage 4 适配 <类别名>

   - 涉及文件 N 个
   - 风险矩阵条目：R-xx, R-yy, R-zz
   - 验证：XxxMapperIntegrationTest、YyyServiceIntegrationTest 全绿
   ```

7. 更新 `risk-matrix.md` 中对应条目状态为 ✅

### 4.3 函数层兼容脚本验证子流程

针对"函数层脚本已覆盖"类别，因为**不改 SQL 就过**，需额外谨慎：

1. 确认 Stage 2 已成功注入脚本且 7 条冒烟 SQL 全通过
2. 对每个涉及函数的 Mapper 方法，至少一条集成测试覆盖真实数据
3. 特别关注 `DATE_FORMAT` / `TRUNCATE`（除法）/ `MOD(text, int)` 这类有"已知行为差异"的函数
4. 测试失败回到 4.2 作为"脚本缺口"类别改写

### 4.4 无法直接兼容的场景

若某条 SQL 在瀚高下**无法原样运行**（脚本不覆盖、语法不能改写、业务无法上移 Java 层）：

- **策略 1 改写**：调整为瀚高 PG 方言写法（优先）
- **策略 2 分方言 Mapper**：MyBatis 使用 `databaseId`，同名 statement 区分 mysql / highgo
- **策略 3 Java 侧处理**：把部分逻辑从 SQL 抽到 Service（慎用，偏离"只做适配"约束）

每次选用策略 2 / 3 需在 `project-docs/decisions/` 记录决策与原因。

### 4.5 集成测试双轨验证

保留 Stage 1 的 `integration-mysql-baseline` profile，Stage 4 期间每次改动后：

- 先跑 `integration-highgo` profile，确认新功能绿
- 再跑 `integration-mysql-baseline` profile，确认未破坏 MySQL 行为（保留 MySQL 兼容时）

**例外**：若改动是瀚高特有（如 `databaseId` 分方言），MySQL 基线应跳过对应用例。

### 4.6 存储过程 / 触发器（如存在）

**默认建议**：不重写存储过程，把逻辑提到 Java 层。

理由：
- PG PL/pgSQL 与 MySQL 存储过程语法**完全不同**，兼容脚本不覆盖此类
- 维护成本高、不利测试
- 违反"不改架构"原则但加"改薄架构"收益明确

若业务强依赖无法改，单独立项处理，并记录到 `decisions/`。

## 出口检查

- [ ] `risk-matrix.md` 所有条目状态为 ✅ 或 `decision-deferred`
- [ ] 每类差异都有独立 commit
- [ ] 所有集成测试在瀚高下全绿
- [ ] 函数层脚本已覆盖的条目均有测试覆盖（而非仅靠 ✅ 假设通过）
- [ ] 未修改 `db/migration/mysql/` 任何文件
- [ ] 所有"分方言"或"架构调整"决策有 `decisions/` 记录

## 产出物

- 一系列 refactor commit
- 更新后的 `risk-matrix.md`
- 若干 `project-docs/decisions/YYYY-MM-DD-*.md`

## 注意事项

- **不要合并多类差异到一个 commit**：出问题不好二分
- **不要跳过测试**：即使是"看起来没影响"的改动
- **脚本覆盖 ≠ 免测**：函数层脚本已覆盖只是说"不改 SQL"，仍必须测
- **Skill 建议要 review**：自动工具可能漏改或误改

## 下一阶段

→ [Stage 5 — 回归与交付](stage-5-verify-deliver.md)
```

- [ ] **Step 10.2：残留扫描 + 提交**

```bash
grep -n -E "GaussDB|gaussdb|B 兼容模式|B 模式|B模式" docs/sop/stage-4-dialect-adapt.md
git add docs/sop/stage-4-dialect-adapt.md
git commit -m "docs(sop): stage-4-dialect-adapt 完整重写，改造量分类按瀚高+兼容脚本重判"
```

---

### Task 11: SOP Stage 0 / 1 / 5 批量术语替换（per P1）

> 原 v1 Task 11 / 12 / 16 合并。每份 SOP 提供关键段落 before/after 清单（per C2）。

**Files:**
- Modify: `docs/sop/stage-0-kickoff.md`
- Modify: `docs/sop/stage-1-test-baseline.md`
- Modify: `docs/sop/stage-5-verify-deliver.md`

- [ ] **Step 11.1：stage-0-kickoff.md 替换清单**

| 原文 | 新文 |
|------|------|
| `- 目标 GaussDB 版本与兼容模式（已知为 **B 兼容模式**）` | `- 目标瀚高版本（已确认为 **v4.1.5**，PostgreSQL 系）` |
| `- 已拉改造分支 `feature/db-migration-gaussdb`` | `- 已拉改造分支 `feature/db-migration-highgo`` |
| `### 0.1 目标库确认\n\n- 确认 GaussDB 版本号\n- 确认兼容模式 = **B（MySQL 兼容）**\n- 确认部署形态（集中式 / 分布式 / DWS）\n- 记录 JDBC 驱动下载渠道与版本` | `### 0.1 目标库确认\n\n- 确认瀚高版本号（预期 v4.1.5）\n- 确认基于的 PG 内核版本\n- 确认部署形态（单机 / 集群 / 备份方案）\n- 记录瀚高 JDBC 驱动下载渠道与版本（C2）\n- 确认目标库已注入厂家 MySQL 兼容脚本（若未注入，Stage 2 必须完成）` |

逐条 Edit 后验证：

```bash
grep -n -E "GaussDB|gaussdb|B 兼容模式|B 模式|B模式" docs/sop/stage-0-kickoff.md
# Expected: 无输出
```

- [ ] **Step 11.2：stage-1-test-baseline.md 替换清单**

| 原文 | 新文 |
|------|------|
| （无需改动——该文件只讨论 MySQL 基线的测试覆盖，不涉及目标库术语） | — |

用 Read 当前文件验证：

```bash
grep -n -E "GaussDB|gaussdb|B 兼容模式|B 模式|B模式" docs/sop/stage-1-test-baseline.md
# Expected: 无输出（stage-1 整篇在 MySQL 侧工作，无目标库术语）
```

若发现残留，逐条 Edit。

- [ ] **Step 11.3：stage-5-verify-deliver.md 替换清单**

| 原文 | 新文 |
|------|------|
| `### 5.1 全量回归（GaussDB）\n\n```bash\nmvn -P integration-gaussdb clean test\n```` | `### 5.1 全量回归（瀚高 v4.1.5）\n\n```bash\nmvn -P integration-highgo clean test\n```` |
| `- 与 Stage 1 MySQL 基线比对，用例数一致（除非有明确声明的"GaussDB 特有用例"或"MySQL 特有用例已下线"）` | `- 与 Stage 1 MySQL 基线比对，用例数一致（除非有明确声明的"瀚高特有用例"或"MySQL 特有用例已下线"）` |
| `- [ ] `application-integration-gaussdb.yml` 字段齐全` | `- [ ] `application-integration-highgo.yml` 字段齐全` |
| `- [ ] Flyway `locations` 指向 `gaussdb` 目录` | `- [ ] Flyway `locations` 指向 `highgo` 目录` |
| `文件：`project-docs/reports/YYYY-MM-DD-gaussdb-migration-report.md`` | `文件：`project-docs/reports/YYYY-MM-DD-highgo-migration-report.md`` |
| `- 测试对比：MySQL 基线 vs GaussDB` | `- 测试对比：MySQL 基线 vs 瀚高 v4.1.5` |
| `把本工程发现的**通用性问题**提炼为 `fix-issue` 记录，推送回 `db-migration-toolkit`：\n\n文件命名：`fix-issue/YYYY-MM-DD-<short-slug>.md`` | `把本工程发现的**通用性问题**提炼为 `fix-issue` 记录，推送回 `db-migration-toolkit`：\n\n文件命名：`fix-issue/YYYY-MM-DD-<short-slug>.md`（保留原路径；fix-issue 搬迁是独立整改项）` |
| `回滚即 `--spring.profiles.active=mysql-baseline`（按实际 profile 命名），不需要代码回滚。` | 保留不动（与瀚高/GaussDB 无关） |
| `- Git tag `stage-5-gaussdb-migration-done-vX.Y.Z`` | `- Git tag `stage-5-highgo-migration-done-vX.Y.Z`` |
| `- `project-docs/reports/YYYY-MM-DD-gaussdb-migration-report.md`` | `- `project-docs/reports/YYYY-MM-DD-highgo-migration-report.md`` |

- [ ] **Step 11.4：残留扫描 + 单 commit**

```bash
grep -rn -E "GaussDB|gaussdb|B 兼容模式|B 模式|B模式" docs/sop/stage-0-kickoff.md docs/sop/stage-1-test-baseline.md docs/sop/stage-5-verify-deliver.md
# Expected: 无输出

git add docs/sop/stage-0-kickoff.md docs/sop/stage-1-test-baseline.md docs/sop/stage-5-verify-deliver.md
git commit -m "docs(sop): stage 0/1/5 批量切换到瀚高 v4.1.5"
```

---

### Task 12: templates 逐文件具体替换（per C1）

**Files:**
- Modify: `docs/templates/baseline-template.md`
- Modify: `docs/templates/risk-matrix-template.md`
- Modify: `docs/templates/test-gap-template.md`
- Modify: `docs/templates/migration-report-template.md`

- [ ] **Step 12.1：baseline-template.md**（行号参考 Read 时的输出）

| 行号 | 原文 | 新文 |
|------|------|------|
| 11 | `- **目标数据库**：GaussDB` | `- **目标数据库**：瀚高（HighGo）v4.1.5` |
| 12 | `- **版本**：<填写>` | `- **版本**：v4.1.5（暂定，C1 待核实）` |
| 13 | `- **兼容模式**：B（MySQL 兼容）` | `- **内核**：基于 PostgreSQL（具体内核版本 ⚠️ 待核实）` |
| 14 | `- **部署形态**：集中式 / 分布式 / DWS（选一）` | `- **部署形态**：单机 / 集群（选一）` |
| 15 | `- **JDBC 驱动**：`com.huawei.gaussdb:gaussdbjdbc:<版本>`` | `- **JDBC 驱动**：`<待确认-瀚高-jdbc-坐标>:<版本>`（C2）` |
| 15 后 | （空） | `- **MySQL 兼容脚本版本**：注入后执行 `SELECT mysql_compat_version()` 填写，示例 `1.0.0-highgo-v4.1.5-vendor-2026-04-21`（R-017）` |
| 26 | `| 分页方言（当前） | mysql |` | `| 分页方言（改造后目标） | postgresql |` |

- [ ] **Step 12.2：risk-matrix-template.md**

| 行号 | 原文 | 新文 |
|------|------|------|
| 15 | `- **类别**：对应 `references/mysql-to-gaussdb-*-mapping.md` 中的大类` | `- **类别**：对应 `references/mysql-to-highgo-*-mapping.md` 中的大类` |
| 18 表头 | `\| ID \| 文件 \| 位置 \| MySQL 特性 \| 类别 \| 严重度 \| B 模式预期 \| 建议动作 \| 状态 \| Commit \| 备注 \|` | `\| ID \| 文件 \| 位置 \| MySQL 特性 \| 类别 \| 严重度 \| 瀚高预期 \| 脚本覆盖 \| 建议动作 \| 状态 \| Commit \| 备注 \|` |
| 20 | `\| R-001 \| UserMapper.xml \| 第 42 行 \| `ON DUPLICATE KEY UPDATE` \| DML \| 🟢 \| ✅ 原生兼容 \| 跑测验证 \| pending \| \| \|` | `\| R-001 \| UserMapper.xml \| 第 42 行 \| `ON DUPLICATE KEY UPDATE` \| DML \| 🔴 \| ❌ 不支持 \| — \| 改 `INSERT ... ON CONFLICT DO UPDATE` \| pending \| \| \|` |
| 21 | `\| R-002 \| OrderMapper.xml \| 第 88 行 \| `GROUP_CONCAT` \| 函数 \| 🟢 \| ✅ 原生兼容 \| 跑测验证 \| pending \| \| \|` | `\| R-002 \| OrderMapper.xml \| 第 88 行 \| `GROUP_CONCAT` \| 函数 \| 🟡 \| ❌ 不支持 \| — \| 改 `STRING_AGG` \| pending \| \| \|` |
| 22 | `\| R-003 \| common.xml \| 第 15 行 \| `user` 列名 \| 保留字 \| 🟡 \| 需加引号 \| 列名改 `user_name` 或加引号 \| pending \| \| 影响面较大 \|` | 保持不变（仍成立） |
| 23 | `\| R-004 \| ReportMapper.java \| queryXxx \| JSON 查询 \| JSON \| 🟡 \| ⚠️ 行为需验证 \| 专项测 \| pending \| \| \|` | `\| R-004 \| ReportMapper.java \| queryXxx \| JSON 查询 \| JSON \| 🔴 \| ❌ 语法不同 \| — \| 改 PG JSONB 操作符 \| pending \| \| \|` |

- [ ] **Step 12.3：test-gap-template.md**

| 行号 | 原文 | 新文 |
|------|------|------|
| 40 | `- [ ] 本地 GaussDB 实例 / 可访问共享测试库` | `- [ ] 本地瀚高 v4.1.5 实例 / 可访问共享测试库（已注入 MySQL 兼容脚本）` |
| 41 | `- [ ] `application-integration-gaussdb.yml`` | `- [ ] `application-integration-highgo.yml`` |

其他不动。

- [ ] **Step 12.4：migration-report-template.md**

| 行号 | 原文 | 新文 |
|------|------|------|
| 7 | `# <工程名> GaussDB 改造验收报告` | `# <工程名> 瀚高 v4.1.5 改造验收报告` |
| 15 | `- **改造分支**：`feature/db-migration-gaussdb`` | `- **改造分支**：`feature/db-migration-highgo`` |
| 16 | `- **改造版本 tag**：`stage-5-gaussdb-migration-done-vX.Y.Z`` | `- **改造版本 tag**：`stage-5-highgo-migration-done-vX.Y.Z`` |
| 60 表头 | `\| 维度 \| MySQL 基线（Stage 1） \| GaussDB（Stage 5） \| 差异说明 \|` | `\| 维度 \| MySQL 基线（Stage 1） \| 瀚高 v4.1.5（Stage 5） \| 差异说明 \|` |
| 70 | `- 新增（GaussDB 特有）：` | `- 新增（瀚高特有）：` |
| 106 | `- 已推送到工具包的条目：`db-migration-toolkit/fix-issue/YYYY-MM-DD-*.md`` | 保持（路径不改，除非合并 fix-issue 搬迁） |

Task 12 **单 commit**（4 文件一起）：

- [ ] **Step 12.5：残留扫描 + 提交**

```bash
grep -rn -E "GaussDB|gaussdb|B 兼容模式|B 模式|B模式" docs/templates/
# Expected: 无输出

git add docs/templates/
git commit -m "docs(templates): 4 份 template 切换到瀚高 v4.1.5（逐文件 line-level 替换）"
```

---

### Task 13: checklists 逐文件具体替换（per C1）

**Files:**
- Modify: `docs/checklists/pre-research-checklist.md`
- Modify: `docs/checklists/migration-pr-checklist.md`
- Modify: `docs/checklists/acceptance-checklist.md`

- [ ] **Step 13.1：pre-research-checklist.md**

| 行号 | 原文 | 新文 |
|------|------|------|
| 13 § | `## 2. 目标库信息\n\n- [ ] GaussDB 版本号已记录\n- [ ] 兼容模式确认 = B（MySQL 兼容）\n- [ ] 部署形态确认（集中式 / 分布式 / DWS）\n- [ ] JDBC 驱动获取渠道已确认\n- [ ] 测试环境连接信息已获取（或已明确获取时间点）` | `## 2. 目标库信息\n\n- [ ] 瀚高版本号已记录（预期 v4.1.5）\n- [ ] 基于的 PG 内核版本已记录\n- [ ] 部署形态确认（单机 / 集群）\n- [ ] 瀚高 JDBC 驱动获取渠道已确认（C2）\n- [ ] 测试环境连接信息已获取\n- [ ] 目标库已注入 MySQL 兼容脚本且 `SELECT mysql_compat_version()` 返回预期版本（R-017）` |

- [ ] **Step 13.2：migration-pr-checklist.md**

| 行号 | 原文 | 新文 |
|------|------|------|
| 7 | `- [ ] 本 PR 仅涉及数据库改造（MySQL → GaussDB），不夹带业务变更` | `- [ ] 本 PR 仅涉及数据库改造（MySQL → 瀚高 v4.1.5），不夹带业务变更` |
| 14 | `- [ ] 新增 Flyway 脚本位于 `db/migration/gaussdb/`，带 `IF NOT EXISTS` / `IF EXISTS` 防护` | `- [ ] 新增 Flyway 脚本位于 `db/migration/highgo/`，带 `IF NOT EXISTS` / `IF EXISTS` 防护（R-018 已冒烟通过）` |
| 22 | `- [ ] `application-integration-gaussdb.yml` 未含明文密码（走占位或环境变量）` | `- [ ] `application-integration-highgo.yml` 未含明文密码（走占位或环境变量）` |
| 23 | `- [ ] `application-integration-mysql-baseline.yml` 保留未删` | 保持不动 |
| 30 | `- [ ] 本 PR 涉及的模块，集成测试在 GaussDB 下全绿` | `- [ ] 本 PR 涉及的模块，集成测试在瀚高下全绿` |

- [ ] **Step 13.3：acceptance-checklist.md**

| 行号 | 原文 | 新文 |
|------|------|------|
| 9 | `- [ ] 应用在 GaussDB profile 下启动成功，无致命错` | `- [ ] 应用在瀚高 profile 下启动成功，无致命错` |
| 15 | `- [ ] `mvn -P integration-gaussdb test` 全绿` | `- [ ] `mvn -P integration-highgo test` 全绿` |
| 38 | `- [ ] `project-docs/reports/YYYY-MM-DD-gaussdb-migration-report.md` 已产出` | `- [ ] `project-docs/reports/YYYY-MM-DD-highgo-migration-report.md` 已产出` |
| 47 | `- [ ] 分支 tag `stage-5-gaussdb-migration-done-vX.Y.Z` 已打` | `- [ ] 分支 tag `stage-5-highgo-migration-done-vX.Y.Z` 已打` |

acceptance-checklist 增加一项（插在 §测试 节末尾）：

```markdown
- [ ] Stage 2 冒烟 SQL 7 条（含 R-002 DATE_FORMAT 递归验证 / R-015 脚本缺口反向验证 / R-017 版本标记）全部通过
```

- [ ] **Step 13.4：残留扫描 + 单 commit**

```bash
grep -rn -E "GaussDB|gaussdb|B 兼容模式|B 模式|B模式" docs/checklists/
# Expected: 无输出

git add docs/checklists/
git commit -m "docs(checklists): 3 份 checklist 切换到瀚高 v4.1.5（逐文件 line-level 替换）"
```

---

### Task 14: Skills 批量更新

**Files:**
- Modify: `skills/db-migration-baseline/SKILL.md`
- Modify: `skills/db-migration-sql-scan/SKILL.md`
- Modify: `skills/db-migration-test-gap/SKILL.md`
- Modify: `skills/db-migration-schema-convert/SKILL.md`
- Modify: `skills/db-migration-dialect-rewrite/SKILL.md`
- Modify: `skills/db-migration-verify/SKILL.md`

- [ ] **Step 14.1：每个 Skill 的 frontmatter `description` 字段**

对所有 6 个 SKILL.md，Edit 将 `description` 字段中的 "GaussDB" → "瀚高" / "gaussdb" → "highgo"，保留触发关键词（MySQL 改造 / Stage N）。

- [ ] **Step 14.2：正文术语替换**

对每个 Skill 的正文：
- `GaussDB` → `瀚高`
- `gaussdb` → `highgo`
- `B 模式` / `B 兼容模式` → 视上下文删除或改"瀚高 v4.1.5"
- `mysql-to-gaussdb-*.md` → `mysql-to-highgo-*.md`
- `known-risks-gaussdb.md` → `known-risks-highgo.md`
- `gaussdb-compatibility-modes.md` → `highgo-v4-compatibility.md`
- `db/migration/gaussdb/` → `db/migration/highgo/`
- `integration-gaussdb` → `integration-highgo`

- [ ] **Step 14.3：专项改动**

**`skills/db-migration-sql-scan/SKILL.md`**：扫描规则节新增/调整：
- 反引号 `` ` `` → 从"低风险"改为"高风险，PG 不支持"
- `LIMIT m,n` → "高风险，必须改写"
- `ON DUPLICATE KEY UPDATE` → "高风险，必须改写"
- `REPLACE INTO` / `INSERT IGNORE` → "高风险"
- `IF(cond, ...)` / `IFNULL(a, b)` → 新增提示"检查实参类型，若非脚本覆盖重载需改写 CASE WHEN / COALESCE"
- `DATE_FORMAT(...)` → "高风险，Pilot 首验证项（R-002）"

**`skills/db-migration-dialect-rewrite/SKILL.md`**：重写"差异点清单"章节，按 Stage 4 类别分组（函数层脚本覆盖/缺口、语法层必改等）。Skill 输出建议应标注"是否依赖兼容脚本"。

**`skills/db-migration-schema-convert/SKILL.md`**：
- DDL 目标改 PG 语法（`GENERATED AS IDENTITY` / `COMMENT ON` / `BYTEA` / `JSONB`）
- 新增注意：输出 DDL 前缀 `V*__highgo_init_schema.sql`
- 新增提示：生成的 DDL 必须经过 Task 9 §3.8 的防护语法冒烟

**`skills/db-migration-verify/SKILL.md`**：
- 引用路径全部更新
- 验收报告骨架的"目标库"字段默认瀚高 v4.1.5
- 新增一项检查："脚本版本标记与工具包一致"（R-017）

- [ ] **Step 14.4：残留扫描 + 单 commit**

```bash
grep -rn -E "GaussDB|gaussdb|B 兼容模式|B 模式|B模式" skills/
# Expected: 无输出

git add skills/
git commit -m "skills: 6 个 Skill 切换目标库到瀚高 v4.1.5，扫描规则与差异清单同步调整"
```

---

### Task 15: 根元文档

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `CHANGELOG.md`
- Modify: `VERSION`
- Modify: `fix-issue/README.md`

- [ ] **Step 15.1：README.md**

逐条 Edit：
- 标题引子 "MySQL → GaussDB（及其他关系型数据库）改造通用工具包" → "MySQL → 瀚高（HighGo v4.1.5）改造通用工具包"
- "当前版本 v0.1.0（2026-04-18 首发，骨架版，待 Pilot 验证后迭代至 v1.0.0）" → "当前版本 v0.2.0（2026-04-21 目标库切换版，骨架版，待 Pilot 验证）"
- "前提假设" 章节的"目标数据库" 改为瀚高相关描述（同 CLAUDE.md §"不可动摇的前提假设"）
- "参考入口"章节引用路径全部改为 highgo-*

- [ ] **Step 15.2：CLAUDE.md**

替换"不可动摇的前提假设"第 1 条为：

```markdown
1. **目标库是瀚高 v4.1.5**（PostgreSQL 系），方言基础按 PG，MySQL 函数借厂家兼容脚本抹平——决策见 `project-docs/decisions/2026-04-21-target-db-highgo-v4.md`、`project-docs/decisions/2026-04-21-use-vendor-mysql-compat-functions.md`
```

其他条（不做数据迁移/不改架构/真实库/Flyway 不改历史）保持不动。

"常见操作" 章节：
- 追加 `- 查兼容脚本说明与缺口清单：docs/references/highgo-v4.1.5-mysql-compat-functions.md`

"工具包自身的元治理：project-docs/" 章节不动。

- [ ] **Step 15.3：CHANGELOG.md**

在文件顶部（现有 "## v0.1.0" 之前）追加：

```markdown
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

```

- [ ] **Step 15.4：VERSION**

Write：

```
0.2.0
```

- [ ] **Step 15.5：fix-issue/README.md**

Edit：
- "MySQL → GaussDB 改造踩坑记录" → "MySQL → 瀚高 v4.1.5 改造踩坑记录"
- 无其他 GaussDB 字样

- [ ] **Step 15.6：残留扫描 + 提交**

```bash
grep -n -E "GaussDB|gaussdb|B 兼容模式|B 模式|B模式" README.md CLAUDE.md CHANGELOG.md fix-issue/README.md
# Expected: 无输出

git add README.md CLAUDE.md CHANGELOG.md VERSION fix-issue/README.md
git commit -m "docs(root): 目标库切换到瀚高 v4.1.5，VERSION bump 到 0.2.0（tag 见 Task 19）"
```

---

### Task 16: project-docs 元数据

**Files:**
- Modify: `project-docs/_meta/doc-catalog.yaml`
- Modify: `project-docs/README.md`
- Modify: `project-docs/plans/2026-04-21-v1.0.0-roadmap.md`
- Modify: `project-docs/facts/2026-04-21-consumer-projects-inventory.md`

- [ ] **Step 16.1：doc-catalog.yaml**

- 把现有 `why-b-compat-mode` 条目的 `summary` 加前缀 `[已废弃，见 target-db-highgo-v4] `
- 追加三条 entries（target-db-highgo-v4 / use-vendor-mysql-compat-functions / 2026-04-21-pivot-to-highgo plan / 2026-04-21-pilot-smoke-test plan）
- 更新文件顶 `updated: 2026-04-21`（今日不变）

- [ ] **Step 16.2：project-docs/README.md**

原文无 GaussDB 引用，但"子目录"章节提到"跨工程通用的 MySQL→GaussDB 踩坑仍放根目录 fix-issue"。改为"跨工程通用的 MySQL→瀚高 踩坑仍放根目录 fix-issue"。

- [ ] **Step 16.3：v1.0.0-roadmap.md**

- "原目标 GaussDB 切换到瀚高 v4.1.5"作为大事件插入 §2.1 Pilot 执行期开头
- 出口条件 §3 加一条：`references/highgo-v4.1.5-mysql-compat-functions.md` 的全部已知缺口被至少一次真实改造验证

- [ ] **Step 16.4：consumer-projects-inventory.md**

无 GaussDB 引用，无需改动。

```bash
grep -n -E "GaussDB|gaussdb|B 兼容模式|B 模式|B模式" project-docs/facts/2026-04-21-consumer-projects-inventory.md
# Expected: 无输出
```

- [ ] **Step 16.5：提交**

```bash
grep -rn -E "GaussDB|gaussdb|B 兼容模式|B 模式|B模式" project-docs/ \
  | grep -v "2026-04-21-why-b-compat-mode.md"
# Expected: 无输出

git add project-docs/
git commit -m "docs(project-docs): 登记新决策与整改 plan，更新路线图与引用"
```

---

### Task 17: 残留扫描 + 链接校验（per A3 / T2 / T3）

**Files:**
- 全仓库（只读校验）

- [ ] **Step 17.1：扩展 regex 全局扫描（per T2），排除 superseded 决策（per A3）**

```bash
cd /Users/cy/MyWorkFactory/workspace/xz-source/db-migration-toolkit

grep -rn -E "GaussDB|gaussdb|B 兼容模式|B 模式|B模式|gaussdbjdbc|huawei\.gauss|jdbc:gaussdb" \
  --include="*.md" --include="*.yaml" --include="*.yml" \
  --exclude="2026-04-21-why-b-compat-mode.md" \
  .
```

Expected: **0 行命中**。任何命中都是整改遗漏，回到对应 Task 修复并新 commit（或 fixup）。

- [ ] **Step 17.2：内部相对链接可达性校验（per T3）**

```bash
# 提取所有 Markdown 相对链接，检查目标文件存在
cd /Users/cy/MyWorkFactory/workspace/xz-source/db-migration-toolkit

find docs/ project-docs/ fix-issue/ skills/ -name "*.md" -type f | while read f; do
  dir=$(dirname "$f")
  grep -hoE '\]\([^)]+\.(md|sql|yaml|yml)\)' "$f" \
    | sed 's/^\](//;s/)$//' \
    | while read link; do
        # 忽略 http/https/mailto
        case "$link" in http*|mailto*) continue;; esac
        # 忽略 anchor 跳转
        target="${link%%#*}"
        [ -z "$target" ] && continue
        # 相对解析
        full="$dir/$target"
        # 规范化（去掉 ../）
        normalized=$(cd "$dir" 2>/dev/null && realpath --relative-to=. "$target" 2>/dev/null || echo "$target")
        if [ ! -f "$dir/$target" ] && [ ! -f "$target" ]; then
          echo "BROKEN: $f → $link"
        fi
      done
done
```

Expected: 无 BROKEN 输出（或仅 superseded 决策里的跨目录历史引用）。发现真实坏链接立即修复。

- [ ] **Step 17.3：doc-catalog.yaml path 校验**

```bash
cd /Users/cy/MyWorkFactory/workspace/xz-source/db-migration-toolkit

python3 -c "
import yaml, os, sys
with open('project-docs/_meta/doc-catalog.yaml') as f:
    cat = yaml.safe_load(f)
missing = [e['path'] for e in cat.get('entries', []) if not os.path.isfile(e['path'])]
if missing:
    print('MISSING PATHS:')
    for p in missing: print(' -', p)
    sys.exit(1)
print('All catalog paths valid.')
"
```

Expected: `All catalog paths valid.`

- [ ] **Step 17.4：待确认清单汇总（per C1–C10）**

```bash
grep -rn -E "⚠️ 待|<待确认-" --include="*.md" --include="*.yml" . \
  > /tmp/highgo-pending-confirmations.txt
wc -l /tmp/highgo-pending-confirmations.txt
cat /tmp/highgo-pending-confirmations.txt
```

输出供 Pilot 首日核实，粘贴到最终 PR description。

- [ ] **Step 17.5：Skill 名称不改名确认**

```bash
ls skills/
```

Expected: 6 个 `db-migration-*` 目录，通用名称不强绑目标库，无需改名。

- [ ] **Step 17.6：git 状态干净**

```bash
git status
git log --oneline -30
```

Expected: 无 uncommitted；log 按 Task 顺序呈现。

- [ ] **Step 17.7：若扫描发现问题，一次性 fixup + amend，提交校验通过后**

如无问题：本 Task **无 commit**（纯校验任务）。

---

### Task 18: Pilot 烟测清单（per T4 新增）

**Files:**
- Create: `project-docs/plans/2026-04-21-pilot-smoke-test.md`

- [ ] **Step 18.1：写烟测清单**

Write：

```markdown
---
type: plan
title: Pilot 工程烟测清单（整改后首日验证）
created: 2026-04-21
updated: 2026-04-21
owner: gloryman
status: pending
---

# Pilot 工程烟测清单

> 用途：本工具包从 GaussDB pivot 到瀚高 v4.1.5 的整改完成后，由 Pilot 工程 `stream_keywords_search` 执行的**首日烟测**，确认整改后的工具包可执行、SOP 可跑通。
>
> 本清单**不替代**五段式 SOP 本身的执行，仅做"工具包交付物可用性"验证。

## 前置条件

- 本工具包 v0.2.0 已整改完成（git tag `v0.2.0`）
- Pilot 工程目录：`/Users/cy/MyWorkFactory/workspace/xz-source/stream_keywords_search`
- 瀚高 v4.1.5 测试环境连接信息已获取（至少可 `psql` 连通）
- Pilot 负责人拥有目标库建库 owner 权限（C9 验证）

## 烟测步骤

### S1: 工具包基本状态

```bash
cd /Users/cy/MyWorkFactory/workspace/xz-source/db-migration-toolkit
cat VERSION                   # 期望：0.2.0
git log --oneline -5          # 期望：最新 commit 涉及 highgo 整改
git tag -l "v0.2.0"           # 期望：存在
```

### S2: 文档结构与引用完整性

```bash
# 扩展 regex 残留扫描
grep -rn -E "GaussDB|gaussdb|B 兼容模式|B 模式|B模式|gaussdbjdbc|huawei\.gauss|jdbc:gaussdb" \
  --include="*.md" --include="*.yaml" --include="*.yml" \
  --exclude="2026-04-21-why-b-compat-mode.md" \
  .
# 期望：0 行
```

### S3: Skill 软链到 Pilot 工程

```bash
cd /Users/cy/MyWorkFactory/workspace/xz-source/stream_keywords_search
mkdir -p .claude/skills
cd .claude/skills
for s in db-migration-baseline db-migration-sql-scan db-migration-test-gap \
         db-migration-dialect-rewrite db-migration-schema-convert db-migration-verify; do
  [ ! -L "$s" ] && ln -s ../../../db-migration-toolkit/skills/$s .
done
ls -la
# 期望：6 条软链全部存在且指向有效目标
```

在 Claude Code 会话里尝试触发一个 Skill（例如 `/db-migration-baseline`），确认可加载。

### S4: 兼容脚本注入与 7 条冒烟 SQL

```bash
psql "<瀚高连接串>" \
  -f /path/to/db-migration-toolkit/docs/references/highgo-v4.1.5-mysql-compat-functions.sql
# 期望：无 ERROR，多条 NOTICE 显示 function created
```

手工跑 Task 8 §2.6 的 7 条冒烟 SQL（4 正向 + 3 反向）。

**关键验证**：
- 正向 1（DATE_FORMAT）**必须**通过；不通过立即上升 R-002 风险，评估是否要改脚本实现
- 反向 5/6（IFNULL timestamp、IF int）**必须**报错；若意外通过说明脚本被私自扩展
- `SELECT mysql_compat_version()` 返回 `1.0.0-highgo-v4.1.5-vendor-2026-04-21`（或工具包 bump 后的版本号）

### S5: Flyway 防护语法冒烟（R-018）

按 Task 9 §3.8 执行 5 类防护语法冒烟 SQL。任一失败记录到 Pilot 工程 `project-docs/fix-issue/` 与工具包 `docs/references/mysql-to-highgo-syntax-mapping.md`。

### S6: Stage 0 skill 可跑通

在 Pilot 工程内调用 Skill `db-migration-baseline`，产出 `project-docs/facts/2026-04-21-db-migration-baseline.md` 骨架。验证：

- 文件生成路径正确
- frontmatter 含 `updated:` 字段
- 内容引用路径指向 highgo-* 而非 gaussdb-*

### S7: 文档交叉引用可达

从 `docs/2026-04-18-master-plan.md` 随机点 5 个链接，确认全部跳得到真实文件。

### S8: 待确认清单核实

跑 Task 17 Step 17.4，对 C1-C10 逐条核实：

| # | 项 | 暂定值 | Pilot 确认后的真实值 |
|---|----|--------|---------------------|
| C1 | 瀚高版本号 | v4.1.5 | |
| C2 | JDBC 坐标 | `<待确认-瀚高-jdbc-坐标>` | |
| C3 | JDBC URL scheme | `jdbc:highgo://` | |
| C4 | Druid dbType | `postgresql` | |
| C5 | 反引号支持 | 不支持 | |
| C6 | `LIMIT m,n` | 不支持 | |
| C7 | `ON DUPLICATE KEY UPDATE` | 不支持 | |
| C8 | 脚本版权 | 内部使用 | |
| C9 | 注入权限 | 建库 owner | |
| C10 | 脚本适用版本 | 仅 v4.1.5 | |

核实结果回灌到工具包相应文档（PR 到 db-migration-toolkit）。

## 出口标准

烟测结论 = **全通过** 的条件：

- [ ] S1 工具包版本 v0.2.0 已发布
- [ ] S2 残留扫描 0 命中
- [ ] S3 6 条软链成功，Skill 可在 Claude Code 中触发
- [ ] S4 正向 4 条冒烟 SQL 全通过，反向 3 条符合预期（报错或预期值）
- [ ] S5 R-018 DDL 防护语法冒烟通过（不支持项已文档化）
- [ ] S6 Stage 0 产出骨架文件正常
- [ ] S7 文档交叉引用全部可达
- [ ] S8 C1-C10 全部核实并回灌

**未通过项处理**：
- S4 正向失败 → 阻塞 Pilot，立即回到工具包修改脚本或文档
- S4 反向意外通过 → 补脚本覆盖列文档，不阻塞
- S5 部分不支持 → 更新 syntax-mapping 状态列，不阻塞
- 其他单项失败 → 修工具包对应文档或 Skill，可继续 Pilot 但需闭环

## 产出物

- 本清单 8 步的实测结果填回本文件
- 发现的问题 PR 到 `db-migration-toolkit`
- 产出 `project-docs/reports/2026-04-XX-pilot-smoke-test-result.md`（Pilot 本地）

## 后续

烟测全通过 → 正式进入 Pilot Stage 0。
```

- [ ] **Step 18.2：提交**

```bash
git add project-docs/plans/2026-04-21-pilot-smoke-test.md
git commit -m "docs(plan): 新增 Pilot 烟测清单，整改完成后首日验证工具包可用性"
```

---

### Task 19: 最终 tag（必选 per C4）

**Files:**
- git repo

- [ ] **Step 19.1：确认状态干净**

```bash
git status
# Expected: working tree clean

grep -rn -E "GaussDB|gaussdb|B 兼容模式|B 模式|B模式" \
  --include="*.md" --include="*.yaml" --include="*.yml" \
  --exclude="2026-04-21-why-b-compat-mode.md" .
# Expected: 0 行
```

- [ ] **Step 19.2：打 annotated tag**

```bash
git tag -a v0.2.0 -m "目标库切换到瀚高 v4.1.5；引入厂家 MySQL 函数兼容脚本"
git tag -l "v0.2.0" -n
# Expected: v0.2.0 的注释显示
```

- [ ] **Step 19.3：最终 log 确认**

```bash
git log --oneline v0.1.0..v0.2.0 2>/dev/null || git log --oneline -30
```

Expected: 约 14 个 commit（含 Task 1 的 4 个子 commit + Task 2-19 各自的 commit，不含 Task 17/19 这两个纯校验/tag 任务）。

---

## 6. Self-Review（内部执行完后执行）

**Coverage check（19 findings + 文件映射表）**：

- ✅ **A1** 脚本命名 v4.1.5：Task 1 Step 1.1 + §1 映射表
- ✅ **A2** rename + 引用单 commit：Task 3–7 每个 Task 内 `git mv + Write + 单 commit`
- ✅ **A3** grep exclude superseded：Task 17 Step 17.1 / Task 19 Step 19.1
- ✅ **A4** 脚本版本管理：Task 1 Step 1.2（注入函数）+ Step 1.7（决策章节）+ Task 7（R-017）+ Task 18 S4（版本标记验证）
- ✅ **A5** 数字加 ⚠️：Task 2 Step 2.2
- ✅ **C1** 逐文件具体替换：Task 12（4 文件 line-level）+ Task 13（3 文件 line-level）
- ✅ **C2** No Placeholders：Task 10（Stage 4 完整重写）+ Task 11（SOP 0/1/5 每处列 before/after）
- ✅ **C3** Edit 拆两次：Task 1 Step 1.9
- ✅ **C4** tag 必选：Task 19 Step 19.2 + Task 15 Step 15.3 注明
- ✅ **C5** 术语表修正：§1 术语统一表条目
- ✅ **C6** Flyway 防护语法：Task 7（R-018）+ Task 9 Step 9.2（§3.8）
- ✅ **C7** R-017 补充：与 A4 合并到 Task 7
- ✅ **T1** 冒烟扩至 7 条：Task 8 Step 8.1
- ✅ **T2** regex 扩展：Task 17 Step 17.1
- ✅ **T3** 链接可达性：Task 17 Step 17.2 / 17.3
- ✅ **T4** Pilot 烟测清单：Task 18
- ✅ **P1** Task 合并：Task 11（合并原 11/12/16 → 1 个 Task）
- ✅ **P2** 并行化策略：§4
- ✅ **P3** Task 1-4 原子：Task 1（1 个逻辑 Task，4 子 commit）

**文件映射表覆盖**：
- 7 条 rename：Task 1（脚本）+ Task 3/4/5/6（references）+ Task 7（risks）
- 3 条新增：Task 1（2 决策 + 1 脚本说明）+ Task 18（Pilot 烟测）
- 1 条状态变更：Task 1 Step 1.9
- 根元文档：Task 15
- project-docs：Task 16
- master-plan：Task 2
- 6 份 SOP：Task 8/9/10/11
- 4 份 templates：Task 12
- 3 份 checklists：Task 13
- 6 份 Skills：Task 14
- fix-issue/README.md：Task 15 Step 15.5

**Placeholder scan**：所有 Task 均给出具体命令、具体文件路径、具体替换内容。v1 留的"Read 当前内容 → Edit 逐条替换"模糊 Task 已在 Task 11/12/13 里落实为 line-level 替换清单。Task 10 Stage 4 整篇草案完整。

**Type consistency**：
- 目标库名统一 "瀚高（HighGo）v4.1.5" / "瀚高 v4.1.5" / "highgo"
- 脚本文件名统一 `highgo-v4.1.5-mysql-compat-functions.{sql,md}`
- 决策文件名 `2026-04-21-target-db-highgo-v4.md` 与 supersedes 引用一致
- Profile 名 `integration-highgo` 贯穿
- Flyway 目录 `db/migration/highgo/` 贯穿
- Tag `stage-5-highgo-migration-done-vX.Y.Z`（工程侧）/ `v0.2.0`（工具包侧）区分清晰

**Risk tracking**：R-001 至 R-018 完整。新增 R-017（脚本版本管理）、R-018（Flyway 防护语法）有对应 Task 落实。

---

## 7. 执行提示

- 推荐用 `superpowers:subagent-driven-development` 逐任务推进，每 Task 或每 Lane 结束 review 一次
- **关键 Task**（Task 1 / 8 / 10 / 15）单独 review，不批量合并
- **并行阶段**（阶段 2 / 3 / 5 / 7，见 §4.3）一次性派发多 subagent，review 时同时检查
- Task 17 的校验脚本要**实际运行**而非靠执行者背书——Bash 输出是证据
- 若启动时用户授权"fix-issue 搬迁合并"（见 §3 Prerequisite），在 Task 11 / 12 / 13 / 14 / 15 / 16 的 commit message 加 `(含 fix-issue 搬迁)` 后缀，并同步更新 `fix-issue/` → `project-docs/fix-issue/` 路径引用
- 出现任何 Pilot 首日才发现的核心假设偏差（如反引号实际支持、或 ON DUPLICATE KEY 意外可用），立即暂停整改，回到 §0 澄清事项重新评估
