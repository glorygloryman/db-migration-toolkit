---
name: db-migration-dialect-rewrite
description: 针对风险矩阵中的某一类差异，给出 MySQL → 瀚高 v4.1.5 的建议改写 diff（区分是否依赖厂家兼容脚本）。只产出建议，不自动改码。Stage 4 方言适配时按类别调用。
---

# db-migration-dialect-rewrite

## 触发场景

- Stage 4 准备处理风险矩阵的某一类差异
- 需要一份"改哪里 / 怎么改"的具体建议清单

## 前置条件

- 已有 `project-docs/facts/YYYY-MM-DD-risk-matrix.md`
- 风险矩阵条目已按类别分组
- 已读 `docs/references/mysql-to-highgo-*.md`
- 已读 `docs/references/highgo-v4.1.5-mysql-compat-functions.md`（厂家兼容脚本覆盖/缺口清单）

## 输入

- 类别名（从下方 Stage 4 差异点分组中取）
- 对应的风险矩阵条目子集

## 差异点清单（Stage 4 分组）

改写建议必须按以下五组分类输出，并在每条建议末尾明确标注「是否依赖兼容脚本」：

### A. 函数层 — 厂家兼容脚本已覆盖（审计为主，不改写）
- `IFNULL(a, b)`（若脚本已提供同名重载）→ 保留原 SQL，增补集成测试
- `IF(cond, a, b)`（若脚本已提供同名重载）→ 保留原 SQL，增补集成测试
- `GROUP_CONCAT`（若脚本已提供）→ 保留原 SQL，验证分隔符与 NULL 处理
- 其他脚本覆盖函数（以 `highgo-v4.1.5-mysql-compat-functions.md` 覆盖表为准）

建议标签：`依赖兼容脚本：是`；动作：**不改 SQL**，但 Stage 1 必须补集成测试验证行为一致。

### B. 函数层 — 脚本覆盖有缺口（必改写）
- `DATE_FORMAT(...)` → 改写为 `TO_CHAR(..., 'YYYY-MM-DD')` 等 PG 格式符，**Pilot 首验证项（R-002）**
- `STR_TO_DATE(...)` → 改写为 `TO_DATE(...)` / `TO_TIMESTAMP(...)`
- `UNIX_TIMESTAMP` / `FROM_UNIXTIME` → 改写为 `EXTRACT(EPOCH FROM ...)` / `TO_TIMESTAMP(epoch)`
- `FIND_IN_SET(x, csv)` → 改写为 `x = ANY(string_to_array(csv, ','))`
- JSON 函数（`JSON_EXTRACT` / `->` / `JSON_CONTAINS` 等）→ 改写为 PG `jsonb` 运算符
- `REGEXP` / `RLIKE` → 改写为 `~` / `~*`

建议标签：`依赖兼容脚本：否（脚本缺口）`；动作：**必须改写 SQL**。

