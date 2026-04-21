---
name: db-migration-verify
description: Stage 5 回归与交付自动化。跑测试、对比 MySQL 基线、生成瀚高 v4.1.5 验收报告骨架。在改造结束时使用。
---

# db-migration-verify

## 触发场景

- Stage 4 所有方言适配完成
- 准备提交 PR / 交付改造
- 需要跑最终回归并出具验收报告

## 前置条件

- 风险矩阵所有条目状态为 ✅ 或 `decision-deferred`
- Stage 1 的测试集仍在、仍绿（MySQL 基线未被破坏）
- 瀚高 v4.1.5 测试环境可用（已安装厂家兼容脚本）

## 执行步骤

### 1. 跑 MySQL 基线回归

```bash
mvn -P integration-mysql-baseline clean test
```

记录：
- 通过 / 失败
- 用例数
- 耗时
- 失败详情（若有）

**预期**：全绿。若有失败，上升阻塞。

### 2. 跑 瀚高 全量回归

```bash
mvn -P integration-highgo clean test
```

记录同上。

**预期**：全绿。若有失败，分类：
- 真实 bug → Stage 4 回头修
- 测试断言与 MySQL 基线不一致 → 评估是否为"声明过的 瀚高 特有行为"

### 3. 用例数对比

对比两轮运行的用例总数、通过数、失败数：

| 维度 | MySQL 基线 | 瀚高 | 差异 |
|------|-----------|---------|------|
| 用例总数 | | | |
| 通过 | | | |
| 失败 | | | |
| 跳过 | | | |
| 耗时（秒） | | | |

耗时爆炸（> 2×）需记录到报告 §7 未解决问题。

### 4. 启动冒烟

```bash
mvn -P integration-highgo spring-boot:run
```

观察：
- 启动成功
- Flyway 执行无错
- 数据源初始化无错
- 无 ERROR 堆栈

### 5. Schema 完整性检查

在 瀚高 中跑：
```sql
SELECT table_name FROM information_schema.tables WHERE table_schema = '<schema>';
SELECT index_name FROM information_schema.statistics WHERE table_schema = '<schema>';
```

对比原 MySQL：
- 表数量
- 索引数量

差异列到报告 §4。

### 6. 生成验收报告

使用 `docs/templates/migration-report-template.md`，填入：
- §1 元信息：**目标库**字段默认填 `瀚高 v4.1.5`（PostgreSQL 系）
- §2 各阶段耗时（从 Git log 读取每阶段起止 commit 推算）
- §3 改造范围汇总（`git diff --stat` 对比 stage-1 基线 tag）
- §4 风险矩阵关闭情况（从 risk-matrix.md 聚合）
- §5 测试对比（上面两轮结果）
- §6 配置变更摘要（对比 yml 文件）
- §7~§10 留骨架，人工补全

写入 `<project>/project-docs/reports/YYYY-MM-DD-highgo-migration-report.md`。

#### 6.1 脚本版本一致性检查（R-017）

执行以下检查并记入报告 §6：

```sql
SELECT highgo_compat_version();
```

对比：
- 目标库返回的脚本版本号
- `db-migration-toolkit` 仓库 `docs/references/highgo-v4.1.5-mysql-compat-functions.sql` 顶注脚本版本
- 本工程 `project-docs/facts/` 中记录的 Stage 2 安装版本

三者必须一致。不一致需在报告 §7 列为未解决问题并阻塞交付。

### 7. 踩坑回灌检查

扫描 `<project>/project-docs/fix-issue/` 中本次改造新增的条目，提示用户：
- 哪些条目是"通用性"的（其他工程也可能遇到）
- 建议推送到 `db-migration-toolkit/fix-issue/`
- 生成迁移命令（`cp` 到工具包仓库对应路径）

### 8. 打 tag

建议命令：
```bash
git tag stage-5-highgo-migration-done-v<工程当前版本>
```

（需用户确认）

## 输出

- `<project>/project-docs/reports/YYYY-MM-DD-highgo-migration-report.md`
- 控制台：两轮测试对比、关键发现、阻塞项（若有）
- 建议的 tag 命令
- 建议回灌到工具包的 fix-issue 清单

## 约束

- **不自动打 tag、不自动推送**，只建议
- 若测试失败，**不前进**，报阻塞
- 报告骨架由 Skill 生成，结论由人工签字

## 人工收尾

- 补全报告 §7 未解决问题
- 补全 §8 回滚方案
- 签字 §10 验收结论
- 创建 PR，贴 [`checklists/migration-pr-checklist.md`](../../docs/checklists/migration-pr-checklist.md) 的勾选结果
- 向 `db-migration-toolkit` 提交 fix-issue PR（若有）
- 向 `db-migration-toolkit` 提 SOP 反馈（Pilot 工程必填）

## 后续步骤

→ PR review
→ 合并
→ 下一个工程启动（从 Stage 0 重来）
