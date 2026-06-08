# MySQL 方言遗漏自检 Skill 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新建 `db-migration-self-check` skill，在验收完成后扫描项目 SQL 源码，发现可能遗漏的 MySQL 方言，输出结构化报告。

**Architecture:** 独立 skill，遵循现有 skill 文件结构（`SKILL.md` + 辅助规则文件）。检测规则独立为 `self-check-rules.md`，便于随兼容脚本版本升级而更新。被 `work-cycle-auto` 在 Stage 6 verify 之后集成调用。

**Tech Stack:** Claude Code Skill（Markdown 定义，Claude 执行），无编译/构建依赖。

---

## 文件变更清单

| 操作 | 文件路径 | 职责 |
|------|---------|------|
| 创建 | `skills/db-migration-self-check/self-check-rules.md` | 检测规则清单（语法层、函数层、风险模式） |
| 创建 | `skills/db-migration-self-check/SKILL.md` | Skill 主文件（触发、前置、工作流、输出） |
| 修改 | `skills/work-cycle-auto/SKILL.md` | Stage 6 增加 self-check 调用步骤 |

---

### Task 1: 创建 self-check-rules.md

**Files:**
- Create: `skills/db-migration-self-check/self-check-rules.md`

- [ ] **Step 1: 创建目录和规则文件**

创建 `skills/db-migration-self-check/` 目录，写入 `self-check-rules.md`。

文件内容：