### C. 语法层 — 必改（PG 不兼容）
- 反引号标识符 `` ` `` → 改写为双引号或去引号（小写统一）
- `LIMIT m,n` → 改写为 `LIMIT n OFFSET m`
- `ON DUPLICATE KEY UPDATE` → 改写为 `INSERT ... ON CONFLICT (key) DO UPDATE SET ...`
- `REPLACE INTO` / `INSERT IGNORE` → 改写为 `INSERT ... ON CONFLICT DO NOTHING/UPDATE`
- 多表 `UPDATE t1 JOIN t2 SET ...` → 改写为 `UPDATE t1 SET ... FROM t2 WHERE ...`
- `UPDATE ... LIMIT n` / `DELETE ... LIMIT n` → 改写为子查询 `WHERE ctid IN (SELECT ctid ... LIMIT n)`
- Hint（`STRAIGHT_JOIN` / `USE INDEX` / `FORCE INDEX`）→ 去除，让 PG 优化器决策

建议标签：`依赖兼容脚本：否`；动作：**必须改写 SQL**。

### D. 类型与保留字层 — 必改
- 保留字列名（MySQL 允许但 PG 拒绝的关键字）→ 加双引号或改名
- 大小写敏感：PG 未引用的标识符默认转小写，需统一
- 时区敏感列：`DATETIME` vs `TIMESTAMPTZ` 语义差异

建议标签：`依赖兼容脚本：否`；动作：**必须改写**，并评估跨 Mapper 影响面。

### E. 架构层 — 需方案
- 存储过程 / 触发器 / EVENT → 不自动翻译，上升为单独决策
- 显式隔离级别声明 → 评估是否需要改 PG 的 `SERIALIZABLE` / `READ COMMITTED`
- `SELECT ... FOR UPDATE` / `LOCK IN SHARE MODE` → PG 兼容 `FOR UPDATE` / `FOR SHARE`，确认行为

建议标签：`依赖兼容脚本：否`；动作：**方案决策**（改写 / 业务层上移 / 分方言 Mapper）。

## 执行步骤

### 1. 定位条目

从 risk-matrix.md 中筛选出指定类别的所有条目，并归入上文 A~E 分组。

### 2. 按特性提供改写建议

对每个条目，产出（示例 — B 组）：

```
条目 ID：R-002
文件：src/main/resources/mapper/OrderMapper.xml
位置：第 42 行
原 SQL 片段：
    SELECT DATE_FORMAT(created_at, '%Y-%m-%d') FROM orders

分组：B 组（函数层 — 脚本覆盖有缺口）
依赖兼容脚本：否（脚本缺口）
建议改写（diff 形式）：
    - SELECT DATE_FORMAT(created_at, '%Y-%m-%d') FROM orders
    + SELECT TO_CHAR(created_at, 'YYYY-MM-DD') FROM orders

风险：格式占位符差异大，务必覆盖所有调用点
参考：docs/references/mysql-to-highgo-function-mapping.md#date_format
     docs/references/highgo-v4.1.5-mysql-compat-functions.md（缺口）
```

示例（A 组 — 审计为主）：

```
条目 ID：R-010
文件：src/main/resources/mapper/UserMapper.xml
位置：第 88 行
原 SQL 片段：
    SELECT IFNULL(nickname, '匿名') FROM users

分组：A 组（函数层 — 兼容脚本已覆盖）
依赖兼容脚本：是
建议动作：
  - 不改 SQL
  - Stage 1 必须补集成测试验证脚本重载签名覆盖所有实参类型组合
参考：docs/references/highgo-v4.1.5-mysql-compat-functions.md#ifnull
```

### 3. 无法直接改写的场景

若某条 SQL 无简单等价改写：
- 提示"分方言 Mapper（`databaseId`）"方案
- 提示"SQL 逻辑上移到 Service"方案
- 给出示例代码框架

### 4. 影响面评估

对每个建议，估算：
- 单独文件改动量
- 跨文件连带改动（如列改名影响其他 Mapper）
- 测试影响范围

### 5. 产出清单

写入 `<project>/project-docs/plans/YYYY-MM-DD-stage4-<category>-rewrite.md`：

```markdown
# Stage 4 - <类别> 改写清单

## 概览
- 条目数：N
- 纯验证（不改）：M
- 需改写：K
- 预估工时：X

## 详细建议
<上述每条的详细说明>

## 执行顺序
1. ...
2. ...

## 测试策略
<如何验证改写正确>

## Commit 建议
<建议的 commit 消息格式与拆分>
```

## 输出

- `<project>/project-docs/plans/YYYY-MM-DD-stage4-<category>-rewrite.md`
- 控制台摘要

## 约束

- **绝对不直接改代码**
- 所有建议必须引用 `references/` 作为依据
- 建议 diff 使用 `unified diff` 格式，便于复制应用
- 不确定的建议标 `需验证` 或 `需决策`

## 人工操作流程

1. Skill 产出清单
2. 人工 review，挑选要执行的条目
3. 人工或借助 AI 工具应用 diff
4. 跑集成测试
5. 测试绿后 commit
6. 更新 risk-matrix.md 状态

## 后续步骤

→ 按清单逐类闭环
→ 所有类别闭环后进入 Stage 5
