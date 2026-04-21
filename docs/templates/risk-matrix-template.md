---
updated: YYYY-MM-DD
project: <工程名>
stage: 0-kickoff
---

# <工程名> 风险矩阵

## 说明

- 每行一条风险
- **严重度**：🔴 高 / 🟡 中 / 🟢 低
- **状态**：`pending`（待处理）/ `in-progress` / ✅（已闭环）/ `decision-deferred`（有 decisions 记录）/ `blocked`
- **类别**：对应 `references/mysql-to-highgo-*-mapping.md` 中的大类

## 矩阵

| ID | 文件 | 位置 | MySQL 特性 | 类别 | 严重度 | 瀚高预期 | 脚本覆盖 | 建议动作 | 状态 | Commit | 备注 |
|----|------|------|-----------|------|--------|---------|---------|---------|------|--------|------|
| R-001 | UserMapper.xml | 第 42 行 | `ON DUPLICATE KEY UPDATE` | DML | 🔴 | ❌ 不支持 | — | 改 `INSERT ... ON CONFLICT DO UPDATE` | pending | | |
| R-002 | OrderMapper.xml | 第 88 行 | `GROUP_CONCAT` | 函数 | 🟡 | ❌ 不支持 | — | 改 `STRING_AGG` | pending | | |
| R-003 | common.xml | 第 15 行 | `user` 列名 | 保留字 | 🟡 | 需加引号 | — | 列名改 `user_name` 或加引号 | pending | | 影响面较大 |
| R-004 | ReportMapper.java | queryXxx | JSON 查询 | JSON | 🔴 | ❌ 语法不同 | — | 改 PG JSONB 操作符 | pending | | |
| ... | | | | | | | | | | | |

## 按类别汇总

| 类别 | 条目数 | 🔴 | 🟡 | 🟢 |
|------|-------|-----|-----|-----|
| DDL 语法 | | | | |
| DML 语法 | | | | |
| 数据类型 | | | | |
| 保留字 | | | | |
| 字符串函数 | | | | |
| 日期函数 | | | | |
| JSON 函数 | | | | |
| 事务 / 锁 | | | | |
| 存储过程 / 触发器 | | | | |
| 其他 | | | | |

## 高风险项单独罗列

- R-xxx: <简述>
- R-xxx: <简述>

## 产出方式

- 通过 Skill `db-migration-sql-scan` 生成初稿
- 人工 review 与补充
- Stage 4 每闭环一条更新状态