```markdown
# MySQL 方言遗漏自检规则清单

> 本文件供 `db-migration-self-check` Skill 逐条匹配。规则会随兼容脚本版本升级而变化，独立于 SKILL.md 维护。
> 白名单来源：`docs/references/highgo-v4.1.5-mysql-compat-functions.md`

---

## A. 语法层 — 必须标记

PostgreSQL 完全不支持以下 MySQL 语法，在已改造项目中不应出现。

| 编号 | 模式 | Grep 关键词/正则 | MySQL 写法 | PG 替代 |
|------|------|-----------------|-----------|---------|
| A1 | 反引号标识符 | `` `[^`]+` `` | `` `col_name` `` | 双引号或去引号 |
| A2 | 双引号字符串字面量（SQL 上下文内） | `"[^"]*"` 在 SQL 片段中 | `"0000"`、`"%"` | 单引号 `'0000'`、`'%'` |
| A3 | LIMIT m,n 分页 | `LIMIT\s+\d+\s*,\s*\d+`、`LIMIT\s*#\{[^}]+\}\s*,\s*#\{` | `LIMIT 10,20` | `LIMIT n OFFSET m` |
| A4 | ON DUPLICATE KEY | `ON\s+DUPLICATE\s+KEY` | `ON DUPLICATE KEY UPDATE` | `ON CONFLICT ... DO UPDATE` |
| A5 | REPLACE INTO | `REPLACE\s+INTO` | `REPLACE INTO t ...` | `ON CONFLICT` 或 DELETE+INSERT |
| A6 | INSERT IGNORE | `INSERT\s+IGNORE` | `INSERT IGNORE INTO` | `ON CONFLICT DO NOTHING` |
| A7 | 多表 UPDATE JOIN | `UPDATE\s+\w+\s+.*\bJOIN\b`（排除子查询） | `UPDATE t1 JOIN t2 SET` | `UPDATE ... FROM ... WHERE` |
| A8 | UPDATE/DELETE + LIMIT | `(?:UPDATE\|DELETE).*\bLIMIT\b` | `DELETE FROM t LIMIT 100` | 子查询限定 |
| A9 | LOCK IN SHARE MODE | `LOCK\s+IN\s+SHARE\s+MODE` | `SELECT ... LOCK IN SHARE MODE` | `FOR SHARE` |
| A10 | STRAIGHT_JOIN | `\bSTRAIGHT_JOIN\b` | `STRAIGHT_JOIN` | 不支持，需调整 |
| A11 | USE/FORCE/IGNORE INDEX | `\b(?:USE\|FORCE\|IGNORE)\s+INDEX\b` | `USE INDEX(idx)` | 不支持 |
| A12 | ORDER BY RAND() | `\bORDER\s+BY\s+RAND\s*\(` | `ORDER BY RAND()` | `RANDOM()` |
| A13 | GROUP BY 非严格模式 | 语义判断：SELECT 列中有非聚合、非 GROUP BY 列 | `SELECT a,b,MAX(c) FROM t GROUP BY a` | PG 要求 b 也在 GROUP BY 中 |
| A14 | PG 保留字冲突 | `\b(?:user\|type\|order\|desc\|group\|role\|level\|status\|current_user\|session_user)\b` 作为列名/表名 | 列名 `user`、`type` | 加双引号或改名 |

---

## B. 函数层 — 兼容白名单（不报，已知缺口给提示）

以下函数已被 `highgo-v4.1.5-mysql-compat-functions.sql` 覆盖，命中时不标记为遗漏，但附带缺口提示。

| 编号 | 函数 | Grep 关键词 | 已知缺口提示 |
|------|------|------------|------------|
| B1 | IFNULL | `\bIFNULL\s*\(` | 用于 timestamp/date 类型时脚本无重载，建议确认 |
| B2 | IF | `\bIF\s*\(`（排除 `IF NOT EXISTS`、`IF EXISTS`） | 用于 numeric/text/int 参数时脚本无重载，建议确认 |
| B3 | DATE_FORMAT | `\bDATE_FORMAT\s*\(` | 存在递归栈溢出风险（R-002），建议确认实际调用场景 |
| B4 | TO_DAYS | `\bTO_DAYS\s*\(` | 与 MySQL 有 1-2 天偏差，建议确认业务精度要求 |
| B5 | MOD | `\bMOD\s*\(` | 除零时返回 NULL（MySQL 抛错），行为不同，建议确认 |

---

## C. 函数层 — 必须标记

以下函数未被兼容脚本覆盖，若出现在已改造项目中，标记为可能遗漏。

| 编号 | 分类 | Grep 关键词 | 说明 |
|------|------|------------|------|
| C1 | 字符串 | `\bSUBSTRING_INDEX\s*\(` | → `SPLIT_PART`（负数需额外处理） |
| C1 | 字符串 | `\bLOCATE\s*\(`、`\bINSTR\s*\(` | 参数顺序与 PG 相反 |
| C1 | 字符串 | `\bFORMAT\s*\(`（MySQL 数值格式化） | → `TO_CHAR` |
| C2 | 聚合/拼接 | `\bGROUP_CONCAT\s*\(` | → `STRING_AGG` |
| C2 | 聚合/拼接 | `\bCONCAT\s*\(` | NULL 行为不同（MySQL 任一 NULL → NULL，PG 按 NULL 空串处理） |
| C3 | 数值 | `\bRAND\s*\(` | → `RANDOM()` |
| C3 | 数值 | `\bROUND\s*\(` | PG 只接受 `(numeric, int)`，需显式 `::numeric` |
| C4 | 日期时间 | `\bUNIX_TIMESTAMP\s*\(` | → `EXTRACT(EPOCH FROM ...)::bigint` |
| C4 | 日期时间 | `\bFROM_UNIXTIME\s*\(` | → `TO_TIMESTAMP(epoch)` |
| C4 | 日期时间 | `\bDATE_ADD\s*\(`、`\bDATE_SUB\s*\(` | → `INTERVAL` 表达式 |
| C4 | 日期时间 | `\bDATEDIFF\s*\(` | → `(d1::date - d2::date)` |
| C4 | 日期时间 | `\bTIMESTAMPDIFF\s*\(` | 无直接等价，需按 UNIT 组合 |
| C4 | 日期时间 | `\bDAYOFWEEK\s*\(` | 周起始不同（MySQL 周日=1，PG 周日=0），需 +1 |
| C4 | 日期时间 | `\bWEEK\s*\(` | mode 参数语义在 PG 无对应 |
| C4 | 日期时间 | `\bCONVERT_TZ\s*\(` | → `AT TIME ZONE` |
| C5 | 流程控制 | `\bISNULL\s*\(`（非 `IS NULL`） | MySQL `ISNULL(expr)` 是函数 → PG `expr IS NULL` 谓词 |
| C6 | JSON | `\bJSON_EXTRACT\s*\(` | → `j->'key'` 或 `j#>'{key}'` |
| C6 | JSON | `\bJSON_OBJECT\s*\(` | → `jsonb_build_object` |
| C6 | JSON | `\bJSON_ARRAY\s*\(` | → `jsonb_build_array` |
| C6 | JSON | `\bJSON_CONTAINS\s*\(` | → `@>` 运算符 |
| C6 | JSON | `\bJSON_SEARCH\s*\(` | → `jsonb_path_query` |
| C6 | JSON | `\bJSON_LENGTH\s*\(` | 按数组/对象分别改写 |
| C7 | 加密 | `\bSHA1\s*\(` | → `encode(digest(str,'sha1'),'hex')` |
| C7 | 加密 | `\bSHA2\s*\(` | → `encode(digest(str,'sha'||bits),'hex')` |
| C7 | 加密 | `\bAES_ENCRYPT\s*\(`、`\bAES_DECRYPT\s*\(` | 默认分组模式/填充不同，密文不兼容 |
| C7 | 加密 | `\bHEX\s*\(` | → `ENCODE(str::bytea, 'hex')` |
| C7 | 加密 | `\bUNHEX\s*\(` | → `DECODE(hex_str, 'hex')` |
| C7 | 加密 | `\bTO_BASE64\s*\(`、`\bFROM_BASE64\s*\(` | → `ENCODE/DECODE` |
| C8 | 系统 | `\bDATABASE\s*\(\)` | → `CURRENT_DATABASE()` |
| C8 | 系统 | `\bLAST_INSERT_ID\s*\(` | → `currval('seq_name')` 或 `INSERT ... RETURNING id` |
| C8 | 系统 | `\bUUID\s*\(` | → `gen_random_uuid()` |
| C8 | 系统 | `\bVERSION\s*\(\)` | 返回格式完全不同 |
| C9 | 正则 | `\bREGEXP\b`、`\bRLIKE\b` | → `~`/`~*` |
| C10 | 隐式类型转换 | `\w+_id\s+LIKE\b`、`\w+_id\)\s+LIKE\b`、`LEFT\s*\(\s*\w+_id`、`RIGHT\s*\(\s*\w+_id` | 整数列参与 LIKE/LEFT/RIGHT → 需显式 `::TEXT` |

---

## D. 风险提示层 — fix-issue 关联

扫描到以下模式时，在报告中附带相关 fix-issue 文件路径供参考。

| 编号 | 风险模式 | Grep 关键词 | 关联 fix-issue |
|------|---------|------------|---------------|
| D1 | DISTINCT ON 排序约束 | `\bDISTINCT\s+ON\b` | 搜索 `fix-issue/` 中含 `DISTINCT ON` 的条目 |
| D2 | 隐式类型转换（字符串 vs 日期/数字） | 字符串参数与日期/数字列比较 | 搜索 `fix-issue/` 中含 `implicit` 或 `隐式` 的条目 |
| D3 | GeneratedKeyHolder 多列返回 | `GeneratedKeyHolder`、`KeyHolder` | 搜索 `fix-issue/` 中含 `GeneratedKeyHolder` 的条目 |
| D4 | 中文错误信息匹配 | `getMessage`、`contains` + 错误信息匹配 | 搜索 `fix-issue/` 中含 `中文` 或 `报错` 的条目 |
| D5 | JPA `::` 与 Hibernate 冲突 | `::` 在 `@Query` 注解中 | 搜索 `fix-issue/` 中含 `Hibernate` 或 `@Query` 的条目 |
| D6 | PageHelper 方言 | `pagehelper`、`PageHelper` | 搜索 `fix-issue/` 中含 `PageHelper` 或 `分页` 的条目 |

---

## 注释过滤

命中后阅读上下文，排除以下场景的命中：

| 类型 | 排除模式 | 说明 |
|------|---------|------|
| XML 注释 | `<!-- ... -->` | MyBatis XML 中的注释块 |
| Java 单行注释 | `// ...` | Java 代码注释 |
| Java 多行注释 | `/* ... */` | Java 代码注释块 |
| SQL 单行注释 | `-- ...` | SQL 行注释 |

以下场景**不排除**（是有效扫描目标）：
- `@Select("...")`、`@Update("...")`、`@Delete("...")`、`@Insert("...")` 注解中的 SQL
- `@Query("...")` 注解中的 JPQL/Native SQL
- MyBatis XML 中 `<select>`、`<insert>`、`<update>`、`<delete>` 标签内的 SQL（含 `<if>`、`<foreach>` 内的动态 SQL）
- JdbcTemplate 参数中的字符串 SQL
```

- [ ] **Step 2: 验证文件写入成功**

Run: `cat skills/db-migration-self-check/self-check-rules.md | head -5`
Expected: 显示文件头部内容

- [ ] **Step 3: 提交**

```bash
git add skills/db-migration-self-check/self-check-rules.md
git commit -m "feat: add self-check rules for MySQL dialect detection"
```

---

### Task 2: 创建 SKILL.md

**Files:**
- Create: `skills/db-migration-self-check/SKILL.md`

- [ ] **Step 1: 写入 SKILL.md**

文件内容：

```markdown
---
name: db-migration-self-check
description: MySQL 方言遗漏自检。在验收完成后扫描项目 SQL 源码（Mapper XML、注解 SQL、内嵌 SQL），发现可能遗漏的 MySQL 方言，输出结构化报告。仅出报告，不阻断交付。
---

# db-migration-self-check

## 触发场景

- Stage 5 验收测试已通过，准备交付
- 需要确认项目中不存在未被改造的 MySQL 方言
- work-cycle-auto Stage 6 验收报告生成后自动调用

## 前置条件

- Stage 4 方言适配已完成
- `docs/references/highgo-v4.1.5-mysql-compat-functions.md` 可用（兼容白名单来源）
- `fix-issue/` 目录可用（风险提示关联来源）

## 扫描范围

| 文件类型 | 匹配方式 | 说明 |
|---------|---------|------|
| MyBatis XML Mapper | `**/*Mapper.xml`、`**/*mapper.xml` | 所有 XML mapper 文件 |
| MyBatis Mapper 接口 | `**/*Mapper.java`、`**/*mapper.java` | 含 `@Select`/`@Update`/`@Delete`/`@Insert` 注解 |
| JPA Repository | `**/*Repository.java` | 含 `@Query` 注解 |
| JdbcTemplate 内嵌 SQL | 搜索含 `"SELECT`/`"INSERT`/`"UPDATE`/`"DELETE` 字符串字面量的 Java 文件 | 非注解形式的内嵌 SQL |

## 执行步骤

### 1. 文件发现

使用 Glob 定位所有目标文件：

```
Glob: **/*Mapper.xml
Glob: **/*mapper.xml
Glob: **/*Mapper.java
Glob: **/*mapper.java
Glob: **/*Repository.java
```

对 Java 文件补充内嵌 SQL 扫描：

```
Grep: "SELECT|"INSERT|"UPDATE|"DELETE  (in .java files)
```

记录文件清单和总数。

### 2. 语法层扫描（A 类）

按照 `self-check-rules.md` 中 A1-A14 的 Grep 关键词/正则，对步骤 1 发现的所有文件逐条扫描。

对每个命中记录：
- 文件路径
- 行号
- 匹配内容（含上下文 2-3 行）
- 规则编号和建议

**注释过滤**：命中后阅读上下文，排除以下场景：
- XML 注释 `<!-- ... -->` 中的内容
- Java 单行注释 `// ...`
- Java 多行注释 `/* ... */`
- SQL 单行注释 `-- ...`

### 3. 函数层扫描（B 类 + C 类）

对步骤 1 发现的所有文件，按照 `self-check-rules.md` 中 B1-B5 和 C1-C10 的 Grep 关键词逐条扫描。

分类处理：
- **B 类（兼容白名单）**：命中标记为"已兼容"，附加已知缺口提示文本
- **C 类（必须标记）**：命中标记为"需确认"，附建议替代写法

### 4. 风险模式扫描（D 类）

扫描 `self-check-rules.md` 中 D1-D6 的风险模式。

对每个命中：
- 在 `fix-issue/` 目录中搜索相关条目
- 附带匹配到的 fix-issue 文件路径

### 5. 汇总过滤

- 去重（同文件同行多次匹配合并）
- 排除确认在注释中的命中
- 统计各分类命中数

### 6. 生成报告

写入 `<project>/project-docs/reports/YYYY-MM-DD-mysql-dialect-self-check.md`，格式如下：

```markdown
# MySQL 方言自检报告

项目：{项目名}
扫描时间：{timestamp}
扫描文件数：{N} 个

## 摘要

| 分类 | 命中数 |
|------|-------|
| 🔴 语法层（需改造） | {n} |
| 🟡 函数层（需确认） | {n} |
| 🟢 兼容函数（已知缺口提示） | {n} |
| ⚠️ 风险模式（fix-issue 关联） | {n} |

## 详细发现

### 🔴 语法层

（逐条列出命中，含文件路径、行号、匹配内容、建议）

### 🟡 函数层（需确认）

（逐条列出命中）

### 🟢 兼容函数（已知缺口提示）

（逐条列出命中 + 缺口提示文本）

### ⚠️ 风险模式

（逐条列出命中 + fix-issue 关联路径）

## 无命中项

以下规则未检测到命中（供确认覆盖完整性）：
- A1 反引号标识符 ✅
- A2 双引号字符串 ✅
- A3 LIMIT m,n ✅
- ...（列出所有规则及其命中状态）
```

## 输出

- `<project>/project-docs/reports/YYYY-MM-DD-mysql-dialect-self-check.md`
- 控制台摘要：命中总数、按分类分布、高风险项 Top 10

## 约束

- **仅出报告，不阻断交付流程**
- 不修改任何代码文件
- 不自动应用修复建议
- 正则匹配假阳性时在报告中标注"需人工复核"
- 扫描覆盖动态 SQL 片段（`<if>` / `<foreach>` 内部 SQL）

## 后续步骤

→ 人工 review 报告
→ 确认命中项是否需要修复
→ 如需修复，回到 Stage 4 处理
```

- [ ] **Step 2: 验证 YAML frontmatter 格式正确**

Run: `head -5 skills/db-migration-self-check/SKILL.md`
Expected: 显示 `---`、`name:`、`description:` 字段

- [ ] **Step 3: 验证规则文件引用路径正确**

确认 `self-check-rules.md` 和 `SKILL.md` 在同一目录，SKILL.md 中引用的路径可访问：
- `self-check-rules.md` — 同目录
- `docs/references/highgo-v4.1.5-mysql-compat-functions.md` — 从 skill 消费方（下游工程）角度看需通过 `{TOOLKIT_PATH}` 前缀访问

- [ ] **Step 4: 提交**

```bash
git add skills/db-migration-self-check/SKILL.md
git commit -m "feat: add db-migration-self-check skill for MySQL dialect detection"
```

---

### Task 3: 更新 work-cycle-auto 集成

**Files:**
- Modify: `skills/work-cycle-auto/SKILL.md` — 在 Stage 6 的 6.4 和 6.5 之间插入新步骤

- [ ] **Step 1: 在 Stage 6 中插入自检步骤**

在 `skills/work-cycle-auto/SKILL.md` 的 Stage 6 部分，找到 `### 6.4 产出验收报告` 的末尾，在其后、`### 6.5 踩坑回灌工具包` 之前，插入以下内容：

```markdown

### 6.4.1 MySQL 方言遗漏自检

调用 Skill `db-migration-self-check`（如已安装），对项目 SQL 源码做 MySQL 方言遗漏扫描。

输出：`<project>/project-docs/reports/YYYY-MM-DD-mysql-dialect-self-check.md`

行为：**仅出报告，不阻断交付**。命中项供人工 review，如需修复回到 Stage 4。

自检报告作为验收报告附件，一并提供给 review 方。
```

- [ ] **Step 2: 验证插入位置正确**

Run: `grep -n "6.4.1\|6.4\|6.5" skills/work-cycle-auto/SKILL.md`
Expected: 6.4、6.4.1、6.5 按顺序出现，6.4.1 在 6.4 和 6.5 之间

- [ ] **Step 3: 验证 Stage 6 出口检查清单无需修改**

Stage 6.7 出口检查是硬检查项（测试通过、schema 完整等），自检是软性报告不进出口检查，确认无需改动 6.7。

- [ ] **Step 4: 提交**

```bash
git add skills/work-cycle-auto/SKILL.md
git commit -m "feat: integrate self-check into work-cycle-auto Stage 6"
```

---

### Task 4: 最终验证

- [ ] **Step 1: 验证目录结构完整**

Run: `find skills/db-migration-self-check -type f`
Expected:
```
skills/db-migration-self-check/SKILL.md
skills/db-migration-self-check/self-check-rules.md
```

- [ ] **Step 2: 验证 SKILL.md 中引用的所有路径在工具包中存在**

检查以下文件/目录存在：
- `skills/db-migration-self-check/self-check-rules.md` — 同目录 ✅
- `docs/references/highgo-v4.1.5-mysql-compat-functions.md` — 工具包内
- `fix-issue/` — 工具包内

Run:
```bash
test -f docs/references/highgo-v4.1.5-mysql-compat-functions.md && echo "OK" || echo "MISSING"
test -d fix-issue && echo "OK" || echo "MISSING"
```

- [ ] **Step 3: 验证 work-cycle-auto 中 self-check 引用正确**

Run: `grep -A3 "6.4.1" skills/work-cycle-auto/SKILL.md`
Expected: 显示 `db-migration-self-check` 引用

- [ ] **Step 4: 按设计 spec 逐项核对覆盖完整性**

对照 `docs/superpowers/specs/2026-06-05-self-check-skill-design.md` 的每个章节：
- [x] §3 扫描范围 — SKILL.md 扫描范围节覆盖
- [x] §4 检测规则 A1-A14 — self-check-rules.md A 节覆盖
- [x] §4 检测规则 B1-B5 — self-check-rules.md B 节覆盖
- [x] §4 检测规则 C1-C10 — self-check-rules.md C 节覆盖
- [x] §4 检测规则 D1-D6 — self-check-rules.md D 节覆盖
- [x] §5 工作流程 — SKILL.md 执行步骤节覆盖
- [x] §6 输出报告格式 — SKILL.md 输出节覆盖
- [x] §7 集成 — work-cycle-auto 6.4.1 覆盖
- [x] §8 文件结构 — 两个文件已创建
